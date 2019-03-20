/**
 *
 * bp_cce_lce_msg_util.h
 *
 * This file contains utility functions that can package up LCE to CCE messages and check CCE
 * to LCE commands for correctness.
 *
 */

#include "systemc.h"

#include <iomanip>
#include <sstream>
#include <string>

#include "bp_cce_verilator.h"
#include "bp_cce.h"
#include "bp_common_me_if.h"

template<typename T>
std::string toHex(T in)
{
  std::stringstream ss;
  ss << std::setfill('0') << std::setw(sizeof(T)*2) << std::hex << in;
  return ss.str();
}

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
             bp_lce_cce_req_non_excl_e non_excl, uint32_t lruWay, bp_lce_cce_lru_dirty_e lruDirty,
             bp_lce_cce_req_non_cacheable_e nc_req = e_lce_req_cacheable,
             bp_lce_cce_nc_req_size_e nc_size = e_lce_nc_req_1)
{
  sc_bv<bp_lce_cce_req_width> msg(0);

  int offset_lo = 0;
  int offset_hi = bp_lce_cce_nc_req_size_width-1;
  msg.range(offset_hi, offset_lo) = (int)nc_size;

  offset_lo = offset_hi+1;
  offset_hi = offset_hi+bp_lce_cce_req_non_cacheable_width;
  msg.range(offset_hi, offset_lo) = (int)nc_req;

  offset_lo = offset_hi+1;
  offset_hi = offset_hi+bp_lce_cce_lru_dirty_width;
  msg.range(offset_hi, offset_lo) = (int)lruDirty;

  offset_lo = offset_hi+1;
  offset_hi = offset_hi+LG_LCE_ASSOC;
  msg.range(offset_hi, offset_lo) = lruWay;

  offset_lo = offset_hi+1;
  offset_hi = offset_hi+ADDR_WIDTH;
  msg.range(offset_hi, offset_lo) = addr;

  offset_lo = offset_hi+1;
  offset_hi = offset_hi+bp_lce_cce_req_non_excl_width;
  msg.range(offset_hi, offset_lo) = (int)non_excl;

  offset_lo = offset_hi+1;
  offset_hi = offset_hi+bp_lce_cce_req_type_width;
  msg.range(offset_hi, offset_lo) = (int)reqType;

  msg.range(bp_lce_cce_req_width-LG_N_CCE-1,bp_lce_cce_req_width-LG_N_CCE-LG_N_LCE) = src;
  msg.range(bp_lce_cce_req_width-1,bp_lce_cce_req_width-LG_N_CCE) = dst;

  cout << "lceReq(" << bp_lce_cce_req_width << "):  " << msg.to_string() << endl;
  cout << " dst(" << LG_N_CCE << "): " << dst
       << " src(" << LG_N_LCE << "): " << src
       << " type(1): " << ((int)reqType ? "W" : "R")
       << " addr(" << ADDR_WIDTH << "): " << toHex<uint64_t>(addr) //toString<uint64_t>(addr, ADDR_WIDTH)
       << " NE(1): " << (int)non_excl
       << " lruWay(" << LG_LCE_ASSOC << "): " << (int)lruWay
       << " lruDirty(1): " << (int)lruDirty
       << " ncReq(1): " << (int)nc_req
       << " ncReqSize(2): " << (int)nc_size
       << endl;

  return msg;
}

bool
checkLceReq(sc_bv<bp_lce_cce_req_width> &msg, uint32_t dst, uint32_t src,
            bp_lce_cce_req_type_e reqType, uint64_t addr, bp_lce_cce_req_non_excl_e non_excl,
            uint32_t lruWay, bp_lce_cce_lru_dirty_e lruDirty,
            bp_lce_cce_req_non_cacheable_e nc_req, bp_lce_cce_nc_req_size_e nc_size)
{
  sc_bv<bp_lce_cce_req_width> exp = createLceReq(dst, src, reqType, addr, non_excl, lruWay, lruDirty, nc_req, nc_size);
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

  cout << "cceCmd(" << bp_cce_lce_cmd_width << "):  " << msg.to_string() << endl;
  cout << " dst(" << LG_N_LCE << "): " << dst
       << " src(" << LG_N_CCE << "): " << src
       << " cmd(" << bp_cce_lce_cmd_type_width << "): " << (uint32_t)cmd 
       << " addr(" << ADDR_WIDTH << "): " << toHex<uint64_t>(addr) //toString<uint64_t>(addr, ADDR_WIDTH)
       << " way(" << LG_LCE_ASSOC << "): " << way
       << " state(" << bp_cce_coh_bits << "): " << (uint32_t)state
       << " target(" << LG_N_LCE << "): " << target
       << " targetWay(" << LG_LCE_ASSOC << "): " << target_way
       << endl;

  return msg;
}

