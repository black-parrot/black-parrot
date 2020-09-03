module bp_sacc_vdp
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bp_be_dcache_pkg::*;  
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem)
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
   `declare_bp_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem);
   
  bp_cce_mem_msg_s io_resp_cast_o;
  bp_cce_mem_msg_header_s resp_header; 
  bp_cce_mem_msg_s io_cmd_cast_i;
 // bp_cce_mem_msg_s io_resp_cast_i;
 // bp_cce_mem_msg_s io_cmd_cast_o;
  
  assign io_cmd_ready_o = 1'b1;
  assign io_resp_ready_o = 1'b1;
  assign io_cmd_v_o = 1'b0;
   
  assign io_cmd_cast_i = io_cmd_i;
  assign io_resp_o = io_resp_cast_o;
 
  logic [63:0] csr_data, resp_data, start_cmd, input_a_ptr, input_b_ptr, input_len, res_status, 
               res_ptr, res_len, operation, spm_data_lo, spm_data_li, spm_external_data_li;
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

  logic [vaddr_width_p-1:0] spm_addr, spm_internal_addr, spm_external_addr;
  logic                     spm_internal_read_v_li, spm_internal_write_v_li,
                            spm_external_read_v_li, spm_external_write_v_li,
                            spm_internal_v_lo, spm_external_v_lo, resp_v_lo;
   
  bp_cce_mem_msg_payload_s  resp_payload;
  bp_mem_msg_size_e         resp_size;
  bp_mem_msg_e              resp_msg;
  bp_local_addr_s           local_addr_li;
  bp_global_addr_s          global_addr_li;
  
  assign global_addr_li = io_cmd_cast_i.header.addr;
  assign local_addr_li = io_cmd_cast_i.header.addr;
  assign resp_data = spm_external_v_lo ? spm_data_lo : csr_data;

  assign resp_header   =  '{msg_type       : resp_msg
                            ,addr          : resp_addr
                            ,payload       : resp_payload
                            ,size          : resp_size  };

  assign io_resp_cast_o = '{header         : resp_header
                            ,data          : resp_data  };

   
  assign spm_internal_addr = load ? (second_operand ? (input_b_ptr+len_b_cnt*8) 
                                                    : (input_a_ptr+len_a_cnt*8)) 
                                  : res_ptr;
  assign spm_addr = (spm_external_read_v_li | spm_external_write_v_li) ? spm_external_addr : spm_internal_addr; 
   
  typedef enum logic [3:0]{
    RESET
    , WAIT_START
    , WAIT_FETCH                            
    , FETCH
    , CHECK_VEC1_LEN
    , FETCH_VEC2
    , CHECK_VEC2_LEN
    , WB_RESULT
    , DONE
  } state_e;
  state_e state_r, state_n;

  assign io_resp_v_o = spm_external_v_lo | resp_v_lo; 
  always_ff @(posedge clk_i) begin
    spm_internal_v_lo <= spm_internal_read_v_li;
    spm_external_v_lo <= spm_external_read_v_li; 
    vector_a[len_a_cnt] <= (spm_internal_v_lo & load & ~second_operand) ? spm_data_lo : vector_a[len_a_cnt];
    len_a_cnt <= (spm_internal_v_lo & load & ~second_operand) ? len_a_cnt + 1'b1 : len_a_cnt;
    vector_b[len_b_cnt]  <= (spm_internal_v_lo & load & second_operand) ? spm_data_lo : vector_b[len_b_cnt];
    len_b_cnt <= (spm_internal_v_lo & load & second_operand) ? len_b_cnt + 1'b1 : len_b_cnt;
    
    if(reset_i)
      state_r <= RESET;
    else
      state_r <= state_n;
 
    if (reset_i || done) begin
      spm_internal_v_lo <= '0;
      spm_external_v_lo <= '0;
      resp_v_lo <= 0; 
      spm_external_read_v_li  <= '0;
      spm_external_write_v_li <= '0; 
      start_cmd     <= '0;
      input_a_ptr   <= '0;
      input_b_ptr   <= '0;
      input_len     <= '0;
      res_ptr       <= '0;
      res_len       <= '0;
      operation     <= '0;
      len_a_cnt     <= '0;
      len_b_cnt     <= '0;
      vector_a      <= '{default:64'd0};
      vector_b      <= '{default:64'd0}; 
    end 
    if (state_r == DONE)
    begin
      start_cmd  <= '0;
      resp_v_lo <= 0; 
      spm_external_write_v_li <= '0;
      spm_external_read_v_li  <= '0;
    end
    else if (io_cmd_v_i & (io_cmd_cast_i.header.msg_type == e_mem_msg_uc_wr) & (global_addr_li.did == '0))
    begin
      resp_size    <= io_cmd_cast_i.header.size;
      resp_payload <= io_cmd_cast_i.header.payload;
      resp_addr    <= io_cmd_cast_i.header.addr;
      resp_msg     <= io_cmd_cast_i.header.msg_type;
      spm_external_write_v_li <= '0;
      spm_external_read_v_li  <= '0;
      resp_v_lo <= 1;
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
    else if (io_cmd_v_i & (io_cmd_cast_i.header.msg_type == e_mem_msg_uc_rd) &  (global_addr_li.did == '0))
    begin
      resp_size    <= io_cmd_cast_i.header.size;
      resp_payload <= io_cmd_cast_i.header.payload;
      resp_addr    <= io_cmd_cast_i.header.addr;
      resp_msg     <= io_cmd_cast_i.header.msg_type;
      spm_external_write_v_li <= '0;
      spm_external_read_v_li  <= '0;
      resp_v_lo <= 1;
      unique 
      case (local_addr_li.addr)
        20'h00000 : csr_data <= input_a_ptr;
        20'h00040 : csr_data <= input_b_ptr;
        20'h00080 : csr_data <= input_len;
        20'h000c0 : csr_data <= start_cmd;
        20'h00100 : csr_data <= res_status; 
        20'h00140 : csr_data <= res_ptr;
        20'h00180 : csr_data <= res_len;
        20'h00200 : csr_data <= operation;
        default : begin end
      endcase 
    end 
    else if (io_cmd_v_i & (io_cmd_cast_i.header.msg_type == e_mem_msg_uc_wr) & (global_addr_li.did == 1))
    begin
      resp_size    <= io_cmd_cast_i.header.size;
      resp_payload <= io_cmd_cast_i.header.payload;
      resp_addr    <= io_cmd_cast_i.header.addr;
      resp_msg     <= io_cmd_cast_i.header.msg_type;
      spm_external_write_v_li <= '1;
      spm_external_read_v_li  <= '0;
      resp_v_lo <= 1; 
      spm_external_data_li  <= io_cmd_cast_i.data;
      spm_external_addr <= io_cmd_cast_i.header.addr; 
    end
    else if (io_cmd_v_i & (io_cmd_cast_i.header.msg_type == e_mem_msg_uc_rd) &  (global_addr_li.did == 1))
    begin
      resp_size    <= io_cmd_cast_i.header.size;
      resp_payload <= io_cmd_cast_i.header.payload;
      resp_addr    <= io_cmd_cast_i.header.addr;
      resp_msg     <= io_cmd_cast_i.header.msg_type;
      spm_external_read_v_li  <= '1;
      spm_external_write_v_li <= '0;
      resp_v_lo <= 0;  
      spm_external_addr <= io_cmd_cast_i.header.addr; 
    end
    else
    begin
      spm_external_write_v_li <= '0;
      spm_external_read_v_li  <= '0;
      resp_v_lo <= 0;
      end
  end

  assign spm_data_li = spm_external_write_v_li ? spm_external_data_li : dot_product_temp;
  
  always_comb begin
    state_n = state_r; 
    case (state_r)
      RESET: begin
        state_n = reset_i ? RESET : WAIT_START;
        res_status = '1;
        spm_internal_write_v_li = '0;
        spm_internal_read_v_li = '0;
        load = 1;
        second_operand= 0;
        done = 0;
      end
        WAIT_START: begin
        state_n = start_cmd ? FETCH : WAIT_START;
        res_status = '1;
        spm_internal_write_v_li = '0;
        spm_internal_read_v_li = '0;    
        load = 1;
        second_operand= 0;
        done = 0;
      end
      FETCH: begin
        state_n = load ? (second_operand ? CHECK_VEC2_LEN : CHECK_VEC1_LEN) : DONE;
        spm_internal_write_v_li = '0;
        spm_internal_read_v_li = '1;
        res_status = '0;
        done = 0;
      end
      CHECK_VEC1_LEN: begin
        state_n = (len_a_cnt == input_len-1) ? FETCH_VEC2 : FETCH;
        res_status = '0;
        spm_internal_write_v_li = '0;
        spm_internal_read_v_li = '0;
        done = 0;
      end
      FETCH_VEC2: begin
        state_n = FETCH;
        res_status = '0;
        spm_internal_write_v_li = '0;
        spm_internal_read_v_li = '0;
        second_operand= 1;
        done = 0;
      end
      CHECK_VEC2_LEN: begin
        state_n= (len_b_cnt == input_len-1) ? WB_RESULT : FETCH;
        res_status = '0;
        spm_internal_write_v_li = '0;
        spm_internal_read_v_li = '0;
        second_operand= 1;
        done = 0;
      end
      WB_RESULT: begin
        state_n = DONE;
        load = 0;
        spm_internal_write_v_li = '1;
        spm_internal_read_v_li = '0;
        res_status = 0;
        second_operand= 0;
        done = 0;
      end
      DONE: begin
        state_n = RESET;
        res_status = 1;
        spm_internal_write_v_li = '0;
        spm_internal_read_v_li = '0;
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

//SPM
wire [`BSG_SAFE_CLOG2(20)-1:0] spm_addr_li = spm_addr >> 3;
bsg_mem_1rw_sync
  #(.width_p(64)
    ,.els_p(20)
  )
  accel_spm
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.data_i(spm_data_li)
   ,.addr_i(spm_addr_li)
   ,.v_i(spm_internal_read_v_li | spm_external_read_v_li | spm_internal_write_v_li | spm_external_write_v_li)
   ,.w_i(spm_internal_write_v_li | spm_external_write_v_li)
   ,.data_o(spm_data_lo)
   );
   
  
endmodule

