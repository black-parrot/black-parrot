----------------------------------------------------------------------
-- BlackParrot MESI Coherence Protocol
--
-- Notes:
-- 1. Unordered networks are modeled (inherited from the example MESI protocol file)
-- 2. A cache is made owner or added to sharers when the CCE / Directory receives the ack. Sharers
--    are cleared at ack receipt.
--
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------
const
  ProcCount: CFG_PROCS;        -- number processors
  ValueCount: 2;               -- number of data values.
  ReqNet: 0;                   -- low priority - LCE Req
  CmdNet: 1;                   -- LCE Cmd
  RespNet: 2;                  -- LCE Resp
  NumVCs: RespNet - ReqNet + 1;
  NetMax: 2*ProcCount;


----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------
type
  Proc: scalarset(ProcCount);   -- unordered range of processors
  Value: 1..ValueCount; -- arbitrary values for tracking coherence
  Home: enum { HomeType };      -- need enumeration for IsMember calls
  Node: union { Home , Proc };
  Count: 0..ProcCount; -- integer range of number of sharers

  VCType: ReqNet..NumVCs-1;

  MessageType: enum { LceRdReq, -- req to dir for read
                      LceWrReq, -- req to dir for write

                      InvCmd,  -- cmd to LCE to invalidate block
                      TrCmd, -- cmd to LCE to send data to another LCE then send writeback
                             -- in practice, TR and WB are two commmands, but they are always sent together,
                             -- and current implementation uses in-order networks, so consider them as one cmd here
                      WBCmd, -- cmd to LCE to write back data to CCE (does not invalidate the block)
                      SetTagWakeupCmd, -- cmd to LCE to set tag and wakeup on upgrade (state -> M)

                      TagAndDataCmd, -- data block to LCE from CCE

                      InvTagAck, -- ack from LCE to CCE for invalidation
                      CohAck, -- ack from LCE to CCE for coherence transaction

                      LceDataRespNull, -- null data from LCE to CCE on WB
                      LceDataResp -- data from LCE to CCE on WB
                      };

  E_HomeState: enum { H_M, H_S, H_I, H_E, -- stable states
                      -- CCE Microcode Processing
                      -- These states represent the CCE stepping through the microcode routines that
                      -- process a single request. They are not transient states of the coherence block.
                      CCE_IA, -- CCE waiting for invalidation acks
                      CCE_TWBA, -- CCE waiting for transfer writeback or coherence ack
                      CCE_TWB, -- CCE waiting for transfer writeback
                      CCE_WB, -- CCE waiting for writeback
                      CCE_CA -- CCE waiting for coherence ack
                      };

  E_ProcState: enum { P_M, P_S, P_I, P_E, -- stable states
                      -- WAIT state is used to model one transaction per block
                      P_WAIT -- waiting for data cmd and tag cmd to arrive
                      };

  Message:
    Record
      mtype: MessageType;
      src: Node;
      -- do not need a destination for verification; the destination is indicated by which array entry in the
      -- Net the message is placed
      -- channel for message
      vc: VCType;
      -- data value for data cmd and data resp
      val: Value;
      -- metadata for requests
      upgrade: boolean;
      -- metadata for commands
      target: Node; -- target for transfer
      nextState: E_ProcState;
    End;

  HomeState:
    Record
      state: E_HomeState;
      owner: Node;
      sharers: multiset [ProcCount] of Node;
      val: Value;
      -- metadata
      ack: Count; -- invalidation ack counter
      upgrade: boolean; -- does requesting LCE want an upgrade?
      transfer: boolean; -- does request result in LCE to LCE transfer?
      nextState: E_ProcState;
      nextHomeState: E_HomeState;
      reqLce: Node;
      trLce: Node;
    End;

  ProcState:
    Record
      state: E_ProcState;
      val: Value;
      dirty: boolean;
    End;

