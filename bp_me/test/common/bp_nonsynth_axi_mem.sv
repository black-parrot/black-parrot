/**
 *  bp_nonsynth_axi_mem.v
 */

module bp_nonsynth_axi_mem
  #(parameter axi_id_width_p="inv"
    , parameter axi_addr_width_p="inv"
    , parameter axi_data_width_p="inv"

    // TODO: Should this be constant?
    , parameter axi_burst_len_p="inv"
    , parameter mem_els_p="inv"

    , parameter lg_mem_els_lp=`BSG_SAFE_CLOG2(mem_els_p)
    , parameter axi_strb_width_lp=(axi_data_width_p>>3)
  )
  ( 
    input clk_i
    , input reset_i
  
    , input [axi_id_width_p-1:0] axi_awid_i
    , input [axi_addr_width_p-1:0] axi_awaddr_i
    , input axi_awvalid_i
    , output logic axi_awready_o 

    , input [axi_data_width_p-1:0] axi_wdata_i
    , input [axi_strb_width_lp-1:0] axi_wstrb_i
    , input axi_wlast_i
    , input axi_wvalid_i
    , output logic axi_wready_o

    , output logic [axi_id_width_p-1:0] axi_bid_o
    , output logic [1:0] axi_bresp_o
    , output logic axi_bvalid_o
    , input axi_bready_i

    , input [axi_id_width_p-1:0] axi_arid_i
    , input [axi_addr_width_p-1:0] axi_araddr_i
    , input axi_arvalid_i
    , output logic axi_arready_o
  
    , output logic [axi_id_width_p-1:0] axi_rid_o
    , output logic [axi_data_width_p-1:0] axi_rdata_o
    , output logic [1:0] axi_rresp_o
    , output logic axi_rlast_o
    , output logic axi_rvalid_o
    , input axi_rready_i
  );

  logic [axi_data_width_p-1:0] ram [mem_els_p-1:0];

  // write channel
  //
  typedef enum logic [1:0] {
    WR_WAIT_ADDR,
    WR_WAIT_DATA,
    WR_RESP
  } wr_state_e;

  wr_state_e wr_state_r, wr_state_n;
  logic [axi_id_width_p-1:0] awid_r, awid_n;
  logic [axi_addr_width_p-1:0] awaddr_r, awaddr_n;
  logic [lg_mem_els_lp-1:0] wr_ram_idx;

  assign wr_ram_idx = awaddr_r[`BSG_SAFE_CLOG2(axi_data_width_p>>3)+:lg_mem_els_lp];

  always_comb begin

    axi_awready_o = 1'b0;

    axi_wready_o = 1'b0;
    
    axi_bid_o = awid_r;
    axi_bresp_o = '0;
    axi_bvalid_o = 1'b0;

    case (wr_state_r)
      WR_WAIT_ADDR: begin
        axi_awready_o = 1'b1;
        awid_n = axi_awvalid_i 
          ? axi_awid_i
          : awid_r;
        awaddr_n = axi_awvalid_i
          ? axi_awaddr_i
          : awaddr_r;
        wr_state_n = axi_awvalid_i
          ? WR_WAIT_DATA
          : WR_WAIT_ADDR;
      end
      
      WR_WAIT_DATA: begin
        axi_wready_o = 1'b1;
        awaddr_n = axi_wvalid_i
          ? awaddr_r + (1 << `BSG_SAFE_CLOG2(axi_data_width_p>>3))
          : awaddr_r;
        wr_state_n = axi_wvalid_i & axi_wlast_i
          ? WR_RESP
          : WR_WAIT_DATA;
      end

      WR_RESP: begin
        axi_bvalid_o = 1'b1;
        wr_state_n = axi_bready_i
          ? WR_WAIT_ADDR
          : WR_RESP;
      end
    endcase
  end

  // read channel
  //
  typedef enum logic {
    RD_WAIT_ADDR
    ,RD_SEND_DATA
  } rd_state_e;

  rd_state_e rd_state_r, rd_state_n;
  logic [axi_id_width_p-1:0] arid_r, arid_n;
  logic [axi_addr_width_p-1:0] araddr_r, araddr_n;
  logic [`BSG_SAFE_CLOG2(axi_burst_len_p)-1:0] rd_burst_r, rd_burst_n;

  logic [lg_mem_els_lp-1:0] rd_ram_idx;
  assign rd_ram_idx = araddr_r[`BSG_SAFE_CLOG2(axi_data_width_p>>3)+:lg_mem_els_lp];

  // uninitialized data
  //
  logic [axi_data_width_p-1:0] uninit_data;
  assign uninit_data = {(axi_data_width_p/32){32'hdead_beef}};

  for (genvar i = 0; i < axi_data_width_p; i++) begin
    assign axi_rdata_o[i] = (ram[rd_ram_idx][i] === 1'bx)
      ? uninit_data[i]
      : ram[rd_ram_idx][i];
  end

  //assign axi_rdata_o = ram[rd_ram_idx];
 
  always_comb begin

    axi_rvalid_o = 1'b0;
    axi_rlast_o = 1'b0;
    axi_rid_o = arid_r;
    axi_rresp_o = '0;
    axi_arready_o = 1'b0;

    case (rd_state_r)
      RD_WAIT_ADDR: begin
        axi_arready_o = 1'b1;

        arid_n = axi_arvalid_i
          ? axi_arid_i
          : arid_r;

        araddr_n = axi_arvalid_i
          ? axi_araddr_i
          : araddr_r;
    
        rd_burst_n = axi_arvalid_i
          ? '0
          : rd_burst_r;
        
        rd_state_n = axi_arvalid_i
          ? RD_SEND_DATA
          : RD_WAIT_ADDR;
      end

      RD_SEND_DATA: begin
        axi_rvalid_o = 1'b1;

        axi_rlast_o = (rd_burst_r == axi_burst_len_p-1);

        rd_burst_n = axi_rready_i
          ? rd_burst_r + 1
          : rd_burst_r;
    
        rd_state_n = ((rd_burst_r == axi_burst_len_p-1) & axi_rready_i)
          ? RD_WAIT_ADDR
          : RD_SEND_DATA;
      
        araddr_n = axi_rready_i
          ? araddr_r + (1 << `BSG_SAFE_CLOG2(axi_data_width_p>>3))
          : araddr_r;

      end
    endcase
  end 

  // sequential logic
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      wr_state_r <= WR_WAIT_ADDR;
      awid_r <= '0;
      awaddr_r <= '0;

      rd_state_r <= RD_WAIT_ADDR;
      arid_r <= '0;
      araddr_r <= '0;
      rd_burst_r <= '0;
    end
    else begin
      wr_state_r <= wr_state_n;
      awid_r <= awid_n;
      awaddr_r <= awaddr_n;

      if ((wr_state_r == WR_WAIT_DATA) & axi_wvalid_i) begin
        for (integer i = 0; i < axi_strb_width_lp; i++) begin
          if (axi_wstrb_i[i]) begin
            ram[wr_ram_idx][i*8+:8] = axi_wdata_i[i*8+:8];
          end
        end
      end

      rd_state_r <= rd_state_n;
      arid_r <= arid_n;
      araddr_r <= araddr_n;
      rd_burst_r <= rd_burst_n;
      
    end
  end
  

endmodule

