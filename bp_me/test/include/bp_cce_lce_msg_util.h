/**
 *
 * bp_cce_lce_msg_util.h
 *
 * This file contains utility functions that can package up LCE to CCE messages and check CCE
 * to LCE commands for correctness.
 *
 */

#include "systemc.h"

#include <sstream>
#include <string>

#include "bp_cce_verilator.h"
#include "bp_cce.h"
#include "bp_common_me_if.h"

template<typename T>
std::string toString(T in, int bits)
{
  std::stringstream ss;
  for (int i = bits; i > 0; i--) {
    if (((in >> (i-1)) & 0x1) == 1) {
      ss << "1";
    } else {
      ss << "0";
    }
  }
  return ss.str();
}

// LCE to CCE Request
sc_bv<bp_lce_cce_req_width>
createLceReq(uint32_t dst, uint32_t src, bp_lce_cce_req_type_e reqType, uint64_t addr,
             bp_lce_cce_req_non_excl_e non_excl, uint32_t lruWay, bp_lce_cce_lru_dirty_e lruDirty)
{
  sc_bv<bp_lce_cce_req_width> msg(0);
  msg.range(0,0) = (int)lruDirty;
  msg.range(LG_LCE_ASSOC,1) = lruWay;
  msg.range(ADDR_WIDTH+LG_LCE_ASSOC,LG_LCE_ASSOC+1) = addr;
  msg.range(ADDR_WIDTH+LG_LCE_ASSOC+1,ADDR_WIDTH+LG_LCE_ASSOC+1) = (int)non_excl;
  msg.range(ADDR_WIDTH+LG_LCE_ASSOC+1+bp_lce_cce_req_type_width,ADDR_WIDTH+LG_LCE_ASSOC+2) = (int)reqType;
  msg.range(bp_lce_cce_req_width-LG_N_CCE-1,bp_lce_cce_req_width-LG_N_CCE-LG_N_LCE) = src;
  msg.range(bp_lce_cce_req_width-1,bp_lce_cce_req_width-LG_N_CCE) = dst;

  cout << "lceReq(" << bp_lce_cce_req_width << "):  " << msg.to_string() << endl;
  cout << " dst(" << LG_N_CCE << "): " << dst
       << " src(" << LG_N_LCE << "): " << src
       << " type(1): " << ((int)reqType ? "W" : "R")
       << " addr(" << ADDR_WIDTH << "): " << toString<uint64_t>(addr, ADDR_WIDTH)
       << " NE(1): " << (int)non_excl
       << " lruWay(" << LG_LCE_ASSOC << "): " << (int)lruWay
       << " lruDirty(1): " << (int)lruDirty << endl;

  return msg;
}

bool
checkLceReq(sc_bv<bp_lce_cce_req_width> &msg, uint32_t dst, uint32_t src,
            bp_lce_cce_req_type_e reqType, uint64_t addr, bp_lce_cce_req_non_excl_e non_excl,
            uint32_t lruWay, bp_lce_cce_lru_dirty_e lruDirty)
{
  sc_bv<bp_lce_cce_req_width> exp = createLceReq(dst, src, reqType, addr, non_excl, lruWay, lruDirty);
  //cout << "LCE Req: " << msg.to_string() << endl;
  //cout << "exp msg: " << exp.to_string() << endl;
  return !(msg.to_string().compare(exp.to_string()));
}