void printCceCmd(sc_bv<bp_cce_lce_cmd_width> &msg)
{
  cout << "cceCmd(" << bp_cce_lce_cmd_width << "):  " << msg.to_string() << endl;
  int high = bp_cce_lce_cmd_width-1;
  cout << " dst(" << LG_N_LCE << "): " << msg.range(high, high-LG_N_LCE+1).to_uint(); //dst
  high -= LG_N_LCE;
  cout << " src(" << LG_N_CCE << "): " << msg.range(high, high-LG_N_CCE+1).to_uint(); //src
  high -= LG_N_CCE;
  cout << " cmd(" << bp_cce_lce_cmd_type_width << "): " << msg.range(high, high-bp_cce_lce_cmd_type_width+1).to_uint(); //(uint32_t)cmd 
  high -= bp_cce_lce_cmd_type_width;
  cout << " addr(" << ADDR_WIDTH << "): " << toHex<uint64_t>(msg.range(high, high-ADDR_WIDTH+1).to_uint64()); //toHex<uint64_t>(addr) //toString<uint64_t>(addr, ADDR_WIDTH)
  high -= ADDR_WIDTH;
  cout << " way(" << LG_LCE_ASSOC << "): " << msg.range(high, high-LG_LCE_ASSOC+1).to_uint(); //way
  high -= LG_LCE_ASSOC;
  cout << " state(" << bp_cce_coh_bits << "): " << msg.range(high, high-bp_cce_coh_bits+1).to_uint(); //(uint32_t)state
  high -= bp_cce_coh_bits;
  cout << " target(" << LG_N_LCE << "): " << msg.range(high, high-LG_N_LCE+1).to_uint(); //target
  high -= LG_N_LCE;
  cout << " targetWay(" << LG_LCE_ASSOC << "): " << msg.range(high, high-LG_LCE_ASSOC+1).to_uint(); //target_way
  cout << endl;

}

bool
checkCceCmd(sc_bv<bp_cce_lce_cmd_width> &msg, uint32_t dst, uint32_t src, uint64_t addr,
            uint32_t way, bp_cce_lce_cmd_type_e cmd, bp_cce_coh_mesi_e state, uint32_t target,
            uint32_t target_way)
{
  cout << "Checking CCE Cmd..." << endl;
  cout << "Creating expected message" << endl;
  sc_bv<bp_cce_lce_cmd_width> exp = createCceCmd(dst, src, cmd, addr, way, state, target, target_way);
  cout << "CCE Cmd: " << msg.to_string() << endl;
  //printCceCmd(msg);
  cout << "exp msg: " << exp.to_string() << endl;
  return !(msg.to_string().compare(exp.to_string()));
}

// LCE to CCE Data Response
sc_bv<bp_lce_cce_data_resp_width>
createLceDataResp(uint32_t dst, uint32_t src, uint64_t addr, bp_lce_cce_resp_msg_type_e wb, uint64_t dataVal)
{
  sc_bv<bp_lce_cce_data_resp_width> msg(0);

  msg.range(DATA_WIDTH_BITS-1,0) = dataVal;
  msg.range(DATA_WIDTH_BITS+ADDR_WIDTH-1,DATA_WIDTH_BITS) = addr;
  msg.range(DATA_WIDTH_BITS+ADDR_WIDTH+bp_lce_cce_resp_msg_type_width-1,DATA_WIDTH_BITS+ADDR_WIDTH) = (uint8_t)wb;
  msg.range(bp_lce_cce_data_resp_width-LG_N_CCE-1, bp_lce_cce_data_resp_width-LG_N_CCE-LG_N_LCE) = src;
  msg.range(bp_lce_cce_data_resp_width-1, bp_lce_cce_data_resp_width-LG_N_CCE) = dst;

  cout << "lceDataResp: " << msg.to_string() << endl;

  return msg;
}

bool
checkLceDataResp(sc_bv<bp_lce_cce_data_resp_width> &msg, uint32_t dst, uint32_t src, uint64_t addr,
                 bp_lce_cce_resp_msg_type_e wb, uint64_t dataVal)
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
sc_bv<bp_lce_data_cmd_width>
createCceDataCmd(uint32_t dst, uint32_t way, bp_lce_data_cmd_type_e cmdType, uint64_t data)
{
  sc_bv<bp_lce_data_cmd_width> msg(0);

  msg.range(LG_LCE_ASSOC-1,0) = way;
  msg.range(LG_LCE_ASSOC+bp_lce_data_cmd_type_width-1, LG_LCE_ASSOC) = (uint8_t)cmdType;
  msg.range(LG_LCE_ASSOC+bp_lce_data_cmd_type_width+LG_N_LCE-1, LG_LCE_ASSOC+bp_lce_data_cmd_type_width) = dst;
  msg.range(bp_lce_data_cmd_width-1, bp_lce_data_cmd_width-DATA_WIDTH_BITS) = data;

  /*
  std::stringstream ss;
  ss << "CCE Data Cmd Addr: " 
     << std::setfill('0') << std::setw(sizeof(uint64_t)*2) << std::hex << addr;
  cout << ss.str() << endl;
  */

  return msg;
}

bool
checkCceDataCmd(sc_bv<bp_lce_data_cmd_width> &msg, uint32_t dst, uint32_t way,
                bp_lce_data_cmd_type_e reqType, uint64_t data, bool checkData)
{
  cout << "Checking CCE Data Cmd..." << endl;
  sc_bv<bp_lce_data_cmd_width> exp = createCceDataCmd(dst, way, reqType, data);
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
