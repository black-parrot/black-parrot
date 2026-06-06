/**
 *
 * Name:
 *   bp_me_bedrock_register_amo.sv
 *
 * Description:
 *   AMO-capable variant of bp_me_bedrock_register.
 *   Starts from the original register adapter and adds a minimal AMO
 *   read->write flow for synchronous register backends.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_bedrock_register_amo
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   // The width of the registers. Currently, must all be the same.
   , parameter reg_data_width_p = dword_width_gp
   // The address width of the registers. For addresses less than paddr_width_p,
   //   the upper bits of the paddr are ignored for matching purposes
   , parameter reg_addr_width_p = paddr_width_p
   // The size of the register
   , parameter reg_size_width_p = `BSG_WIDTH(`BSG_SAFE_CLOG2(reg_data_width_p/8))
   // The number of registers to control
   , parameter els_p = 1

   // We would like to use unpacked here, but Verilator 4.202 does not support it
   // Unsupported tristate construct: INITITEM
   //// An unpacked array of int register base addresses
   ////   e.g. localparam int base_addr_lp [1:0] = '{0xf00bad, 0x00cafe}
   //// Can also accept pattern matches such as 0x8???
   //, parameter int base_addr_p [els_p-1:0] = '{0}
   , parameter [els_p-1:0][reg_addr_width_p-1:0] base_addr_p = '0
   )
  (input                                            clk_i
   , input                                          reset_i

   // Network-side BP-Stream interface
   , input [mem_fwd_header_width_lp-1:0]            mem_fwd_header_i
   , input [bedrock_fill_width_p-1:0]               mem_fwd_data_i
   , input                                          mem_fwd_v_i
   , output logic                                   mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0]     mem_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]        mem_rev_data_o
   , output logic                                   mem_rev_v_o
   , input                                          mem_rev_ready_and_i


   // Synchronous register read/write interface.
   // Actually 1rw, but expose both ports to prevent unnecessary and gates
   // Assume latch last read behavior at registers, and do not have
   //   unnecessary read/writes. This could be parameterizable, but requires
   //   a read register in this module to do and maintain helpfulness
   , output logic [els_p-1:0]                       r_v_o
   , output logic [els_p-1:0]                       w_v_o
   , output logic [reg_addr_width_p-1:0]            addr_o
   , output logic [reg_size_width_p-1:0]            size_o
   , output logic [reg_data_width_p-1:0]            data_o
   , input [els_p-1:0][reg_data_width_p-1:0]        data_i
   );

  if (reg_data_width_p != 64) $error("BedRock interface data width must be 64-bits");
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_o(bp_bedrock_mem_rev_header_s, mem_rev_header);

  bp_bedrock_mem_fwd_header_s mem_fwd_header_li;
  logic [bedrock_fill_width_p-1:0] mem_fwd_data_li;
  logic mem_fwd_v_li, mem_fwd_yumi_li;
  bsg_one_fifo
   #(.width_p($bits(bp_bedrock_mem_fwd_header_s)+bedrock_fill_width_p))
   fwd_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({mem_fwd_data_i, mem_fwd_header_cast_i})
     ,.v_i(mem_fwd_v_i)
     ,.ready_and_o(mem_fwd_ready_and_o)

     ,.data_o({mem_fwd_data_li, mem_fwd_header_li})
     ,.v_o(mem_fwd_v_li)
     ,.yumi_i(mem_fwd_yumi_li)
     );

  logic v_r;
  wire req_is_wr = (mem_fwd_header_li.msg_type == e_bedrock_mem_wr);
  wire req_is_rd = (mem_fwd_header_li.msg_type == e_bedrock_mem_rd);
  wire req_is_amo = (mem_fwd_header_li.msg_type == e_bedrock_mem_amo);
  wire v_n = mem_fwd_v_li & ~v_r;
  logic [els_p-1:0] r_v_r;
  bsg_dff_reset_set_clear
   #(.width_p(1+els_p), .clear_over_set_p(1))
   v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     // We also track reads which don't match to prevent deadlock
     ,.set_i({v_n, r_v_o})
     ,.clear_i({(els_p+1){mem_fwd_yumi_li}})
     ,.data_o({v_r, r_v_r})
     );

  logic [reg_data_width_p-1:0] rdata_lo;
  bsg_mux_one_hot
   #(.width_p(reg_data_width_p), .els_p(els_p))
   rmux_oh
    (.data_i(data_i)
     ,.sel_one_hot_i(r_v_r)
     ,.data_o(rdata_lo)
     );

  logic [els_p-1:0] addr_match;
  wire reg_write = mem_fwd_v_li & ~v_r & req_is_wr;
  wire reg_read  = mem_fwd_v_li & ~v_r & (req_is_rd | req_is_amo);
  wire [reg_data_width_p-1:0] reg_data = mem_fwd_data_li;
  wire [reg_addr_width_p-1:0] reg_addr = mem_fwd_header_li.addr;
  wire [reg_size_width_p-1:0] reg_size = mem_fwd_header_li.size;
  for (genvar i = 0; i < els_p; i++)
    begin : abcd
      assign addr_match[i] = (reg_addr inside {base_addr_p[i]});
    end

  // Minimal AMO tracking FSM: capture the AMO request, then issue a single
  // write pulse after read data becomes available.
  logic amo_pending_r, amo_write_done_r;
  logic [els_p-1:0] amo_match_r;
  logic [reg_addr_width_p-1:0] amo_addr_r;
  logic [reg_size_width_p-1:0] amo_size_r;
  logic [reg_data_width_p-1:0] amo_operand_r;
  bp_bedrock_wr_subop_e amo_subop_r;

  logic lr_v_r;
  logic [reg_addr_width_p-1:0] lr_addr_r;
  wire sc_success = lr_v_r & (lr_addr_r == amo_addr_r);
  wire [reg_data_width_p-1:0] sc_resp_data = {{(reg_data_width_p-1){1'b0}}, ~sc_success};

  logic [reg_data_width_p-1:0] atomic_alu_result;
  always_comb
    begin
      unique case (amo_subop_r)
        e_bedrock_amoswap: atomic_alu_result = amo_operand_r;
        e_bedrock_amoand : atomic_alu_result = amo_operand_r & rdata_lo;
        e_bedrock_amoor  : atomic_alu_result = amo_operand_r | rdata_lo;
        e_bedrock_amoxor : atomic_alu_result = amo_operand_r ^ rdata_lo;
        e_bedrock_amoadd : atomic_alu_result = amo_operand_r + rdata_lo;
        e_bedrock_amomin : atomic_alu_result =
          ($signed(amo_operand_r) < $signed(rdata_lo)) ? amo_operand_r : rdata_lo;
        e_bedrock_amomax : atomic_alu_result =
          ($signed(amo_operand_r) > $signed(rdata_lo)) ? amo_operand_r : rdata_lo;
        e_bedrock_amominu: atomic_alu_result = (amo_operand_r < rdata_lo) ? amo_operand_r : rdata_lo;
        e_bedrock_amomaxu: atomic_alu_result = (amo_operand_r > rdata_lo) ? amo_operand_r : rdata_lo;
        default          : atomic_alu_result = rdata_lo;
      endcase
    end

  wire amo_do_write = amo_pending_r & ~amo_write_done_r
                      & (amo_subop_r != e_bedrock_amolr)
                      & ((amo_subop_r != e_bedrock_amosc) | sc_success);

  wire [reg_data_width_p-1:0] amo_wdata =
    (amo_subop_r == e_bedrock_amosc) ? amo_operand_r : atomic_alu_result;

  assign r_v_o = {els_p{reg_read}} & addr_match;
  assign w_v_o = ({els_p{reg_write}} & addr_match) | ({els_p{amo_do_write}} & amo_match_r);
  assign addr_o = amo_do_write ? amo_addr_r : reg_addr;
  assign size_o = amo_do_write ? amo_size_r : reg_size;
  assign data_o = amo_do_write ? amo_wdata : reg_data;

  assign mem_rev_header_cast_o = mem_fwd_header_li;
  assign mem_rev_v_o = v_r;
  assign mem_fwd_yumi_li = mem_rev_ready_and_i & mem_rev_v_o;

  logic [reg_data_width_p-1:0] resp_data_lo;
  always_comb
    begin
      resp_data_lo = rdata_lo;
      if (amo_pending_r & (amo_subop_r == e_bedrock_amosc))
        resp_data_lo = sc_resp_data;
    end

  always_ff @(posedge clk_i)
    begin
      if (reset_i)
        begin
          amo_pending_r <= 1'b0;
          amo_write_done_r <= 1'b0;
          amo_match_r <= '0;
          amo_addr_r <= '0;
          amo_size_r <= '0;
          amo_operand_r <= '0;
          amo_subop_r <= e_bedrock_store;
          lr_v_r <= 1'b0;
          lr_addr_r <= '0;
        end
      else
        begin
          if (v_n & req_is_amo)
            begin
              amo_pending_r <= 1'b1;
              amo_write_done_r <= 1'b0;
              amo_match_r <= addr_match;
              amo_addr_r <= reg_addr;
              amo_size_r <= reg_size;
              amo_operand_r <= reg_data;
              amo_subop_r <= mem_fwd_header_li.subop;
            end

          if (amo_do_write)
            amo_write_done_r <= 1'b1;

          if (mem_fwd_yumi_li)
            begin
              amo_pending_r <= 1'b0;
              amo_write_done_r <= 1'b0;

              if (req_is_amo)
                begin
                  if (amo_subop_r == e_bedrock_amolr)
                    begin
                      lr_v_r <= 1'b1;
                      lr_addr_r <= amo_addr_r;
                    end
                  else
                    lr_v_r <= 1'b0;
                end
              else if (req_is_wr)
                lr_v_r <= 1'b0;
            end
        end
    end

  localparam sel_width_lp = `BSG_SAFE_CLOG2(reg_data_width_p>>3);
  localparam size_width_lp = `BSG_SAFE_CLOG2(sel_width_lp);
  bsg_bus_pack
   #(.in_width_p(reg_data_width_p), .out_width_p(bedrock_fill_width_p))
   fwd_bus_pack
    (.data_i(resp_data_lo)
     ,.sel_i('0) // We are aligned
     ,.size_i(mem_rev_header_cast_o.size[0+:size_width_lp])
     ,.data_o(mem_rev_data_o)
     );

  // synopsys translate_off
  always_ff @(negedge clk_i)
    begin
      assert(reset_i !== '0 || ~mem_fwd_v_li || (v_r | ~req_is_wr | |w_v_o) || (v_r | ~(req_is_rd|req_is_amo) | |r_v_o))
        else $error("Command to non-existent register: %x", addr_o);
    end
  // synopsys translate_on

endmodule