----------------------------------------------------------------------
-- Variables
----------------------------------------------------------------------
var
  HomeNode:  HomeState;
  Procs: array [Proc] of ProcState;
  Net:   array [Node] of multiset [NetMax] of Message;  -- One multiset for each destination - messages are arbitrarily reordered by the multiset
  InBox: array [Node] of array [VCType] of Message; -- If a message is not processed, it is placed in InBox, blocking that virtual channel
  msg_processed: boolean;
  LastWrite: Value; -- Used to confirm that writes are not lost; this variable would not exist in real hardware

----------------------------------------------------------------------
-- Procedures
----------------------------------------------------------------------
Procedure printMsgType(mtype:MessageType;);
Begin
  switch (mtype)
  case LceRdReq:
    put "LceRdReq";
  case LceWrReq:
    put "LceWrReq";
  case InvCmd:
    put "InvCmd";
  case TrCmd:
    put "TrCmd";
  case WBCmd:
    put "WBCmd";
  case SetTagWakeupCmd:
    put "SetTagWakeupCmd";
  case TagAndDataCmd:
    put "TagAndDataCmd";
  case InvTagAck:
    put "InvTagAck";
  case CohAck:
    put "CohAck";
  case LceDataRespNull:
    put "LceDataRespNull";
  case LceDataResp:
    put "LceDataResp";
  else
    put "Unhandled message type "; put mtype; put "\n";
    error "Unhandled message type!";
  endswitch;
end;

Procedure Send(mtype:MessageType;
               dst:Node;
               src:Node;
               vc:VCType;
               val:Value;
               upgrade:boolean;
               target:Node;
               nextState:E_ProcState;
         );
var msg:Message;
Begin
--  put "Sending msg on Net "; put dst;
--  put " msgType: "; put mtype;
--  put " msgType: "; printMsgType(mtype);
--  put " src: "; put src; put " vc: "; put vc;
--  put "\n";
  Assert (MultiSetCount(i:Net[dst], true) < NetMax) "Too many messages";
  msg.mtype := mtype;
  msg.src   := src;
  msg.vc    := vc;
  -- data value for data cmd and data resp
  msg.val   := val;
  -- metadata for requests
  msg.upgrade := upgrade;
  -- metadata for commands
  msg.target := target; -- target for transfer
  msg.nextState := nextState;

  MultiSetAdd(msg, Net[dst]);
End;

Procedure ErrorUnhandledMsg(msg:Message; n:Node);
Begin
  put "Unhandled msg "; put msg.mtype; put " from proc "; put n;
  error "Unhandled message type!";
End;

Procedure ErrorUnhandledState();
Begin
  error "Unhandled state!";
End;

Procedure AddToSharersList(n:Node);
Begin
  if MultiSetCount(i:HomeNode.sharers, HomeNode.sharers[i] = n) = 0
  then
    MultiSetAdd(n, HomeNode.sharers);
  endif;
End;

Function IsSharer(n:Node) : Boolean;
Begin
  return MultiSetCount(i:HomeNode.sharers, HomeNode.sharers[i] = n) > 0
End;

Procedure RemoveFromSharersList(n:Node);
Begin
  MultiSetRemovePred(i:HomeNode.sharers, HomeNode.sharers[i] = n);
End;

-- Sends a message to all sharers except rqst
Procedure SendInvReqToSharers(rqst:Node);
Begin
  for n:Node do
    if (IsMember(n, Proc) &
        MultiSetCount(i:HomeNode.sharers, HomeNode.sharers[i] = n) != 0)
    then
      if n != rqst
      then
        Send(InvCmd, n, HomeType, CmdNet, UNDEFINED, false, UNDEFINED, UNDEFINED);
      endif;
    endif;
  endfor;
End;


