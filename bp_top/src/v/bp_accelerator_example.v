/**
 *  bp_accelerator_example.v
 *
 */

module bp_accelerator_example
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bp_be_dcache_pkg::*;  
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_io_if_widths(paddr_width_p, dword_width_p, lce_id_width_p)
    , localparam cfg_bus_width_lp= `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
    )
   (
    input                                     clk_i
    , input                                   reset_i

    , input [lce_id_width_p-1:0]              lce_id_i
    
    , output [lce_cce_req_width_lp-1:0]       lce_req_o
    , output                                  lce_req_v_o
    , input                                   lce_req_ready_i

    , output [lce_cce_resp_width_lp-1:0]      lce_resp_o
    , output                                  lce_resp_v_o
    , input                                   lce_resp_ready_i

    , input [lce_cmd_width_lp-1:0]            lce_cmd_i
    , input                                   lce_cmd_v_i
    , output                                  lce_cmd_yumi_o

    , output [lce_cmd_width_lp-1:0]           lce_cmd_o
    , output                                  lce_cmd_v_o
    , input                                   lce_cmd_ready_i

    // Master link
    , input  [cce_io_msg_width_lp-1:0]        io_cmd_i
    , input                                   io_cmd_v_i
    , output                                  io_cmd_ready_o

    , output [cce_io_msg_width_lp-1:0]        io_resp_o
    , output logic                            io_resp_v_o
    , input                                   io_resp_yumi_i

    
    , input [io_noc_cord_width_p-1:0]         my_cord_i
//    , input [io_noc_cord_width_p-1:0]         dst_cord_i

    );

//dcache_pkt is the cached requests of the accelerator when miss happens
 `declare_bp_be_dcache_pkt_s(bp_page_offset_width_gp, dword_width_p);
 `declare_bp_be_mmu_structs(vaddr_width_p, ptag_width_p, lce_sets_p, cce_block_width_p/8);
   
  bp_be_dcache_pkt_s        dcache_pkt;   
  logic                     dcache_ready, dcache_v;
  logic [dword_width_p-1:0] dcache_data;
  logic                     dcache_tlb_miss, dcache_poison;
  logic [ptag_width_p-1:0]  dcache_ptag;
  logic                     dcache_uncached;
  logic                     dcache_miss_v;
  logic                     load_op_tl_lo, store_op_tl_lo;
  logic                     dcache_pkt_v;
   
  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i.dcache_id = lce_id_i;
  
//  assign dcache_pkt = '0;
 // assign dcache_ptag = '0;
 assign dcache_poison = '0;
 assign dcache_tlb_miss = '0;
 assign dcache_uncached = '0;

 bp_be_dcache 
  #(.bp_params_p(bp_params_p))
  accel_dcache
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.cfg_bus_i(cfg_bus_cast_i)

    ,.dcache_pkt_i(dcache_pkt)
    ,.v_i(dcache_pkt_v)
    ,.ready_o(dcache_ready)

    ,.v_o(dcache_v)
    ,.data_o(dcache_data)

    ,.tlb_miss_i(dcache_tlb_miss)
    ,.ptag_i(dcache_ptag)
    ,.uncached_i(dcache_uncached)

    ,.load_op_tl_o(load_op_tl_lo)
    ,.store_op_tl_o(store_op_tl_lo)

    ,.cache_miss_o(dcache_miss_v)
    ,.poison_i(dcache_poison)

    // LCE-CCE interface
    ,.lce_req_o(lce_req_o)
    ,.lce_req_v_o(lce_req_v_o)
    ,.lce_req_ready_i(lce_req_ready_i)

    ,.lce_resp_o(lce_resp_o)
    ,.lce_resp_v_o(lce_resp_v_o)
    ,.lce_resp_ready_i(lce_resp_ready_i)

    // CCE-LCE interface
    ,.lce_cmd_i(lce_cmd_i)
    ,.lce_cmd_v_i(lce_cmd_v_i & (ac_x_dim_p > 0))
    ,.lce_cmd_yumi_o(lce_cmd_yumi_o)

    ,.lce_cmd_o(lce_cmd_o)
    ,.lce_cmd_v_o(lce_cmd_v_o)
    ,.lce_cmd_ready_i(lce_cmd_ready_i)

    ,.credits_full_o(/*credits_full_o*/)
    ,.credits_empty_o(/*credits_empty_o*/)
  
    );

  // CCE-IO interface packets used for uncached requests-read/write memory mapped CSR
  `declare_bp_io_if(paddr_width_p, dword_width_p, lce_id_width_p);
  
  bp_cce_io_msg_s io_resp_cast_o;
  bp_cce_io_msg_s io_cmd_cast_i;
  
  assign io_cmd_ready_o = 1'b1;
  assign io_cmd_cast_i = io_cmd_i;
  assign io_resp_o = io_resp_cast_o;
