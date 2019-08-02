/**
 *
 * test_bp.v
 *
 */

#include <map>
#include <iomanip>
#include <string>
#include <unistd.h>
#include <sstream>

#include "systemc.h"
#include "verilated_vcd_sc.h"

#include "Vbp_cce_gad.h"

// define some parameters to override defaults in "bp_cce.h"
#define N_LCE 4
#define LG_N_LCE 2

#define LCE_ASSOC 4
#define LG_LCE_ASSOC 2

#define LCE_SETS 16
#define LG_LCE_SETS 4

#include "bp_cce_verilator.h"
#include "bp_cce.h"
#include "bp_cce_lce_msg_util.h"

uint32_t genShared(uint32_t reqLce, uint32_t &reqWay, uint32_t &ways, uint32_t &states) {
  reqWay = rand() % LCE_ASSOC;
  ways = reqWay << (reqLce * LG_LCE_ASSOC);
  uint32_t hits = 0;
  int max_i = (rand() % (N_LCE-2)) + 1;
  int i = 0;
  while (i < max_i) {
    uint32_t shLce = rand() % N_LCE;
    if (shLce != reqLce) {
      hits = hits | (1 << shLce);
      uint32_t shWay = rand() % LG_LCE_ASSOC;
      ways = ways | (shWay << (shLce*LG_LCE_ASSOC));
      states = states | (e_COH_S << (shLce*LG_COH_ST));
      i++;
    }
  }
  //cout << "hits: " << toString<uint32_t>(hits, N_LCE) << endl;
  return hits;
}

uint32_t genExclusive(uint32_t reqLce, uint32_t &reqWay, uint32_t &ways, uint32_t &states) {
  reqWay = rand() % LCE_ASSOC;
  ways = reqWay << (reqLce * LG_LCE_ASSOC);
  uint32_t hits = 0;
  int max_i = 1;
  int i = 0;
  while (i < max_i) {
    uint32_t shLce = rand() % N_LCE;
    if (shLce != reqLce) {
      hits = hits | (1 << shLce);
      uint32_t shWay = rand() % LG_LCE_ASSOC;
      ways = ways | (shWay << (shLce*LG_LCE_ASSOC));
      states = states | (e_COH_E << (shLce*LG_COH_ST));
      i++;
    }
  }
  //cout << "hits: " << toString<uint32_t>(hits, N_LCE) << endl;
  return hits;
}

uint32_t genModified(uint32_t reqLce, uint32_t &reqWay, uint32_t &ways, uint32_t &states) {
  reqWay = rand() % LCE_ASSOC;
  ways = reqWay << (reqLce * LG_LCE_ASSOC);
  uint32_t hits = 0;
  int max_i = 1;
  int i = 0;
  while (i < max_i) {
    uint32_t shLce = rand() % N_LCE;
    if (shLce != reqLce) {
      hits = hits | (1 << shLce);
      uint32_t shWay = rand() % LG_LCE_ASSOC;
      ways = ways | (shWay << (shLce*LG_LCE_ASSOC));
      states = states | (e_COH_M << (shLce*LG_COH_ST));
      i++;
    }
  }
  //cout << "hits: " << toString<uint32_t>(hits, N_LCE) << endl;
  return hits;
}