Procedure HomeReceive(msg:Message);
var cnt:0..ProcCount;  -- for counting sharers
Begin
-- Debug output may be helpful:
--  put "Receiving "; put msg.mtype; put " on VC"; put msg.vc;
--  put " at home -- "; put HomeNode.state;
--  put "\n";

  -- compiler barfs if we put this inside a switch, so it is useful to
  -- pre-calculate the sharer count here
  cnt := MultiSetCount(i:HomeNode.sharers, true);


  -- default to 'processing' message.  set to false otherwise
  msg_processed := true;

  -- H_M, H_S, H_I, H_E, CCE_IA, CCE_CA, CCE_TWB, CCE_TWBA

  switch HomeNode.state
  -- Stable states

  -- invalid in directory - immediately reply with current data and set tag
  case H_I:
    switch msg.mtype
      case LceRdReq:
        HomeNode.state := CCE_CA;
        HomeNode.ack := 0; -- invalid, no acks required
        HomeNode.upgrade := false; -- not an upgrade
        HomeNode.transfer := false; -- not a transfer
        HomeNode.nextState := P_E; -- LCE will go to P_E
        HomeNode.nextHomeState := H_E; -- HomeNode will go to H_E after receiving coh ack
        HomeNode.reqLce := msg.src;
        undefine HomeNode.trLce;

        -- send commands
        --put "sending data cmd cce and set tag cmd from H_I\n";
        Send(TagAndDataCmd, msg.src, HomeType, CmdNet, HomeNode.val, false, UNDEFINED, P_E);

      case LceWrReq:
        HomeNode.state := CCE_CA;
        HomeNode.ack := 0; -- invalid, no acks required
        HomeNode.upgrade := false; -- not an upgrade
        HomeNode.transfer := false; -- not a transfer
        HomeNode.nextState := P_M; -- LCE will go to P_M
        HomeNode.nextHomeState := H_M; -- HomeNode will go to H_M after receiving coh ack
        HomeNode.reqLce := msg.src;
        undefine HomeNode.trLce;

        -- send commands
        --put "sending data cmd cce and set tag cmd from H_I\n";
        Send(TagAndDataCmd, msg.src, HomeType, CmdNet, HomeNode.val, false, UNDEFINED, P_M);

      else
        ErrorUnhandledMsg(msg, HomeType);
    endswitch;

  -- block in shared in directory
  case H_S:
    switch msg.mtype
      case LceRdReq:
        HomeNode.state := CCE_CA;
        HomeNode.ack := 0; -- invalid, no acks required
        HomeNode.upgrade := false; -- not an upgrade
        HomeNode.transfer := false; -- not a transfer
        HomeNode.nextState := P_S; -- LCE will go to P_S
        HomeNode.nextHomeState := H_S; -- HomeNode will go to H_S after receiving coh ack
        HomeNode.reqLce := msg.src;
        undefine HomeNode.trLce;

        -- send commands
        --put "sending data cmd and set tag cmd from H_S\n";
        Send(TagAndDataCmd, msg.src, HomeType, CmdNet, HomeNode.val, false, UNDEFINED, P_S);

      case LceWrReq:
        -- there are two cases for a write request when block is cached in shared:
        -- 1. request is from a cache with block in P_S ==> Upgrade
        -- 2. request is from a cache with block in P_I ==> Write miss

        -- invalidate all the other caches regardless of upgrade or write miss
        --put "sending invalidations from H_S\n";
        SendInvReqToSharers(msg.src);

        if (IsSharer(msg.src))
        then
          assert(msg.upgrade) "Upgrade detected, but request is not uprade";
          -- this is an upgrade
          HomeNode.upgrade := true;
          HomeNode.ack := cnt - 1;

          -- special case: the only sharer is the requestor
          if (cnt = 1)
          then
            --put "sending set tag wakeup cmd from H_S\n";
            Send(SetTagWakeupCmd, msg.src, HomeType, CmdNet, UNDEFINED, false, UNDEFINED, P_M);
            HomeNode.state := CCE_CA;
          else
            HomeNode.state := CCE_IA;
          endif;
        else
          -- requestor does not have block cached, not an upgrade, all sharers will ack
          HomeNode.upgrade := false; -- not an upgrade
          HomeNode.ack := cnt;
          -- wait for acks
          HomeNode.state := CCE_IA;
        endif;

        HomeNode.transfer := false; -- not a transfer
        HomeNode.nextState := P_M; -- LCE will go to P_M
        HomeNode.nextHomeState := H_M; -- HomeNode will go to H_M after receiving inv acks and coh ack
        HomeNode.reqLce := msg.src;
        undefine HomeNode.trLce;

      else
        ErrorUnhandledMsg(msg, HomeType);
    endswitch;

  case H_E:
    switch msg.mtype
      case LceRdReq:
        HomeNode.state := CCE_IA;
        -- send invalidation to owner
        --put "sending invalidations from H_E\n";
        Send(InvCmd, HomeNode.owner, HomeType, CmdNet, UNDEFINED, false, UNDEFINED, UNDEFINED);
        HomeNode.ack := 1; -- cached in E by single cache
        HomeNode.upgrade := false; -- not an upgrade
        HomeNode.transfer := true; -- transfer
        HomeNode.nextState := P_S; -- LCE will go to P_S
        HomeNode.nextHomeState := H_S; -- HomeNode will go to H_S after receiving tr ack
        HomeNode.reqLce := msg.src;
        HomeNode.trLce := HomeNode.owner;

      case LceWrReq:
        HomeNode.state := CCE_IA;
        -- send invalidations
        --put "sending invalidations from H_E\n";
        Send(InvCmd, HomeNode.owner, HomeType, CmdNet, UNDEFINED, false, UNDEFINED, UNDEFINED);
        HomeNode.ack := 1; -- cached in E by single cache
        HomeNode.upgrade := false; -- not an upgrade
        HomeNode.transfer := true; -- transfer
        HomeNode.nextState := P_M; -- LCE will go to P_M
        HomeNode.nextHomeState := H_M; -- HomeNode will go to H_M after receiving tr ack
        HomeNode.reqLce := msg.src;
        HomeNode.trLce := HomeNode.owner;

      else
        ErrorUnhandledMsg(msg, HomeType);
    endswitch;

  -- block in modified, cached in a single LCE
  case H_M:
    switch msg.mtype
      case LceRdReq:
        HomeNode.state := CCE_IA;
        --put "sending invalidations from H_M\n";
        Send(InvCmd, HomeNode.owner, HomeType, CmdNet, UNDEFINED, false, UNDEFINED, UNDEFINED);
        HomeNode.ack := 1; -- cached in E by single cache
        HomeNode.upgrade := false; -- not an upgrade
        HomeNode.transfer := true; -- transfer
        HomeNode.nextState := P_S; -- LCE will go to P_S
        HomeNode.nextHomeState := H_S; -- HomeNode will go to H_S after receiving tr ack
        HomeNode.reqLce := msg.src;
        HomeNode.trLce := HomeNode.owner;

      case LceWrReq:
        HomeNode.state := CCE_IA;
        --put "sending invalidations from H_M\n";
        Send(InvCmd, HomeNode.owner, HomeType, CmdNet, UNDEFINED, false, UNDEFINED, UNDEFINED);
        HomeNode.ack := 1; -- cached in E by single cache
        HomeNode.upgrade := false; -- not an upgrade
        HomeNode.transfer := true; -- transfer
        HomeNode.nextState := P_M; -- LCE will go to P_M
        HomeNode.nextHomeState := H_M; -- HomeNode will go to H_M after receiving tr ack
        HomeNode.reqLce := msg.src;
        HomeNode.trLce := HomeNode.owner;

      else
        ErrorUnhandledMsg(msg, HomeType);
    endswitch;



  -- CCE Processing States

  -- waiting for invalidation acks
  case CCE_IA:
    switch msg.mtype
      case LceRdReq, LceWrReq:
        msg_processed := false;
      case InvTagAck:
        HomeNode.ack := HomeNode.ack - 1;
        -- remove LCE from sharers as invalidation acks arrive
        RemoveFromSharersList(msg.src);
        if (HomeNode.ack = 0)
        then
          if (HomeNode.upgrade = true)
          then
            --put "sending set tag wakeup from CCE_IA\n";
            Send(SetTagWakeupCmd, HomeNode.reqLce, HomeType, CmdNet, UNDEFINED, false, UNDEFINED, P_M);
            HomeNode.state := CCE_CA;
          elsif (HomeNode.transfer = true)
          then
            --put "sending set tag, tr, and writeback from CCE_IA\n";
            Send(TrCmd, HomeNode.trLce, HomeType, CmdNet, UNDEFINED, false, HomeNode.reqLce, HomeNode.nextState);
            HomeNode.state := CCE_TWBA;
          else
            --put "sending set tag and data cmd from CCE_IA\n";
            Send(TagAndDataCmd, HomeNode.reqLce, HomeType, CmdNet, HomeNode.val, false, UNDEFINED, HomeNode.nextState);
            HomeNode.state := CCE_CA;
          endif;
        endif;
      else
        ErrorUnhandledMsg(msg, HomeType);
    endswitch;

  -- waiting for coherence ack
  case CCE_CA:
    switch msg.mtype
      case LceRdReq, LceWrReq:
        msg_processed := false;
      case CohAck:
        HomeNode.state := HomeNode.nextHomeState;
        HomeNode.transfer := false;
        --assert(msg.src = HomeNode.reqLce) "Coh Ack arrived from other than requesting LCE";
        if (HomeNode.nextHomeState = H_E | HomeNode.nextHomeState = H_M)
        then
          RemoveFromSharersList(msg.src);
          undefine HomeNode.sharers;
          HomeNode.owner := HomeNode.reqLce;
        elsif (HomeNode.nextHomeState = H_S)
        then
          AddToSharersList(HomeNode.reqLce);
          undefine HomeNode.owner;
        endif;
      else
        ErrorUnhandledMsg(msg, HomeType);
    endswitch;

  -- waiting for writeback from transfer LCE or Coh Ack
  case CCE_TWBA:
    switch msg.mtype
      case LceRdReq, LceWrReq:
        msg_processed := false;
      case CohAck:
        HomeNode.state := CCE_TWB;

        HomeNode.transfer := false;
        --assert(msg.src = HomeNode.reqLce) "Coh Ack arrived from other than requesting LCE";
        if (HomeNode.nextHomeState = H_E | HomeNode.nextHomeState = H_M)
        then
          RemoveFromSharersList(msg.src);
          undefine HomeNode.sharers;
          HomeNode.owner := HomeNode.reqLce;
        elsif (HomeNode.nextHomeState = H_S)
        then
          AddToSharersList(HomeNode.reqLce);
          undefine HomeNode.owner;
        endif;


      case LceDataResp:
        HomeNode.state := CCE_CA;
        HomeNode.val := msg.val;
      case LceDataRespNull:
        HomeNode.state := CCE_CA;
        --assert(msg.val = HomeNode.val) "TWB arrived with bad value";
        --HomeNode.val := msg.val;
      else
        ErrorUnhandledMsg(msg, HomeType);
    endswitch;

  -- waiting for writeback from transfer LCE, CohAck already processed
  case CCE_TWB:
    switch msg.mtype
      case LceRdReq, LceWrReq:
        msg_processed := false;
      case LceDataResp:
        HomeNode.state := HomeNode.nextHomeState;
        HomeNode.val := msg.val;
      case LceDataRespNull:
        HomeNode.state := HomeNode.nextHomeState;
        --assert(msg.val = HomeNode.val) "TWB arrived with bad value";
        --HomeNode.val := msg.val;
      else
        ErrorUnhandledMsg(msg, HomeType);
    endswitch;

  -- waiting for writeback from LCE after CCE initiated WB
  case CCE_WB:
    switch msg.mtype
      case LceRdReq, LceWrReq:
        msg_processed := false;
      case LceDataResp:
        HomeNode.state := HomeNode.nextHomeState;
        HomeNode.val := msg.val;
      case LceDataRespNull:
        HomeNode.state := HomeNode.nextHomeState;
        --assert(msg.val = HomeNode.val) "WB arrived with bad value";
        --HomeNode.val := msg.val;
      else
        ErrorUnhandledMsg(msg, HomeType);
    endswitch;

  else
    ErrorUnhandledState();
  endswitch;