//  assign io_resp_v_o = io_cmd_v_i;
   
  logic [63:0] resp_data, start_cmd, input_a_ptr, input_b_ptr, input_len, res_status, res_ptr, res_len, operation, dot_product_res;
  logic [63:0] vector_a [0:7];
  logic [63:0] vector_b [0:7];
  logic [2:0] len_a_cnt, len_b_cnt; 
  logic load, second_operand, done; 
  bp_cce_io_msg_payload_s    resp_payload;
  bp_cce_io_req_size_e       resp_size;
  logic [paddr_width_p-1:0]  resp_addr;
  bp_cce_io_cmd_type_e       resp_msg;
  logic [63:0] product_temp [0:7];
  logic [63:0] sum_1_temp [0:3];
  logic [63:0] sum_2_temp [0:1];
  logic [63:0] product_sum_temp;

   logic [63:0] a, b, c ,d, e,f,g,h,z;
   assign {a, b, c ,d, e,f,g,h,z} = {vector_a[0], vector_a[1], vector_b[0], vector_b[1], product_temp [0], product_temp[1], sum_1_temp[0], sum_2_temp[0], product_sum_temp};
   
 
  bp_local_addr_s  local_addr_li;
  assign local_addr_li = io_cmd_cast_i.addr;

  typedef enum logic [3:0] {
    RESET
    , WAIT_START
    , WAIT_FETCH                            
    , FETCH
    , WAIT_DCACHE_1
    , WAIT_DCACHE_2
    , FETCH_MISS
    , WAIT_DCACHE_MISS
    , CHECK_B_LEN
    , FETCH_SECOND
    , CHECK_A_LEN
    , OPERATION
    , WB_RESULT
    , DONE
  } state_e;
  state_e state_r, state_n;

 
always_ff @(posedge clk_i) begin
  io_resp_v_o  <= io_cmd_v_i;
  vector_a[len_a_cnt] <= (dcache_v & load & ~second_operand) ? dcache_data : vector_a[len_a_cnt];
  len_a_cnt <= (dcache_v & load & ~second_operand) ? len_a_cnt + 1'b1 : len_a_cnt;
  vector_b[len_b_cnt]  <= (dcache_v & load & second_operand) ? dcache_data : vector_b[len_b_cnt];
  len_b_cnt <= (dcache_v & load & second_operand) ? len_b_cnt + 1'b1 : len_b_cnt;
 
  if (reset_i || done)
    begin
      start_cmd            <= '0;
      input_a_ptr          <= '0;
      input_b_ptr          <= '0;
      input_len            <= '0;
//      res_status           <= '0;
      res_ptr              <= '0;
      res_len              <= '0;
      operation            <= '0;
      io_resp_v_o          <= '0;
      len_a_cnt            <= '0;
      len_b_cnt            <= '0;
      vector_a             <= '{default:64'd0};
      vector_b             <= '{default:64'd0}; 
    end 
  if (state_r == DONE) 
    begin
       start_cmd  <= '0;
     end
  else if (io_cmd_v_i & (io_cmd_cast_i.msg_type == e_cce_io_wr))
    begin
      resp_size    <= io_cmd_cast_i.size;
       resp_payload <= io_cmd_cast_i.payload;
       resp_addr    <= io_cmd_cast_i.addr;
       resp_msg     <= io_cmd_cast_i.msg_type;
      unique 
      case (local_addr_li.addr)
        20'h00000 : input_a_ptr <= io_cmd_cast_i.data;
        20'h00040 : input_b_ptr <= io_cmd_cast_i.data;
        20'h00080 : input_len  <= io_cmd_cast_i.data;
        20'h000c0 : start_cmd  <= io_cmd_cast_i.data;
