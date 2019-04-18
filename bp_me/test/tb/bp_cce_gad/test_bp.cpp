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

#define LCE_SETS 4
#define LG_LCE_SETS 2

#define ADDR_WIDTH 12

#include "bp_cce_verilator.h"
#include "bp_cce.h"

typedef struct {
  uint32_t tag : TAG_WIDTH;
  uint32_t state : LG_COH_ST;
} entry_s;

uint32_t entry_s_to_int(entry_s *s) {
  return (((s->tag & TAG_MASK) << LG_COH_ST) | (s->state & COH_ST_MASK));
}

// way-group = N_LCE tag sets = N_LCE * (LCE_ASSOC * entry)
// wg = {LCE_0, Way_0; LCE_0, Way_1; ... LCE_N-1, Way_Assoc-1}
uint32_t wg[N_LCE*LCE_ASSOC];

void clearWg(uint32_t *wg) {
  for (int i = 0; i < N_LCE*LCE_ASSOC; i++) {
    wg[i] = 0;
  }
}

// randomly generate a way group with one shared block
void genSharerWayGroup(uint32_t *wg, entry_s *s, uint32_t *lce_o, uint32_t *lru_way, uint32_t *n) {
  // clear the wg
  clearWg(wg);
  // determine how many LCEs will have a copy (1 to 4)
  int sharers = (rand() % N_LCE) + 1;
  // generate the tag and state == Shared = 1
  s->tag = rand() % (1 << TAG_WIDTH);
  s->state = 1;

  // populate sharers number of LCEs with the block
  int lce = 0;
  int cnt = 0;
  int way = 0;
  while (cnt < sharers) {
    // choose an LCE
    lce = rand() % N_LCE;
    // check if the chosen LCE already has an entry
    bool present = false;
    for (int i = lce*LCE_ASSOC; i < (lce*LCE_ASSOC)+LCE_ASSOC; i++) {
      if (wg[i]) {
        present = true;
      }
    }
    if (present) {
      continue;
    }
    // not found, choose a random way
    way = rand() % LCE_ASSOC;
    wg[lce*LCE_ASSOC + way] = entry_s_to_int(s);
    cnt++;
    // use this last LCE as the owner
    *lce_o = lce;
    // set LRU way to the next way in the set
    *lru_way = (way+1) % LCE_ASSOC;
  }
  *n = sharers;
}

// Randomly generate way-group with one cache holding block in E
uint32_t genWayGroupSingle(uint32_t *wg, uint32_t state, entry_s *s, uint32_t *lce, uint32_t *way, uint32_t *lru_way) {
  // clear the wg
  clearWg(wg);
  // generate the tag and state == Excl = 2
  s->tag = rand() % (1 << TAG_WIDTH);
  s->state = state;

  // pick an LCE and way
  *lce = rand() % N_LCE;
  *way = rand() % LCE_ASSOC;
  // lru way is next way in set (wrapped around if necessary)
  *lru_way = ((*way)+1) % LCE_ASSOC;
 
  // populate the entry
  wg[*lce*LCE_ASSOC + *way] = entry_s_to_int(s);

  // choose which LCE will request
  uint32_t reqLce = rand() % N_LCE;
  #if (N_LCE >= 2)
  while (reqLce == *lce) {
    reqLce = rand() % N_LCE;
  }
  #endif
  return reqLce;
}

// convert wg array into bit vector
// each entry in WG is a properly formatted tag + state
// want lsb's to hold LCE_0, Way_0
void writeWgToBV(uint32_t *wg, sc_signal<sc_bv<WG_WIDTH> > &wg_bv) {
  std::stringstream ss;
  for (int i = (N_LCE*LCE_ASSOC-1); i >= 0; i--) {
    for (int j = (TAG_WIDTH+LG_COH_ST-1); j >= 0; j--) {
      if ((wg[i] >> j) & 0x1) {
        ss << "1";
      } else {
        ss << "0";
      }
    }
  }
  //cout << ss.str() << endl;
  wg_bv = ss.str().c_str();
}

void writeWgToUint(uint32_t *wg, sc_signal<uint32_t> &out) {
  uint32_t tmp = 0;
  for (int i = (N_LCE*LCE_ASSOC-1); i >= 0; i--) {
    for (int j = (TAG_WIDTH+LG_COH_ST-1); j >= 0; j--) {
      tmp |= ((wg[i] >> j) & 0x1);
      tmp <<= 1;
    }
  }
  out = tmp;
}