End;


Procedure ProcReceive(msg:Message; p:Proc);
Begin
--  put "Receiving "; put msg.mtype; put " on VC"; put msg.vc;
--  put " at proc "; put p; put " in state "; put Procs[p].state;
--  put "\n";

  -- default to 'processing' message.  set to false otherwise
  msg_processed := true;

  alias ps:Procs[p].state do
  alias pv:Procs[p].val do

-- Processor states
-- P_I, P_S, P_E, P_M, P_WAIT
-- Send(mtype, dst, src, vc, val, upgrade, target, nextState)

  switch ps
    -- invalid, block is clean
    case P_I:
      switch msg.mtype
        case TrCmd:
          --put "sending data cmd lce from P_I\n";
          Send(TagAndDataCmd, msg.target, p, CmdNet, pv, false, UNDEFINED, msg.nextState);
          if (Procs[p].dirty)
          then
            Send(LceDataResp, msg.src, p, RespNet, pv, false, UNDEFINED, UNDEFINED);
          else
            Send(LceDataRespNull, msg.src, p, RespNet, pv, false, UNDEFINED, UNDEFINED);
            Procs[p].dirty := false;
          endif;
          -- stay in invalid
        else
          ErrorUnhandledMsg(msg, p);
      endswitch;

    -- invalid, waiting for tag or data
    case P_WAIT:
      switch msg.mtype
        case InvCmd:
          --put "sending inv tag ack from P_WAIT\n";
          Send(InvTagAck, msg.src, p, RespNet, UNDEFINED, false, UNDEFINED, UNDEFINED);
        case TrCmd:
          --put "sending data cmd lce from P_WAIT\n";
          Send(TagAndDataCmd, msg.target, p, CmdNet, pv, false, UNDEFINED, msg.nextState);
          Send(LceDataRespNull, msg.src, p, RespNet, pv, false, UNDEFINED, UNDEFINED);
        case TagAndDataCmd:
          -- record data value received
          pv := msg.val;
          ps := msg.nextState;
          Send(CohAck, HomeType, p, RespNet, UNDEFINED, false, UNDEFINED, msg.nextState);
        case SetTagWakeupCmd:
          ps := P_M;
          Send(CohAck, msg.src, p, RespNet, UNDEFINED, false, UNDEFINED, P_M);
        case WBCmd:
          if (Procs[p].dirty)
          then
            Send(LceDataResp, msg.src, p, RespNet, pv, false, UNDEFINED, UNDEFINED);
          else
            Send(LceDataRespNull, msg.src, p, RespNet, pv, false, UNDEFINED, UNDEFINED);
            Procs[p].dirty := false;
          endif;
        else
          ErrorUnhandledMsg(msg, p);
      endswitch;

    -- shared
    case P_S:
    switch msg.mtype
      case InvCmd:
        --put "sending inv tag ack from P_S\n";
        Send(InvTagAck, msg.src, p, RespNet, UNDEFINED, false, UNDEFINED, UNDEFINED);
        ps := P_I;
      case WBCmd:
        --put "sending null WB resp from P_S\n";
        Send(LceDataRespNull, msg.src, p, RespNet, pv, false, UNDEFINED, UNDEFINED);
      else
        ErrorUnhandledMsg(msg, p);
    endswitch;

    -- exclusive
    case P_E:
    switch msg.mtype
      case InvCmd:
        --put "sending inv tag ack from P_E\n";
        Send(InvTagAck, msg.src, p, RespNet, UNDEFINED, false, UNDEFINED, UNDEFINED);
        -- block is clean, so go to invalid state
        ps := P_I;
      case WBCmd:
        --put "sending null WB resp from P_E\n";
        Send(LceDataRespNull, msg.src, p, RespNet, pv, false, UNDEFINED, UNDEFINED);
      else
        ErrorUnhandledMsg(msg, p);
    endswitch;

    -- modified
    case P_M:
    switch msg.mtype
      case InvCmd:
        --put "sending inv tag ack from P_M\n";
        Send(InvTagAck, msg.src, p, RespNet, UNDEFINED, false, UNDEFINED, UNDEFINED);
        ps := P_I;
      case WBCmd:
        --put "sending null WB resp from P_M\n";
        Send(LceDataResp, msg.src, p, RespNet, pv, false, UNDEFINED, UNDEFINED);
        -- clear the dirty bit since block is being written back
        Procs[p].dirty := false;
      else
        ErrorUnhandledMsg(msg, p);
    endswitch;

  ----------------------------
  -- Error catch
  ----------------------------
  else
    ErrorUnhandledState();

  endswitch;

  endalias;
  endalias;
