/**
 *
 * Name:
 *   bp_me_nonsynth_dev_tracer.sv
 *
 * Description:
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_dev_tracer
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter trace_file_p = "dev"

    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
  )
  (input                                            clk_i
   , input                                          reset_i
   , input                                          freeze_i

   , input [core_id_width_p-1:0]                    id_i

   // CCE-MEM Interface
   // BedRock Stream protocol: ready&valid
   , input [mem_fwd_header_width_lp-1:0]            mem_fwd_header_i
   , input [dword_width_gp-1:0]                     mem_fwd_data_i
   , input                                          mem_fwd_v_i
   , input                                          mem_fwd_ready_and_i
   , input                                          mem_fwd_last_i

   , input [mem_rev_header_width_lp-1:0]            mem_rev_header_i
   , input [dword_width_gp-1:0]                     mem_rev_data_i
   , input                                          mem_rev_v_i
   , input                                          mem_rev_ready_and_i
   , input                                          mem_rev_last_i
  );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);

  `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);

  integer file;
  string file_name;

  wire delay_li = reset_i | freeze_i;
  always_ff @(negedge delay_li)
    begin
      file_name = $sformatf("%s_%x.trace", trace_file_p, id_i);
      file      = $fopen(file_name, "w");
    end

  // Tracer
  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      if (mem_fwd_v_i & mem_fwd_ready_and_i) begin
        $fdisplay(file, "%12t |: MEM FWD addr[%H] msg[%b] size[%b]"
                 , $time
                 , mem_fwd_header_cast_i.addr
                 , mem_fwd_header_cast_i.msg_type.fwd
                 , mem_fwd_header_cast_i.size
                 );
        if (mem_fwd_header_cast_i.msg_type.fwd inside {e_bedrock_mem_uc_wr, e_bedrock_mem_wr}) begin
          $fdisplay(file, "%12t |: MEM FWD DATA last[%0b] %H"
                   , $time
                   , mem_fwd_last_i
                   , mem_fwd_data_i
                   );
        end
      end
      if (mem_rev_v_i & mem_rev_ready_and_i) begin
        $fdisplay(file, "%12t |: MEM REV addr[%H] msg[%b] size[%b]"
                 , $time
                 , mem_rev_header_cast_i.addr
                 , mem_rev_header_cast_i.msg_type.rev
                 , mem_rev_header_cast_i.size
                 );
        if (mem_rev_header_cast_i.msg_type.rev inside {e_bedrock_mem_uc_rd, e_bedrock_mem_rd}) begin
          $fdisplay(file, "%12t |: MEM REV DATA last[%0b] %H"
                   , $time
                   , mem_rev_last_i
                   , mem_rev_data_i
                   );
        end
      end
    end // reset & trace
  end // always_ff

endmodule