// CCE to LCE Command
sc_bv<bp_cce_lce_cmd_width>
createCceCmd(uint32_t dst, uint32_t src, bp_cce_lce_cmd_type_e cmd, uint64_t addr, uint32_t way,
             bp_cce_coh_mesi_e state, uint32_t target, uint32_t target_way)
{
  sc_bv<bp_cce_lce_cmd_width> msg(0);

  msg.range(LG_LCE_ASSOC-1,0) = target_way;
  msg.range(LG_LCE_ASSOC+LG_N_LCE-1, LG_LCE_ASSOC) = target;
  msg.range(LG_LCE_ASSOC+LG_N_LCE+LG_COH_ST-1,LG_LCE_ASSOC+LG_N_LCE) = (uint8_t)state;
  msg.range(LG_LCE_ASSOC+LG_N_LCE+LG_COH_ST+LG_LCE_ASSOC-1,LG_LCE_ASSOC+LG_N_LCE+LG_COH_ST) = way;
  msg.range(LG_LCE_ASSOC+LG_N_LCE+LG_COH_ST+LG_LCE_ASSOC+ADDR_WIDTH-1,LG_LCE_ASSOC+LG_N_LCE+LG_COH_ST+LG_LCE_ASSOC) = addr;
  msg.range(bp_cce_lce_cmd_width-LG_N_LCE-LG_N_CCE-1,LG_LCE_ASSOC+LG_N_LCE+LG_COH_ST+LG_LCE_ASSOC+ADDR_WIDTH) = (uint32_t)cmd;
  msg.range(bp_cce_lce_cmd_width-LG_N_LCE-1, bp_cce_lce_cmd_width-LG_N_LCE-LG_N_CCE) = src;
  msg.range(bp_cce_lce_cmd_width-1, bp_cce_lce_cmd_width-LG_N_LCE) = dst;

	cout << "target: " << target << endl;

  return msg;
}

bool
checkCceCmd(sc_bv<bp_cce_lce_cmd_width> &msg, uint32_t dst, uint32_t src, uint64_t addr,
            uint32_t way, bp_cce_lce_cmd_type_e cmd, bp_cce_coh_mesi_e state, uint32_t target,
            uint32_t target_way)
{
  sc_bv<bp_cce_lce_cmd_width> exp = createCceCmd(dst, src, cmd, addr, way, state, target, target_way);
  cout << "CCE Cmd: " << msg.to_string() << endl;
  cout << "exp msg: " << exp.to_string() << endl;
  return !(msg.to_string().compare(exp.to_string()));
}

// LCE to CCE Data Response
sc_bv<bp_lce_cce_data_resp_width>
createLceDataResp(uint32_t dst, uint32_t src, uint64_t addr, bp_lce_cce_wb_resp_type_e wb, uint64_t dataVal)
{
  sc_bv<bp_lce_cce_data_resp_width> msg(0);

  msg.range(DATA_WIDTH_BITS-1,0) = dataVal;
  msg.range(DATA_WIDTH_BITS+ADDR_WIDTH-1,DATA_WIDTH_BITS) = addr;
  msg.range(DATA_WIDTH_BITS+ADDR_WIDTH+bp_lce_cce_wb_resp_type_width-1,DATA_WIDTH_BITS+ADDR_WIDTH) = (uint8_t)wb;
  msg.range(bp_lce_cce_data_resp_width-LG_N_CCE-1, bp_lce_cce_data_resp_width-LG_N_CCE-LG_N_LCE) = src;
  msg.range(bp_lce_cce_data_resp_width-1, bp_lce_cce_data_resp_width-LG_N_CCE) = dst;

  cout << "lceDataResp: " << msg.to_string() << endl;

  return msg;
}

bool
checkLceDataResp(sc_bv<bp_lce_cce_data_resp_width> &msg, uint32_t dst, uint32_t src, uint64_t addr,
                 bp_lce_cce_wb_resp_type_e wb, uint64_t dataVal)
{
  sc_bv<bp_lce_cce_data_resp_width> exp = createLceDataResp(dst, src, addr, wb, dataVal);
  cout << "LCE Data Resp: " << msg.to_string() << endl;
  cout << "exp msg:       " << exp.to_string() << endl;
  return !(msg.to_string().compare(exp.to_string()));
}

// LCE to CCE Response
sc_bv<bp_lce_cce_resp_width>
createLceResp(uint32_t dst, uint32_t src, bp_lce_cce_ack_type_e ack, uint64_t addr)
{
  sc_bv<bp_lce_cce_resp_width> msg(0);
  msg.range(ADDR_WIDTH-1,0) = addr;
  msg.range(ADDR_WIDTH+bp_lce_cce_ack_type_width-1,ADDR_WIDTH) = (uint8_t)ack;
  msg.range(bp_lce_cce_resp_width-LG_N_CCE-1, bp_lce_cce_resp_width-LG_N_CCE-LG_N_LCE) = src;
  msg.range(bp_lce_cce_resp_width-1, bp_lce_cce_resp_width-LG_N_CCE) = dst;

  cout << "lceResp: " << msg.to_string() << endl;

  return msg;
}