End;

----------------------------------------------------------------------
-- Rules
----------------------------------------------------------------------

-- Processor states
-- P_M, P_S, P_I, P_E, P_WAIT

-- Processor actions (affecting coherency)
ruleset n:Proc do
  alias p:Procs[n] do

    ---------------------------------------------------------------
    -- load or store hits
    ---------------------------------------------------------------
    ruleset v:Value Do
    rule "store new value"
      (p.state = P_M)
        ==>
      p.val := v;
      LastWrite := v;  --We use LastWrite to sanity check that reads receive the value of the last write
      --put "storing value := "; put v; put " by proc "; put n; put "\n";
      p.dirty := true;
    endrule;
    endruleset;

    ruleset v:Value Do
    rule "store new value on exclusive"
      (p.state = P_E)
        ==>
      p.val := v;
      LastWrite := v;  --We use LastWrite to sanity check that reads receive the value of the last write
      p.state := P_M;
      --put "storing value := "; put v; put " by proc "; put n; put "\n";
      p.dirty := true;
    endrule;
    endruleset;

    ---------------------------------------------------------------
    -- load or stores with no replacement
    ---------------------------------------------------------------
    rule "read request"
      (p.state = P_I & p.dirty = false)
        ==>
      --put "LceRdReq from Proc "; put n; put " in state "; put p.state;
      Send(LceRdReq, HomeType, n, ReqNet, UNDEFINED, false, UNDEFINED, UNDEFINED);
      p.state := P_WAIT;
    endrule;

    rule "write request"
      (p.state = P_I & p.dirty = false)
        ==>
      --put "LceWrReq from Proc "; put n; put " in state "; put p.state;
      Send(LceWrReq, HomeType, n, ReqNet, UNDEFINED, false, UNDEFINED, UNDEFINED);
      p.state := P_WAIT;
    endrule;

    rule "upgrade request"
      (p.state = P_S)
        ==>
      --put "LceWrReq from Proc "; put n; put " in state "; put p.state;
      Send(LceWrReq, HomeType, n, ReqNet, UNDEFINED, true, UNDEFINED, UNDEFINED);
      p.state := P_WAIT;
    endrule;

  endalias;
