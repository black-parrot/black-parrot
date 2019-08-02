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

#include "Vbp_cce_alu.h"

#include "bp_cce_verilator.h"
#include "bp_cce_inst.h"

#define UINT16_MAX_HALF (UINT16_MAX/2)

int sc_main(int argc, char **argv) 
{
    sc_init("bp_cce_alu", argc, argv);

    sc_signal <uint32_t> opd_a_i("opd_a");
    sc_signal <uint32_t> opd_b_i("opd_b");
    sc_signal <bool>     v_i("valid_in");
    sc_signal <bool>     br_v_i("branch_valid_in");
    sc_signal <uint32_t> alu_op_i("alu_op");
    sc_signal <uint32_t> br_op_i("br_op");
    sc_signal <uint32_t> res_o("result");
    sc_signal <bool>     branch_res_o("branch_res_out");

    Vbp_cce_alu DUT("DUT");
    DUT.opd_a_i(opd_a_i);
    DUT.opd_b_i(opd_b_i);
    DUT.v_i(v_i);
    DUT.br_v_i(br_v_i);
    DUT.alu_op_i(alu_op_i);
    DUT.br_op_i(br_op_i);
    DUT.res_o(res_o);
    DUT.branch_res_o(branch_res_o);

    #if (VM_TRACE == 1)
    VerilatedVcdSc* wf = new VerilatedVcdSc;
    DUT.trace(wf, TRACE_LEVELS);
    wf->open("dump.vcd");
    #endif

    sc_start(0, SC_NS);
    br_v_i = false;
    br_op_i = 0;

    cout << "@" << sc_time_stamp() << " UINT16_MAX: " << UINT16_MAX << endl;
    // Iterate ALU ops
    // Add
    for(int i = 0; i < TRACE_ITERS; i++)
    {
        // select a in [0, UINT16_MAX]
        opd_a_i = rand() % UINT16_MAX_HALF;
        // select b in [0, UINT16_MAX-a]
        opd_b_i = rand() % UINT16_MAX_HALF;
        alu_op_i = e_add;
        v_i = true;

        sc_start(10, SC_NS);

        cout << "@" << sc_time_stamp() << " a,b: " << opd_a_i << ", " << opd_b_i;
        cout << " Result (a+b): " << res_o << endl;

        if((opd_a_i + opd_b_i) != res_o) 
        {
            cout << "@" << sc_time_stamp() << " TEST FAILED " << endl;
            #if (VM_TRACE == 1)
            wf->close();
            #endif

            return -1;
        }
    }

    int a, b;
    // Sub
    for(int i = 0; i < TRACE_ITERS; i++)
    {
        a = rand() % UINT16_MAX;
        b = rand() % UINT16_MAX;

        cout << "@" << sc_time_stamp() << " a,b: " << a << ", " << b << endl;
        if (a < b) {
          opd_a_i = b;
          opd_b_i = a;
        } else {
          opd_a_i = a;
          opd_b_i = b;
        }

        alu_op_i = e_sub;
        v_i = true;

        sc_start(10, SC_NS);

        cout << "@" << sc_time_stamp() << " a,b: " << opd_a_i << ", " << opd_b_i;
        cout << " Result (a-b): " << res_o << endl;

        if((opd_a_i - opd_b_i) != res_o) 
        {
            cout << "@" << sc_time_stamp() << " TEST FAILED " << endl;
            #if (VM_TRACE == 1)
            wf->close();
            #endif

            return -1;
        }
    }

    // Iterate Branch ops
    // BEQ
    v_i = false;
    alu_op_i = 0;
    for(int i = 0; i < TRACE_ITERS; i++)
    {
        opd_a_i = rand() % UINT16_MAX;
        opd_b_i = rand() % UINT16_MAX;
        br_op_i = e_beq;
        br_v_i = true;

        sc_start(10, SC_NS);

        cout << "@" << sc_time_stamp() << " a,b: " << opd_a_i << ", " << opd_b_i;
        cout << " BEQ: " << branch_res_o << endl;

        if((opd_a_i == opd_b_i) && !branch_res_o) 
        {
            cout << "@" << sc_time_stamp() << " TEST FAILED " << endl;
            #if (VM_TRACE == 1)
            wf->close();
            #endif

            return -1;
        }
    }

    // BNE
    for(int i = 0; i < TRACE_ITERS; i++)
    {
        opd_a_i = rand() % UINT16_MAX;
        opd_b_i = rand() % UINT16_MAX;
        br_op_i = e_bne;
        br_v_i = true;

        sc_start(10, SC_NS);

        cout << "@" << sc_time_stamp() << " a,b: " << opd_a_i << ", " << opd_b_i;
        cout << " BNE: " << branch_res_o << endl;

        if((opd_a_i != opd_b_i) && !branch_res_o) 
        {
            cout << "@" << sc_time_stamp() << " TEST FAILED " << endl;
            #if (VM_TRACE == 1)
            wf->close();
            #endif

            return -1;
        }
    }

    // BLT
    for(int i = 0; i < TRACE_ITERS; i++)
    {
        opd_a_i = rand() % UINT16_MAX;
        opd_b_i = rand() % UINT16_MAX;
        br_op_i = e_blt;
        br_v_i = true;

        sc_start(10, SC_NS);

        cout << "@" << sc_time_stamp() << " a,b: " << opd_a_i << ", " << opd_b_i;
        cout << " BLT " << branch_res_o << endl;

        if((opd_a_i < opd_b_i) && !branch_res_o) 
        {
            cout << "@" << sc_time_stamp() << " TEST FAILED " << endl;
            #if (VM_TRACE == 1)
            wf->close();
            #endif

            return -1;
        }
    }

    // BLE
    for(int i = 0; i < TRACE_ITERS; i++)
    {
        opd_a_i = rand() % UINT16_MAX;
        opd_b_i = rand() % UINT16_MAX;
        br_op_i = e_ble;
        br_v_i = true;

        sc_start(10, SC_NS);

        cout << "@" << sc_time_stamp() << " a,b: " << opd_a_i << ", " << opd_b_i;
        cout << " BLE: " << branch_res_o << endl;

        if((opd_a_i <= opd_b_i) && !branch_res_o) 
        {
            cout << "@" << sc_time_stamp() << " TEST FAILED " << endl;
            #if (VM_TRACE == 1)
            wf->close();
            #endif

            return -1;
        }
    }

    // BI
    for(int i = 0; i < TRACE_ITERS; i++)
    {
        opd_a_i = rand() % UINT16_MAX;
        opd_b_i = rand() % UINT16_MAX;
        br_op_i = e_bi;
        br_v_i = true;

        sc_start(10, SC_NS);

        cout << "@" << sc_time_stamp() << " a,b: " << opd_a_i << ", " << opd_b_i;
        cout << " BI: " << branch_res_o << endl;

        if(!branch_res_o) 
        {
            cout << "@" << sc_time_stamp() << " TEST FAILED " << endl;
            #if (VM_TRACE == 1)
            wf->close();
            #endif
            return -1;
        }
    }

    cout << "TEST PASSED!" << endl;

    #if (VM_TRACE == 1)
    wf->close();
    #endif

    return 0;
}
