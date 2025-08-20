/**
 *
 * Name:
 *   bp_me_nonsynth_dev_tracer.sv
 *
 * Description:
 *
 */

`include "bp_common_test_defines.svh"
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_dev_tracer
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter `BSG_INV_PARAM(els_p)
   , parameter `BSG_INV_PARAM(reg_data_width_p)
   , parameter `BSG_INV_PARAM(reg_addr_width_p)

   , parameter string trace_str_p = ""
   `declare_bp_common_if_widths(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   )
  (input                                              clk_i
   , input                                            reset_i
   , input                                            en_i
   , input [cfg_bus_width_lp-1:0]                     cfg_bus_i
   );

  localparam reg_size_width_lp = `BSG_WIDTH(`BSG_SAFE_CLOG2(reg_data_width_p/8));
  localparam lg_els_lp = `BSG_SAFE_CLOG2(els_p);

  `declare_bp_common_if(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  // snoop
  wire [els_p-1:0] r_v = bp_me_bedrock_register.r_v_o;
  wire [els_p-1:0] w_v = bp_me_bedrock_register.w_v_o;
  wire [reg_addr_width_p-1:0] addr = bp_me_bedrock_register.addr_o;
  wire [reg_size_width_lp-1:0] size = bp_me_bedrock_register.size_o;
  wire [reg_data_width_p-1:0] wdata = bp_me_bedrock_register.data_o;
  wire [els_p-1:0][reg_data_width_p-1:0] rdata = bp_me_bedrock_register.data_i;

  // process
  wire bp_cfg_bus_s cfg_bus = cfg_bus_i;
  wire [core_id_width_p-1:0] mhartid = cfg_bus.core_id;
  wire [lg_els_lp-1:0] r_sel = $clog2(r_v);
  wire [lg_els_lp-1:0] w_sel = $clog2(w_v);

  logic [els_p-1:0] r_v_r; always_ff @(posedge clk_i) r_v_r <= r_v;
  logic [reg_addr_width_p-1:0] addr_r; always_ff @(posedge clk_i) addr_r <= addr;
  logic [reg_size_width_lp-1:0] size_r; always_ff @(posedge clk_i) size_r <= size;
  wire [lg_els_lp-1:0] r_sel_r = $clog2(r_v_r);
  wire [reg_data_width_p-1:0] rdata_r = rdata[r_sel_r];

  // record
  `declare_bp_tracer_control(clk_i, reset_i, en_i, trace_str_p, mhartid);
  always_ff @(posedge clk_i)
    if (is_go)
      begin
        if (|w_v)
          $fdisplay(file, "%8t |: write register %x addr[%H] size[%b] data[%x]"
                    , $time, w_sel, addr, size, wdata
                    );

        if (|r_v_r)
          $fdisplay(file, "%8t |: read register %x addr[%H] size[%b] data[%x]"
                    , $time, r_sel_r, addr_r, size_r, rdata_r
                    );
      end

endmodule