endruleset;

-- Directory Actions
alias h:HomeNode do

  rule "writeback block"
    (h.state = H_E | h.state = H_M)
      ==>
    Send(WBCmd, h.owner, HomeType, CmdNet, UNDEFINED, false, UNDEFINED, UNDEFINED);
    h.state := CCE_WB;
    h.nextHomeState := h.state;
  endrule;

endalias;

-- Message delivery rules
ruleset n:Node do
  choose midx:Net[n] do
    alias chan:Net[n] do
    alias msg:chan[midx] do
    alias box:InBox[n] do

    -- Pick a random message in the network and delivier it
    rule "receive-net"
      (isundefined(box[msg.vc].mtype))
        ==>
      if IsMember(n, Home)
      then
        HomeReceive(msg);
      else
        ProcReceive(msg, n);
      endif;

      if ! msg_processed
      then
        -- The node refused the message, stick it in the InBox to block the VC.
        box[msg.vc] := msg;
      endif;

      MultiSetRemove(midx, chan);
    endrule;

    endalias
    endalias;
    endalias;
  endchoose;

    -- Try to deliver a message from a blocked VC; perhaps the node can handle it now
    ruleset vc:VCType do
    rule "receive-blocked-vc"
            (! isundefined(InBox[n][vc].mtype))
    ==>
      if IsMember(n, Home)
      then
        HomeReceive(InBox[n][vc]);
      else
        ProcReceive(InBox[n][vc], n);
            endif;

            if msg_processed
            then
                -- Message has been handled, forget it
            undefine InBox[n][vc];
            endif;

    endrule;
  endruleset;