int sc_main(int argc, char **argv) 
{

  sc_init("bp_cce_gad", argc, argv);

  sc_signal <bool>     reset_i("reset_i");

  #if (WG_WIDTH > 64)
  sc_signal <sc_bv<WG_WIDTH> >  way_group_i("way_group_i");
  #else
  sc_signal <uint32_t>          way_group_i("way_group_i");
  #endif

  #if (N_LCE > 2)
  sc_signal <uint32_t> req_lce_i("req_lce_i");
  #else
  sc_signal <bool>     req_lce_i("req_lce_i");
  #endif
  sc_signal <uint32_t> req_tag_i("req_tag_i");
  sc_signal <uint32_t> lru_way_i("lru_way_i");
  sc_signal <bool>     rqf_i("rqf_i");
  sc_signal <bool>     ldf_i("ldf_i");

  sc_signal <uint32_t> req_addr_way_o("req_addr_way_o");
  sc_signal <uint32_t> coh_state_o("coh_state_o");

  sc_signal <uint32_t> lru_tag_o("lru_tag_o");

  sc_signal <bool>     tf_o("tf_o");
  sc_signal <bool>     rf_o("rf_o");
  sc_signal <bool>     uf_o("uf_o");
  sc_signal <bool>     if_o("if_o");
  sc_signal <bool>     ef_o("ef_o");
  sc_signal <bool>     cf_o("cf_o");
  #if (N_LCE > 2)
  sc_signal <uint32_t> tr_lce_o("tr_lce_o");
  #else
  sc_signal <bool>     tr_lce_o("tr_lce_o");
  #endif
  sc_signal <uint32_t> tr_way_o("tr_way_o");

  // TODO: if N_LCE or LCE_ASSOC increases significantly for tests, sc_bv<> must be used
  //sc_signal <sc_bv<N_LCE> >  sh_hits_o("sh_hits_o");
  #if (N_LCE > 2)
  sc_signal <uint32_t> sh_hits_o("sh_hits_o");
  #else
  sc_signal <bool>     sh_hits_o("sh_hits_o");
  #endif
  //sc_signal <sc_bv<N_LCE*LG_LCE_ASSOC> >  sh_ways_o("sh_ways_o");
  sc_signal <uint32_t> sh_ways_o("sh_ways_o");
  //sc_signal <sc_bv<N_LCE*LG_COH_ST> >  sh_coh_states_o("sh_coh_states_o");
  sc_signal <uint32_t> sh_coh_states_o("sh_coh_states_o");

  sc_signal <bool>     gad_v_i("gad_v_i");

  sc_clock clock("clk", sc_time(CLK_TIME, SC_NS));

  Vbp_cce_gad DUT("DUT");

  DUT.clk_i(clock);
  DUT.reset_i(reset_i);
  DUT.way_group_i(way_group_i);
  DUT.req_lce_i(req_lce_i);
  DUT.req_tag_i(req_tag_i);
  DUT.lru_way_i(lru_way_i);
  DUT.req_type_flag_i(rqf_i);
  DUT.lru_dirty_flag_i(ldf_i);
  DUT.gad_v_i(gad_v_i);

  DUT.req_addr_way_o(req_addr_way_o);
  DUT.coh_state_o(coh_state_o);
  DUT.lru_tag_o(lru_tag_o);
  DUT.transfer_flag_o(tf_o);
  DUT.transfer_lce_o(tr_lce_o);
  DUT.transfer_way_o(tr_way_o);
  DUT.replacement_flag_o(rf_o);
  DUT.upgrade_flag_o(uf_o);
  DUT.invalidate_flag_o(if_o);
  DUT.exclusive_flag_o(ef_o);
  DUT.cached_flag_o(cf_o);

  DUT.sharers_hits_o(sh_hits_o);
  DUT.sharers_ways_o(sh_ways_o);
  DUT.sharers_coh_states_o(sh_coh_states_o);

  #if (VM_TRACE == 1)
  VerilatedVcdSc* wf = new VerilatedVcdSc;
  DUT.trace(wf, TRACE_LEVELS);
  wf->open("dump.vcd");
  #endif

  reset_i = 0;
  way_group_i = 0;
  req_lce_i = 0;
  req_tag_i = 0;
  lru_way_i = 0;
  rqf_i = 0;
  ldf_i = 0;
  gad_v_i = 0;

  for (int i = 0; i < N_LCE*LCE_ASSOC; i++) {
    wg[i] = 0;
  }

  uint32_t lce = 0;
  uint32_t lru_way = 0;
  uint32_t n = 0;
  uint32_t way = 0;
  entry_s e;

  gad_v_i = 1;

  // Test block in I, read request
  cout << endl << "Starting Invalid Read Request Tests..." << endl;
  for (int i = 0; i < TRACE_ITERS; i++) {
    req_lce_i = genWayGroupSingle(wg, 0, &e, &lce, &way, &lru_way);
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
    if (tf_o || uf_o || if_o || rf_o || ef_o) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      return -1;
    }
  }

  // Test block in I, read request
  cout << endl << "Starting Invalid Write Request Tests..." << endl;
  for (int i = 0; i < TRACE_ITERS; i++) {
    req_lce_i = genWayGroupSingle(wg, 0, &e, &lce, &way, &lru_way);
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
    if (tf_o || uf_o || if_o || rf_o || ef_o) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      return -1;
    }
  }

  // Test block in S, read request
  cout << endl << "Starting Shared Read Request Tests..." << endl;
  for (int i = 0; i < TRACE_ITERS; i++) {
    req_lce_i = genWayGroupSingle(wg, 1, &e, &lce, &way, &lru_way);
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
    if (tf_o || uf_o || if_o || rf_o || ef_o) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      return -1;
    }
  }

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

  cout << "TEST PASSED!" << endl;

  #if (VM_TRACE == 1)
  wf->close();
  #endif

  return 0;
}
