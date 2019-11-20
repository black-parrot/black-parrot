
module bp_addr_map
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [mem_noc_cord_width_p-1:0]          my_cord_i

   // Command physical address
   , input [paddr_width_p-1:0]               paddr_i
   , input                                   dram_en_i

   // Destination router coordinates
   , output logic [mem_noc_did_width_p-1:0]  dst_did_o
   , output logic [mem_noc_cord_width_p-1:0] dst_cord_o
   , output logic [mem_noc_cid_width_p-1:0]  dst_cid_o
   );

localparam core_id_width_lp = `BSG_SAFE_CLOG2(num_core_p);

function [mem_noc_cord_width_p-1:0] core_id_to_cord;
  input [core_id_width_lp-1:0] core_id;
  begin
    core_id_to_cord[0+:mem_noc_x_cord_width_p]                      = core_id % mem_noc_x_dim_p;
    core_id_to_cord[mem_noc_x_cord_width_p+:mem_noc_y_cord_width_p] = core_id / mem_noc_x_dim_p + 1;
  end
endfunction

wire [mem_noc_y_cord_width_p-1:0] my_y_cord_li = my_cord_i[mem_noc_x_cord_width_p+:mem_noc_y_cord_width_p];
wire [mem_noc_x_cord_width_p-1:0] my_x_cord_li = my_cord_i[0+:mem_noc_x_cord_width_p];

wire [mem_noc_cord_width_p-1:0] io_cord_li = {'0, my_x_cord_li};

wire [mem_noc_cord_width_p-1:0] coproc_cord_li  = {my_y_cord_li, my_x_cord_li + 1'b1};
wire [mem_noc_cord_width_p-1:0] dram_cord_li    = {my_y_cord_li + 1'b1, my_x_cord_li};

wire [mem_noc_did_width_p-1:0] paddr_did_li = paddr_i[paddr_width_p-1-:mem_noc_did_width_p];

// By default, just send as far right as possible
wire [mem_noc_did_width_p-1:0] default_did_li = '1;

always_comb
  if (paddr_did_li == '0)
    casez (paddr_i)
      cfg_link_dev_base_addr_gp:
        begin
          dst_did_o = '0;
          dst_cord_o = core_id_to_cord(paddr_i[cfg_addr_width_p+:cfg_core_width_p]);
          dst_cid_o  = 2'd1;
        end
      mipi_reg_base_addr_gp:
        begin
          dst_did_o = '0;
          dst_cord_o = core_id_to_cord(paddr_i[2+:core_id_width_lp]);
          dst_cid_o  = 2'd2;
        end
      mtimecmp_reg_base_addr_gp:
        begin
          dst_did_o = '0;
          dst_cord_o = core_id_to_cord(paddr_i[3+:core_id_width_lp]);
          dst_cid_o  = 2'd2;
        end
      mtime_reg_addr_gp:
        begin
          // Currently, we can only write into our own mtime register
          dst_did_o = '0;
          dst_cord_o = my_cord_i;
          dst_cid_o  = 2'd2;
        end
      host_dev_base_addr_gp:
        begin
          // Default, send way far east
          dst_did_o = default_did_li;
          dst_cord_o = io_cord_li;
          dst_cid_o  = '0;
        end
      cce_dev_base_addr_gp:
        begin
          // Currently, we can only write into our own CCE address
          //   We should encode a 'core id', similar to config link
          dst_did_o = '0;
          dst_cord_o = my_cord_i;
          dst_cid_o  = '0;
        end
      plic_dev_base_addr_gp: 
        begin
          dst_did_o = '0;
          dst_cord_o = core_id_to_cord(paddr_i[3+:core_id_width_lp]);
          dst_cid_o  = '0;
        end
      //coproc_dev_base_addr_gp:
      //  begin
      //    // Coproc is assumed to be due east
      //    dst_did_o = '0;
      //    dst_cord_o = coproc_cord_li;
      //    dst_cid_o  = '0;
      //  end
      default: // DRAM 
        begin
          // TODO: DRAM is either enabled, or we send to next chip
          //   Should we make a more flexible scheme?
          dst_did_o = dram_en_i ? '0 : default_did_li;
          dst_cord_o = dram_en_i ? dram_cord_li : io_cord_li;
          dst_cid_o  = '0;
        end
    endcase
  else
    begin
      dst_did_o = paddr_i[paddr_width_p-1-:mem_noc_did_width_p];
      dst_cord_o = io_cord_li;
      dst_cid_o  = '0;
    end

endmodule

