/**
 * bp_me_cce_to_wormhole_link_master.v
 */
 
`include "bp_mem_wormhole.svh"

module bp_me_cce_to_xui
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_me_pkg::*;
 import bsg_dmc_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

   , parameter flit_width_p = "inv"
   , parameter cord_width_p = "inv"
   , parameter cid_width_p  = "inv"
   , parameter len_width_p  = "inv"

   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(flit_width_p)
   )
  (input                                 clk_i
   , input                               reset_i

   // CCE-MEM Interface
   , input  [cce_mem_msg_width_lp-1:0]   mem_cmd_i
   , input                               mem_cmd_v_i
   , output                              mem_cmd_ready_o
                                          
   , output [cce_mem_msg_width_lp-1:0]   mem_resp_o
   , output logic                        mem_resp_v_o
   , input                               mem_resp_yumi_i
                                         
   // xilinx user interface
   , output [paddr_width_p-1:0]          app_addr_o
   , output app_cmd_e                    app_cmd_o
   , output                              app_en_o
   , input                               app_rdy_i
   , output                              app_wdf_wren_o
   , output [cce_block_width_p-1:0]      app_wdf_data_o
   , output [(cce_block_width_p>>3)-1:0] app_wdf_mask_o
   , output                              app_wdf_end_o
   , input                               app_wdf_rdy_i
   , input                               app_rd_data_valid_i
   , input [cce_block_width_p-1:0]       app_rd_data_i
   , input                               app_rd_data_end_i
   );
  
// CCE-MEM interface packets
`declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);

bp_bedrock_cce_mem_msg_s mem_cmd_cast_li, mem_resp_cast_lo;
bp_bedrock_cce_mem_msg_s mem_cmd_cast;

logic wr_cyc, rd_cyc;

logic rd_data_valid;
logic [cce_block_width_p-1:0] rd_data;

assign mem_cmd_cast_li = mem_cmd_i;
assign mem_resp_o = mem_resp_cast_lo;

assign app_addr_o      = mem_cmd_cast_li.header.addr;
assign app_cmd_o       = app_cmd_e'(mem_cmd_cast_li.header.msg_type == e_bedrock_mem_rd);
assign app_en_o        = mem_cmd_v_i & mem_cmd_ready_o;
assign app_wdf_wren_o  = app_en_o & (mem_cmd_cast_li.header.msg_type == e_bedrock_mem_wr);
assign app_wdf_data_o  = mem_cmd_cast_li.data;
assign app_wdf_mask_o  = '0;
assign app_wdf_end_o   = app_wdf_wren_o;

assign mem_cmd_ready_o = ~reset_i & (rd_cyc? 1'b0: app_rdy_i & app_wdf_rdy_i);

assign mem_resp_cast_lo.data            = rd_cyc? rd_data: '0;
assign mem_resp_cast_lo.header.payload  = mem_cmd_cast.header.payload;
assign mem_resp_cast_lo.header.size     = mem_cmd_cast.header.size;
assign mem_resp_cast_lo.header.addr     = mem_cmd_cast.header.addr;
assign mem_resp_cast_lo.header.msg_type = mem_cmd_cast.header.msg_type;

assign mem_resp_v_o = rd_cyc? rd_data_valid: wr_cyc;

always_ff @ (posedge clk_i)
  if(mem_cmd_v_i && mem_cmd_ready_o) mem_cmd_cast <= mem_cmd_cast_li;

always_ff @ (posedge clk_i) begin
  if (reset_i)
    rd_cyc <= 1'b0;
  else if(mem_resp_yumi_i)
    rd_cyc <= 1'b0;
  else if(mem_cmd_v_i && mem_cmd_ready_o)
    rd_cyc <= mem_cmd_cast_li.header.msg_type==e_bedrock_mem_rd;
end

always_ff @ (posedge clk_i) begin
  if (reset_i)
    wr_cyc <= 1'b0;
  else if(mem_cmd_v_i && mem_cmd_ready_o)
    wr_cyc <= (mem_cmd_cast_li.header.msg_type==e_bedrock_mem_wr) & app_rdy_i;
  else
    wr_cyc <= 1'b0;
end

always_ff @ (posedge clk_i) begin
  if (reset_i) begin
    rd_data_valid <= 1'b0;
    rd_data <= '0;
  end
  else if(app_rd_data_valid_i) begin
    rd_data_valid <= 1'b1;
    rd_data <= app_rd_data_i;
  end
  else if(mem_resp_yumi_i)
    rd_data_valid <= 1'b0;
end

endmodule