//      20'h00100 : res_status 
        20'h00140 : res_ptr    <= io_cmd_cast_i.data;
        20'h00180 : res_len    <= io_cmd_cast_i.data;
        20'h00200 : operation  <= io_cmd_cast_i.data;
        default : begin end
      endcase 
    end 
   else if (io_cmd_v_i & (io_cmd_cast_i.msg_type == e_cce_io_rd))
     begin
       resp_size    <= io_cmd_cast_i.size;
       resp_payload <= io_cmd_cast_i.payload;
       resp_addr    <= io_cmd_cast_i.addr;
       resp_msg     <= io_cmd_cast_i.msg_type;
      unique 
      case (local_addr_li.addr)
        20'h00000 : resp_data <= input_a_ptr;
        20'h00040 : resp_data <= input_b_ptr;
        20'h00080 : resp_data <= input_len;
        20'h000c0 : resp_data <= start_cmd;
        20'h00100 : resp_data <= res_status; 
        20'h00140 : resp_data <= res_ptr;
        20'h00180 : resp_data <= res_len;
        20'h00200 : resp_data <= operation;
        default : begin end
      endcase 
    end
  end
 
//  bp_cce_io_msg_s io_resp_lo; 
  assign io_resp_cast_o = '{msg_type       : resp_msg
                            ,addr          : resp_addr
                            ,payload       : resp_payload
                            ,size          : resp_size
                            ,data          : resp_data  };

   
  always_ff @(posedge clk_i) begin
     if (reset_i) begin
        state_r <= RESET;
     end else begin
        state_r <= state_n;
     end
  end

  bp_be_mmu_vaddr_s v_addr;
  assign v_addr = load ? (second_operand ? (input_b_ptr+len_b_cnt*8) : (input_a_ptr+len_a_cnt*8)) : res_ptr;
 
  always_comb begin
    state_n = state_r; 
    case (state_r)
      RESET: begin
         state_n = reset_i ? RESET : WAIT_START;
         res_status = '0;
         dcache_ptag = '0;
         dcache_pkt = '0;
         dcache_pkt_v = '0;
         load = 0;
         second_operand = 0;
         done = 0;
      end
      WAIT_START: begin
         state_n = start_cmd ? WAIT_FETCH : WAIT_START;
         res_status = '1;
         dcache_ptag = '0;
         dcache_pkt = '0;
         dcache_pkt_v = '0;
         load = 1;
         second_operand= 0;
         done = 0;
      end
      WAIT_FETCH: begin
         state_n = dcache_ready ? FETCH : WAIT_FETCH;
         res_status = '0;
         dcache_ptag = '0;
         dcache_pkt = '0;
         dcache_pkt_v = '0;
         done = 0;
      end
      FETCH: begin
        dcache_ptag = {(ptag_width_p-vtag_width_p)'(0), v_addr.tag};
        dcache_pkt.opcode = load ? e_dcache_opcode_ld : e_dcache_opcode_sd;
        dcache_pkt.data = load ? '0 : dot_product_res; 
        dcache_pkt.page_offset = {v_addr.index, v_addr.offset};
        res_status = '0;
        dcache_pkt_v = '1;
        state_n = WAIT_DCACHE_1;
        done = 0;
      end
      WAIT_DCACHE_1: begin
        state_n = WAIT_DCACHE_2;
        res_status = '0;
        dcache_ptag = {(ptag_width_p-vtag_width_p)'(0), v_addr.tag};
        dcache_pkt.opcode = load ? e_dcache_opcode_ld : e_dcache_opcode_sd;
        dcache_pkt.page_offset = {v_addr.index, v_addr.offset};
        dcache_pkt.data = load ? '0 : dot_product_res;
        dcache_pkt_v = '0;
        done = 0;
      end
      WAIT_DCACHE_2: begin
        state_n = dcache_miss_v ? WAIT_DCACHE_2 : (dcache_v ? (load ? (second_operand ? CHECK_B_LEN : CHECK_A_LEN) : DONE) : FETCH_MISS);
        res_status = '0;
        dcache_ptag = {(ptag_width_p-vtag_width_p)'(0), v_addr.tag};
        dcache_pkt.opcode = load ? e_dcache_opcode_ld : e_dcache_opcode_sd;
        dcache_pkt.data = load ? '0 : dot_product_res;
        dcache_pkt.page_offset = {v_addr.index, v_addr.offset};
        dcache_pkt_v = '0;
        done = 0;
      end
      FETCH_MISS: begin
        dcache_ptag = {(ptag_width_p-vtag_width_p)'(0), v_addr.tag};
        dcache_pkt.opcode = load ? e_dcache_opcode_ld : e_dcache_opcode_sd;
        dcache_pkt.data = load ? '0 : dot_product_res;
        dcache_pkt.page_offset = {v_addr.index, v_addr.offset};
        res_status = '0;
        dcache_pkt_v = '1;
        state_n = WAIT_DCACHE_MISS;
        done = 0;
      end
      WAIT_DCACHE_MISS: begin
        state_n = dcache_v ? (load ? (second_operand ? CHECK_B_LEN : CHECK_A_LEN) : DONE) : WAIT_DCACHE_MISS;
        res_status = '0;
        dcache_ptag = {(ptag_width_p-vtag_width_p)'(0), v_addr.tag};
        dcache_pkt.opcode = load ? e_dcache_opcode_ld : e_dcache_opcode_sd;
        dcache_pkt.data = load ? '0 : dot_product_res;
        dcache_pkt.page_offset = {v_addr.index, v_addr.offset};
        dcache_pkt_v = '0;
        done = 0;
      end
      CHECK_A_LEN: begin
        state_n = (len_a_cnt == input_len) ? FETCH_SECOND : WAIT_FETCH;
        res_status = '0;
        dcache_ptag = {(ptag_width_p-vtag_width_p)'(0), v_addr.tag};
        dcache_pkt.opcode = load ? e_dcache_opcode_ld : e_dcache_opcode_sd;
        dcache_pkt.data = load ? '0 : dot_product_res;
        dcache_pkt.page_offset = {v_addr.index, v_addr.offset};
        dcache_pkt_v = '0;
        done = 0;
      end
      FETCH_SECOND: begin
        state_n = WAIT_FETCH;
        res_status = '0;
        dcache_ptag = {(ptag_width_p-vtag_width_p)'(0), v_addr.tag};
        dcache_pkt.opcode = load ? e_dcache_opcode_ld : e_dcache_opcode_sd;
        dcache_pkt.data = load ? '0 : dot_product_res;
        dcache_pkt.page_offset = {v_addr.index, v_addr.offset};
        dcache_pkt_v = '0;
        second_operand= 1;
        done = 0;
      end
      CHECK_B_LEN: begin
         state_n= (len_b_cnt == input_len) ? OPERATION : WAIT_FETCH;
         res_status = '0;
        dcache_ptag = {(ptag_width_p-vtag_width_p)'(0), v_addr.tag};
        dcache_pkt.opcode = load ? e_dcache_opcode_ld : e_dcache_opcode_sd;
        dcache_pkt.data = load ? '0 : dot_product_res;
        dcache_pkt.page_offset = {v_addr.index, v_addr.offset};
        dcache_pkt_v = '0;
        second_operand= 1;
        done = 0;
      end
      OPERATION: begin
        state_n = WB_RESULT;
        res_status = '0;
        dcache_pkt = '0;
        dcache_pkt_v = '0;
        load = 0;
        second_operand= 0;
        dot_product_res = product_sum_temp;
        done = 0;
      end
      WB_RESULT: begin
        load = 0;
        state_n = WAIT_FETCH;
        second_operand= 0;
        done = 0;
      end
      DONE: begin
        state_n = RESET;
        res_status = 1;
        dcache_ptag = '0;
        dcache_pkt = '0;
        dcache_pkt_v = '0;
        load = 0;
        second_operand= 0;
        done = 1; 
      end
    endcase 
  end 
   
 //dot product unit
for (genvar i=0; i < 8; i++)
  begin : product
    assign product_temp [i]= vector_a[i] * vector_b[i];
  end
for (genvar i=0; i < 4; i++)
  begin : sum_1
    assign sum_1_temp [i]= product_temp[2*i] + product_temp[2*i+1];
  end

for (genvar i=0; i < 2; i++)
  begin : sum_2
    assign sum_2_temp [i]= sum_1_temp[2*i] + sum_1_temp[2*i+1];
  end

  assign product_sum_temp = sum_2_temp[0] + sum_2_temp [1];
  
endmodule

