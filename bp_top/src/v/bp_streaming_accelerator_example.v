/**
 *  bp_streaming_accelerator_example.v
 *
 */

module bp_streaming_accelerator_example
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bp_be_dcache_pkg::*;  
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    , parameter bp_enable_accelerator_p = 0
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
    , localparam cfg_bus_width_lp= `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
    )
   (
    input                                     clk_i
    , input                                   reset_i

    , input [lce_id_width_p-1:0]              lce_id_i
    
    , input  [cce_mem_msg_width_lp-1:0]       io_cmd_i
    , input                                   io_cmd_v_i
    , output                                  io_cmd_ready_o

    , output [cce_mem_msg_width_lp-1:0]       io_resp_o
    , output logic                            io_resp_v_o
    , input                                   io_resp_yumi_i

    , output [cce_mem_msg_width_lp-1:0]       io_cmd_o
    , output logic                            io_cmd_v_o
    , input                                   io_cmd_yumi_i

    , input [cce_mem_msg_width_lp-1:0]        io_resp_i
    , input                                   io_resp_v_i
    , output                                  io_resp_ready_o
    );



  // CCE-IO interface is used for uncached requests-read/write memory mapped CSR
   `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
   
  bp_cce_mem_msg_s io_resp_cast_o;
  bp_cce_mem_msg_s io_cmd_cast_i;
  bp_cce_mem_msg_s io_resp_cast_i;
  bp_cce_mem_msg_s io_cmd_cast_o;
  
  assign io_cmd_ready_o = 1'b1;
  assign io_resp_ready_o = 1'b1;
   
  assign io_cmd_cast_i = io_cmd_i;
  assign io_resp_o = io_resp_cast_o;
  assign io_cmd_o = io_cmd_cast_o;
  assign io_resp_cast_i = io_resp_i;
 
  logic [63:0] resp_data, start_cmd, input_a_ptr, input_b_ptr, input_len, 
               res_status, res_ptr, res_len, operation, dot_product_res;
  logic [63:0] vector_a [0:7];
  logic [63:0] vector_b [0:7]; 
  logic [2:0] len_a_cnt, len_b_cnt; 
  logic load, second_operand, done;
  logic [paddr_width_p-1:0]  resp_addr;

  //chnage the names
  logic [63:0] product_res [0:7];
  logic [63:0] sum_l1 [0:3];
  logic [63:0] sum_l2 [0:1];
  logic [63:0] dot_product_temp;
   
  bp_cce_mem_msg_payload_s  resp_payload;
  bp_cce_mem_req_size_e     resp_size;  
  bp_cce_mem_cmd_type_e     resp_msg;
  bp_local_addr_s          local_addr_li;
  
  assign local_addr_li = io_cmd_cast_i.addr;
  assign io_resp_cast_o = '{msg_type       : resp_msg
                            ,addr          : resp_addr
                            ,payload       : resp_payload
                            ,size          : resp_size
                            ,data          : resp_data  };

   
  logic [vaddr_width_p-1:0] v_addr; 
  assign v_addr = load ? (second_operand ? (input_b_ptr+len_b_cnt*8) 
                                         : (input_a_ptr+len_a_cnt*8)) 
                       : res_ptr;

   
  typedef enum logic [3:0]{
    RESET
    , WAIT_START
    , WAIT_FETCH                            
    , FETCH
    , WAIT_DCACHE_C1
    , WAIT_DCACHE_C2
    , CHECK_VEC1_LEN
    , FETCH_VEC2
    , CHECK_VEC2_LEN
    , WB_RESULT
    , DONE
  } state_e;
  state_e state_r, state_n;
 
  always_ff @(posedge clk_i) begin
    io_resp_v_o  <= io_cmd_v_i;
    vector_a[len_a_cnt] <= (io_resp_v_i & load & ~second_operand) ? io_resp_cast_i.data : vector_a[len_a_cnt];
    len_a_cnt <= (io_resp_v_i & load & ~second_operand) ? len_a_cnt + 1'b1 : len_a_cnt;
    vector_b[len_b_cnt]  <= (io_resp_v_i & load & second_operand) ? io_resp_cast_i.data : vector_b[len_b_cnt];
    len_b_cnt <= (io_resp_v_i & load & second_operand) ? len_b_cnt + 1'b1 : len_b_cnt;
    
    if(reset_i)
      state_r <= RESET;
    else
      state_r <= state_n;
 
    if (reset_i || done) begin
      start_cmd     <= '0;
      input_a_ptr   <= '0;
      input_b_ptr   <= '0;
      input_len     <= '0;
      res_ptr       <= '0;
      res_len       <= '0;
      operation     <= '0;
      io_resp_v_o   <= '0;
      len_a_cnt     <= '0;
      len_b_cnt     <= '0;
      vector_a      <= '{default:64'd0};
      vector_b      <= '{default:64'd0}; 
    end 
    if (state_r == DONE) 
      start_cmd  <= '0;
    else if (io_cmd_v_i & (io_cmd_cast_i.msg_type == e_cce_mem_uc_wr))
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
        20'h00140 : res_ptr    <= io_cmd_cast_i.data;
        20'h00180 : res_len    <= io_cmd_cast_i.data;
        20'h00200 : operation  <= io_cmd_cast_i.data;
        default : begin end
      endcase 
    end 
    else if (io_cmd_v_i & (io_cmd_cast_i.msg_type == e_cce_mem_uc_rd))
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
 
   
  always_comb begin
    state_n = state_r; 
    case (state_r)
      RESET: begin
        state_n = reset_i ? RESET : WAIT_START;
        res_status = '0;

        io_cmd_cast_o = '0; 
        io_cmd_v_o = '0;
         
        load = 0;
        second_operand = 0;
        done = 0;
      end
      WAIT_START: begin
        state_n = start_cmd ? FETCH : WAIT_START;
        res_status = '1;

        io_cmd_cast_o = '0; 
        io_cmd_v_o = '0;
        
        load = 1;
        second_operand= 0;
        done = 0;
      end
