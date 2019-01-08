
`include "bsg_defines.v"

`include "bp_common_me_if.vh"

`include "bp_be_internal_if.vh"
`include "bp_be_rv_defines.vh"

/* TODO: Does not support byte / hword / word / dword loads / stores */
module bp_be_nonsynth_mock_mmu 
 #(parameter vaddr_width_p="inv"
   ,parameter paddr_width_p="inv"
   ,parameter asid_width_p="inv"
   ,parameter branch_metadata_fwd_width_p="inv"

   ,parameter boot_rom_els_p="inv"
   ,parameter boot_rom_width_p="inv"
   ,parameter perfect_p="inv"

   ,localparam lg_boot_rom_els_lp=`BSG_SAFE_CLOG2(boot_rom_els_p)
   ,localparam boot_rom_bytes_lp=boot_rom_els_p*boot_rom_width_p/RV64_byte_width_gp
   ,localparam lg_boot_rom_bytes_lp=`BSG_SAFE_CLOG2(boot_rom_bytes_lp)

   ,localparam mmu_cmd_width_lp=`bp_be_mmu_cmd_width
   ,localparam mmu_resp_width_lp=`bp_be_mmu_resp_width

   ,localparam reg_data_width_lp=RV64_reg_data_width_gp
   ,localparam eaddr_width_lp=RV64_eaddr_width_gp
   ,localparam byte_width_lp=RV64_byte_width_gp
   ,localparam hword_width_lp=RV64_hword_width_gp
   ,localparam word_width_lp=RV64_word_width_gp
   ,localparam dword_width_lp=RV64_dword_width_gp

   ,localparam cache_hit_latency_lp=3
   ,localparam cache_miss_latency_lp=8
   ,localparam lg_cache_miss_latency_lp=`BSG_SAFE_CLOG2(cache_miss_latency_lp)
   )
  (input logic                            clk_i
   ,input logic                           reset_i

   ,input logic [mmu_cmd_width_lp-1:0]    mmu_cmd_i
   ,input logic                           mmu_cmd_v_i
   ,output logic                          mmu_cmd_rdy_o

   ,input logic                           chk_psn_ex_i

   ,output logic [mmu_resp_width_lp-1:0]  mmu_resp_o
   ,output logic                          mmu_resp_v_o
   ,input logic                           mmu_resp_rdy_i

   ,output logic [lg_boot_rom_els_lp-1:0] boot_rom_addr_o
   ,input logic  [boot_rom_width_p-1:0]   boot_rom_data_i
   );

`declare_bp_be_internal_if_structs(vaddr_width_p,paddr_width_p,asid_width_p
                                   ,branch_metadata_fwd_width_p);

// Cast input and output ports 
bp_be_mmu_cmd_s        mmu_cmd, mmu_cmd_dly;
bp_be_mmu_resp_s       mmu_resp;

assign mmu_cmd    = mmu_cmd_i;
assign mmu_resp_o = mmu_resp;

// Internal signals
logic mmu_cmd_v_dly;

logic dmem_r_v, dmem_w_v;
logic [lg_boot_rom_bytes_lp-1:0] dmem_addr;
logic [reg_data_width_lp-1:0] dmem_r_data, dmem_w_data;
logic [cache_hit_latency_lp-1:0] psn_n, psn_r;
logic [lg_boot_rom_els_lp-1:0] boot_count = -'d1; // Even though this is nonsynth, 
                                                   // we're cycling through every value 
                                                   // so initial value is irrelevant.

// Module instantiations
bsg_shift_reg #(.width_p(mmu_cmd_width_lp)
                ,.stages_p(cache_hit_latency_lp-1)
                )
         cmd_dly(.clk(clk_i)
                ,.reset_i(reset_i)
                ,.valid_i(mmu_cmd_v_i)
                ,.data_i(mmu_cmd)
                ,.valid_o(mmu_cmd_v_dly)
                ,.data_o(mmu_cmd_dly)
                );