bool
checkLceResp(sc_bv<bp_lce_cce_resp_width> &msg, uint32_t dst, uint32_t src,
             bp_lce_cce_ack_type_e ack, uint64_t addr)
{
  sc_bv<bp_lce_cce_resp_width> exp = createLceResp(dst, src, ack, addr);
  cout << "LCE Resp: " << msg << endl;
  cout << "exp msg:  " << exp.to_string() << endl;
  return !(msg.to_string().compare(exp.to_string()));
}

// CCE to LCE Data Command
sc_bv<bp_cce_lce_data_cmd_width>
createCceDataCmd(uint32_t dst, uint32_t src, uint64_t addr, uint32_t way,
                 bp_lce_cce_req_type_e reqType, uint64_t data)
{
  sc_bv<bp_cce_lce_data_cmd_width> msg(0);

  msg.range(DATA_WIDTH_BITS-1,0) = data;
  msg.range(DATA_WIDTH_BITS+ADDR_WIDTH-1,DATA_WIDTH_BITS) = addr;
  msg.range(DATA_WIDTH_BITS+ADDR_WIDTH+LG_LCE_ASSOC-1,DATA_WIDTH_BITS+ADDR_WIDTH) = way;
  msg.range(DATA_WIDTH_BITS+ADDR_WIDTH+LG_LCE_ASSOC+bp_lce_cce_req_type_width-1,DATA_WIDTH_BITS+ADDR_WIDTH+LG_LCE_ASSOC) = (uint8_t)reqType;
  msg.range(bp_cce_lce_data_cmd_width-LG_N_LCE-1, bp_cce_lce_data_cmd_width-LG_N_LCE-LG_N_CCE) = src;
  msg.range(bp_cce_lce_data_cmd_width-1, bp_cce_lce_data_cmd_width-LG_N_LCE) = dst;

  return msg;
}

bool
checkCceDataCmd(sc_bv<bp_cce_lce_data_cmd_width> &msg, uint32_t dst, uint32_t src, uint64_t addr,
                uint32_t way, bp_lce_cce_req_type_e reqType, uint64_t data, bool checkData)
{
  sc_bv<bp_cce_lce_data_cmd_width> exp = createCceDataCmd(dst, src, addr, way, reqType, data);
  // if not checking data, set data to 0 in both received message and expected message
  if (!checkData) {
    msg.range(DATA_WIDTH_BITS-1,0) = 0;
    exp.range(DATA_WIDTH_BITS-1,0) = 0;
  }
  cout << "CCE Data Cmd: " << msg << endl;
  cout << "exp msg:      " << exp.to_string() << endl;
  return !(msg.to_string().compare(exp.to_string()));
}

// LCE to LCE Transfer Response
sc_bv<bp_lce_lce_tr_resp_width>
createLceTrResp(uint32_t dst, uint32_t src, uint64_t addr, uint32_t way)
{
  sc_bv<bp_lce_lce_tr_resp_width> msg(0);
  msg.range(DATA_WIDTH_BITS-1,0) = 0;
  msg.range(DATA_WIDTH_BITS-ADDR_WIDTH-1,DATA_WIDTH_BITS) = addr;
  msg.range(DATA_WIDTH_BITS-ADDR_WIDTH-LG_LCE_ASSOC-1,DATA_WIDTH_BITS-ADDR_WIDTH) = way;
  msg.range(bp_lce_lce_tr_resp_width-LG_N_CCE-1, bp_lce_lce_tr_resp_width-LG_N_LCE-LG_N_LCE) = src;
  msg.range(bp_lce_lce_tr_resp_width-1, bp_lce_lce_tr_resp_width-LG_N_LCE) = dst;

  cout << "lceTrResp: " << msg.to_string() << endl;

  return msg;
}

bool
checkLceTrResp(sc_bv<bp_lce_lce_tr_resp_width> &msg, uint32_t dst, uint32_t src, uint64_t addr,
               uint32_t way)
{
  sc_bv<bp_lce_lce_tr_resp_width> exp = createLceTrResp(dst, src, addr, way);
  cout << "LCE Tr Resp: " << msg << endl;
  cout << "exp msg:     " << exp.to_string() << endl;
  return !(msg.to_string().compare(exp.to_string()));
}
