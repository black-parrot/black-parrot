//`include "cr_global_params.vh"
module bp_sacc_zipline
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
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
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

//   `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);

  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);
   
  bp_bedrock_cce_mem_msg_s io_resp_cast_o;
  bp_bedrock_cce_mem_msg_header_s resp_header; 
  bp_bedrock_cce_mem_msg_s io_cmd_cast_i, io_cmd_cast_o;

 // bp_cce_mem_msg_s io_resp_cast_i;
 // bp_cce_mem_msg_s io_cmd_cast_o;
  

   logic [`N_RBUS_ADDR_BITS-1:0] apb_paddr;
   logic                         apb_psel;
   logic                         apb_penable;
   logic                         apb_pwrite;
   logic [`N_RBUS_DATA_BITS-1:0] apb_pwdata;
   logic [`N_RBUS_DATA_BITS-1:0] apb_prdata;
   logic                         apb_pready;
   logic                         apb_pslverr;

   logic                         ib_tready;
   logic [`AXI_S_TID_WIDTH-1:0]  ib_tid;
   logic [`AXI_S_DP_DWIDTH-1:0]  ib_tdata;
   logic [`AXI_S_TSTRB_WIDTH-1:0] ib_tstrb;
   logic [`AXI_S_USER_WIDTH-1:0]  ib_tuser;
   logic                          ib_tvalid;
   logic                          ib_tlast;


   logic                          ob_tready;
   logic [`AXI_S_TID_WIDTH-1:0]   ob_tid;
   logic [`AXI_S_DP_DWIDTH-1:0]   ob_tdata;
   logic [`AXI_S_TSTRB_WIDTH-1:0] ob_tstrb;
   logic [`AXI_S_USER_WIDTH-1:0] ob_tuser;
   logic                         ob_tvalid;
   logic                         ob_tlast;


   logic                         sch_update_tready;
   logic [7:0]                   sch_update_tdata;
   logic                         sch_update_tvalid;
   logic                         sch_update_tlast;
   logic [1:0]                   sch_update_tuser;


   logic                         engine_int;
   logic                         engine_idle;
   logic                         key_mode;
   logic                         dbg_cmd_disable;
   logic                         xp9_disable;



   bp_bedrock_cce_mem_payload_s  resp_payload;
   bp_bedrock_msg_size_e         resp_size;
   bp_bedrock_mem_type_e         resp_msg;

   logic [paddr_width_p-1:0]     resp_addr;
   logic [63:0]                  resp_data;
   logic [63:0]                  tlv_type;
   logic [63:0]                  tlv_idx;
   
   bp_local_addr_s           local_addr_li;
   bp_global_addr_s          global_addr_li;

   assign key_mode = 0;
   assign dbg_cmd_disable = 0;
   assign xp9_disable = 0;
   assign sch_update_tready = 1;
   
   
//   assign io_cmd_ready_o = apb_pready;
   assign io_cmd_ready_o = 1;
   assign io_resp_ready_o = 1'b1;

//   assign io_cmd_v_o = 1'b0;
   

   assign io_cmd_cast_i = io_cmd_i;
   assign io_resp_o = io_resp_cast_o;
   
   assign global_addr_li = io_cmd_cast_i.header.addr;
   assign local_addr_li = io_cmd_cast_i.header.addr;

   assign resp_data = apb_prdata;
   assign resp_header   =  '{msg_type       : resp_msg
                             ,addr          : resp_addr
                             ,payload       : resp_payload
                             ,size          : resp_size  };
   assign io_resp_cast_o = '{header         : resp_header
                             ,data          : resp_data  };
   
   
  // assign apb_paddr= local_addr_li.addr;
  // assign apb_psel= io_cmd_v_i & (global_addr_li.did == '0);
  // assign apb_penable= io_cmd_v_i & (global_addr_li.did == '0);
   assign apb_paddr= 0;
   assign apb_psel= 1'b1;
   assign apb_penable= io_cmd_v_i & (local_addr_li.dev == '1);
   

   assign apb_pwrite= io_cmd_v_i & (io_cmd_cast_i.header.msg_type.mem == e_bedrock_mem_uc_wr) & (local_addr_li.dev == '1);

   assign apb_pwdata= io_cmd_cast_i.data;

/*   assign io_resp_out =apb_prdata;
   assign io_resp_out =apb_pready;
   assign io_resp_out =apb_pslverr;
  */

assign io_cmd_ready_o = ib_tready;
assign ob_tready= 1'b1;



//dma engine
logic           dma_enable;
logic [63:0]    dma_address;

assign dma_enable = io_cmd_v_i & (local_addr_li.dev == 4'd2) & (local_addr_li.nonlocal == 9'd0);//device number 2 is dma

assign io_cmd_o = io_cmd_cast_o;

   
always_ff @(posedge clk_i) 
begin
   if (io_cmd_v_i  & (local_addr_li.nonlocal == 9'd0) /*&  (global_addr_li.did == '0)*/)
     begin
        resp_size    <= io_cmd_cast_i.header.size;
        resp_payload <= io_cmd_cast_i.header.payload;
        resp_addr    <= io_cmd_cast_i.header.addr;
        resp_msg     <= io_cmd_cast_i.header.msg_type.mem;
        io_resp_v_o  <= 1'b1;
        ib_tvalid    <= 1'b0;
        ib_tlast     <= 1'b0;
        ib_tdata     <= 64'd0;
        ib_tid       <= 1'b0;
        io_cmd_v_o   <= 1'b0;
        case (local_addr_li.addr)
          20'h10000 : tlv_type <= io_cmd_cast_i.data;
          20'h10008 : tlv_idx  <= io_cmd_cast_i.data;
          default : begin end
        endcase 
     end 
   else if (io_cmd_v_i  & (local_addr_li.nonlocal != 9'd0))
     begin
        resp_size    <= io_cmd_cast_i.header.size;
        resp_payload <= io_cmd_cast_i.header.payload;
        resp_addr    <= io_cmd_cast_i.header.addr;
        resp_msg     <= io_cmd_cast_i.header.msg_type.mem;
        io_resp_v_o  <= 1'b1;
        ib_tvalid    <= 1'b1;
        ib_tlast     <= (tlv_type == 64'd4) & (tlv_idx == 64'd2);
        ib_tdata     <= io_cmd_cast_i.data;
        ib_tid       <=1'b0;
        io_cmd_v_o   <= 1'b0;
        io_cmd_v_o   <= 1'b0;
     end
   else if(dma_enable)
     begin
        io_resp_v_o  <= 1'b0;
        ib_tvalid    <= 1'b0;
        ib_tdata     <= 64'd0;
        ib_tid       <= 1'b0;
        ib_tlast     <= 1'b0;
        io_cmd_v_o   <= io_cmd_yumi_i;
        dma_address  <= dma_enable ? io_cmd_cast_i.data : 64'd0;
     end
   else
     begin
        io_resp_v_o  <= 1'b0;
        ib_tvalid    <= 1'b0;
        ib_tdata     <= 64'd0;
        ib_tid       <= 1'b0;
        ib_tlast     <= 1'b0;
        io_cmd_v_o   <= 1'b0;
     end
end 


assign ib_tstrb  = 8'hff;
assign ib_tuser  = tlv_idx;
   
   cr_cceip_64#( 
               )
      dut(.ib_tready(ib_tready),
          .ib_tvalid(ib_tvalid),
          .ib_tlast(ib_tlast),
          .ib_tid(ib_tid),
          .ib_tstrb(ib_tstrb),
          .ib_tuser(ib_tuser),
          .ib_tdata(ib_tdata),


          .ob_tready(ob_tready),
          .ob_tvalid(ob_tvalid),
          .ob_tlast(ob_tlast),
          .ob_tid(ob_tid),
          .ob_tstrb(ob_tstrb),
          .ob_tuser(ob_tuser),
          .ob_tdata(ob_tdata),


          .sch_update_tready(sch_update_tready),
          .sch_update_tvalid(sch_update_tvalid),
          .sch_update_tlast(sch_update_tlast),
          .sch_update_tuser(sch_update_tuser),
          .sch_update_tdata(sch_update_tdata),

          
          .apb_paddr(apb_paddr),
          .apb_psel(apb_psel),
          .apb_penable(apb_penable),
          .apb_pwrite(apb_pwrite),
          .apb_pwdata(apb_pwdata),
          .apb_prdata(apb_prdata),
          .apb_pready(apb_pready),
          .apb_pslverr(apb_pslverr),


          .clk(clk_i),
          .rst_n(~reset_i),
          .key_mode (key_mode),
          .dbg_cmd_disable (dbg_cmd_disable),
          .xp9_disable (xp9_disable),
          .cceip_int (engine_int),
          .cceip_idle (engine_idle),
          .scan_en(1'b0),
          .scan_mode(1'b0),
          .scan_rst_n(1'b0),


          .ovstb(1'b1),
          .lvm(1'b0),
          .mlvm(1'b0)

          );
          
                                 
      
   
  
endmodule