bsg_mux_segmented #(.segments_p(cache_hit_latency_lp)
                    ,.segment_width_p(1)
                    )
      psn_stage_mux(.data0_i({psn_r[0+:cache_hit_latency_lp-1]
                              ,1'b0})
                    ,.data1_i({1'b1
                               ,1'b1
                               })
                    ,.sel_i({chk_psn_ex_i
                             ,chk_psn_ex_i
                             })
                    ,.data_o(psn_n)
                    );

    bsg_dff #(.width_p(1*cache_hit_latency_lp)
              )
psn_stage_reg(.clk_i(clk_i)
              ,.data_i(psn_n)
              ,.data_o(psn_r)
              );

logic [byte_width_lp-1:0] mem [0:boot_rom_bytes_lp-1];
logic [1:0] do_cache_miss;
logic outstanding_miss;
logic [lg_cache_miss_latency_lp-1:0] cache_miss_count;

assign dmem_addr = mmu_cmd_dly.addr[0+:lg_boot_rom_bytes_lp];
assign dmem_w_data = mmu_cmd_dly.data;
assign dmem_r_v = mmu_cmd_v_dly & (~psn_r[cache_hit_latency_lp-1]) 
                  & ((mmu_cmd_dly.mem_op == e_lb)
                     | (mmu_cmd_dly.mem_op == e_lh)
                     | (mmu_cmd_dly.mem_op == e_lw)
                     | (mmu_cmd_dly.mem_op == e_lbu)
                     | (mmu_cmd_dly.mem_op == e_lhu)
                     | (mmu_cmd_dly.mem_op == e_lwu)
                     | (mmu_cmd_dly.mem_op == e_ld)
                     );
assign dmem_w_v = mmu_cmd_v_dly & (~psn_r[cache_hit_latency_lp-1]) 
                  & ((mmu_cmd_dly.mem_op == e_sb)
                     | (mmu_cmd_dly.mem_op == e_sh)
                     | (mmu_cmd_dly.mem_op == e_sw)
                     | (mmu_cmd_dly.mem_op == e_sd)
                     );

bsg_counter_clear_up #(.max_val_p(cache_miss_latency_lp-1)
                       ,.init_val_p(0)
                       )
             miss_wait(.clk_i(clk_i)
                       ,.reset_i(reset_i)

                       ,.clear_i(cache_miss_count == (cache_miss_latency_lp-1))
                       /* TODO: Extremely ugly -- refactor */
                       ,.up_i((mmu_resp_v_o & (do_cache_miss == 2'b00))
                              | (outstanding_miss & (cache_miss_count != (cache_miss_latency_lp-1)))
                              )
                       ,.count_o(cache_miss_count)
                       );

if(perfect_p) begin
    assign outstanding_miss = 1'b0;
end else begin
    assign outstanding_miss = (mmu_resp_v_o & (do_cache_miss == 2'b00)) | (cache_miss_count > 0);
end

always_comb begin
    mmu_cmd_rdy_o = ~outstanding_miss; 

    mmu_resp_v_o = dmem_r_v | dmem_w_v;

    mmu_resp.exception  = '0;
    mmu_resp.exception.cache_miss_v = (dmem_r_v | dmem_w_v) & outstanding_miss;

    case(mmu_cmd_dly.mem_op)
        e_ld: mmu_resp.data = {mem[dmem_addr+7]
                               ,mem[dmem_addr+6]
                               ,mem[dmem_addr+5]
                               ,mem[dmem_addr+4]
                               ,mem[dmem_addr+3]
                               ,mem[dmem_addr+2]
                               ,mem[dmem_addr+1]
                               ,mem[dmem_addr+0]
                               };
        e_lwu: mmu_resp.data = {32'b0
                                ,mem[dmem_addr+3]
                                ,mem[dmem_addr+2]
                                ,mem[dmem_addr+1]
                                ,mem[dmem_addr+0]
                                };
        e_lhu: mmu_resp.data = {48'b0
                                ,mem[dmem_addr+1]
                                ,mem[dmem_addr+0]
                                };
        e_lbu: mmu_resp.data = {56'b0
                                ,mem[dmem_addr+0]
                                };
        e_lw: mmu_resp.data = {{32{mem[dmem_addr+3][7]}}
                                ,mem[dmem_addr+3]
                                ,mem[dmem_addr+2]
                                ,mem[dmem_addr+1]
                                ,mem[dmem_addr+0]
                                };
        e_lh: mmu_resp.data = {{48{mem[dmem_addr+1][7]}}
                                ,mem[dmem_addr+1]
                                ,mem[dmem_addr+0]
                                };
        e_lb: mmu_resp.data = {{56{mem[dmem_addr+0][7]}}
                                ,mem[dmem_addr+0]
                                };
        default: mmu_resp.data = 'X;
    endcase
end

always_ff @(posedge clk_i) begin 
    if(reset_i) begin
        /* Boot RAM from ROM */
        for(integer i=0;i<boot_rom_width_p/byte_width_lp;i=i+1) begin : rom_load
            mem[boot_rom_width_p/byte_width_lp*boot_count+i] 
                           <= boot_rom_data_i[i*byte_width_lp+:byte_width_lp];
        end
        boot_rom_addr_o    <= boot_count + 'd1;
        boot_count         <= boot_count + 'd1;
        do_cache_miss      <= 2'b1;
    end else begin
        if(outstanding_miss) begin
            do_cache_miss <= 2'b1;
        end else if(mmu_resp_v_o) begin
            do_cache_miss <= do_cache_miss+2'b1;
        end

        if(dmem_w_v) begin
            case(mmu_cmd_dly.mem_op)
                e_sb: begin
                    mem[dmem_addr+0] <= mmu_cmd_dly.data[0*byte_width_lp+:byte_width_lp];
                end
                e_sh: begin
                    mem[dmem_addr+0] <= mmu_cmd_dly.data[0*byte_width_lp+:byte_width_lp];
                    mem[dmem_addr+1] <= mmu_cmd_dly.data[1*byte_width_lp+:byte_width_lp];
                end 
                e_sw: begin
                    mem[dmem_addr+0] <= mmu_cmd_dly.data[0*byte_width_lp+:byte_width_lp];
                    mem[dmem_addr+1] <= mmu_cmd_dly.data[1*byte_width_lp+:byte_width_lp];
                    mem[dmem_addr+2] <= mmu_cmd_dly.data[2*byte_width_lp+:byte_width_lp];
                    mem[dmem_addr+3] <= mmu_cmd_dly.data[3*byte_width_lp+:byte_width_lp];
                end
                e_sd: begin
                    mem[dmem_addr+0] <= mmu_cmd_dly.data[0*byte_width_lp+:byte_width_lp];
                    mem[dmem_addr+1] <= mmu_cmd_dly.data[1*byte_width_lp+:byte_width_lp];
                    mem[dmem_addr+2] <= mmu_cmd_dly.data[2*byte_width_lp+:byte_width_lp];
                    mem[dmem_addr+3] <= mmu_cmd_dly.data[3*byte_width_lp+:byte_width_lp];
                    mem[dmem_addr+4] <= mmu_cmd_dly.data[4*byte_width_lp+:byte_width_lp];
                    mem[dmem_addr+5] <= mmu_cmd_dly.data[5*byte_width_lp+:byte_width_lp];
                    mem[dmem_addr+6] <= mmu_cmd_dly.data[6*byte_width_lp+:byte_width_lp];
                    mem[dmem_addr+7] <= mmu_cmd_dly.data[7*byte_width_lp+:byte_width_lp];
                end
                default: begin
                    mem[dmem_addr+0] <= 'X; 
                    mem[dmem_addr+1] <= 'X; 
                    mem[dmem_addr+2] <= 'X; 
                    mem[dmem_addr+3] <= 'X; 
                    mem[dmem_addr+4] <= 'X; 
                    mem[dmem_addr+5] <= 'X; 
                    mem[dmem_addr+6] <= 'X; 
                    mem[dmem_addr+7] <= 'X; 
                end
            endcase
        end
    end
end

endmodule : bp_be_nonsynth_mock_mmu

