`include "bp_common_defines.svh"

module bp_be_nonsynth_satp_checker
 #(parameter ppn_width_p = 28)
  (input clk_i
   , input reset_i
   , input write_v_i
   , input [11:0] write_addr_i
   , input [63:0] write_data_i
   , input [63:0] satp_next_i
   , input [63:0] satp_read_i
   );

  wire satp_write = write_v_i & (write_addr_i == `CSR_ADDR_SATP);
  wire supported_mode = write_data_i[63:60] inside {4'd0, 4'd8};
  wire rejected_write = satp_write & ~supported_mode;
  // Bare requires all remaining fields to be zero in software.
  wire accepted_write = satp_write
    & ((write_data_i == 64'b0) | (write_data_i[63:60] == 4'd8));

  // BlackParrot implements no ASIDs and retains the physical root PPN bits.
  wire [63:0] accepted_readback =
    {write_data_i[63:60], 16'b0, {(44-ppn_width_p){1'b0}}, write_data_i[0+:ppn_width_p]};

  // Check the complete architectural value before compression and after storage.
  reject_preserves_next: assert property
    (@(posedge clk_i) disable iff (reset_i)
     rejected_write |-> (satp_next_i == satp_read_i));

  reject_preserves_register: assert property
    (@(posedge clk_i) disable iff (reset_i)
     rejected_write |=> (satp_read_i == $past(satp_read_i)));

  idle_preserves_register: assert property
    (@(posedge clk_i) disable iff (reset_i)
     !satp_write |=> (satp_read_i == $past(satp_read_i)));

  accept_forwards_write: assert property
    (@(posedge clk_i) disable iff (reset_i)
     accepted_write |-> (satp_next_i == write_data_i));

  accept_updates_register: assert property
    (@(posedge clk_i) disable iff (reset_i)
     accepted_write |=> (satp_read_i == $past(accepted_readback)));

  // Non-vacuity: rejection is reachable from both supported stored modes.
  reject_from_bare: cover property
    (@(posedge clk_i) disable iff (reset_i)
     rejected_write && (satp_read_i[63:60] == 4'd0));

  reject_from_sv39: cover property
    (@(posedge clk_i) disable iff (reset_i)
     rejected_write && (satp_read_i[63:60] == 4'd8));

  bare_update: cover property
    (@(posedge clk_i) disable iff (reset_i)
     accepted_write && (write_data_i[63:60] == 4'd0) && (satp_next_i != satp_read_i));

  sv39_update: cover property
    (@(posedge clk_i) disable iff (reset_i)
     accepted_write && (write_data_i[63:60] == 4'd8) && (satp_next_i != satp_read_i));

endmodule

bind bp_be_csr bp_be_nonsynth_satp_checker
 #(.ppn_width_p(paddr_width_p-page_offset_width_gp))
 satp_checker
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.write_v_i(csr_w_v_li)
   ,.write_addr_i(csr_addr_li)
   ,.write_data_i(csr_data_li)
   ,.satp_next_i(satp_li)
   ,.satp_read_i(satp_lo)
   );
