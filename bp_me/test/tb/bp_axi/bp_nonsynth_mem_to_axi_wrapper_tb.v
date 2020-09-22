`include "bsg_defines.v"

module bp_nonsynth_mem_to_axi_wrapper_tb

 #(// BP PARAMS
  parameter cce_block_width_p  = 512

  // AXI WRITE DATA CHANNEL PARAMS
  , parameter axi_data_width_p   = 64
  , localparam axi_strb_width_lp = axi_data_width_p/8

  // AXI WRITE/READ ADDRESS CHANNEL PARAMS	
  , parameter axi_id_width_p     = 1
  , parameter axi_addr_width_p   = 64
  , parameter axi_burst_type_p   = 2'b01                                     //INCR type
  , parameter axi_size_p         = 3                                         //8 Bytes, or 64bits, per transfer (this is done in power of 2's)
  , localparam axi_len_lp        = cce_block_width_p/axi_data_width_p - 1    //(512/64) - 1 = 7 (but it's 8 transfers since AxLEN+1)
  //, localparam axi_user_width_lp = 1 
  
  // Memory depth
  , parameter mem_els_p          = 2^40
  , localparam lg_mem_els_lp     =`BSG_SAFE_CLOG2(mem_els_p)                                      
  )

  (
  //==================== GLOBAL SIGNALS =======================
  	input 	aclk_i  
  , input 	aresetn_i

  //======================== AXI side =========================
  // WRITE ADDRESS CHANNEL SIGNALS
  , input [axi_id_width_p-1:0]          axi_awid_i     //write addr ID    
  , input [axi_addr_width_p-1:0]        axi_awaddr_i   //write address
  , input [7:0]                         axi_awlen_i    //burst length (# of transfers 0-256)
  , input [2:0]                         axi_awsize_i   //burst size (# of bytes in transfer 0-128)
  , input [1:0]                         axi_awburst_i  //burst type (FIXED, INCR, or WRAP)
  , input [3:0]                         axi_awcache_i  //memory type (write-through, write-back, etc.)
  , input [2:0]                         axi_awprot_i   //protection type (unpriv, secure, etc)
  , input [3:0]                         axi_awqos_i    //QoS (use default 0000 if no QoS scheme)
  , input                               axi_awvalid_i  //master device write addr validity
  , output logic                        axi_awready_o  //slave device readiness
  //, input                             axi_awlock_i   //lock type (not supported by AXI-4)
  //, input [axi_user_width_lp-1:0]     axi_awuser_i   //user-defined signals (optional, recommended for interconnect)
  //, input [3:0]                       axi_awregion_i //region identifier (optional)

  // WRITE DATA CHANNEL SIGNALS
  , input [axi_id_width_p-1:0]          axi_wid_i      //write data ID
  , input [axi_data_width_p-1:0]        axi_wdata_i    //write data
  , input [axi_strb_width_lp-1:0]       axi_wstrb_i    //write strobes (indicates valid data byte lane)
  , input                               axi_wlast_i    //write last (indicates last transfer in a write burst)
  , input                               axi_wvalid_i   //master device write validity
  , output logic                        axi_wready_o   //slave device readiness
  //, input [axi_user_width_lp-1:0]     axi_wuser_i    //user-defined signals (optional)

  // WRITE RESPONSE CHANNEL SIGNALS
  , output logic [axi_id_width_p-1:0]   axi_bid_o      //slave response ID
  , output logic [1:0]                  axi_bresp_o    //status of the write transaction (OKAY, EXOKAY, SLVERR, or DECERR)
  , output logic                        axi_bvalid_o   //slave device write reponse validity
  , input                               axi_bready_i   //master device write response readiness 
  //, output logic [axi_user_width_lp-1:0]    axi_buser_o    //user-defined signals (optional)
  
  // READ ADDRESS CHANNEL SIGNALS
  , input [axi_id_width_p-1:0]          axi_arid_i     //read addr ID
  , input [axi_addr_width_p-1:0]        axi_araddr_i   //read address
  , input [7:0]                         axi_arlen_i    //burst length (# of transfers 0-256)
  , input [2:0]                         axi_arsize_i   //burst size (# of bytes in transfer 0-128)
  , input [1:0]                         axi_arburst_i  //burst type (FIXED, INCR, or WRAP)
  , input [3:0]                         axi_arcache_i  //memory type (write-through, write-back, etc.)
  , input [2:0]                         axi_arprot_i   //protection type (unpriv, secure, etc)
  , input [3:0]                         axi_arqos_i    //QoS (use default 0000 if no QoS scheme)
  , input                               axi_arvalid_i  //master device read addr validity
  , output logic                        axi_arready_o  //slave device readiness
  //, input                             axi_arlock_i   //lock type (not supported by AXI-4)
  //, input [axi_user_width_lp-1:0]     axi_aruser_i   //user-defined signals (optional)
  //, input [3:0]                       axi_arregion_i //region identifier (optional)

  // READ DATA CHANNEL SIGNALS
  , output logic [axi_id_width_p-1:0]   axi_rid_o      //read data ID
  , output logic [axi_data_width_p-1:0] axi_rdata_o    //read data
  , output logic [1:0]                  axi_rresp_o    //read response
  , output logic                        axi_rlast_o    //read last
  , output logic                        axi_rvalid_o   //slave device read data validity
  , input                               axi_rready_i   //master device read data readiness
  //, output logic                      axi_ruser_o    //user-defined signals (optional)
  //===========================================================
  );

  // declaring RAM
  logic [axi_data_width_p-1:0] ram [mem_els_p-1:0];

  //==================================================  
  // write channel signal declaration and assignment
  typedef enum logic [1:0] {
    WRITE_ADDR_WAIT,
    WRITE_DATA_WAIT,
    WRITE_RESP
  } wr_state_e;

  wr_state_e wr_state_r, wr_state_n;
  
  logic [axi_id_width_p-1:0]   awid_r, awid_n;
  logic [axi_addr_width_p-1:0] awaddr_r, awaddr_n;
  logic [lg_mem_els_lp-1:0]     wr_ram_idx;

  //assign wr_ram_idx = awaddr_r[`BSG_SAFE_CLOG2(axi_data_width_p>>3)+:lg_mem_els_lp];
  assign wr_ram_idx = awaddr_r;

  //==================================================
  // read channel signal declaration and assignment
  typedef enum logic {
    READ_ADDR_WAIT,
    READ_DATA_SEND
  } rd_state_e;

  rd_state_e rd_state_r, rd_state_n;

  logic [axi_id_width_p-1:0] arid_r, arid_n;
  logic [axi_addr_width_p-1:0] araddr_r, araddr_n;
  logic [`BSG_SAFE_CLOG2(axi_len_lp)-1:0] rd_burst_r, rd_burst_n;
  logic [lg_mem_els_lp-1:0] rd_ram_idx;

  //assign rd_ram_idx = araddr_r[`BSG_SAFE_CLOG2(axi_data_width_p>>3)+:lg_mem_els_lp];
  assign rd_ram_idx = araddr_r;

  //==================================================
  // write related combinational logic
  always_comb begin
    // WRITE ADDRESS SIGNALS
    axi_awready_o = '0;

    // WRITE DATA SIGNALS
    axi_wready_o  = '0;
  
    // WRITE RESPONSE SIGNALS
    axi_bid_o     = awid_r;
    axi_bresp_o   = '0;
    axi_bvalid_o  = '0;

    case (wr_state_r)

      WRITE_ADDR_WAIT: begin
        axi_awready_o = 1'b1;
        // if the incoming write address and control info are valid
        if (axi_awvalid_i) begin
          awid_n      = axi_awid_i;
          awaddr_n    = axi_awaddr_i;
          wr_state_n  = WRITE_DATA_WAIT;
        end
        // else if they're invalid
        else begin
          awid_n      = awid_r;
          awaddr_n    = awaddr_r;
          wr_state_n  = wr_state_r;
        end
      end

      WRITE_DATA_WAIT: begin
        axi_awready_o = 1'b1;
        awaddr_n      = axi_wvalid_i & (axi_awburst_i==2'b01)
                      ? awaddr_r + (1 << `BSG_SAFE_CLOG2(axi_data_width_p>>3))
                      : awaddr_r;
        wr_state_n    = (axi_wvalid_i & axi_wlast_i)
                      ? WRITE_RESP
                      : wr_state_r;
      end 

      WRITE_RESP: begin
        axi_bvalid_o = 1'b1;
        wr_state_n   = axi_bready_i
                     ? WRITE_ADDR_WAIT
                     : wr_state_r;
      end
    endcase
  end

  //==================================================
  // read related combinational logic
  always_comb begin
    // READ ADDRESS SIGNALS
    axi_arready_o = '0;

    // READ DATA SIGNALS
    axi_rvalid_o  = '0;
    axi_rlast_o   = '0;
    axi_rid_o     = arid_r;
    axi_rresp_o   = '0;

    case (rd_state_r)

      READ_ADDR_WAIT: begin
        axi_arready_o = 1'b1;
        // if the incoming read address and control info are valid
        if (axi_arvalid_i) begin
          arid_n      = axi_arid_i;
          araddr_n    = axi_araddr_i;
          rd_burst_n  = '0;
          rd_state_n  = READ_DATA_SEND;
        end
        else begin
          arid_n      = arid_r;
          araddr_n    = araddr_r;
          rd_burst_n  = rd_burst_r;
          rd_state_n  = rd_state_r;
        end 
      end

      READ_DATA_SEND: begin
        axi_rvalid_o  = 1'b1;
        axi_rlast_o   = (rd_burst_r == axi_len_lp);

        rd_burst_n    = axi_rready_i
                      ? rd_burst_r + 1
                      : rd_burst_r;

        rd_state_n    = (axi_rlast_o & axi_rready_i)
                      ? READ_ADDR_WAIT
                      : rd_state_r;

        araddr_n      = axi_rready_i
                      ? araddr_r + (1 << `BSG_SAFE_CLOG2(axi_data_width_p>>3))
                      : araddr_r;
      end
    endcase
  end
  
  //==================================================
  // sequential logic

  always_ff @(posedge aclk_i) begin
    if (~aresetn_i) begin
      // write logic
      wr_state_r <= WRITE_ADDR_WAIT;
      awid_r     <= '0;
      awaddr_r   <= '0;

      // read logic
      rd_state_r <= READ_ADDR_WAIT;
      arid_r     <= '0;
      araddr_r   <= '0;
      rd_burst_r <= '0;
    end

  	else begin
      // write logic
      wr_state_r <= wr_state_n;
      awid_r     <= awid_n;
      awaddr_r   <= awaddr_n;

      if ((wr_state_r == WRITE_DATA_WAIT) & axi_wvalid_i) begin
        for (integer i=0; i < axi_strb_width_lp; i++) begin
          if (axi_wstrb_i[i]) begin
            ram[wr_ram_idx][i*8+:8] = axi_wdata_i[i*8+:8];
          end
        end
      end

      // read logic
      rd_state_r <= rd_state_n;
      arid_r     <= arid_n;
      araddr_r   <= araddr_n;
      rd_burst_r <= rd_burst_n;
    end
  end

  //==================================================
  // uninitialized data
  //
  logic [axi_data_width_p-1:0] uninit_data;
  assign uninit_data = {(axi_data_width_p/32){32'hdead_beef}};

  for (genvar i = 0; i < axi_data_width_p; i++) begin
    assign axi_rdata_o[i] = (ram[rd_ram_idx][i] === 1'bx)
      ? uninit_data[i]
      : ram[rd_ram_idx][i];
  end

endmodule