/*      WAIT_FETCH: begin
        state_n = io_cmd_yumi_i ? FETCH : WAIT_FETCH;
        res_status = '0;
         
        io_cmd_cast_o = '0; 
        io_cmd_v_o = '1;
        
        done = 0;
      end*/
      FETCH: begin
        state_n = io_cmd_yumi_i ? WAIT_DCACHE_C1 : FETCH;
        
        io_cmd_cast_o.data = load ? '0 : dot_product_res;
        io_cmd_cast_o.addr = {(ptag_width_p-vtag_width_p)'(0), v_addr};
        io_cmd_cast_o.msg_type= load ? e_cce_mem_uc_rd : e_cce_mem_uc_wr;
        io_cmd_cast_o.size = e_mem_size_8; 
        io_cmd_v_o = '1;
        
        res_status = '0;
        done = 0;
      end
      WAIT_DCACHE_C1: begin
        state_n = ~io_resp_v_i ? WAIT_DCACHE_C1 : 
                  (load ? (second_operand ? CHECK_VEC2_LEN : CHECK_VEC1_LEN) : DONE);
        
        io_cmd_cast_o.data =  load ? '0 : dot_product_res;
        io_cmd_cast_o.addr = {(ptag_width_p-vtag_width_p)'(0), v_addr};
        io_cmd_cast_o.msg_type= load ? e_cce_mem_uc_rd : e_cce_mem_uc_wr;
        io_cmd_cast_o.size = e_mem_size_8; 
        io_cmd_v_o = '0;
        
        res_status = '0;
        done = 0;
      end
      CHECK_VEC1_LEN: begin
        state_n = (len_a_cnt == input_len) ? FETCH_VEC2 : FETCH;
        res_status = '0;
        
        io_cmd_cast_o = '0; 
        io_cmd_v_o = '0;
         
        done = 0;
      end
      FETCH_VEC2: begin
        state_n = FETCH;
        res_status = '0;
         
        io_cmd_cast_o = '0; 
        io_cmd_v_o = '0;
        
        second_operand= 1;
        done = 0;
      end
      CHECK_VEC2_LEN: begin
        state_n= (len_b_cnt == input_len) ? WB_RESULT : FETCH;
        res_status = '0;
        
        io_cmd_cast_o = '0; 
        io_cmd_v_o = '0;
        
        second_operand= 1;
        done = 0;
        dot_product_res = dot_product_temp;         
      end
      WB_RESULT: begin
        state_n = FETCH;
        load = 0;
        
        io_cmd_cast_o = '0; 
        io_cmd_v_o = '0;
        
        res_status = 0;
        second_operand= 0;
        done = 0;
      end
      DONE: begin
        state_n = RESET;
        res_status = 1;
        
        io_cmd_cast_o = '0; 
        io_cmd_v_o = '0;
      
        load = 0;
        second_operand= 0;
        done = 1; 
      end
    endcase 
   end // always_comb

   
  //dot_product unit
  for (genvar i=0; i<8; i++)
  begin : product
    assign product_res[i]= vector_a[i] * vector_b[i];
  end

  for (genvar i=0; i<4; i++)
  begin : sum_level_1
    assign sum_l1[i]= product_res[2*i] + product_res[2*i+1];
  end

  for (genvar i=0; i<2; i++)
  begin : sum_level_2
    assign sum_l2[i]= sum_l1[2*i] + sum_l1[2*i+1];
  end

   assign dot_product_temp = sum_l2[0] + sum_l2[1];
  
endmodule