endruleset;

----------------------------------------------------------------------
-- Startstate
----------------------------------------------------------------------
startstate

  msg_processed := false;

  -- home node initialization
  HomeNode.state := H_I;
  undefine HomeNode.owner;
  undefine HomeNode.sharers;
  HomeNode.val := 1;
  HomeNode.ack := 0;
  HomeNode.upgrade := false;
  HomeNode.transfer := false;
  undefine HomeNode.nextState;
  undefine HomeNode.reqLce;
  undefine HomeNode.trLce;

  -- global last write value
  LastWrite := HomeNode.val;

  -- processor initialization
  for i:Proc do
    Procs[i].state := P_I;
    undefine Procs[i].val;
    Procs[i].dirty := false;
  endfor;

  -- network initialization
  undefine Net;
endstartstate;

----------------------------------------------------------------------
-- Invariants
----------------------------------------------------------------------

-- Ownership Invariants
invariant "Invalid implies empty owner"
  HomeNode.state = H_I
    ->
  IsUndefined(HomeNode.owner);

invariant "Shared implies empty owner"
  HomeNode.state = H_S
    ->
  IsUndefined(HomeNode.owner);

-- Sharers List Invariants

invariant "Modified implies empty sharers list"
  HomeNode.state = H_M
    ->
  MultiSetCount(i:HomeNode.sharers, true) = 0;

