/**
 *
 * test_bp.v
 *
 */

#include <map>
#include <iomanip>
#include <string>
#include <unistd.h>

#include "systemc.h"
#include "verilated_vcd_sc.h"

#include "Vbp_me_top_test.h"

#include "bp_cce_verilator.h"
#include "bp_cce.h"
#include "bp_common_me_if.h"
#include "bp_cce_lce_msg_util.h"

#define STALL_MAX (CLK_TIME*1000)

uint64_t tags[N_LCE][LCE_SETS][LCE_ASSOC];

uint64_t getTag(uint64_t addr) {
  return (addr >> (LG_LCE_SETS + LG_DATA_WIDTH_BYTES)) & TAG_MASK;
}

uint64_t getSetIdx(uint64_t addr) {
  return (addr >> LG_DATA_WIDTH_BYTES) & SET_MASK;
}

// most recently used way per set
std::map<uint64_t, uint32_t> MRU;

int sc_main(int argc, char **argv) 
{
  sc_init("bp_me_top_test", argc, argv);

  sc_signal <bool>     reset_i("reset_i");

  sc_signal <sc_bv<bp_lce_cce_req_width> > lce_req_i("lce_req_i");
  sc_signal <bool>     lce_req_v_i("lce_req_v_i");
  sc_signal <bool>     lce_req_ready_o("lce_req_ready_o");

  sc_signal <uint64_t> lce_resp_i("lce_resp_i");
  sc_signal <bool>     lce_resp_v_i("lce_resp_v_i");
  sc_signal <bool>     lce_resp_ready_o("lce_resp_ready_o");

  sc_signal <sc_bv<bp_lce_cce_data_resp_width> > lce_data_resp_i("lce_data_resp_i");
  sc_signal <bool>     lce_data_resp_v_i("lce_data_resp_v_i");
  sc_signal <bool>     lce_data_resp_ready_o("lce_data_resp_ready_o");

  #if (bp_cce_lce_cmd_width > 64)
  sc_signal <sc_bv<bp_cce_lce_cmd_width> > lce_cmd_o("lce_cmd_o");
  #elif (bp_cce_lce_cmd_width > 32)
  sc_signal <uint64_t> lce_cmd_o("lce_cmd_o");
  #else
  sc_signal <uint32_t> lce_cmd_o("lce_cmd_o");
  #endif
  sc_signal <bool>     lce_cmd_v_o("lce_cmd_v_o");
  sc_signal <bool>     lce_cmd_ready_i("lce_cmd_ready_i");

  sc_signal <sc_bv<bp_lce_data_cmd_width> > lce_data_cmd_o("lce_data_cmd_o");
  sc_signal <bool>     lce_data_cmd_v_o("lce_data_cmd_v_o");
  sc_signal <bool>     lce_data_cmd_ready_i("lce_data_cmd_ready_i");

  sc_clock clock("clk", sc_time(CLK_TIME, SC_NS));

  Vbp_me_top_test DUT("DUT");

  DUT.clk_i(clock);
  DUT.reset_i(reset_i);

  DUT.lce_req_i(lce_req_i);
  DUT.lce_req_v_i(lce_req_v_i);
  DUT.lce_req_ready_o(lce_req_ready_o);

  DUT.lce_resp_i(lce_resp_i);
  DUT.lce_resp_v_i(lce_resp_v_i);
  DUT.lce_resp_ready_o(lce_resp_ready_o);

  DUT.lce_data_resp_i(lce_data_resp_i);
  DUT.lce_data_resp_v_i(lce_data_resp_v_i);
  DUT.lce_data_resp_ready_o(lce_data_resp_ready_o);

  DUT.lce_cmd_o(lce_cmd_o);
  DUT.lce_cmd_v_o(lce_cmd_v_o);
  DUT.lce_cmd_ready_i(lce_cmd_ready_i);

  DUT.lce_data_cmd_o(lce_data_cmd_o);
  DUT.lce_data_cmd_v_o(lce_data_cmd_v_o);
  DUT.lce_data_cmd_ready_i(lce_data_cmd_ready_i);

  VerilatedVcdSc* wf = new VerilatedVcdSc;
  DUT.trace(wf, TRACE_LEVELS);
  wf->open("dump.vcd");

  // reset
  lce_req_i = 0;
  lce_req_v_i = 0;
  lce_resp_i = 0;
  lce_resp_v_i = 0;
  lce_data_resp_i = 0;
  lce_data_resp_v_i = 0;
  lce_cmd_ready_i = 0;
  lce_data_cmd_ready_i = 0;

  cout << "@" << sc_time_stamp() << " Reset started..." << endl;
  reset_i = 1;
  sc_start(RST_TIME, SC_NS);
  reset_i = 0;
  cout << "@" << sc_time_stamp() << " Reset finished!" << endl;

  int stallDetect = 0;

  bool sync_rcvd = false;
  // loop until sync command received
  while (!sync_rcvd) {
    // CCE is demanding as producer, so pull ready high
    lce_cmd_ready_i = 1;
    // wait for LCE command valid signal
    while (!lce_cmd_v_o) {
      stallDetect++;
      if (stallDetect == STALL_MAX) {
        cout << "@" << sc_time_stamp() << " STALL!" << endl;
        wf->close();
        return 0;
      }
      sc_start(CLK_TIME, SC_NS);
    }

    // LCE command valid asserted, check command
    sc_bv<bp_cce_lce_cmd_width> lce_cmd(lce_cmd_o.read());
    if (checkCceCmd(lce_cmd, 0, 0, 0, 0, e_lce_cmd_sync, e_MESI_I, 0, 0)) {
      cout << "@" << sc_time_stamp() << " SyncCmd: " << lce_cmd.to_string() << endl;
      sync_rcvd = true;
    } else {
      cout << "@" << sc_time_stamp() << " SetClearCmd: " << lce_cmd.to_string() << endl;
    }

    // something received, or stalled, pull ready low
    lce_cmd_ready_i = 0;
    sc_start(CLK_TIME, SC_NS);
  }

  stallDetect = 0;
  while (!lce_resp_ready_o) {
    stallDetect++;
    if (stallDetect == STALL_MAX) {
      cout << "@" << sc_time_stamp() << " STALL!" << endl;
      wf->close();
      return 0;
    }
    sc_start(CLK_TIME, SC_NS);
  }

  lce_resp_i = createLceResp(0, 0, e_lce_cce_sync_ack, 0x0).to_uint();
  lce_resp_v_i = 1;
  sc_start(CLK_TIME, SC_NS);
  lce_resp_i = 0;
  lce_resp_v_i = 0;
  sc_start(CLK_TIME, SC_NS);

  // Let the CCE finish initialization
  sc_start(CLK_TIME*1000, SC_NS);

  // NOTE: at this point, all tags and states in directory should be 0
  cout << "@" << sc_time_stamp() << " SYNC FINISHED!" << endl << endl;

  // Test non-exclusive request with clean LRU way
  for (int i = 0; i < TRACE_ITERS; i++) {
    cout << "@" << sc_time_stamp() << " Iteration: " << i << endl;
    stallDetect = 0;
    while (!lce_req_ready_o) {
      stallDetect++;
      if (stallDetect == STALL_MAX) {
        cout << "@" << sc_time_stamp() << " STALL!" << endl;
        wf->close();
        return 0;
      }
      sc_start(CLK_TIME, SC_NS);
    }

    // create and send a request
    bp_lce_cce_req_type_e reqType = e_lce_req_type_rd;
    uint64_t reqAddr = rand() % ((uint64_t)1 << ADDR_WIDTH);
    uint32_t lruWay = rand() % (1 << LG_LCE_ASSOC);
    lce_req_i = createLceReq(0, 0, reqType, reqAddr, e_lce_req_not_excl, lruWay, e_lce_req_lru_clean).to_uint();
    lce_req_v_i = 1;
    sc_start(CLK_TIME, SC_NS);
    lce_req_i = 0;
    lce_req_v_i = 0;
    sc_start(CLK_TIME, SC_NS);

    // wait for and check data cmd
    lce_data_cmd_ready_i = 1;
    stallDetect = 0;
    while (!lce_data_cmd_v_o) {
      sc_start(CLK_TIME, SC_NS);
      stallDetect++;
      if (stallDetect == STALL_MAX) {
        cout << "@" << sc_time_stamp() << " STALL!" << endl;
        wf->close();
        return 0;
      }
    }

    sc_bv<bp_lce_data_cmd_width> data_cmd(lce_data_cmd_o.read());
    if (!checkCceDataCmd(data_cmd, 0, lruWay, e_lce_data_cmd_cce, 0, false)) {
      cout << "@" << sc_time_stamp() << " TEST FAILED!" << endl;
      wf->close();
      exit(-1);
    } else {
      cout << "@" << sc_time_stamp() << " lceDataCmd: " << data_cmd.to_string() << endl;
    }

    // something received, or stalled, pull ready low
    lce_data_cmd_ready_i = 0;
    sc_start(CLK_TIME, SC_NS);

    // wait for and check cmd
    lce_cmd_ready_i = 1;
    stallDetect = 0;
    while (!lce_cmd_v_o) {
      sc_start(CLK_TIME, SC_NS);
      stallDetect++;
      if (stallDetect == STALL_MAX) {
        cout << "@" << sc_time_stamp() << " STALL!" << endl;
        wf->close();
        return 0;
      }
    }
    sc_bv<bp_cce_lce_cmd_width> cmd(lce_cmd_o.read());
    if (!checkCceCmd(cmd, 0, 0, reqAddr, lruWay, e_lce_cmd_set_tag, e_MESI_E, 0, 0)) {
      cout << "@" << sc_time_stamp() << " TEST FAILED!" << endl;
      wf->close();
      exit(-1);
    } else {
      cout << "@" << sc_time_stamp() << " lceCmd: " << cmd.to_string() << endl;
    }

    // something received, or stalled, pull ready low
    lce_cmd_ready_i = 0;
    sc_start(CLK_TIME, SC_NS);
    cout << endl;

    sc_start(RST_TIME, SC_NS);
  }


///////////////////////////////////////////////////////////////////////////////////////////////////
/*
  // reset
  lce_req_i = 0;
  lce_req_v_i = 0;
  lce_resp_i = 0;
  lce_resp_v_i = 0;
  lce_data_resp_i = 0;
  lce_data_resp_v_i = 0;
  lce_cmd_ready_i = 0;
  lce_data_cmd_ready_i = 0;

  cout << "@" << sc_time_stamp() << " Reset started..." << endl;
  reset_i = 1;
  sc_start(RST_TIME, SC_NS);
  reset_i = 0;
  cout << "@" << sc_time_stamp() << " Reset finished!" << endl;

  stallDetect = 0;

  sync_rcvd = false;
  // loop until sync command received
  while (!sync_rcvd) {
    lce_cmd_ready_i = 1;
    // wait for LCE command valid signal
    while (!lce_cmd_v_o) {
      stallDetect++;
      if (stallDetect == STALL_MAX) {
        cout << "@" << sc_time_stamp() << " STALL!" << endl;
        wf->close();
        return 0;
      }
      sc_start(CLK_TIME, SC_NS);
    }

    // LCE command valid asserted, check command
    sc_bv<bp_cce_lce_cmd_width> lce_cmd(lce_cmd_o.read());
    if (checkCceCmd(lce_cmd, 0, 0, 0, 0, e_lce_cmd_sync, e_MESI_I, 0, 0)) {
      cout << "@" << sc_time_stamp() << " SyncCmd: " << lce_cmd.to_string() << endl;
      sync_rcvd = true;
    } else {
      cout << "@" << sc_time_stamp() << " SetClearCmd: " << lce_cmd.to_string() << endl;
    }
    lce_cmd_ready_i = 0;
    sc_start(CLK_TIME, SC_NS);
  }

  stallDetect = 0;
  while (!lce_resp_ready_o) {
    stallDetect++;
    if (stallDetect == STALL_MAX) {
      cout << "@" << sc_time_stamp() << " STALL!" << endl;
      wf->close();
      return 0;
    }
    sc_start(CLK_TIME, SC_NS);
  }

  lce_resp_i = createLceResp(0, 0, e_lce_cce_sync_ack, 0).to_uint();
  lce_resp_v_i = 1;
  sc_start(CLK_TIME, SC_NS);
  lce_resp_i = 0;
  lce_resp_v_i = 0;
  sc_start(CLK_TIME, SC_NS);

  cout << "@" << sc_time_stamp() << " SYNC FINISHED!" << endl << endl;

  // Let the CCE finish initialization
  sc_start(CLK_TIME*1000, SC_NS);

  // NOTE: at this point, all tags and states in directory should be 0

  // 22 bit address = 10 tag, 6 set, 6 offset
  uint64_t addrs[3] = {0x2000,0x4000,0x8000};
  uint32_t ways[3] = {0,1,0};
  uint8_t reqTypes[3] = {1,0,0};
  uint32_t lruDirty[3] = {0,0,1};

  // Test non-exclusive request with dirty LRU way
  for (int i = 0; i < 3; i++) {
    stallDetect = 0;
    while (!lce_req_ready_o) {
      stallDetect++;
      if (stallDetect == STALL_MAX) {
        cout << "@" << sc_time_stamp() << " STALL!" << endl;
        wf->close();
        return 0;
      }
      sc_start(CLK_TIME, SC_NS);
    }

    // create and send a request
    bp_lce_cce_req_type_e reqType = (bp_lce_cce_req_type_e)reqTypes[i];
    uint64_t reqAddr = addrs[i];
    uint32_t lruWay = ways[i];

    lce_req_i = createLceReq(0, 0, reqType, reqAddr, e_lce_req_excl, lruWay, (bp_lce_cce_lru_dirty_e)lruDirty[i]).to_uint();
    lce_req_v_i = 1;
    sc_start(CLK_TIME, SC_NS);
    lce_req_i = 0;
    lce_req_v_i = 0;
    sc_start(CLK_TIME, SC_NS);

    if (lruDirty[i]) {
      uint64_t lruAddr = addrs[0];

      // wait for and check cmd
      stallDetect = 0;
      lce_cmd_ready_i = 1;
      while (!lce_cmd_v_o) {
        sc_start(CLK_TIME, SC_NS);
        stallDetect++;
        if (stallDetect == STALL_MAX) {
          cout << "@" << sc_time_stamp() << " STALL!" << endl;
          wf->close();
          return 0;
        }
      }
      sc_bv<bp_cce_lce_cmd_width> lce_cmd(lce_cmd_o.read());
      if (!checkCceCmd(lce_cmd, 0, 0, lruAddr, lruWay, e_lce_cmd_writeback, (bp_cce_coh_mesi_e)0, 0, 0)) {
        cout << "@" << sc_time_stamp() << " TEST FAILED!" << endl;
        wf->close();
        exit(-1);
      } else {
        cout << "@" << sc_time_stamp() << " lceCmd: " << lce_cmd.to_string() << endl;
      }
      lce_cmd_ready_i = 0;
      sc_start(CLK_TIME, SC_NS);

      stallDetect = 0;
      while (!lce_data_resp_ready_o) {
        stallDetect++;
        if (stallDetect == STALL_MAX) {
          cout << "@" << sc_time_stamp() << " STALL!" << endl;
          wf->close();
          return 0;
        }
        sc_start(CLK_TIME, SC_NS);
      }

      lce_data_resp_i = createLceDataResp(0, 0, lruAddr, e_lce_resp_wb, 0x0);
      lce_data_resp_v_i = 1;
      sc_start(CLK_TIME, SC_NS);
      lce_data_resp_i = 0;
      lce_data_resp_v_i = 0;
      sc_start(CLK_TIME, SC_NS);
    }

    // wait for and check data cmd
    stallDetect = 0;
    lce_data_cmd_ready_i = 1;
    while (!lce_data_cmd_v_o) {
      sc_start(CLK_TIME, SC_NS);
      stallDetect++;
      if (stallDetect == STALL_MAX) {
        cout << "@" << sc_time_stamp() << " STALL!" << endl;
        wf->close();
        return 0;
      }
    }

    sc_bv<bp_lce_data_cmd_width> data_cmd(lce_data_cmd_o.read());
    if (!checkCceDataCmd(data_cmd, 0, lruWay, e_lce_data_cmd_cce, 0, false)) {
      cout << "@" << sc_time_stamp() << " TEST FAILED!" << endl;
      wf->close();
      exit(-1);
    } else {
      cout << "@" << sc_time_stamp() << " lceDataCmd: " << data_cmd.to_string() << endl;
    }
    lce_data_cmd_ready_i = 0;
    sc_start(CLK_TIME, SC_NS);

    // wait for and check cmd
    stallDetect = 0;
    lce_cmd_ready_i = 1;
    while (!lce_cmd_v_o) {
      sc_start(CLK_TIME, SC_NS);
      stallDetect++;
      if (stallDetect == STALL_MAX) {
        cout << "@" << sc_time_stamp() << " STALL!" << endl;
        wf->close();
        return 0;
      }
    }
    sc_bv<bp_cce_lce_cmd_width> cmd(lce_cmd_o.read());
    if (!checkCceCmd(cmd, 0, 0, reqAddr, lruWay, e_lce_cmd_set_tag, e_MESI_E, 0, 0)) {
      cout << "@" << sc_time_stamp() << " TEST FAILED!" << endl;
      wf->close();
      exit(-1);
    } else {
      cout << "@" << sc_time_stamp() << " lceCmd: " << cmd.to_string() << endl;
    }
    lce_cmd_ready_i = 0;
    sc_start(CLK_TIME, SC_NS);

    sc_start(RST_TIME, SC_NS);
  }
*/
  sc_start(RST_TIME, SC_NS);

  cout << "@" << sc_time_stamp() << " TEST PASSED!" << endl;

  wf->close();

  return 0;
}
