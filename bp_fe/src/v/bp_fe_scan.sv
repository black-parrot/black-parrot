/*
 * bp_fe_instr_scan.v
 *
 * Instr scan check if the intruction is aligned, compressed, or normal instruction.
 * The entire block is implemented in combinational logic, achieved within one cycle.
*/

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_scan
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam decode_width_lp = $bits(bp_fe_decode_s)
   , localparam scan_width_lp = $bits(bp_fe_scan_s)
   )
  (input                                             assembled_v_i
   , input [vaddr_width_p-1:0]                       assembled_pc_i
   , input [fetch_cinstr_p-1:0][cinstr_width_gp-1:0] assembled_instr_i
   , input [branch_metadata_fwd_width_p-1:0]         assembled_br_metadata_fwd_i
   , input [fetch_ptr_p-1:0]                         assembled_count_i
   , input                                           assembled_partial_i
   , output logic [fetch_ptr_p-1:0]                  assembled_count_o
   , output logic                                    assembled_yumi_o

   , output logic                                    fetch_v_o
   , output logic [vaddr_width_p-1:0]                fetch_pc_o
   , output logic [fetch_width_p-1:0]                fetch_instr_o
   , output logic [branch_metadata_fwd_width_p-1:0]  fetch_br_metadata_fwd_o
   , output logic [fetch_ptr_p-1:0]                  fetch_count_o
   , output logic                                    fetch_partial_o
   , output logic [scan_width_lp-1:0]                fetch_scan_o
   , output logic                                    fetch_startup_o
   , output logic                                    fetch_catchup_o
   , output logic                                    fetch_rebase_o
   , output logic                                    fetch_linear_o
   , input                                           fetch_taken_i
   , input                                           fetch_yumi_i
   );

  `bp_cast_o(bp_fe_scan_s, fetch_scan);

  bp_fe_decode_s [fetch_cinstr_p : 0] decode_lo;
  logic [fetch_cinstr_p :-1][cinstr_width_gp-1:0] instr;
  logic [fetch_cinstr_p :-1] full1;
  logic [fetch_cinstr_p : 0] branch;
  logic [fetch_cinstr_p : 0] complete;

  assign instr = {assembled_instr_i, 16'b0};
  assign full1[-1] = 1'b0;
  for (genvar i = 0; i <= fetch_cinstr_p; i++)
    begin : scan
      rv64_instr_rtype_s curr_instr;

      wire is_full1 = assembled_v_i && (i < assembled_count_i) &&  full1[i];
      wire is_full2 = assembled_v_i && (i < assembled_count_i) &&              full1[i-1];
      wire is_comp  = assembled_v_i && (i < assembled_count_i) && !full1[i] & !full1[i-1];

      assign curr_instr = is_full2 ? {instr[i], instr[i-1]} : instr[i];
      wire is_br = is_full2 && curr_instr inside {`RV64_BRANCH};
      wire is_jal = is_full2 && curr_instr inside {`RV64_JAL};
      wire is_jalr = is_full2 && curr_instr inside {`RV64_JALR};

      wire is_link_dest = curr_instr.rd_addr inside {5'h1, 5'h5};
      wire is_link_src  = curr_instr.rs1_addr inside {5'h1, 5'h5};
      wire is_link_match = is_link_src & is_link_dest & (curr_instr.rd_addr == curr_instr.rs1_addr);
      wire is_call = (is_jal | is_jalr) & is_link_dest;
      wire is_return = is_jalr & is_link_src & !is_link_match;

      wire is_cbr = is_comp && curr_instr inside {`RV64_CBEQZ, `RV64_CBNEZ};
      wire is_cj = is_comp && curr_instr inside {`RV64_CJ};
      wire is_cjr = is_comp && curr_instr inside {`RV64_CJR};
      wire is_cjalr = is_comp && curr_instr inside {`RV64_CJALR};

      wire is_clink_dest  = is_cjalr;
      wire is_clink_src   = curr_instr.rd_addr inside {5'h1, 5'h5};
      wire is_clink_match = is_clink_src & is_clink_dest & {curr_instr.rd_addr == 5'h1};
      wire is_ccall = (is_cj | is_cjr | is_cjalr) & is_clink_dest;
      wire is_creturn = (is_cjr | is_cjalr) & is_clink_src & !is_clink_match;

      logic [vaddr_width_p-1:0] imm;
      always_comb
               if (is_br ) imm = `rv64_signext_b_imm(curr_instr ) + ((i - 1'b1) << 1'b1);
        else   if (is_jal) imm = `rv64_signext_j_imm(curr_instr ) + ((i - 1'b1) << 1'b1);
        else   if (is_cj ) imm = `rv64_signext_cj_imm(curr_instr) + ((i - 1'b0) << 1'b1);
        else   // if (is_cbr )
                           imm = `rv64_signext_cb_imm(curr_instr) + ((i - 1'b0) << 1'b1);

      assign full1[i] = &curr_instr[0+:2] && !full1[i-1];
      assign branch[i] = is_br | is_jal | is_jalr | is_cbr | is_cj | is_cjr | is_cjalr;
      assign complete[i] = is_comp || is_full2;
      assign decode_lo[i] =
       '{br      : is_br | is_cbr
         ,jal    : is_jal | is_cj
         ,jalr   : is_jalr | is_cjr | is_cjalr
         ,call   : is_call | is_ccall
         ,_return: is_return | is_creturn
         ,imm    : imm
         ,full1  : is_full1
         ,full2  : is_full2
         ,comp   : is_comp
         };
    end

  logic any_complete;
  logic [fetch_sel_p-1:0] complete_addr;
  wire [fetch_cinstr_p-1:0] complete_vector = complete;
  bsg_priority_encode
   #(.width_p(fetch_cinstr_p), .lo_to_hi_p(0))
   complete_pe
    (.i(complete_vector)
     ,.addr_o(complete_addr)
     ,.v_o(any_complete)
     );
  wire [fetch_ptr_p-1:0] linear_sel   = fetch_cinstr_p - 1'b1 - complete_addr;
  wire [fetch_ptr_p-1:0] linear_count = any_complete ? linear_sel + 1'b1 : '0;

  logic any_branch;
  logic [fetch_sel_p-1:0] branch_sel;
  wire [fetch_cinstr_p-1:0] branch_vector = branch;
  bsg_priority_encode
   #(.width_p(fetch_cinstr_p), .lo_to_hi_p(1))
   branch_sel_pe
    (.i(branch_vector)
     ,.addr_o(branch_sel)
     ,.v_o(any_branch)
     );
  wire [fetch_ptr_p-1:0] branch_count = any_branch ? branch_sel + 1'b1 : '0;

  logic any_last_branch;
  logic [fetch_ptr_p-1:0] last_branch_addr;
  wire [fetch_cinstr_p :0] last_branch_vector = branch;
  bsg_priority_encode
   #(.width_p(fetch_cinstr_p+1), .lo_to_hi_p(0))
   second_branch_pe
    (.i(last_branch_vector)
     ,.addr_o(last_branch_addr)
     ,.v_o(any_last_branch)
     );

  wire [fetch_ptr_p-1:0] last_branch_sel = fetch_cinstr_p - last_branch_addr;
  wire [fetch_ptr_p-1:0] last_branch_count = any_last_branch ? last_branch_sel + 1'b1 : '0;
  wire double_branch = any_branch && (branch_sel != last_branch_sel);

  bp_fe_decode_s branch_decode_lo;
  bsg_mux
   #(.width_p(decode_width_lp), .els_p(fetch_cinstr_p+1))
   branch_decode_mux
    (.data_i(decode_lo)
     ,.sel_i(branch_sel)
     ,.data_o(branch_decode_lo)
     );

  bp_fe_decode_s next_decode_lo;
  wire [fetch_ptr_p-1:0] next_sel = any_branch ? branch_sel+1'b1 : linear_sel+1'b1;
  bsg_mux
   #(.width_p(decode_width_lp), .els_p(fetch_cinstr_p+1))
   next_decode_mux
    (.data_i(decode_lo)
     ,.sel_i(next_sel)
     ,.data_o(next_decode_lo)
     );
  wire [fetch_ptr_p-1:0] next_count = any_complete ? next_sel : 1'b1;

  wire assembled_startup = ~any_branch & ~fetch_taken_i & ('0               == linear_count);
  wire assembled_catchup =  any_branch & ~fetch_taken_i & (assembled_count_i > branch_count) & ~double_branch;
  wire assembled_rebase  =  any_branch & ~fetch_taken_i & (assembled_count_i > branch_count) &  double_branch;
  wire assembled_linear  = ~any_branch                  & (assembled_count_i > linear_count);
  always_comb
    begin
      fetch_scan_cast_o = '0;
      fetch_scan_cast_o.linear_imm = (linear_count + 1'd1) << 3'b1;
      fetch_scan_cast_o.ntaken_imm = (next_count + 1'd0) << 3'b1;
      fetch_scan_cast_o.taken_imm  = branch_decode_lo.imm;

      if (fetch_yumi_i)
        begin
          fetch_scan_cast_o.br = branch_decode_lo.br;
          fetch_scan_cast_o.jal = branch_decode_lo.jal;
          fetch_scan_cast_o.jalr = branch_decode_lo.jalr;
          fetch_scan_cast_o.call = branch_decode_lo.call;
          fetch_scan_cast_o._return = branch_decode_lo._return;
        end
    end

  assign fetch_v_o = assembled_v_i;
  assign fetch_pc_o = assembled_pc_i;
  assign fetch_instr_o = assembled_instr_i;
  assign fetch_br_metadata_fwd_o = assembled_br_metadata_fwd_i;
  assign fetch_partial_o = assembled_partial_i;
  assign fetch_count_o = any_branch ? branch_count : linear_count;
  assign fetch_startup_o = fetch_yumi_i & assembled_startup;
  assign fetch_catchup_o = fetch_yumi_i & assembled_catchup;
  assign fetch_rebase_o = fetch_yumi_i & assembled_rebase;
  assign fetch_linear_o = fetch_yumi_i & assembled_linear;

  assign assembled_count_o = any_branch ? (assembled_rebase | fetch_taken_i) ? assembled_count_i : branch_count : linear_count;
  assign assembled_yumi_o = fetch_yumi_i;

endmodule