invariant "Invalid implies empty sharer list"
  HomeNode.state = H_I
    ->
  MultiSetCount(i:HomeNode.sharers, true) = 0;

invariant "Exclusive implies empty sharer list"
  HomeNode.state = H_E
    ->
  MultiSetCount(i:HomeNode.sharers, true) = 0;

-- Additional State Invariants

invariant "Home in Shared state implies Proc in Invalid or Shared"
  Forall n : Proc do
    HomeNode.state = H_S
      ->
      (Procs[n].state = P_S |  Procs[n].state = P_I
       | Procs[n].state = P_WAIT)
  end;

-- Data or Value Invariants

invariant "Value in memory matches value of last write, when shared or invalid"
  (HomeNode.state = H_S | HomeNode.state = H_I)
    ->
  HomeNode.val = LastWrite;

invariant "Values in shared state must match last write"
  Forall n : Proc do
    Procs[n].state = P_S
      ->
      Procs[n].val = LastWrite
  end;

invariant "Values in exclusive state must match last write"
  Forall n : Proc do
    Procs[n].state = P_E
      ->
      Procs[n].val = LastWrite
  end;

invariant "Values in modified state must match last write"
  Forall n : Proc do
    Procs[n].state = P_M
      ->
      Procs[n].val = LastWrite
  end;

invariant "Exclusive has a clean copy of data"
  Forall n : Proc do
    HomeNode.state = H_E & Procs[n].state = P_E
      ->
    (HomeNode.val = Procs[n].val & Procs[n].dirty = false)
  end;

invariant "Shared has a clean copy of data"
  Forall n : Proc do
    HomeNode.state = H_S & Procs[n].state = P_S
      ->
    (HomeNode.val = Procs[n].val & Procs[n].dirty = false)
  end;

invariant "Exclusive has a clean copy of data"
  Forall n : Proc do
    Procs[n].state = P_E
      ->
    Procs[n].dirty = false
  end;

invariant "Shared has a clean copy of data"
  Forall n : Proc do
    Procs[n].state = P_S
      ->
    Procs[n].dirty = false
  end;

-- Not necessarily true; CCE can writeback the data, making in clean in M
--invariant "Modified has a dirty copy of data"
--  Forall n : Proc do
--    HomeNode.state = H_M & Procs[n].state = P_M
--      ->
--    (HomeNode.val != Procs[n].val & Procs[n].dirty = true)
--  end;

