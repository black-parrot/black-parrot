/**
 * transducer.v
 *
 * This is the top level module for the CCE.
 *
 */

`include "bsg_defines.v"
`include "bp_common_me_if.vh"
`include "bp_cce_inst_pkg.v"
`include "bp_cce_internal_if.vh"

module transducer
  import bp_cce_inst_pkg::*;
  #(parameter num_lce_p=2
    ,parameter num_cce_p=1
    ,parameter addr_width_p="inv"
    ,parameter lce_assoc_p="inv"
    ,parameter lce_sets_p="inv"
    ,parameter coh_states_p=4
    ,parameter block_size_in_bytes_p="inv"

    ,parameter block_size_in_bits_lp=block_size_in_bytes_p*8

    ,parameter bp_lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, addr_width_p, lce_assoc_p)
    ,parameter bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, addr_width_p)
    ,parameter bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, addr_width_p, block_size_in_bits_lp)
    ,parameter bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, addr_width_p, lce_assoc_p, coh_states_p)
    ,parameter bp_cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, addr_width_p, block_size_in_bits_lp, lce_assoc_p)

    ,parameter harden_p=0

    ,parameter lg_block_size_in_bytes_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)
    ,parameter lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    ,parameter lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p)
  )
  (
    input                                                  clk_i
    ,input                                                 reset_i
    ,output                                                reset_done_o

    // LCE-CCE Interface

    // I$
    // inbound: ready->valid, helpful consumer from demanding producer
    ,input [bp_lce_cce_req_width_lp-1:0]                   icache_lce_req_i
    ,input                                                 icache_lce_req_v_i
    ,output logic                                          icache_lce_req_ready_o

    ,input [bp_lce_cce_resp_width_lp-1:0]                  icache_lce_resp_i
    ,input                                                 icache_lce_resp_v_i
    ,output logic                                          icache_lce_resp_ready_o

    ,input [bp_lce_cce_data_resp_width_lp-1:0]             icache_lce_data_resp_i
    ,input                                                 icache_lce_data_resp_v_i
    ,output logic                                          icache_lce_data_resp_ready_o

    // outbound: ready->valid, demanding producer to helpful consumer
    ,output logic [bp_cce_lce_cmd_width_lp-1:0]            icache_lce_cmd_o
    ,output logic                                          icache_lce_cmd_v_o
    ,input                                                 icache_lce_cmd_ready_i

    ,output logic [bp_cce_lce_data_cmd_width_lp-1:0]       icache_lce_data_cmd_o
    ,output logic                                          icache_lce_data_cmd_v_o
    ,input                                                 icache_lce_data_cmd_ready_i

    // D$
    // inbound: ready->valid, helpful consumer from demanding producer
    ,input [bp_lce_cce_req_width_lp-1:0]                   dcache_lce_req_i
    ,input                                                 dcache_lce_req_v_i
    ,output logic                                          dcache_lce_req_ready_o

    ,input [bp_lce_cce_resp_width_lp-1:0]                  dcache_lce_resp_i
    ,input                                                 dcache_lce_resp_v_i
    ,output logic                                          dcache_lce_resp_ready_o

    ,input [bp_lce_cce_data_resp_width_lp-1:0]             dcache_lce_data_resp_i
    ,input                                                 dcache_lce_data_resp_v_i
    ,output logic                                          dcache_lce_data_resp_ready_o

    // outbound: ready->valid, demanding producer to helpful consumer
    ,output logic [bp_cce_lce_cmd_width_lp-1:0]            dcache_lce_cmd_o
    ,output logic                                          dcache_lce_cmd_v_o
    ,input                                                 dcache_lce_cmd_ready_i

    ,output logic [bp_cce_lce_data_cmd_width_lp-1:0]       dcache_lce_data_cmd_o
    ,output logic                                          dcache_lce_data_cmd_v_o
    ,input                                                 dcache_lce_data_cmd_ready_i

    // Transducer-PMesh
    ,input                                                 noc1_ready_i
    ,output logic                                          noc1_v_o
    ,output logic [`NOC_DATA_WIDTH-1:0]                    noc1_data_o

    ,input                                                 noc2_v_i
    ,input [`NOC_DATA_WIDTH-1:0]                           noc2_data_i
    ,output logic                                          noc2_ready_o

    ,input                                                 noc3_ready_i
    ,output logic                                          noc3_v_o
    ,output logic [`NOC_DATA_WIDTH-1:0]                    noc3_data_o
  );

  logic rst_n;
  assign rst_n = ~reset_i;

  logic [bp_lce_cce_req_width_lp-1:0]            dcache_lce_req_to_tr;
  logic                                          dcache_lce_req_v_to_tr;
  logic                                          dcache_lce_req_yumi_from_tr;
  logic [bp_lce_cce_resp_width_lp-1:0]           dcache_lce_resp_to_tr;
  logic                                          dcache_lce_resp_v_to_tr;
  logic                                          dcache_lce_resp_yumi_from_tr;
  logic [bp_lce_cce_data_resp_width_lp-1:0]      dcache_lce_data_resp_to_tr;
  logic                                          dcache_lce_data_resp_v_to_tr;
  logic                                          dcache_lce_data_resp_yumi_from_tr;

  logic [bp_lce_cce_req_width_lp-1:0]            icache_lce_req_to_tr;
  logic                                          icache_lce_req_v_to_tr;
  logic                                          icache_lce_req_yumi_from_tr;
  logic [bp_lce_cce_resp_width_lp-1:0]           icache_lce_resp_to_tr;
  logic                                          icache_lce_resp_v_to_tr;
  logic                                          icache_lce_resp_yumi_from_tr;
  logic [bp_lce_cce_data_resp_width_lp-1:0]      icache_lce_data_resp_to_tr;
  logic                                          icache_lce_data_resp_v_to_tr;
  logic                                          icache_lce_data_resp_yumi_from_tr;

  logic l15_noc2decoder_ack;
  logic l15_noc2decoder_header_ack;
  logic noc2decoder_l15_val;
  logic [`L15_MSHR_ID_WIDTH-1:0] noc2decoder_l15_mshrid;
  logic noc2decoder_l15_l2miss;
  logic noc2decoder_l15_icache_type;
  logic noc2decoder_l15_f4b;
  logic [`MSG_TYPE_WIDTH-1:0] noc2decoder_l15_reqtype;
  logic [`L15_MESI_STATE_WIDTH-1:0] noc2decoder_l15_ack_state;
  logic [63:0] noc2decoder_l15_data_0;
  logic [63:0] noc2decoder_l15_data_1;
  logic [63:0] noc2decoder_l15_data_2;
  logic [63:0] noc2decoder_l15_data_3;
  logic [63:0] noc2decoder_l15_data_4;
  logic [63:0] noc2decoder_l15_data_5;
  logic [63:0] noc2decoder_l15_data_6;
  logic [63:0] noc2decoder_l15_data_7;
  logic [`L15_PADDR_HI:0] noc2decoder_l15_address;
  logic [3:0] noc2decoder_l15_fwd_subcacheline_vector;
  logic [`PACKET_HOME_ID_WIDTH-1:0] noc2decoder_l15_src_homeid;
  
  logic [`L15_CSM_NUM_TICKETS_LOG2-1:0] noc2decoder_l15_csm_mshrid;
  logic [`L15_THREADID_MASK] noc2decoder_l15_threadid;
  logic noc2decoder_l15_hmc_fill;

  // Look for interrupt packet
  logic                                          reset_int_recv;
  logic                                          reset_int_recv_r;
  logic                                          noc1_ready_with_reset;

  assign noc1_ready_with_reset = noc1_ready_i & reset_int_recv_r;

  always_ff @(posedge clk_i) begin
      if (~rst_n) begin
          reset_int_recv_r <= 1'b0;
      end
      else if (reset_int_recv) begin
          reset_int_recv_r <= 1'b1;
      end
  end

  always_comb begin
      if (noc2decoder_l15_val & (noc2decoder_l15_reqtype == `MSG_TYPE_INTERRUPT)) begin
        if (noc2decoder_l15_data_0[17:16] == 2'b01) begin
            reset_int_recv = 1'b1;
        end
        else begin
            reset_int_recv = 1'b0;
        end
      end
      else begin
          reset_int_recv = 1'b0;
      end
  end


  // Inbound LCE to Transducer - D$
  bsg_two_fifo
    #(.width_p(bp_lce_cce_req_width_lp)
      ,.ready_THEN_valid_p(1) // ready-then-valid
    )
    dcache_lce_tr_req_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.v_i(dcache_lce_req_v_i)
     ,.data_i(dcache_lce_req_i)
     ,.ready_o(dcache_lce_req_ready_o)
     ,.v_o(dcache_lce_req_v_to_tr)
     ,.data_o(dcache_lce_req_to_tr)
     ,.yumi_i(dcache_lce_req_yumi_from_tr)
    );

  bsg_two_fifo
    #(.width_p(bp_lce_cce_resp_width_lp)
      ,.ready_THEN_valid_p(1) // ready-then-valid
    )
    dcache_lce_tr_resp_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.v_i(dcache_lce_resp_v_i)
     ,.data_i(dcache_lce_resp_i)
     ,.ready_o(dcache_lce_resp_ready_o)
     ,.v_o(dcache_lce_resp_v_to_tr)
     ,.data_o(dcache_lce_resp_to_tr)
     ,.yumi_i(dcache_lce_resp_yumi_from_tr)
    );

  bsg_two_fifo
    #(.width_p(bp_lce_cce_data_resp_width_lp)
      ,.ready_THEN_valid_p(1) // ready-then-valid
    )
    dcache_lce_tr_data_resp_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.v_i(dcache_lce_data_resp_v_i)
     ,.data_i(dcache_lce_data_resp_i)
     ,.ready_o(dcache_lce_data_resp_ready_o)
     ,.v_o(dcache_lce_data_resp_v_to_tr)
     ,.data_o(dcache_lce_data_resp_to_tr)
     ,.yumi_i(dcache_lce_data_resp_yumi_from_tr)
    );

  // Inbound LCE to Transducer - I$
  bsg_two_fifo
    #(.width_p(bp_lce_cce_req_width_lp)
      ,.ready_THEN_valid_p(1) // ready-then-valid
    )
    icache_lce_tr_req_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.v_i(icache_lce_req_v_i)
     ,.data_i(icache_lce_req_i)
     ,.ready_o(icache_lce_req_ready_o)
     ,.v_o(icache_lce_req_v_to_tr)
     ,.data_o(icache_lce_req_to_tr)
     ,.yumi_i(icache_lce_req_yumi_from_tr)
    );

  bsg_two_fifo
    #(.width_p(bp_lce_cce_resp_width_lp)
      ,.ready_THEN_valid_p(1) // ready-then-valid
    )
    icache_lce_tr_resp_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.v_i(icache_lce_resp_v_i)
     ,.data_i(icache_lce_resp_i)
     ,.ready_o(icache_lce_resp_ready_o)
     ,.v_o(icache_lce_resp_v_to_tr)
     ,.data_o(icache_lce_resp_to_tr)
     ,.yumi_i(icache_lce_resp_yumi_from_tr)
    );

  bsg_two_fifo
    #(.width_p(bp_lce_cce_data_resp_width_lp)
      ,.ready_THEN_valid_p(1) // ready-then-valid
    )
    icache_lce_tr_data_resp_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.v_i(icache_lce_data_resp_v_i)
     ,.data_i(icache_lce_data_resp_i)
     ,.ready_o(icache_lce_data_resp_ready_o)
     ,.v_o(icache_lce_data_resp_v_to_tr)
     ,.data_o(icache_lce_data_resp_to_tr)
     ,.yumi_i(icache_lce_data_resp_yumi_from_tr)
    );

////////////////////////////////////////////////////////////////////////////////
// Piton PMesh side
////////////////////////////////////////////////////////////////////////////////

/*
    NoC2 buffer gets all the flits of a packet before transmitting it to the L1.5
    TODO: optimize it so that full buffering is not needed,
            ie. we can have a header ready signal + data ready signal
*/

logic [575:0] noc2_data;
logic noc2_data_val;
logic noc2_data_ack;

simplenocbuffer simplenocbuffer(
    .clk(clk_i),
    .rst_n(rst_n),
    // inputs
    .noc_in_val(noc2_v_i),
    .noc_in_data(noc2_data_i),
    .msg_ack(noc2_data_ack),
    // outputs
    .noc_in_rdy(noc2_ready_o),
    .msg(noc2_data),
    .msg_val(noc2_data_val)
);


/*
    noc2decoder takes the data from the buffer and decode it to meaningful signals
    to the l15
*/
assign l15_noc2decoder_ack = noc2_data_val;
assign l15_noc2decoder_header_ack = noc2_data_val;
noc2decoder noc2decoder(
    .clk(clk_i),
    .rst_n(rst_n),
    // inputs
    .noc2_data(noc2_data),
    .noc2_data_val(noc2_data_val),
    .l15_noc2decoder_ack(l15_noc2decoder_ack),
    .l15_noc2decoder_header_ack(l15_noc2decoder_header_ack),
    // outputs
    .noc2_data_ack(noc2_data_ack),
    .noc2decoder_l15_val(noc2decoder_l15_val),
    .noc2decoder_l15_mshrid(noc2decoder_l15_mshrid),
    .noc2decoder_l15_l2miss(noc2decoder_l15_l2miss),
    .noc2decoder_l15_icache_type(noc2decoder_l15_icache_type),
    .noc2decoder_l15_f4b(noc2decoder_l15_f4b),
    .noc2decoder_l15_reqtype(noc2decoder_l15_reqtype),
    .noc2decoder_l15_ack_state(noc2decoder_l15_ack_state),
    .noc2decoder_l15_data_0(noc2decoder_l15_data_0),
    .noc2decoder_l15_data_1(noc2decoder_l15_data_1),
    .noc2decoder_l15_data_2(noc2decoder_l15_data_2),
    .noc2decoder_l15_data_3(noc2decoder_l15_data_3),
    .noc2decoder_l15_data_4(noc2decoder_l15_data_4),
    .noc2decoder_l15_data_5(noc2decoder_l15_data_5),
    .noc2decoder_l15_data_6(noc2decoder_l15_data_6),
    .noc2decoder_l15_data_7(noc2decoder_l15_data_7),
    .noc2decoder_l15_address(noc2decoder_l15_address),
    .noc2decoder_l15_fwd_subcacheline_vector(noc2decoder_l15_fwd_subcacheline_vector),
    .noc2decoder_l15_src_homeid(noc2decoder_l15_src_homeid),
    .noc2decoder_l15_csm_mshrid(noc2decoder_l15_csm_mshrid),
    .noc2decoder_l15_threadid(noc2decoder_l15_threadid),
    .noc2decoder_l15_hmc_fill(noc2decoder_l15_hmc_fill),
    .l15_dmbr_l2missIn(l15_dmbr_l2missIn),
    .l15_dmbr_l2missTag(l15_dmbr_l2missTag),
    .l15_dmbr_l2responseIn(l15_dmbr_l2responseIn)
);



// noc1 signal declarations
logic noc1encoder_l15_req_ack;
logic noc1encoder_l15_req_sent;
logic l15_noc1buffer_req_val;
logic [`NOC1_BUFFER_ACK_DATA_WIDTH-1:0] noc1encoder_l15_req_data_sent;

logic [`L15_NOC1_REQTYPE_WIDTH-1:0] l15_noc1buffer_req_type;
logic [`L15_THREADID_MASK] l15_noc1buffer_req_threadid;
logic [`L15_MSHR_ID_WIDTH-1:0] l15_noc1buffer_req_mshrid;
logic [`L15_PADDR_HI:0] l15_noc1buffer_req_address;
logic l15_noc1buffer_req_non_cacheable;
logic [2:0] l15_noc1buffer_req_size;
logic l15_noc1buffer_req_prefetch;
// logic l15_noc1buffer_req_blkstore;
// logic l15_noc1buffer_req_blkinitstore;
logic [63:0] l15_noc1buffer_req_data_0;
logic [63:0] l15_noc1buffer_req_data_1;
logic [`TLB_CSM_WIDTH-1:0] l15_noc1buffer_req_csm_data;
// csm
logic [`L15_CSM_NUM_TICKETS_LOG2-1:0] l15_noc1buffer_req_csm_ticket;
logic [`PACKET_HOME_ID_WIDTH-1:0] l15_noc1buffer_req_homeid;
logic l15_noc1buffer_req_homeid_val;
logic [`MSG_SDID_WIDTH-1:0] noc1buffer_noc1encoder_req_csm_sdid;
logic [`MSG_LSID_WIDTH-1:0] noc1buffer_noc1encoder_req_csm_lsid;

logic [`L15_NOC1_REQTYPE_WIDTH-1:0] noc1buffer_noc1encoder_req_type;
logic [`L15_THREADID_MASK] noc1buffer_noc1encoder_req_threadid;
logic [`L15_MSHR_ID_WIDTH-1:0] noc1buffer_noc1encoder_req_mshrid;
logic [`L15_PADDR_HI:0] noc1buffer_noc1encoder_req_address;
logic noc1buffer_noc1encoder_req_non_cacheable;
logic [2:0] noc1buffer_noc1encoder_req_size;
logic noc1buffer_noc1encoder_req_prefetch;
// logic noc1buffer_noc1encoder_req_blkstore;
// logic noc1buffer_noc1encoder_req_blkinitstore;
logic [63:0] noc1buffer_noc1encoder_req_data_0;
logic [63:0] noc1buffer_noc1encoder_req_data_1;
logic [`PACKET_HOME_ID_WIDTH-1:0] noc1buffer_noc1encoder_req_homeid;

logic noc1encoder_noc1buffer_req_ack;
logic noc1buffer_noc1encoder_req_val;


// noc3 signal declarations
logic noc3encoder_l15_req_ack;
logic noc3encoder_noc3buffer_req_ack;

logic l15_noc3encoder_req_val;
logic noc3buffer_noc3encoder_req_val;
logic [`L15_NOC3_REQTYPE_WIDTH-1:0] l15_noc3encoder_req_type;
logic [63:0] l15_noc3encoder_req_data_0;
logic [63:0] l15_noc3encoder_req_data_1;
logic [63:0] l15_noc3encoder_req_data_2;
logic [63:0] l15_noc3encoder_req_data_3;
logic [63:0] l15_noc3encoder_req_data_4;
logic [63:0] l15_noc3encoder_req_data_5;
logic [63:0] l15_noc3encoder_req_data_6;
logic [63:0] l15_noc3encoder_req_data_7;
logic [`L15_MSHR_ID_WIDTH-1:0] l15_noc3encoder_req_mshrid;
logic [1:0] l15_noc3encoder_req_sequenceid;
logic [`L15_THREADID_MASK] l15_noc3encoder_req_threadid;
logic [`L15_PADDR_HI:0] l15_noc3encoder_req_address;
logic l15_noc3encoder_req_with_data;
logic l15_noc3encoder_req_was_inval;
logic [3:0] l15_noc3encoder_req_fwdack_vector;
logic [`PACKET_HOME_ID_WIDTH-1:0] l15_noc3encoder_req_homeid;

logic [`L15_NOC3_REQTYPE_WIDTH-1:0] noc3buffer_noc3encoder_req_type;
logic [63:0] noc3buffer_noc3encoder_req_data_0;
logic [63:0] noc3buffer_noc3encoder_req_data_1;
logic [63:0] noc3buffer_noc3encoder_req_data_2;
logic [63:0] noc3buffer_noc3encoder_req_data_3;
logic [63:0] noc3buffer_noc3encoder_req_data_4;
logic [63:0] noc3buffer_noc3encoder_req_data_5;
logic [63:0] noc3buffer_noc3encoder_req_data_6;
logic [63:0] noc3buffer_noc3encoder_req_data_7;
logic [`L15_MSHR_ID_WIDTH-1:0] noc3buffer_noc3encoder_req_mshrid;
logic [1:0] noc3buffer_noc3encoder_req_sequenceid;
logic [`L15_THREADID_MASK] noc3buffer_noc3encoder_req_threadid;
logic [`L15_PADDR_HI:0] noc3buffer_noc3encoder_req_address;
logic noc3buffer_noc3encoder_req_with_data;
logic noc3buffer_noc3encoder_req_was_inval;
logic [3:0] noc3buffer_noc3encoder_req_fwdack_vector;
logic [`PACKET_HOME_ID_WIDTH-1:0] noc3buffer_noc3encoder_req_homeid;




/*
NoC1 buffers data before send out to NoC1, unlike NoC3 which doesn't have to buffer
    The buffer scheme will probably work as follow:
        We will have 4 queues: writeback guard queue, CAS queue, 8B data inst queue, and ld/st queue
        - Combined WBG/ldst queue: 6 entries (1l/1s/1if each thread). No data
        - Dataqueue of 16B
            Supporting CAS/LDSTUB/SWAP and write-through. 1 CAS or 2 LDSTUB/SWAP or 2 write-through.
        All need to have the address + request metadata
    Priorities for the queues:
        1. writeback guard
        2. CAS
        3. data queue
        4. ld/st queue
        Note: TSO will not be violated regardless of how the NoC1 priority is chosen.
                This is due to the fact that only 1 load per thread can be outstanding, and no ordering between different threads enforced
                Actually, WBG might need to be ordered with respect to LD/ST req
*/
noc1buffer noc1buffer(
    .clk(clk_i),
    .rst_n(rst_n),
    // inputs
    .l15_noc1buffer_req_data_0(l15_noc1buffer_req_data_0),
    .l15_noc1buffer_req_data_1(l15_noc1buffer_req_data_1),
    .l15_noc1buffer_req_val(l15_noc1buffer_req_val),
    .l15_noc1buffer_req_type(l15_noc1buffer_req_type),
    .l15_noc1buffer_req_threadid(l15_noc1buffer_req_threadid),
    .l15_noc1buffer_req_mshrid(l15_noc1buffer_req_mshrid),
    .l15_noc1buffer_req_address(l15_noc1buffer_req_address),
    .l15_noc1buffer_req_non_cacheable(l15_noc1buffer_req_non_cacheable),
    .l15_noc1buffer_req_size(l15_noc1buffer_req_size),
    .l15_noc1buffer_req_prefetch(l15_noc1buffer_req_prefetch),
    // .l15_noc1buffer_req_blkstore(l15_noc1buffer_req_blkstore),
    // .l15_noc1buffer_req_blkinitstore(l15_noc1buffer_req_blkinitstore),
    .l15_noc1buffer_req_csm_data(l15_noc1buffer_req_csm_data),
    
    .l15_noc1buffer_req_csm_ticket(l15_noc1buffer_req_csm_ticket),
    .l15_noc1buffer_req_homeid(l15_noc1buffer_req_homeid),
    .l15_noc1buffer_req_homeid_val(l15_noc1buffer_req_homeid_val),

    // outputs
    .noc1buffer_noc1encoder_req_csm_sdid(noc1buffer_noc1encoder_req_csm_sdid),
    .noc1buffer_noc1encoder_req_csm_lsid(noc1buffer_noc1encoder_req_csm_lsid),
    
    .noc1encoder_noc1buffer_req_ack(noc1encoder_noc1buffer_req_ack),
    
    .noc1buffer_noc1encoder_req_data_0(noc1buffer_noc1encoder_req_data_0),
    .noc1buffer_noc1encoder_req_data_1(noc1buffer_noc1encoder_req_data_1),
    .noc1buffer_noc1encoder_req_val(noc1buffer_noc1encoder_req_val),
    .noc1buffer_noc1encoder_req_type(noc1buffer_noc1encoder_req_type),
    .noc1buffer_noc1encoder_req_mshrid(noc1buffer_noc1encoder_req_mshrid),
    .noc1buffer_noc1encoder_req_threadid(noc1buffer_noc1encoder_req_threadid),
    .noc1buffer_noc1encoder_req_address(noc1buffer_noc1encoder_req_address),
    .noc1buffer_noc1encoder_req_non_cacheable(noc1buffer_noc1encoder_req_non_cacheable),
    .noc1buffer_noc1encoder_req_size(noc1buffer_noc1encoder_req_size),
    .noc1buffer_noc1encoder_req_prefetch(noc1buffer_noc1encoder_req_prefetch),
    // .noc1buffer_noc1encoder_req_blkstore(noc1buffer_noc1encoder_req_blkstore),
    // .noc1buffer_noc1encoder_req_blkinitstore(noc1buffer_noc1encoder_req_blkinitstore),
    
    // stall signal from dmbr prevents the encoder from sending requests to the L2
    // .l15_dmbr_l1missIn(l15_dmbr_l1missIn),
    // .l15_dmbr_l1missTag(l15_dmbr_l1missTag),
    // .dmbr_l15_stall(dmbr_l15_stall),
    
    // CSM
    .l15_csm_read_ticket(l15_csm_read_ticket),
    .l15_csm_clear_ticket(l15_csm_clear_ticket),
    .l15_csm_clear_ticket_val(l15_csm_clear_ticket_val),
    .csm_l15_read_res_data(csm_l15_read_res_data),
    .csm_l15_read_res_val(csm_l15_read_res_val),
    .noc1buffer_noc1encoder_req_homeid(noc1buffer_noc1encoder_req_homeid),
    
    // .noc1buffer_l15_req_ack(noc1encoder_l15_req_ack),
    .noc1buffer_l15_req_sent(noc1encoder_l15_req_sent),
    .noc1buffer_l15_req_data_sent(noc1encoder_l15_req_data_sent),
    
    // homeid
    .noc1buffer_mshr_homeid_write_threadid_s4(noc1buffer_mshr_homeid_write_threadid_s4),
    .noc1buffer_mshr_homeid_write_val_s4(noc1buffer_mshr_homeid_write_val_s4),
    .noc1buffer_mshr_homeid_write_mshrid_s4(noc1buffer_mshr_homeid_write_mshrid_s4),
    .noc1buffer_mshr_homeid_write_data_s4(noc1buffer_mshr_homeid_write_data_s4)
);

noc1encoder noc1encoder(
    .clk(clk_i),
    .rst_n(rst_n),
    .noc1buffer_noc1encoder_req_data_0(noc1buffer_noc1encoder_req_data_0),
    .noc1buffer_noc1encoder_req_data_1(noc1buffer_noc1encoder_req_data_1),
    .noc1buffer_noc1encoder_req_val(noc1buffer_noc1encoder_req_val),
    .noc1buffer_noc1encoder_req_type(noc1buffer_noc1encoder_req_type),
    .noc1buffer_noc1encoder_req_mshrid(noc1buffer_noc1encoder_req_mshrid),
    .noc1buffer_noc1encoder_req_threadid(noc1buffer_noc1encoder_req_threadid),
    .noc1buffer_noc1encoder_req_address(noc1buffer_noc1encoder_req_address),
    .noc1buffer_noc1encoder_req_non_cacheable(noc1buffer_noc1encoder_req_non_cacheable),
    .noc1buffer_noc1encoder_req_size(noc1buffer_noc1encoder_req_size),
    .noc1buffer_noc1encoder_req_prefetch(noc1buffer_noc1encoder_req_prefetch),
    // .noc1buffer_noc1encoder_req_blkstore(noc1buffer_noc1encoder_req_blkstore),
    // .noc1buffer_noc1encoder_req_blkinitstore(noc1buffer_noc1encoder_req_blkinitstore),
    .noc1buffer_noc1encoder_req_csm_sdid(noc1buffer_noc1encoder_req_csm_sdid),
    .noc1buffer_noc1encoder_req_csm_lsid(noc1buffer_noc1encoder_req_csm_lsid),
    .noc1buffer_noc1encoder_req_homeid(noc1buffer_noc1encoder_req_homeid),
    
    .dmbr_l15_stall(dmbr_l15_stall),
    .chipid(chipid),
    .coreid_x(coreid_x),
    .coreid_y(coreid_y),
    .noc1out_ready(noc1_ready_with_reset),
    
    .l15_dmbr_l1missIn(l15_dmbr_l1missIn),
    .l15_dmbr_l1missTag(l15_dmbr_l1missTag),
    .noc1encoder_noc1buffer_req_ack(noc1encoder_noc1buffer_req_ack),
    .noc1encoder_noc1out_val(noc1_v_o),
    .noc1encoder_noc1out_data(noc1_data_o),
    
    // csm interface
    .noc1encoder_csm_req_ack(noc1encoder_csm_req_ack),
    .csm_noc1encoder_req_val(csm_noc1encoder_req_val),
    .csm_noc1encoder_req_type(csm_noc1encoder_req_type),
    .csm_noc1encoder_req_mshrid(csm_noc1encoder_req_mshrid),
    .csm_noc1encoder_req_address(csm_noc1encoder_req_address),
    .csm_noc1encoder_req_non_cacheable(csm_noc1encoder_req_non_cacheable),
    .csm_noc1encoder_req_size(csm_noc1encoder_req_size)
);


/*
   1 deep buffer for noc3 to improve performance and reduce timing pressure
*/
noc3buffer noc3buffer(
    .clk(clk_i),
    .rst_n(rst_n),
    .l15_noc3encoder_req_val(l15_noc3encoder_req_val),
    .l15_noc3encoder_req_type(l15_noc3encoder_req_type),
    .l15_noc3encoder_req_data_0(l15_noc3encoder_req_data_0),
    .l15_noc3encoder_req_data_1(l15_noc3encoder_req_data_1),
    .l15_noc3encoder_req_data_2(l15_noc3encoder_req_data_2),
    .l15_noc3encoder_req_data_3(l15_noc3encoder_req_data_3),
    .l15_noc3encoder_req_data_4(l15_noc3encoder_req_data_4),
    .l15_noc3encoder_req_data_5(l15_noc3encoder_req_data_5),
    .l15_noc3encoder_req_data_6(l15_noc3encoder_req_data_6),
    .l15_noc3encoder_req_data_7(l15_noc3encoder_req_data_7),
    .l15_noc3encoder_req_mshrid(l15_noc3encoder_req_mshrid),
    .l15_noc3encoder_req_sequenceid(l15_noc3encoder_req_sequenceid),
    .l15_noc3encoder_req_threadid(l15_noc3encoder_req_threadid),
    .l15_noc3encoder_req_address(l15_noc3encoder_req_address),
    .l15_noc3encoder_req_with_data(l15_noc3encoder_req_with_data),
    .l15_noc3encoder_req_was_inval(l15_noc3encoder_req_was_inval),
    .l15_noc3encoder_req_fwdack_vector(l15_noc3encoder_req_fwdack_vector),
    .l15_noc3encoder_req_homeid(l15_noc3encoder_req_homeid),
    .noc3buffer_l15_req_ack(noc3encoder_l15_req_ack),
    
    // from buffer to encoder
    .noc3buffer_noc3encoder_req_val(noc3buffer_noc3encoder_req_val),
    .noc3buffer_noc3encoder_req_type(noc3buffer_noc3encoder_req_type),
    .noc3buffer_noc3encoder_req_data_0(noc3buffer_noc3encoder_req_data_0),
    .noc3buffer_noc3encoder_req_data_1(noc3buffer_noc3encoder_req_data_1),
    .noc3buffer_noc3encoder_req_data_2(noc3buffer_noc3encoder_req_data_2),
    .noc3buffer_noc3encoder_req_data_3(noc3buffer_noc3encoder_req_data_3),
    .noc3buffer_noc3encoder_req_data_4(noc3buffer_noc3encoder_req_data_4),
    .noc3buffer_noc3encoder_req_data_5(noc3buffer_noc3encoder_req_data_5),
    .noc3buffer_noc3encoder_req_data_6(noc3buffer_noc3encoder_req_data_6),
    .noc3buffer_noc3encoder_req_data_7(noc3buffer_noc3encoder_req_data_7),
    .noc3buffer_noc3encoder_req_mshrid(noc3buffer_noc3encoder_req_mshrid),
    .noc3buffer_noc3encoder_req_sequenceid(noc3buffer_noc3encoder_req_sequenceid),
    .noc3buffer_noc3encoder_req_threadid(noc3buffer_noc3encoder_req_threadid),
    .noc3buffer_noc3encoder_req_address(noc3buffer_noc3encoder_req_address),
    .noc3buffer_noc3encoder_req_with_data(noc3buffer_noc3encoder_req_with_data),
    .noc3buffer_noc3encoder_req_was_inval(noc3buffer_noc3encoder_req_was_inval),
    .noc3buffer_noc3encoder_req_fwdack_vector(noc3buffer_noc3encoder_req_fwdack_vector),
    .noc3buffer_noc3encoder_req_homeid(noc3buffer_noc3encoder_req_homeid),
    .noc3encoder_noc3buffer_req_ack(noc3encoder_noc3buffer_req_ack)
);

noc3encoder noc3encoder(
    .clk(clk_i),
    .rst_n(rst_n),
    .l15_noc3encoder_req_val(noc3buffer_noc3encoder_req_val),
    .l15_noc3encoder_req_type(noc3buffer_noc3encoder_req_type),
    .l15_noc3encoder_req_data_0(noc3buffer_noc3encoder_req_data_0),
    .l15_noc3encoder_req_data_1(noc3buffer_noc3encoder_req_data_1),
    .l15_noc3encoder_req_data_2(noc3buffer_noc3encoder_req_data_2),
    .l15_noc3encoder_req_data_3(noc3buffer_noc3encoder_req_data_3),
    .l15_noc3encoder_req_data_4(noc3buffer_noc3encoder_req_data_4),
    .l15_noc3encoder_req_data_5(noc3buffer_noc3encoder_req_data_5),
    .l15_noc3encoder_req_data_6(noc3buffer_noc3encoder_req_data_6),
    .l15_noc3encoder_req_data_7(noc3buffer_noc3encoder_req_data_7),
    .l15_noc3encoder_req_mshrid(noc3buffer_noc3encoder_req_mshrid),
    .l15_noc3encoder_req_sequenceid(noc3buffer_noc3encoder_req_sequenceid),
    .l15_noc3encoder_req_threadid(noc3buffer_noc3encoder_req_threadid),
    .l15_noc3encoder_req_address(noc3buffer_noc3encoder_req_address),
    .l15_noc3encoder_req_with_data(noc3buffer_noc3encoder_req_with_data),
    .l15_noc3encoder_req_was_inval(noc3buffer_noc3encoder_req_was_inval),
    .l15_noc3encoder_req_fwdack_vector(noc3buffer_noc3encoder_req_fwdack_vector),
    .l15_noc3encoder_req_homeid(noc3buffer_noc3encoder_req_homeid),
    .chipid(chipid),
    .coreid_x(coreid_x),
    .coreid_y(coreid_y),
    .noc3out_ready(noc3_ready_i),
    .noc3encoder_l15_req_ack(noc3encoder_noc3buffer_req_ack),
    .noc3encoder_noc3out_val(noc3_v_o),
    .noc3encoder_noc3out_data(noc3_data_o)
);


// Transducer state machine and protocol translator

/* LCE to CCE messages
 *
 * lce_cce_sync_ack: internal to transducer
 * lce_cce_coherence_ack: likely pass through to NoC3 as an ack
 *
 *
 *
 *
 * CCE to LCE messages
 *
 * cce_lce_set_clear_cmd: internal between transducer and LCEs
 * cce_lce_sync_cmd: internal between transducer and LCEs
 *
 *
 * NoC1 (low priority)
 *
 * ReqRd = lce_cce_read_cache_req
 * ReqExRd = lce_cce_write_cache_req
 * ReqWBGuard = generate when sending a writeback on NoC3
 *
 *
 * NoC2 (medium priority)
 *
 * FwdRd = set tag to invalid (or shared?), initiate writeback
 * FwdRdEx = set tag to invalid, initiate writeback
 * Inv = set tag (invalid)
 * LdMem = send data
 * StMem = 
 * AckDt = send set tag and data to LCE
 * Ack = absorb, maybe send tag?
 *
 *
 *
 * NoC3 (high priority)
 *
 */


  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, addr_width_p, lce_assoc_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, addr_width_p);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, addr_width_p, block_size_in_bits_lp);
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, addr_width_p, lce_assoc_p, coh_states_p);
  `declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, addr_width_p, block_size_in_bits_lp, lce_assoc_p);
  `declare_bp_lce_lce_tr_resp_s(num_lce_p, addr_width_p, block_size_in_bits_lp, lce_assoc_p);

  // Registers for LCE to CCE messages - these get shared by I$ and D$ channels
  bp_lce_cce_req_s          lce_req_r;
  bp_lce_cce_resp_s         lce_resp_r;
  bp_lce_cce_data_resp_s    lce_data_resp_r;

  // Registers for CCE to LCE messages - these are unique per I$ and D$
  bp_cce_lce_cmd_s          dcache_lce_cmd_r;
  bp_cce_lce_cmd_s          icache_lce_cmd_r;
  bp_cce_lce_data_cmd_s     dcache_lce_data_cmd_r;
  bp_cce_lce_data_cmd_s     icache_lce_data_cmd_r;

  always_comb begin
    dcache_lce_cmd_o = dcache_lce_cmd_r;
    icache_lce_cmd_o = icache_lce_cmd_r;
    dcache_lce_data_cmd_o = dcache_lce_data_cmd_r;
    icache_lce_data_cmd_o = icache_lce_data_cmd_r;
  end

  typedef enum logic [4:0] {
    RESET_SET_CLEAR
    ,RESET_SYNC
    ,RESET_SYNC_ACK
    ,READY
    ,LCE_REQ
    ,LCE_REQ_END
    ,LCE_RESP
    ,LCE_DATA_RESP
    ,SEND_CCE_CMD
    ,SEND_CCE_DATA_CMD
  } transducer_state_e;

  transducer_state_e trans_state;

  logic icache_req_r;
  logic [lg_lce_sets_lp:0] set_count_r;

  logic [lg_num_lce_lp:0] sync_count_r;
  logic [lg_num_lce_lp:0] sync_ack_count_r;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      trans_state <= RESET_SET_CLEAR;
      lce_req_r <= '0;
      lce_resp_r <= '0;
      lce_data_resp_r <= '0;

      dcache_lce_cmd_r <= '0;
      dcache_lce_cmd_v_o <= 1'b0;
      icache_lce_cmd_r <= '0;
      icache_lce_cmd_v_o <= 1'b0;

      dcache_lce_data_cmd_r <= '0;
      dcache_lce_data_cmd_v_o <= 1'b0;
      icache_lce_data_cmd_r <= '0;
      icache_lce_data_cmd_v_o <= 1'b0;

      icache_req_r <= 1'b0;
      set_count_r <= '0;
      sync_count_r <= '0;
      sync_ack_count_r <= '0;

      icache_lce_req_yumi_from_tr <= 1'b0;
      icache_lce_resp_yumi_from_tr <= 1'b0;
      icache_lce_data_resp_yumi_from_tr <= 1'b0;
      dcache_lce_req_yumi_from_tr <= 1'b0;
      dcache_lce_resp_yumi_from_tr <= 1'b0;
      dcache_lce_data_resp_yumi_from_tr <= 1'b0;

    end else begin
      case (trans_state)
        RESET_SET_CLEAR: begin
          if (set_count_r < lce_sets_p) begin
            if (dcache_lce_cmd_ready_i && icache_lce_cmd_ready_i) begin
              dcache_lce_cmd_v_o <= 1'b1;
              dcache_lce_cmd_r.dst_id <= 1'b1;
              dcache_lce_cmd_r.src_id <= 1'b0;
              dcache_lce_cmd_r.msg_type <= e_lce_cmd_set_clear;
              dcache_lce_cmd_r.addr <= (set_count_r << (lg_block_size_in_bytes_lp));
              dcache_lce_cmd_r.way_id <= '0;
              dcache_lce_cmd_r.state <= '0;
              dcache_lce_cmd_r.target <= '0;
              dcache_lce_cmd_r.target_way_id <= '0;

              icache_lce_cmd_v_o <= 1'b1;
              icache_lce_cmd_r.dst_id <= 1'b0;
              icache_lce_cmd_r.src_id <= 1'b0;
              icache_lce_cmd_r.msg_type <= e_lce_cmd_set_clear;
              icache_lce_cmd_r.addr <= (set_count_r << (lg_block_size_in_bytes_lp));
              icache_lce_cmd_r.way_id <= '0;
              icache_lce_cmd_r.state <= '0;
              icache_lce_cmd_r.target <= '0;
              icache_lce_cmd_r.target_way_id <= '0;

              set_count_r <= set_count_r + 'd1;

            end else begin
              dcache_lce_cmd_r <= '0;
              dcache_lce_cmd_v_o <= 1'b0;
              icache_lce_cmd_r <= '0;
              icache_lce_cmd_v_o <= 1'b0;
            end
          end else begin
            dcache_lce_cmd_r <= '0;
            dcache_lce_cmd_v_o <= 1'b0;
            icache_lce_cmd_r <= '0;
            icache_lce_cmd_v_o <= 1'b0;
            trans_state <= RESET_SYNC;
          end
        end
        RESET_SYNC: begin
          if (sync_count_r < num_lce_p) begin
            if (dcache_lce_cmd_ready_i && icache_lce_cmd_ready_i) begin
              dcache_lce_cmd_v_o <= 1'b1;
              dcache_lce_cmd_r.dst_id <= 1'b1;
              dcache_lce_cmd_r.src_id <= 1'b0;
              dcache_lce_cmd_r.msg_type <= e_lce_cmd_sync;
              dcache_lce_cmd_r.addr <= '0;
              dcache_lce_cmd_r.way_id <= '0;
              dcache_lce_cmd_r.state <= '0;
              dcache_lce_cmd_r.target <= '0;
              dcache_lce_cmd_r.target_way_id <= '0;

              icache_lce_cmd_v_o <= 1'b1;
              icache_lce_cmd_r.dst_id <= 1'b0;
              icache_lce_cmd_r.src_id <= 1'b0;
              icache_lce_cmd_r.msg_type <= e_lce_cmd_sync;
              icache_lce_cmd_r.addr <= '0;
              icache_lce_cmd_r.way_id <= '0;
              icache_lce_cmd_r.state <= '0;
              icache_lce_cmd_r.target <= '0;
              icache_lce_cmd_r.target_way_id <= '0;

              sync_count_r <= sync_count_r + 'd1;

            end else begin
              dcache_lce_cmd_r <= '0;
              dcache_lce_cmd_v_o <= 1'b0;
              icache_lce_cmd_r <= '0;
              icache_lce_cmd_v_o <= 1'b0;
            end
          end else begin
            dcache_lce_cmd_r <= '0;
            dcache_lce_cmd_v_o <= 1'b0;
            icache_lce_cmd_r <= '0;
            icache_lce_cmd_v_o <= 1'b0;
            trans_state <= RESET_SYNC_ACK;
          end
        end
        RESET_SYNC_ACK: begin
          icache_lce_resp_yumi_from_tr <= '0;
          dcache_lce_resp_yumi_from_tr <= '0;
          if (sync_ack_count_r < num_lce_p) begin
            if (icache_lce_resp_v_to_tr) begin
              sync_ack_count_r <= sync_ack_count_r + 'd1;
              icache_lce_resp_yumi_from_tr <= 1'b1;
              lce_resp_r <= icache_lce_resp_to_tr;
            end else if (dcache_lce_resp_v_to_tr) begin
              sync_ack_count_r <= sync_ack_count_r + 'd1;
              dcache_lce_resp_yumi_from_tr <= 1'b1;
              lce_resp_r <= dcache_lce_resp_to_tr;
            end else begin
              dcache_lce_resp_yumi_from_tr <= '0;
              icache_lce_resp_yumi_from_tr <= '0;
              lce_resp_r <= '0;
            end
          end else begin
            dcache_lce_resp_yumi_from_tr <= '0;
            icache_lce_resp_yumi_from_tr <= '0;
            lce_resp_r <= '0;
            trans_state <= READY;
          end
        end
        READY: begin
          dcache_lce_cmd_v_o <= '0;
          icache_lce_cmd_v_o <= '0;
          // prefer icache requests over dcache requests
          if (icache_lce_req_v_to_tr) begin
            lce_req_r <= icache_lce_req_to_tr;
            icache_lce_req_yumi_from_tr <= 1'b1;
            trans_state <= LCE_REQ;
            icache_req_r <= 1'b1;
          end else if (dcache_lce_req_v_to_tr) begin
            lce_req_r <= dcache_lce_req_to_tr;
            dcache_lce_req_yumi_from_tr <= 1'b1;
            trans_state <= LCE_REQ;
          end
        end
        LCE_REQ: begin
          icache_lce_req_yumi_from_tr <= '0;
          dcache_lce_req_yumi_from_tr <= '0;

          l15_noc1buffer_req_val <= 1'b1;
          if (icache_req_r) begin
            l15_noc1buffer_req_type <= `L15_NOC1_REQTYPE_IFILL_REQUEST;
            icache_req_r <= '0;
          //end else begin
          // TODO: how do we know that request should be Rd or RdEx?
          // LCE does not send any information about this because it is tracked by
          // the CCE.
          //  l15_noc1buffer_req_type <= `L15_NOC1_REQTYPE_
          end

          l15_noc1buffer_req_threadid <= '0;
          l15_noc1buffer_req_mshrid <= '0;
          l15_noc1buffer_req_address <= lce_req_r.addr;
          l15_noc1buffer_req_non_cacheable <= '0;
          l15_noc1buffer_req_size <= 3'b100;
          l15_noc1buffer_req_prefetch <= '0;


          l15_noc1buffer_req_csm_data <= '0;
          l15_noc1buffer_req_data_0 <= '0;
          l15_noc1buffer_req_data_1 <= '0;

        end
        LCE_REQ_END: begin
          l15_noc1buffer_req_val <= '0;
          trans_state <= READY;
        end
        default: begin
          trans_state <= RESET_SET_CLEAR;
        end
      endcase
    end
  end



endmodule
