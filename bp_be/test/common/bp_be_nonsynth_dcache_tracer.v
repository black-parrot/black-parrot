
module bp_be_nonsynth_dcache_tracer
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)

   // Default parameters
   , parameter dcache_trace_file_p = "dcache"

   // Calculated parameters
   , localparam mhartid_width_lp      = `BSG_SAFE_CLOG2(num_core_p)
   )
  (input                                                   clk_i
   , input                                                 reset_i
   , input                                                 freeze_i

   , input [mhartid_width_lp-1:0]                          mhartid_i
   , input                                                 v_tv_r
   , input                                                 cache_miss_o

   , input [paddr_width_p-1:0]                             paddr_tv_r
   , input                                                 uncached_tv_r
   , input                                                 load_op_tv_r
   , input                                                 store_op_tv_r
   , input                                                 lr_op_tv_r
   , input                                                 sc_op_tv_r
   , input [dword_width_p-1:0]                             load_data
   , input [dword_width_p-1:0]                             store_data
   );

integer file;
string file_name;

logic freeze_r;
always_ff @(posedge clk_i)
  freeze_r <= freeze_i;

initial
  if (freeze_r & ~freeze_i)
    begin
      file_name = $sformatf("%s_%x.trace", dcache_trace_file_p, mhartid_i);
      file      = $fopen(file_name, "w");
    end

string op;

always_comb
  begin
    if (lr_op_tv_r)
      op = "[lr]";
    else if (sc_op_tv_r)
      op = "[sc]";
    else if (load_op_tv_r)
      op = "[load]";
    else if (store_op_tv_r)
      op = "[store]";
    else
      op = "[null]";
  end

wire [dword_width_p-1:0] data_li = store_op_tv_r ? store_data : load_data;
always_ff @(posedge clk_i)
  begin
    if (v_tv_r)
      begin
        $fwrite(file, "[%t] %s addr: %x data: %x uncached: %x, miss: %x\n", $time, op, paddr_tv_r, data_li, uncached_tv_r, cache_miss_o);
      end
  end

endmodule