int sc_main(int argc, char **argv) 
{

  sc_init("bp_cce_gad", argc, argv);

  sc_clock clock("clk", sc_time(CLK_TIME, SC_NS));
  sc_signal <bool>     reset_i("reset_i");
  sc_signal <bool>     gad_v_i("gad_v_i");

  sc_signal <bool>     sh_v_i("sh_v_i");
  sc_signal <uint32_t> sh_hits_i("sh_hits_i");
  sc_signal <uint32_t> sh_ways_i("sh_ways_i");
  sc_signal <uint32_t> sh_coh_states_i("sh_coh_states_i");
 
  sc_signal <uint32_t> req_lce_i("req_lce_i");
  sc_signal <bool>     rqf_i("rqf_i");
  sc_signal <bool>     ldf_i("ldf_i");
  sc_signal <bool>     lru_cached_excl_flag_i("lru_cached_excl_flag_i");

  sc_signal <uint32_t> req_addr_way_o("req_addr_way_o");

  sc_signal <bool>     tf_o("tf_o");
  sc_signal <uint32_t> tr_lce_o("tr_lce_o");
  sc_signal <uint32_t> tr_way_o("tr_way_o");
  sc_signal <bool>     rf_o("rf_o");
  sc_signal <bool>     uf_o("uf_o");
  sc_signal <bool>     if_o("if_o");
  sc_signal <bool>     cf_o("cf_o");
  sc_signal <bool>     cef_o("cef_o");
  sc_signal <bool>     cof_o("cof_o");
  sc_signal <bool>     cdf_o("cdf_o");


  Vbp_cce_gad DUT("DUT");

  DUT.clk_i(clock);
  DUT.reset_i(reset_i);
  DUT.gad_v_i(gad_v_i);

  DUT.sharers_v_i(sh_v_i);
  DUT.sharers_hits_i(sh_hits_i);
  DUT.sharers_ways_i(sh_ways_i);
  DUT.sharers_coh_states_i(sh_coh_states_i);

  DUT.req_lce_i(req_lce_i);
  DUT.req_type_flag_i(rqf_i);
  DUT.lru_dirty_flag_i(ldf_i);
  DUT.lru_cached_excl_flag_i(lru_cached_excl_flag_i);

  DUT.req_addr_way_o(req_addr_way_o);

  DUT.transfer_flag_o(tf_o);
  DUT.transfer_lce_o(tr_lce_o);
  DUT.transfer_way_o(tr_way_o);
  DUT.replacement_flag_o(rf_o);
  DUT.upgrade_flag_o(uf_o);
  DUT.invalidate_flag_o(if_o);
  DUT.cached_flag_o(cf_o);
  DUT.cached_exclusive_flag_o(cef_o);
  DUT.cached_owned_flag_o(cof_o);
  DUT.cached_dirty_flag_o(cdf_o);


  #if (VM_TRACE == 1)
  VerilatedVcdSc* wf = new VerilatedVcdSc;
  DUT.trace(wf, TRACE_LEVELS);
  wf->open("dump.vcd");
  #endif

  reset_i = 0;
  gad_v_i = 0;
  sh_hits_i = 0;
  sh_ways_i = 0;
  sh_coh_states_i = 0;
  req_lce_i = 0;
  rqf_i = 0;
  ldf_i = 0;
  lru_cached_excl_flag_i = 0;

  sc_start(RST_TIME, SC_NS);

  gad_v_i = 1;
  sh_v_i = 1;

  // Test block in I, read request
  cout << endl << "Starting Invalid Read Request Tests..." << endl;
  for (int i = 0; i < TRACE_ITERS; i++) {
    uint32_t reqLce = rand() % N_LCE;
    uint32_t reqWay =  rand() % LCE_ASSOC;
    uint32_t ways = reqWay << (reqLce * LG_LCE_ASSOC);
    req_lce_i = reqLce;
    rqf_i = 0;
    ldf_i = 0;
    sh_hits_i = 0;
    sh_ways_i = ways;
    sh_coh_states_i = 0;
    sc_start(CLK_TIME, SC_NS);
    cout << "@" << sc_time_stamp() << " reqLce: " << reqLce << " reqWay: " << reqWay
         << " shWays: " << toString<uint32_t>(ways, N_LCE*LG_LCE_ASSOC) << endl;
    if (tf_o || uf_o || if_o || rf_o || cef_o || (req_addr_way_o != 0)) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      #if (VM_TRACE == 1)
      wf->close();
      #endif
      return -1;
    }
  }

  // Test block in I, write request
  cout << endl << "Starting Invalid Write Request Tests..." << endl;
  for (int i = 0; i < TRACE_ITERS; i++) {
    uint32_t reqLce = rand() % N_LCE;
    uint32_t reqWay =  rand() % LCE_ASSOC;
    uint32_t ways = reqWay << (reqLce * LG_LCE_ASSOC);
    req_lce_i = reqLce;
    rqf_i = 1;
    ldf_i = 0;
    sh_hits_i = 0;
    sh_ways_i = ways;
    sh_coh_states_i = 0;
    sc_start(CLK_TIME, SC_NS);
    cout << "@" << sc_time_stamp() << " reqLce: " << reqLce << " reqWay: " << reqWay
         << " shWays: " << toString<uint32_t>(ways, N_LCE*LG_LCE_ASSOC) << endl;
    if (tf_o || uf_o || if_o || rf_o || cef_o || (req_addr_way_o != 0)) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      #if (VM_TRACE == 1)
      wf->close();
      #endif
      return -1;
    }
  }

  // Test block in S, read request
  cout << endl << "Starting Shared Read Request Tests..." << endl;
  for (int i = 0; i < TRACE_ITERS; i++) {
    uint32_t reqLce = rand() % N_LCE;
    uint32_t reqWay =  0;
    uint32_t ways = 0;
    uint32_t states = 0;
    uint32_t hits = genShared(reqLce, reqWay, ways, states);
    req_lce_i = reqLce;
    rqf_i = 1;
    ldf_i = 0;
    sh_hits_i = hits;
    sh_ways_i = ways;
    sh_coh_states_i = states;
    sc_start(CLK_TIME, SC_NS);
    cout << "@" << sc_time_stamp() << " reqLce: " << reqLce << " reqWay: " << reqWay
         << " shWays: " << toString<uint32_t>(ways, N_LCE*LG_LCE_ASSOC) << endl;
    if (tf_o || uf_o || !if_o || rf_o || cef_o || (req_addr_way_o != 0)) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      #if (VM_TRACE == 1)
      wf->close();
      #endif
      return -1;
    }
  }

  // Test block in E, read request
  cout << endl << "Starting Exclusive Read Request Tests..." << endl;
  for (int i = 0; i < TRACE_ITERS; i++) {
    uint32_t reqLce = rand() % N_LCE;
    uint32_t reqWay =  0;
    uint32_t ways = 0;
    uint32_t states = 0;
    uint32_t hits = genExclusive(reqLce, reqWay, ways, states);
    req_lce_i = reqLce;
    rqf_i = 1;
    ldf_i = 0;
    sh_hits_i = hits;
    sh_ways_i = ways;
    sh_coh_states_i = states;
    sc_start(CLK_TIME, SC_NS);
    cout << "@" << sc_time_stamp() << " reqLce: " << reqLce << " reqWay: " << reqWay
         << " shWays: " << toString<uint32_t>(ways, N_LCE*LG_LCE_ASSOC) << endl;
    //cout << "trLce= " << tr_lce_o << " lce= " << lce << endl;
    //cout << "trWay= " << tr_way_o << " way= " << way << endl;
    if (!tf_o || uf_o || !if_o || rf_o || !cef_o || (req_addr_way_o != 0)) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      #if (VM_TRACE == 1)
      wf->close();
      #endif
      return -1;
    }
  }

  // Test block in M, read request
  cout << endl << "Starting Modified Read Request Tests..." << endl;
  for (int i = 0; i < TRACE_ITERS; i++) {
    uint32_t reqLce = rand() % N_LCE;
    uint32_t reqWay =  0;
    uint32_t ways = 0;
    uint32_t states = 0;
    uint32_t hits = genModified(reqLce, reqWay, ways, states);
    req_lce_i = reqLce;
    rqf_i = 1;
    ldf_i = 0;
    sh_hits_i = hits;
    sh_ways_i = ways;
    sh_coh_states_i = states;
    sc_start(CLK_TIME, SC_NS);
    cout << "@" << sc_time_stamp() << " reqLce: " << reqLce << " reqWay: " << reqWay
         << " shWays: " << toString<uint32_t>(ways, N_LCE*LG_LCE_ASSOC) << endl;
    //cout << "trLce= " << tr_lce_o << " lce= " << lce << endl;
    //cout << "trWay= " << tr_way_o << " way= " << way << endl;
    if (!tf_o || uf_o || !if_o || rf_o || !cef_o || (req_addr_way_o != 0)) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      #if (VM_TRACE == 1)
      wf->close();
      #endif
      return -1;
    }
  }


  /*
  // TODO: test fails if N_LCE == 1 because transfer flag will never be set for 1 LCE system
  // Test block in S, write request
  cout << endl << "Starting Shared Write Request Tests..." << endl;
  for (int i = 0; i < TRACE_ITERS; i++) {
    req_lce_i = genWayGroupSingle(wg, 1, &e, &lce, &way, &lru_way);
    req_tag_i = e.tag;
    lru_way_i = lru_way;
    #if (WG_WIDTH > 32)
    writeWgToBV(wg, way_group_i);
    #else
    writeWgToUint(wg, way_group_i);
    #endif
    rqf_i = 1;
    ldf_i = 0;
    sc_start(CLK_TIME, SC_NS);
    cout << "@" << sc_time_stamp() << " reqLce= " << req_lce_i << " reqTag= " << req_tag_i << endl;
    if (tf_o || uf_o || !if_o || rf_o || ef_o) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      return -1;
    }
  }

  // Test block in E, read request, transfer to another cache
  cout << endl << "Starting Exclusive Read Request Tests..." << endl;
  for (int i = 0; i < TRACE_ITERS; i++) {
    req_lce_i = genWayGroupSingle(wg, 2, &e, &lce, &way, &lru_way);
    req_tag_i = e.tag;
    lru_way_i = lru_way;
    #if (WG_WIDTH > 32)
    writeWgToBV(wg, way_group_i);
    #else
    writeWgToUint(wg, way_group_i);
    #endif
    rqf_i = 0;
    ldf_i = 0;
    sc_start(CLK_TIME, SC_NS);
    cout << "@" << sc_time_stamp() << " reqLce= " << req_lce_i << " reqTag= " << req_tag_i << endl;
    cout << "trLce= " << tr_lce_o << " lce= " << lce << endl;
    cout << "trWay= " << tr_way_o << " way= " << way << endl;
    if (lce != tr_lce_o || way != tr_way_o || !tf_o || uf_o || !if_o || rf_o || !ef_o) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      return -1;
    }
  }

  // Test block in E, write request, transfer to another cache
  cout << endl << "Starting Exclusive Write Request Tests..." << endl;
  for (int i = 0; i < TRACE_ITERS; i++) {
    req_lce_i = genWayGroupSingle(wg, 2, &e, &lce, &way, &lru_way);
    req_tag_i = e.tag;
    lru_way_i = lru_way;
    #if (WG_WIDTH > 32)
    writeWgToBV(wg, way_group_i);
    #else
    writeWgToUint(wg, way_group_i);
    #endif
    rqf_i = 1;
    ldf_i = 0;
    sc_start(CLK_TIME, SC_NS);
    cout << "@" << sc_time_stamp() << " reqLce= " << req_lce_i << " reqTag= " << req_tag_i << endl;
    cout << "trLce= " << tr_lce_o << " lce= " << lce << endl;
    cout << "trWay= " << tr_way_o << " way= " << way << endl;
    if (lce != tr_lce_o || way != tr_way_o || !tf_o || uf_o || !if_o || rf_o || !ef_o) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      return -1;
    }
  }

  // Test block in M, read request, transfer to another cache
  cout << endl << "Starting Modified Read Request Tests..." << endl;
  for (int i = 0; i < TRACE_ITERS; i++) {
    req_lce_i = genWayGroupSingle(wg, 3, &e, &lce, &way, &lru_way);
    req_tag_i = e.tag;
    lru_way_i = lru_way;
    #if (WG_WIDTH > 32)
    writeWgToBV(wg, way_group_i);
    #else
    writeWgToUint(wg, way_group_i);
    #endif
    rqf_i = 0;
    ldf_i = 0;
    sc_start(CLK_TIME, SC_NS);
    cout << "@" << sc_time_stamp() << " reqLce= " << req_lce_i << " reqTag= " << req_tag_i << endl;
    cout << "trLce= " << tr_lce_o << " lce= " << lce << endl;
    cout << "trWay= " << tr_way_o << " way= " << way << endl;
    if (lce != tr_lce_o || way != tr_way_o || !tf_o || uf_o || !if_o || rf_o || !ef_o) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      return -1;
    }
  }

  // Test block in M, write request, transfer to another cache
  cout << endl << "Starting Modified Write Request Tests..." << endl;
  for (int i = 0; i < TRACE_ITERS; i++) {
    req_lce_i = genWayGroupSingle(wg, 3, &e, &lce, &way, &lru_way);
    req_tag_i = e.tag;
    lru_way_i = lru_way;
    #if (WG_WIDTH > 32)
    writeWgToBV(wg, way_group_i);
    #else
    writeWgToUint(wg, way_group_i);
    #endif
    rqf_i = 1;
    ldf_i = 0;
    sc_start(CLK_TIME, SC_NS);
    cout << "@" << sc_time_stamp() << " reqLce= " << req_lce_i << " reqTag= " << req_tag_i << endl;
    cout << "trLce= " << tr_lce_o << " lce= " << lce << endl;
    cout << "trWay= " << tr_way_o << " way= " << way << endl;
    if (lce != tr_lce_o || way != tr_way_o || !tf_o || uf_o || !if_o || rf_o || !ef_o) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      return -1;
    }
  }

  // Test block in S, upgrade request
  cout << endl << "Starting Shared Upgrade Write Request Tests..." << endl;
  for (int i = 0; i < TRACE_ITERS; i++) {
    uint32_t unused = genWayGroupSingle(wg, 1, &e, &lce, &way, &lru_way);
    req_lce_i = lce;
    req_tag_i = e.tag;
    lru_way_i = lru_way;
    #if (WG_WIDTH > 32)
    writeWgToBV(wg, way_group_i);
    #else
    writeWgToUint(wg, way_group_i);
    #endif
    rqf_i = 1;
    ldf_i = 0;
    sc_start(CLK_TIME, SC_NS);
    cout << "@" << sc_time_stamp() << " reqLce= " << req_lce_i << " reqTag= " << req_tag_i << endl;
    if (tf_o || !uf_o || if_o || rf_o || ef_o) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      return -1;
    }
  }

  // TODO: test replacement flag

  // TODO: test multiple sharers
  // Test block shared randomly between 1 or more LCEs
  cout << endl << "Starting Shared Tests..." << endl;
  for (int i = 0; i < TRACE_ITERS; i++) {
    genSharerWayGroup(wg, &e, &lce, &lru_way, &n);
    #if (WG_WIDTH > 32)
    writeWgToBV(wg, way_group_i);
    #else
    writeWgToUint(wg, way_group_i);
    #endif
    req_lce_i = lce;
    req_tag_i = e.tag;
    lru_way_i = lru_way;
    rqf_i = 1;
    ldf_i = 0;
    sc_start(CLK_TIME, SC_NS);
    cout << "@" << sc_time_stamp() << " lce= " << req_lce_i << " tag= " << req_tag_i << endl;
    if (lru_tag_o != 0) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      return -1;
    }
    if (n == 1 && (!uf_o || if_o || ef_o || rf_o || tf_o)) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      return -1;
    }
    if (n > 1 && (!uf_o || !if_o || ef_o || rf_o || tf_o)) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      return -1;
    }
  }
  */
  cout << "TEST PASSED!" << endl;

  #if (VM_TRACE == 1)
  wf->close();
  #endif

  return 0;
}
