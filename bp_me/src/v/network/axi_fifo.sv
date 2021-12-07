/* This module implements a FIFO connected to
*  AXI-Lite interfaces on both ends.
*
*  The input side is write-only, a read returns 0
*  and does not hang.
*
*  The output side is read-only, a write is dropped
*  and does not hang.
*/

module axi_fifo
 #(parameter fifo_els_p = -1
  // AXI WRITE DATA CHANNEL PARAMS
  , parameter  axi_data_width_p             = 32
  , localparam axi_strb_width_lp            = axi_data_width_p/8

  // AXI WRITE/READ ADDRESS CHANNEL PARAMS
  , parameter  axi_addr_width_p             = 32
  )

  (//==================== GLOBAL SIGNALS =======================
   input clk_i
   , input reset_i

   //=================== AXI-4 LITE INPUT =======================
   // WRITE ADDRESS CHANNEL SIGNALS
   , input [axi_addr_width_p-1:0]               in_axi_lite_awaddr_i
   , input [2:0]                                in_axi_lite_awprot_i
   , input                                      in_axi_lite_awvalid_i
   , output logic                               in_axi_lite_awready_o

   // WRITE DATA CHANNEL SIGNALS
   , input [axi_data_width_p-1:0]               in_axi_lite_wdata_i
   , input [axi_strb_width_lp-1:0]              in_axi_lite_wstrb_i
   , input                                      in_axi_lite_wvalid_i
   , output logic                               in_axi_lite_wready_o

   // WRITE RESPONSE CHANNEL SIGNALS
   , output [1:0]                               in_axi_lite_bresp_o
   , output logic                               in_axi_lite_bvalid_o
   , input                                      in_axi_lite_bready_i

   // READ ADDRESS CHANNEL SIGNALS
   , input [axi_addr_width_p-1:0]               in_axi_lite_araddr_i
   , input [2:0]                                in_axi_lite_arprot_i
   , input                                      in_axi_lite_arvalid_i
   , output logic                               in_axi_lite_arready_o

   // READ DATA CHANNEL SIGNALS
   , output logic [axi_data_width_p-1:0]        in_axi_lite_rdata_o
   , output [1:0]                               in_axi_lite_rresp_o
   , output logic                               in_axi_lite_rvalid_o
   , input                                      in_axi_lite_rready_i

   //================== AXI-4 LITE OUTPUT =======================
   // WRITE ADDRESS CHANNEL SIGNALS
   , input [axi_addr_width_p-1:0]               out_axi_lite_awaddr_i
   , input [2:0]                                out_axi_lite_awprot_i
   , input                                      out_axi_lite_awvalid_i
   , output logic                               out_axi_lite_awready_o

   // WRITE DATA CHANNEL SIGNALS
   , input [axi_data_width_p-1:0]               out_axi_lite_wdata_i
   , input [axi_strb_width_lp-1:0]              out_axi_lite_wstrb_i
   , input                                      out_axi_lite_wvalid_i
   , output logic                               out_axi_lite_wready_o

   // WRITE RESPONSE CHANNEL SIGNALS
   , output [1:0]                               out_axi_lite_bresp_o
   , output logic                               out_axi_lite_bvalid_o
   , input                                      out_axi_lite_bready_i

   // READ ADDRESS CHANNEL SIGNALS
   , input [axi_addr_width_p-1:0]               out_axi_lite_araddr_i
   , input [2:0]                                out_axi_lite_arprot_i
   , input                                      out_axi_lite_arvalid_i
   , output logic                               out_axi_lite_arready_o

   // READ DATA CHANNEL SIGNALS
   , output logic [axi_data_width_p-1:0]        out_axi_lite_rdata_o
   , output [1:0]                               out_axi_lite_rresp_o
   , output logic                               out_axi_lite_rvalid_o
   , input                                      out_axi_lite_rready_i
  );

  // Protection signals aren't used right now
  wire [2:0]  unused_0 = in_axi_lite_awprot_i;
  wire [2:0]  unused_1 = in_axi_lite_arprot_i;
  wire [2:0]  unused_2 = out_axi_lite_awprot_i;
  wire [2:0]  unused_3 = out_axi_lite_arprot_i;

  // Input read and output write signals aren't used
  wire [axi_addr_width_p-1:0]  unused_4 = in_axi_lite_araddr_i;
  wire [axi_addr_width_p-1:0]  unused_5 = out_axi_lite_awaddr_i;
  wire [axi_data_width_p-1:0]  unused_6 = out_axi_lite_wdata_i;
  wire [axi_strb_width_lp-1:0] unused_7 = out_axi_lite_wstrb_i;

  // Use the strobe to enqueue correct data
  logic [axi_data_width_p-1:0] fifo_data_li, fifo_data_lo;
  for (genvar i = 0; i < axi_strb_width_lp; i++) begin : fifo_data
    assign fifo_data_li[i*8+:8] = (in_axi_lite_wstrb_i[i])
                                  ? in_axi_lite_wdata_i[i*8+:8]
                                  : 8'b0;
  end

  // Axi device read or write channel validity
  logic in_axi_lite_r_v, in_axi_lite_w_v;
  logic out_axi_lite_r_v, out_axi_lite_w_v;

  assign in_axi_lite_w_v = in_axi_lite_wvalid_i & in_axi_lite_awvalid_i;
  assign out_axi_lite_r_v = out_axi_lite_arvalid_i;

  // Output side write is always ready because it is dropped
  assign out_axi_lite_awready_o = 1'b1;
  assign out_axi_lite_wready_o  = 1'b1;
  assign out_axi_lite_bresp_o   = '0;

  // Logic for output side bvalid
  always_ff @(posedge clk_i)
    begin
      if (reset_i)
	out_axi_lite_bvalid_o <= 1'b0;
      else if (out_axi_lite_awvalid_i & out_axi_lite_wvalid_i)
	out_axi_lite_bvalid_o <= 1'b1;
      else if (out_axi_lite_bready_i)
	out_axi_lite_bvalid_o <= 1'b0;
    end

  // Input side read is always ready because it returns 0
  assign in_axi_lite_arready_o  = 1'b1;
  assign in_axi_lite_rdata_o    = '0;
  assign in_axi_lite_rresp_o    = '0;

  // Logic for input side read
  always_ff @(posedge clk_i)
    begin
      if (reset_i)
	in_axi_lite_rvalid_o <= 1'b0;
      else if (in_axi_lite_arvalid_i)
	in_axi_lite_rvalid_o <= 1'b1;
      else if (in_axi_lite_rready_i)
	in_axi_lite_rvalid_o <= 1'b0;
    end

  logic fifo_v_li, fifo_ready_lo;
  logic fifo_v_lo, fifo_yumi_li;

  // The FIFO
  bsg_fifo_1r1w_small
   #(.width_p(axi_data_width_p)
     ,.els_p(fifo_els_p)
     )
   msg_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(fifo_data_li)
     ,.v_i(fifo_v_li)
     ,.ready_o(fifo_ready_lo)

     ,.data_o(fifo_data_lo)
     ,.v_o(fifo_v_lo)
     ,.yumi_i(fifo_yumi_li)
     );

  // Counter for number of elements in the FIFO
  logic num_free_els;
  bsg_flow_counter
   #(.els_p(fifo_els_p))
   free_els_count
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(in_axi_lite_w_v)
     ,.ready_i(fifo_ready_lo)
     ,.yumi_i(fifo_yumi_li)

     ,.count_o(num_free_els)
     );

  enum logic {e_write_wait, e_write_resp} in_state_r, in_state_n;
  enum logic [1:0] {e_read_wait, e_count_resp, e_fifo_resp} out_state_r, out_state_n;

  // Input combinational logic
  always_comb
    begin
      // WRITE ADDRESS CHANNEL SIGNALS
      in_axi_lite_awready_o = '0;

      // WRITE DATA CHANNEL SIGNALS
      in_axi_lite_wready_o  = '0;

      // WRITE RESPONSE CHANNEL SIGNALS
      in_axi_lite_bresp_o   = '0;
      in_axi_lite_bvalid_o  = '0;

      fifo_v_li             = '0;
      in_state_n            = in_state_r;

      case (in_state_r)
        e_write_wait : begin
          // The AXI interface is ready if FIFO is not full
          in_axi_lite_awready_o = fifo_ready_lo;
          in_axi_lite_wready_o  = fifo_ready_lo;

	  // Enqueue the FIFO if a request arrives and FIFO is not full
          fifo_v_li  = in_axi_lite_w_v & fifo_ready_lo;
          in_state_n = fifo_v_li ? e_write_resp : e_write_wait;
        end

        e_write_resp : begin
          // Response valid is high until bready arrives
          in_axi_lite_bvalid_o = 1'b1;
          in_state_n           = (in_axi_lite_bready_i)
                               ? e_write_wait
                               : e_write_resp;
        end
      endcase
    end

  // Output combinational logic
  always_comb
    begin
      // READ ADDRESS CHANNEL SIGNALS
      out_axi_lite_arready_o = '0;

      // READ DATA CHANNEL SIGNALS
      out_axi_lite_rvalid_o  = '0;
      out_axi_lite_rdata_o   = '0;
      out_axi_lite_rresp_o   = '0;

      fifo_yumi_li           = '0;
      out_state_n            = out_state_r;

      case(out_state_r)
	e_read_wait : begin
          // Read ready is always high in this state since the request is
	  // accepted
	  out_axi_lite_arready_o = 1'b1;
	  // Decide which module to read based on address
	  out_state_n            = out_axi_lite_r_v
	  			   ? (out_axi_lite_araddr_i[3:0] == 3'h4)
	  			     ? e_count_resp
				     : e_fifo_resp
				   : e_read_wait;
	end

	e_count_resp : begin
          // Send the num_free_els as rdata
	  out_axi_lite_rvalid_o = 1'b1;
	  out_axi_lite_rdata_o  = axi_data_width_p'(num_free_els);
	  out_state_n           = out_axi_lite_rready_i
	  			  ? e_read_wait
				  : e_count_resp;
	end

	e_fifo_resp : begin
          // Send the FIFO data as rdata if FIFO is not empty, else send -1
          // Only dequeue the FIFO if there was valid data in it
	  out_axi_lite_rvalid_o = 1'b1;
	  out_axi_lite_rdata_o  = fifo_v_lo ? fifo_data_lo : '1;

	  fifo_yumi_li          = fifo_v_lo & out_axi_lite_rready_i;
	  out_state_n           = out_axi_lite_rready_i
	  			  ? e_read_wait
				  : e_fifo_resp;
	end

	default : begin
	  out_state_n = e_read_wait;
	end
      endcase
    end

  always_ff @(posedge clk_i)
    begin
      if (reset_i)
	begin
          in_state_r <= e_write_wait;
	  out_state_r <= e_read_wait;
	end
      else
	begin
          in_state_r <= in_state_n;
	  out_state_r <= out_state_n;
	end
    end

  if (axi_data_width_p != 32 && axi_data_width_p != 64)
    $error("AXI4-LITE only supports a data width of 32 or 64bits.");

  //synopsys translate_off
  initial
    begin
      assert(reset_i !== '0 || in_axi_lite_awprot_i == 3'b000) else $info("AXI4-LITE access permission mode is not supported.");
    end
  //synopsys translate_on
endmodule
