/**
 *
 * Name:
 *   bp_be_regfile.v
 *
 * Description:
 *   Synchronous register file wrapper for integer and floating point RISC-V registers. Inlcudes
 *     logic to maintain the source register values during pipeline stalls.
 *
 * Notes:
 *   - Is it okay to continuously read on stalls? There's no switching, so energy may not
 *       be an issue.  An alternative would be to save the read data, but that's more flops / power
 *   - Should we read the regfile at all for x0? The memory will be a power of 2 size, so it comes
 *       down to if writing / reading x0 and then muxing is less power than checking x == 0 on input.
 */

module bp_be_regfile
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

   , parameter data_width_p = "inv"
   , parameter read_ports_p = "inv"
   )
  (input                                            clk_i
   , input                                          reset_i

   // rs read bus
   , input [read_ports_p-1:0]                       rs_r_v_i
   , input [read_ports_p-1:0][reg_addr_width_p-1:0] rs_addr_i
   , output [read_ports_p-1:0][data_width_p-1:0]    rs_data_o

   // rd write bus
   , input                                          rd_w_v_i
   , input [reg_addr_width_p-1:0]                   rd_addr_i
   , input [data_width_p-1:0]                       rd_data_i
   );

  localparam rf_els_lp = 2**reg_addr_width_p;
  logic [read_ports_p-1:0] rs_v_li;
  logic [read_ports_p-1:0][reg_addr_width_p-1:0] rs_addr_li;
  logic [read_ports_p-1:0][data_width_p-1:0] rs_data_lo;
  if (read_ports_p == 2)
    begin : tworonew
      bsg_mem_2r1w_sync
       #(.width_p(data_width_p), .els_p(rf_els_lp))
       rf
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.w_v_i(rd_w_v_i)
         ,.w_addr_i(rd_addr_i)
         ,.w_data_i(rd_data_i)

         ,.r0_v_i(rs_v_li[0])
         ,.r0_addr_i(rs_addr_li[0])
         ,.r0_data_o(rs_data_lo[0])

         ,.r1_v_i(rs_v_li[1])
         ,.r1_addr_i(rs_addr_li[1])
         ,.r1_data_o(rs_data_lo[1])
         );
    end
  else if (read_ports_p == 3)
    begin : threeronew
      bsg_mem_3r1w_sync
       #(.width_p(data_width_p), .els_p(rf_els_lp))
       rf
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.w_v_i(rd_w_v_i)
         ,.w_addr_i(rd_addr_i)
         ,.w_data_i(rd_data_i)

         ,.r0_v_i(rs_v_li[0])
         ,.r0_addr_i(rs_addr_li[0])
         ,.r0_data_o(rs_data_lo[0])

         ,.r1_v_i(rs_v_li[1])
         ,.r1_addr_i(rs_addr_li[1])
         ,.r1_data_o(rs_data_lo[1])

         ,.r2_v_i(rs_v_li[2])
         ,.r2_addr_i(rs_addr_li[2])
         ,.r2_data_o(rs_data_lo[2])
         );
    end
  else
    begin : error
      $fatal(1, "Error: unsupported number of read ports");
    end

  // Save the written data for forwarding
  logic [data_width_p-1:0] rd_data_r;
  bsg_dff
   #(.width_p(data_width_p))
   rd_reg
    (.clk_i(clk_i)
     ,.data_i(rd_data_i)
     ,.data_o(rd_data_r)
     );

  for (genvar i = 0; i < read_ports_p; i++)
    begin : bypass
      logic fwd_rs_r, rs_r_v_r;
      logic [data_width_p-1:0] fwd_data_lo;
      wire fwd_rs = rd_w_v_i & rs_r_v_i[i] & (rd_addr_i == rs_addr_i[i]);
      bsg_dff
       #(.width_p(2))
       rs_r_v_reg
        (.clk_i(clk_i)

         ,.data_i({fwd_rs, rs_r_v_i[i]})
         ,.data_o({fwd_rs_r, rs_r_v_r})
         );
      assign fwd_data_lo = fwd_rs_r ? rd_data_r : rs_data_lo[i];

      logic [reg_addr_width_p-1:0] rs_addr_r;
      bsg_dff_en
       #(.width_p(reg_addr_width_p))
       rs_addr_reg
        (.clk_i(clk_i)
         ,.en_i(rs_r_v_i[i])

         ,.data_i(rs_addr_i[i])
         ,.data_o(rs_addr_r)
         );

      logic [data_width_p-1:0] rs_data_n, rs_data_r;
      wire replace_rs = rd_w_v_i & (rs_addr_r == rd_addr_i);
      assign rs_data_n = replace_rs ? rd_data_i : fwd_data_lo;
      bsg_dff_en
       #(.width_p(data_width_p))
       rs_data_reg
        (.clk_i(clk_i)

         ,.en_i(rs_r_v_r | replace_rs)
         ,.data_i(rs_data_n)
         ,.data_o(rs_data_r)
         );

      // Technically, this is unnecessary, since most hardened SRAMs still write correctly
      //   on read-write conflicts, and the read is handled by forwarding. But this avoids
      //   nasty warnings and possible power sink.
      assign rs_v_li[i] = rs_r_v_i[i] & ~fwd_rs;
      assign rs_addr_li[i] = rs_addr_i[i];
      // Forward if we read/wrote, else pass out the register data
      assign rs_data_o[i] = rs_r_v_r ? fwd_data_lo : rs_data_r;
    end

endmodule

