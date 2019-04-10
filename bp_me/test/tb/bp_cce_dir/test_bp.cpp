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

#include "Vbp_cce_dir.h"

#include "bp_cce_verilator.h"
#include "bp_cce.h"
#include "bp_cce_inst.h"


int sc_main(int argc, char **argv) 
{
    sc_init("bp_cce_dir", argc, argv);

    sc_signal <bool>     reset_i("reset_i");

    sc_signal <uint32_t> way_group_i("wg_i");
    #if N_LCE <= 2
    sc_signal <bool>     lce_i("lce_i");
    #else
    sc_signal <uint32_t> lce_i("lce_i");
    #endif
    #if LCE_ASSOC <= 2
    sc_signal <bool>     way_i("way_i");
    #else
    sc_signal <uint32_t> way_i("way_i");
    #endif
    sc_signal <uint32_t> r_cmd_i("r_cmd_i");
    sc_signal <bool>     r_v_i("r_v_i");

    sc_signal <uint64_t> tag_i("tag_i");
    sc_signal <uint32_t> coh_state_i("coh_state_i");
    sc_signal <bool>     pending_i("pending_i");
    sc_signal <uint32_t> w_cmd_i("w_cmd_i");
    sc_signal <bool>     w_v_i("w_v_i");


    sc_signal <bool>        pending_o("pending_o");
    sc_signal <bool>        pending_v_o("pending_v_o");
    sc_signal <uint64_t>    tag_o("tag_o");
    sc_signal <uint32_t>    coh_state_o("coh_state_o");
    sc_signal <bool>        entry_v_o("entry_v_o");
    #if WG_WIDTH > 64
    sc_signal <sc_bv<WG_WIDTH> >  way_group_o("way_group_o");
    #elif WG_WIDTH > 32
    sc_signal <uint64_t>          way_group_o("way_group_o");
    #else
    sc_signal <uint32_t>          way_group_o("way_group_o");
    #endif
    sc_signal <bool>        way_group_v_o("way_group_v_o");

    sc_clock clock("clk", sc_time(CLK_TIME, SC_NS));

    Vbp_cce_dir DUT("DUT");

    DUT.clk_i(clock);
    DUT.reset_i(reset_i);

    DUT.way_group_i(way_group_i);
    DUT.lce_i(lce_i);
    DUT.way_i(way_i);
    DUT.r_cmd_i(r_cmd_i);
    DUT.r_v_i(r_v_i);

    DUT.tag_i(tag_i);
    DUT.coh_state_i(coh_state_i);
    DUT.pending_i(pending_i);
    DUT.w_cmd_i(w_cmd_i);
    DUT.w_v_i(w_v_i);

    DUT.pending_o(pending_o);
    DUT.pending_v_o(pending_v_o);
    DUT.tag_o(tag_o);
    DUT.coh_state_o(coh_state_o);
    DUT.entry_v_o(entry_v_o);
    DUT.way_group_o(way_group_o);
    DUT.way_group_v_o(way_group_v_o);

    #if (VM_TRACE == 1)
    VerilatedVcdSc* wf = new VerilatedVcdSc;
    DUT.trace(wf, TRACE_LEVELS);
    wf->open("dump.vcd");
    #endif

    r_v_i = 0;
    w_v_i = 0;

    // reset
    cout << "@" << sc_time_stamp() << " Reset started..." << endl;
    reset_i = 1;
    sc_start(RST_TIME, SC_NS);
    reset_i = 0;
    sc_start(RST_TIME, SC_NS);
    cout << "@" << sc_time_stamp() << " Reset finished!" << endl;

    // write to pending and wg rams
    pending_i = 0;
    tag_i = 0;
    coh_state_i = 0;
    w_v_i = 1;
    w_cmd_i = e_wdp;
    for (int i = 0; i < N_WG; i++) {
      way_group_i = i;
      sc_start(CLK_TIME, SC_NS);
      cout << "@" << sc_time_stamp() << " WDP wg=" << way_group_i << endl;
    }

    w_v_i = 0;
    w_cmd_i = 0;
    way_group_i = 0;
    lce_i = 0;
    way_i = 0;
    sc_start(CLK_TIME, SC_NS);

    w_v_i = 1;
    w_cmd_i = e_wde;
    for (int i = 0; i < N_WG; i++) {
      way_group_i = i;
      for (int j = 0; j < N_LCE; j++) {
        lce_i = j;
        for (int k = 0; k < LCE_ASSOC; k++) {
          way_i = k;
          sc_start(CLK_TIME, SC_NS);
          cout << "@" << sc_time_stamp() << " WDE wg=" << way_group_i << " lce=" << lce_i << " way="
               << way_i << " : tag, st : " << tag_i << ", " << coh_state_i << endl;
        }
      }
    }

    w_v_i = 0;
    w_cmd_i = 0;
    way_group_i = 0;
    lce_i = 0;
    way_i = 0;
    sc_start(CLK_TIME, SC_NS);

    uint64_t tag_cnt = 0;
    uint32_t coh_state_cnt = 0;
    w_v_i = 1;
    w_cmd_i = e_wde;
    for (int i = 0; i < N_WG; i++) {
      way_group_i = i;
      for (int j = 0; j < N_LCE; j++) {
        lce_i = j;
        for (int k = 0; k < LCE_ASSOC; k++, tag_cnt++, coh_state_cnt++) {
          way_i = k;
          tag_i = tag_cnt & TAG_MASK;
          coh_state_i = coh_state_cnt & COH_ST_MASK;
          sc_start(CLK_TIME, SC_NS);
          cout << "@" << sc_time_stamp() << " WDE wg=" << way_group_i << " lce=" << lce_i << " way="
               << way_i << " : tag, st : " << tag_i << ", " << coh_state_i << endl;
        }
      }
    }

    w_v_i = 0;
    w_cmd_i = 0;
    way_group_i = 0;
    lce_i = 0;
    way_i = 0;
    tag_i = 0;
    coh_state_i = 0;
    sc_start(10*CLK_TIME, SC_NS);

    // read out entries
    r_v_i = 1;
    r_cmd_i = e_rdp;
    for (int i = 0; i < N_WG; i++) {
      way_group_i = i;
      sc_start(CLK_TIME, SC_NS);
      cout << "@" << sc_time_stamp() << " RDP wg=" << way_group_i << endl;
      if (!pending_v_o || pending_o) {
            cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
            #if (VM_TRACE == 1)
            wf->close();
            #endif
            return -1;
      }
    }


    r_cmd_i = 0;
    r_v_i = 0;

    sc_start(10*CLK_TIME, SC_NS);

    r_cmd_i = e_rde;
    tag_cnt = 0;
    coh_state_cnt = 0;
    for (int i = 0; i < N_WG; i++) {
      way_group_i = i;
      for (int j = 0; j < N_LCE; j++) {
        lce_i = j;
        for (int k = 0; k < LCE_ASSOC; k++, tag_cnt++, coh_state_cnt++) {
          r_v_i = 1;
          way_i = k;
          sc_start(CLK_TIME, SC_NS); // set up the read
          r_v_i = 0;
          sc_start(CLK_TIME, SC_NS); // clock one cycle to get the output -- synchronous RAM
          cout << "@" << sc_time_stamp() << " RDE wg=" << way_group_i << " lce=" << lce_i << " way="
               << way_i << " : tag, st : " << tag_o << ", " << coh_state_o << endl;
          if (!entry_v_o || (coh_state_o != (coh_state_cnt & COH_ST_MASK)) || (tag_o != (tag_cnt & TAG_MASK))) {
            cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
            #if (VM_TRACE == 1)
            wf->close();
            #endif
            return -1;
          }
        }
      }
    }

    sc_start(CLK_TIME, SC_NS);


    cout << "TEST PASSED!" << endl;

    #if (VM_TRACE == 1)
    wf->close();
    #endif

    return 0;
}
