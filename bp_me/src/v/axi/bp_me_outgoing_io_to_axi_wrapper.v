module bp_me_outgoing_io_to_axi_wrapper

 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bsg_noc_pkg::*;

 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p,cce_mem)

  // AXI WRITE DATA CHANNEL PARAMS
  , parameter  axi_data_width_p             = 64
  , localparam axi_data_width_in_byte_lp    = axi_data_width_p/8
  , localparam axi_strb_width_lp            = axi_data_width_p/8
  , localparam lg_axi_data_width_in_byte_lp = `BSG_SAFE_CLOG2(axi_data_width_in_byte_lp)

  // AXI WRITE/READ ADDRESS CHANNEL PARAMS  
  , parameter axi_id_width_p       = 1
  , parameter axi_addr_width_p     = 64
  , parameter axi_burst_type_p     = 2'b01                                      //INCR type
  , localparam axi_user_devices_lp = 16
  , localparam lg_axi_user_dev_lp  = `BSG_SAFE_CLOG2(axi_user_devices_lp)
  
  // FIFO depth for PISO and SIPO
  , localparam fifo_els_lp         = cce_block_width_p/axi_data_width_p         //in most cases, it'll be 512/64 = 8
  )

  ( 
  //==================== GLOBAL SIGNALS =======================
    input aclk_i  
  , input aresetn_i

  //========================= BP side =========================
  // io commands to the axi wrapper
  , input  [cce_mem_msg_width_lp-1:0]       io_cmd_i
  , input                                   io_cmd_v_i
  , output logic                            io_cmd_ready_o

  //io responses from the axi wrapper
  , output logic [cce_mem_msg_width_lp-1:0] io_resp_o
  , output logic                            io_resp_v_o
  , input                                   io_resp_yumi_i

  //======================== AXI side =========================
  // WRITE ADDRESS CHANNEL SIGNALS
  , output logic [lg_axi_user_dev_lp-1:0]   axi_awid_o     //write addr ID    
  , output logic [axi_addr_width_p-1:0]     axi_awaddr_o   //write address
  , output logic [7:0]                      axi_awlen_o    //burst length (# of transfers 0-256)
  , output logic [2:0]                      axi_awsize_o   //burst size (# of bytes in transfer 0-128)
  , output logic [1:0]                      axi_awburst_o  //burst type (FIXED, INCR, or WRAP)
  , output logic [3:0]                      axi_awcache_o  //memory type (write-through, write-back, etc.)
  , output logic [2:0]                      axi_awprot_o   //protection type (unpriv, secure, etc)
  , output logic [3:0]                      axi_awqos_o    //QoS (use default 0000 if no QoS scheme)
  , output logic                            axi_awvalid_o  //master device write addr validity
  , input                                   axi_awready_i  //slave device readiness
  //, output                                axi_awlock_o   //lock type (not supported by AXI-4)
  //, output [axi_user_width_lp-1:0]        axi_awuser_o   //user-defined signals (optional, recommended for interconnect)
  //, output [3:0]                          axi_awregion_o //region identifier (optional)

  // WRITE DATA CHANNEL SIGNALS
  , output logic [lg_axi_user_dev_lp-1:0]   axi_wid_o      //write data ID
  , output logic [axi_data_width_p-1:0]     axi_wdata_o    //write data
  , output logic [axi_strb_width_lp-1:0]    axi_wstrb_o    //write strobes (indicates valid data byte lane)
  , output logic                            axi_wlast_o    //write last (indicates last transfer in a write burst)
  , output logic                            axi_wvalid_o   //master device write validity
  , input                                   axi_wready_i   //slave device readiness
  //, output [axi_user_width_lp-1:0]        axi_wuser_o    //user-defined signals (optional)

  // WRITE RESPONSE CHANNEL SIGNALS
  , input [lg_axi_user_dev_lp-1:0]          axi_bid_i      //slave response ID
  , input [1:0]                             axi_bresp_i    //status of the write transaction (OKAY, EXOKAY, SLVERR, or DECERR)
  , input                                   axi_bvalid_i   //slave device write reponse validity
  , output logic                            axi_bready_o   //master device write response readiness 
   //, input [axi_user_width_lp-1:0]        axi_buser_o    //user-defined signals (optional)
  
  // READ ADDRESS CHANNEL SIGNALS
  , output logic [lg_axi_user_dev_lp-1:0]   axi_arid_o     //read addr ID
  , output logic [axi_addr_width_p-1:0]     axi_araddr_o   //read address
  , output logic [7:0]                      axi_arlen_o    //burst length (# of transfers 0-256)
  , output logic [2:0]                      axi_arsize_o   //burst size (# of bytes in transfer 0-128)
  , output logic [1:0]                      axi_arburst_o  //burst type (FIXED, INCR, or WRAP)
  , output logic [3:0]                      axi_arcache_o  //memory type (write-through, write-back, etc.)
  , output logic [2:0]                      axi_arprot_o   //protection type (unpriv, secure, etc)
  , output logic [3:0]                      axi_arqos_o    //QoS (use default 0000 if no QoS scheme)
  , output logic                            axi_arvalid_o  //master device read addr validity
  , input                                   axi_arready_i  //slave device readiness
  //, output                                axi_arlock_o   //lock type (not supported by AXI-4)
  //, output [axi_user_width_lp-1:0]        axi_aruser_o   //user-defined signals (optional)
  //, output [3:0]                          axi_arregion_o //region identifier (optional)

  // READ DATA CHANNEL SIGNALS
  , input [lg_axi_user_dev_lp-1:0]          axi_rid_i      //read data ID
  , input [axi_data_width_p-1:0]            axi_rdata_i    //read data
  , input [1:0]                             axi_rresp_i    //read response
  , input                                   axi_rlast_i    //read last
  , input                                   axi_rvalid_i   //slave device read data validity
  , output logic                            axi_rready_o   //master device read data readiness
  //, input                                 axi_ruser_i    //user-defined signals (optional)
 );

  // declaring io command and response struct type and size
  `declare_bp_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem);
  bp_cce_mem_msg_s io_cmd_cast_i, io_resp_cast_o;

  assign io_resp_o      = io_resp_cast_o;
  assign io_cmd_cast_i  = io_cmd_i;

  // SIPO and PISO related signals
  logic                         axi_read_sipo_ready_lo;
  logic                         axi_read_sipo_v_lo;
  logic [cce_block_width_p-1:0] axi_read_sipo_data_lo;

  logic                         axi_write_piso_ready_lo;
  logic                         axi_write_piso_v_lo;
  logic [axi_data_width_p-1:0]  axi_write_piso_data_lo;
  logic                         axi_write_piso_reset_li;
  logic                         axi_write_piso_deq_li;

  // Write counter and strobe logic
  logic [7:0]                              axi_awburst_cnt_r, axi_awburst_cnt_n;
  logic [axi_strb_width_lp-1:0]            write_strb;
  logic [lg_axi_data_width_in_byte_lp-1:0] write_strb_cnt_r, write_strb_cnt_n, write_strb_cnt_max;

  // io command read/write validity
  logic io_cmd_read_v;
  logic io_cmd_write_v;

  assign io_cmd_read_v  = io_cmd_v_i & io_cmd_cast_i.header.msg_type inside {e_mem_msg_rd, e_mem_msg_uc_rd, e_mem_msg_pre};
  assign io_cmd_write_v = io_cmd_v_i & io_cmd_cast_i.header.msg_type inside {e_mem_msg_wr, e_mem_msg_uc_wr};

  // storing io_cmd's header for io_resp's use
  // only accepts changes when io_cmd is valid
  bp_cce_mem_msg_header_s io_cmd_header_r;
  
  bsg_dff_reset_en
   #(.width_p(cce_mem_msg_header_width_lp))
   io_header_reg
    (.clk_i(aclk_i)
    ,.reset_i(~aresetn_i)
    ,.en_i(io_cmd_v_i)
    ,.data_i(io_cmd_cast_i.header)
    ,.data_o(io_cmd_header_r)
    );

  // Declaring all possible states
  typedef enum logic [2:0] {
    e_wait             = 3'b000
    ,e_read_tx         = 3'b001
    ,e_read_err        = 3'b010
    ,e_read_done       = 3'b011
    ,e_write_addr_tx   = 3'b100
    ,e_write_data_tx   = 3'b101
    ,e_write_err       = 3'b110
  } state_e;

  state_e state_r, state_n;

  // Combinational Logic
  always_comb begin
  
    // BP side
    io_cmd_ready_o         = axi_write_piso_ready_lo & (state_r == e_wait);
    io_resp_cast_o.header  = io_cmd_header_r;
    io_resp_cast_o.data    = '0;
    io_resp_v_o            = '0;

    // READ ADDRESS CHANNEL SIGNALS
    axi_araddr_o  = {{axi_addr_width_p - paddr_width_p{1'b0}}, io_cmd_cast_i.header.addr};
    axi_arlen_o   = ((2**io_cmd_cast_i.header.size << 3) > axi_data_width_p)               //if data transfer size is larger than data bus width
                  ? (2**(io_cmd_cast_i.header.size - lg_axi_data_width_in_byte_lp)) - 1    //then it's multiple transfers, otherwise
                  : 8'h01;                                                                 //it's one transfer
    axi_arsize_o  = io_cmd_cast_i.header.size;              
    axi_arburst_o = axi_burst_type_p;
    axi_arvalid_o = io_cmd_read_v;
    axi_arid_o    = io_cmd_cast_i.header.addr[23:20];                                      //device ID is located in addr[23:20]
    axi_arcache_o = 4'b0011;                                                               //normal non-cacheable bufferable (recommended for Xilinx IP)
    axi_arprot_o  = '0;                                                                    //unprivileged access
    axi_arqos_o   = '0;                                                                    //no QoS scheme

    // READ DATA CHANNEL SIGNALS
    axi_rready_o  = '0;

    // WRITE ADDRRESS CHANNEL SIGNALS
    axi_awaddr_o  = {{axi_addr_width_p - paddr_width_p{1'b0}}, io_cmd_cast_i.header.addr};
    axi_awlen_o   = ((2**io_cmd_cast_i.header.size << 3) > axi_data_width_p)
                  ? (2**(io_cmd_cast_i.header.size - lg_axi_data_width_in_byte_lp)) - 1
                  : 8'h01;
    axi_awsize_o  = io_cmd_cast_i.header.size;
    axi_awburst_o = axi_burst_type_p;
    axi_awvalid_o = io_cmd_write_v;
    axi_awid_o    = io_cmd_cast_i.header.addr[23:20];
    axi_awcache_o = 4'b0011; 
    axi_awprot_o  = '0;      
    axi_awqos_o   = '0;      

    // WRITE DATA CHANNEL SIGNALS
    axi_wdata_o       = '0;
    axi_wstrb_o       = '0;
    axi_wlast_o       = '0; 
    axi_wvalid_o      = '0;
    axi_wid_o         = io_cmd_cast_i.header.addr[23:20];
    axi_awburst_cnt_n = '0;

    // WRITE RESPONSE CHANNEL SIGNALS
    axi_bready_o      = 1'b1;

    // PISO logic
    axi_write_piso_reset_li = 1'b0;
    axi_write_piso_deq_li   = 1'b0;

    // other logic
    state_n            = state_r;
    write_strb         = '1;
    write_strb_cnt_max = '0;
    write_strb_cnt_n   = '0; 

    case (state_r)
      e_wait : begin
        if (io_cmd_read_v) begin
          state_n = e_read_tx;
        end
        else if (io_cmd_write_v & axi_awready_i) begin
          state_n = e_write_data_tx;
        end
        else if (io_cmd_write_v & ~axi_awready_i) begin
          state_n = e_write_addr_tx;
        end
      end

      // READ STATES
      e_read_tx : begin
        // holding valid high for data transfer 
        axi_arvalid_o = 1'b1;

        // continue to send read address/control info until the slave device is ready to receive
        axi_araddr_o  = {{axi_addr_width_p - paddr_width_p{1'b0}}, io_cmd_header_r.addr};
        axi_arlen_o   = ((2**io_cmd_header_r.size << 3) > axi_data_width_p) 
                      ? (2**(io_cmd_header_r.size  - lg_axi_data_width_in_byte_lp)) - 1
                      : 8'h01;
        axi_arsize_o  = io_cmd_header_r.size;
        axi_arid_o    = io_cmd_header_r.addr[23:20];

        // sending read data signals
        axi_rready_o  = axi_read_sipo_ready_lo;

        // if read data response is not ok or the returned device ID is not what the cmd requested, go to err
        if ((axi_rresp_i != '0) | (axi_rid_i != io_cmd_header_r.addr[23:20])) begin
          state_n = e_read_err;
        end
        else if (axi_rlast_i) begin
          state_n = e_read_done;
        end
      end

      e_read_done : begin
        // bp signals
        io_resp_v_o         = axi_read_sipo_v_lo;
        io_resp_cast_o.data = axi_read_sipo_data_lo;

        // if io_resp is ready to accept the data, then return to e_wait
        if (io_resp_yumi_i) begin
          state_n = e_wait;
        end
      end

      e_read_err : begin
        // do something when data read back is not OKAY
      end

      e_write_addr_tx : begin
        // holding valid high for data transfer
        axi_awvalid_o = 1'b1;

        // continue to send write address/control info until the slave device is ready to receive
        axi_awaddr_o  = {{axi_addr_width_p - paddr_width_p{1'b0}}, io_cmd_header_r.addr};
        axi_awlen_o   = ((2**io_cmd_header_r.size << 3) > axi_data_width_p)
                      ? (2**(io_cmd_header_r.size  - lg_axi_data_width_in_byte_lp)) - 1
                      : 8'h01;
        axi_awsize_o  = io_cmd_header_r.size;
        axi_awid_o    = io_cmd_header_r.addr[23:20];

        // if the address is accepted, move onto data transfer
        if (axi_awready_i) begin
          state_n = e_write_data_tx;
        end
      end       

      e_write_data_tx: begin
        // sending write addr signals
        axi_wvalid_o       = axi_write_piso_v_lo;
        axi_wdata_o        = axi_write_piso_data_lo;
        axi_wstrb_o        = '0;
        axi_wid_o          = io_cmd_header_r.addr[23:20];

        // write strobe related logic
        axi_awburst_cnt_n  = axi_awburst_cnt_r;
        write_strb_cnt_max = (lg_axi_data_width_in_byte_lp > io_cmd_header_r.size)
                           ? 2**(lg_axi_data_width_in_byte_lp - io_cmd_header_r.size) - 1
                           : '0;
        write_strb_cnt_n   = write_strb_cnt_r;

        // if the receiving slave device is ready, then proceed to send data
        if (axi_wready_i) begin
          axi_wlast_o       = (axi_awburst_cnt_r == (io_cmd_cast_i.header.size >> 3));
          axi_awburst_cnt_n = axi_awburst_cnt_r + 1;

          write_strb_cnt_n  = (write_strb_cnt_r == write_strb_cnt_max)
                            ? '0
                            : write_strb_cnt_r + 1;

          axi_write_piso_deq_li = (write_strb_cnt_r == write_strb_cnt_max);
          write_strb            = write_strb << ((axi_data_width_p >> 3) - (2**io_cmd_header_r.size));
          write_strb            = write_strb >> ((axi_data_width_p >> 3) - (2**io_cmd_header_r.size) - write_strb_cnt_r);
          axi_wstrb_o           = ((2**io_cmd_header_r.size << 3) < axi_data_width_p)
                                ? write_strb
                                : '1;
        end
        
        // else if the response is not OKAY and valid
        else if ((axi_bresp_i != '0 & axi_bvalid_i) | (axi_bid_i != io_cmd_header_r.addr[23:20])) begin
          state_n = e_write_err;
        end

        // else if the response is OKAY and valid
        else if (axi_bresp_i == '0 & axi_bvalid_i) begin
          state_n                 = e_wait;
          io_resp_v_o             = 1'b1;
          axi_write_piso_reset_li = 1'b1;        
        end
      end

      e_write_err : begin
        // do something if there is an write error
      end
    endcase
  end

  // Sequential Logic
  always_ff @(posedge aclk_i) begin
    if (~aresetn_i) begin
      state_r           <= e_wait;
      axi_awburst_cnt_r <= '0;
      write_strb_cnt_r  <= '0;
    end
    else begin
      state_r           <= state_n;
      axi_awburst_cnt_r <= axi_awburst_cnt_n;
      write_strb_cnt_r  <= write_strb_cnt_n;
    end
  end

  // SIPO for read data
  bsg_serial_in_parallel_out_full 
    #(.width_p  (axi_data_width_p)
     ,.els_p    (fifo_els_lp)
     )
    axi_read_data_sipo
    (.clk_i     (aclk_i)
    ,.reset_i   (~aresetn_i)

    ,.v_i       (axi_rvalid_i)
    ,.ready_o   (axi_read_sipo_ready_lo)
    ,.data_i    (axi_rdata_i) 

    ,.data_o    (axi_read_sipo_data_lo)
    ,.v_o       (axi_read_sipo_v_lo)
    ,.yumi_i    (io_resp_yumi_i & (state_r == e_read_done))
    );

  // PISO for write data
  bsg_parallel_in_serial_out
    #(.width_p  (axi_data_width_p)
     ,.els_p    (fifo_els_lp)
     ) 
    axi_write_data_piso
    (.clk_i     (aclk_i)
    ,.reset_i   (~aresetn_i | axi_write_piso_reset_li)

    ,.valid_i   (io_cmd_write_v & (state_r == e_wait))
    ,.data_i    (io_cmd_cast_i.data)
    ,.ready_o   (axi_write_piso_ready_lo)

    ,.valid_o   (axi_write_piso_v_lo)
    ,.data_o    (axi_write_piso_data_lo)
    ,.yumi_i    (axi_wready_i & axi_write_piso_deq_li)
    );

endmodule
