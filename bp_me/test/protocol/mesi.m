----------------------------------------------------------------------
-- BlackParrot MESI Coherence Protocol
--
-- Notes:
-- 1. Replacement is not modeled since we use the single address assumption. The LCEs are not
--    allowed to evict a block on their own, only the CCE can evict a block.
-- 2. "Message delivery cannot be assumed to be in the same order as they were sent, even for
--     the same sender and receiver pair"
-- 3. A cache is made owner or added to sharers when the CCE / Directory receives the ack. Sharers
--    are cleared at ack receipt.
--
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------
const
  ProcCount: 2;          -- number processors
  ValueCount: 2;         -- number of data values.
  VC0: 0;                -- low priority - LCE Req
  VC1: 1;                -- LCE Cmd
  VC2: 2;                -- LCE Data Cmd
  VC3: 3;                -- LCE Resp
  VC4: 4;                -- LCE Data Resp
  NumVCs: VC4 - VC0 + 1;
  -- TODO: what is max messages?
  NetMax: (2*ProcCount)+1;


----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------
type
  Proc: scalarset(ProcCount);   -- unordered range of processors
  Value: 1..ValueCount; -- arbitrary values for tracking coherence
  Home: enum { HomeType };      -- need enumeration for IsMember calls
  Node: union { Home , Proc };
  Count: 0..ProcCount; -- integer range of number of sharers

  VCType: VC0..NumVCs-1;

  MessageType: enum { LceRdReq, -- req to dir for read
                      LceWrReq, -- req to dir for write

                      InvTagCmd,  -- cmd to LCE to invalidate block
                      TrCmd, -- cmd to LCE to send data to another LCE
                      SetTagCmd, -- cmd to LCE to set tag and coherence state of block
                      SetTagWakeupCmd, -- cmd to LCE to set tag and wakeup on upgrade (state -> M)
                      WritebackCmd, -- cmd to LCE to send data to CCE

                      DataCmdCce, -- data block to LCE from CCE
                      DataCmdLce, -- data block to LCE from LCE (transfer)

                      InvTagAck, -- ack from LCE to CCE for invalidation
                      CohAck, -- ack from LCE to CCE for coherence transaction
                      TrAck, -- ack from LCE to CCE for transfer

                      LceDataRespNull, -- null data from LCE to CCE on WB
                      LceDataResp -- data from LCE to CCE on WB
                      };

  E_HomeState: enum { H_M, H_S, H_I, H_E, -- stable states
                      -- "transient" states - states that CCE steps through to process request
                      H_IA, -- wait for invalidation acks
                      H_CA, -- wait for coherence ack
                      H_TWB, -- wait for writeback or null writeback from transferring LCE
                      H_TA -- wait for transfer ack
                      };

  E_ProcState: enum { P_M, P_S, P_I, P_E, -- stable states
                      P_I_DT, -- invalid waiting for data cmd or tag cmd to arrive
                      P_I_D, -- invalid waiting for data cmd to arrive
                      P_I_T, -- invalid waiting for tag cmd to arrive
                      P_ID, -- invalid and dirty (waiting for WB command)
                      P_S_U -- shared to modified upgrade
                      };

  Message:
    Record
      mtype: MessageType;
      src: Node;
      -- do not need a destination for verification; the destination is indicated by which array entry in the Net the message is placed
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
      -- metadata
      nextState: E_ProcState;
      transfer: boolean;
      blocked: boolean;
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
  case InvTagCmd:
    put "InvTagCmd";
  case TrCmd:
    put "TrCmd";
  case SetTagCmd:
    put "SetTagCmd";
  case SetTagWakeupCmd:
    put "SetTagWakeupCmd";
  case WritebackCmd:
    put "WritebackCmd";
  case DataCmdCce:
    put "DataCmdCce";
  case DataCmdLce:
    put "DataCmdLce";
  case InvTagAck:
    put "InvTagAck";
  case CohAck:
    put "CohAck";
  case TrAck:
    put "TrAck";
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
        Send(InvTagCmd, n, HomeType, VC1, UNDEFINED, false, UNDEFINED, UNDEFINED);
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

  -- H_M, H_S, H_I, H_E, H_IA, H_CA, H_TA, H_TWB

  switch HomeNode.state
  -- Stable states

  -- invalid in directory - immediately reply with current data and set tag
  case H_I:
    assert(cnt = 0) "home invalid, but sharers count not 0";
    switch msg.mtype
      case LceRdReq:
        HomeNode.state := H_CA;
        HomeNode.ack := 0; -- invalid, no acks required
        HomeNode.upgrade := false; -- not an upgrade
        HomeNode.transfer := false; -- not a transfer
        HomeNode.nextState := P_E; -- LCE will go to P_E
        HomeNode.nextHomeState := H_E; -- HomeNode will go to H_E after receiving coh ack
        HomeNode.reqLce := msg.src;
        undefine HomeNode.trLce;

        -- send commands
        --put "sending data cmd cce and set tag cmd from H_I\n";
        Send(DataCmdCce, msg.src, HomeType, VC2, HomeNode.val, false, UNDEFINED, UNDEFINED);
        Send(SetTagCmd, msg.src, HomeType, VC1, UNDEFINED, false, UNDEFINED, P_E);

      case LceWrReq:
        HomeNode.state := H_CA;
        HomeNode.ack := 0; -- invalid, no acks required
        HomeNode.upgrade := false; -- not an upgrade
        HomeNode.transfer := false; -- not a transfer
        HomeNode.nextState := P_M; -- LCE will go to P_M
        HomeNode.nextHomeState := H_M; -- HomeNode will go to H_M after receiving coh ack
        HomeNode.reqLce := msg.src;
        undefine HomeNode.trLce;

        -- send commands
        --put "sending data cmd cce and set tag cmd from H_I\n";
        Send(DataCmdCce, msg.src, HomeType, VC2, HomeNode.val, false, UNDEFINED, UNDEFINED);
        Send(SetTagCmd, msg.src, HomeType, VC1, UNDEFINED, false, UNDEFINED, P_M);

      else
        ErrorUnhandledMsg(msg, HomeType);
    endswitch;

  -- block in shared in directory
  case H_S:
    switch msg.mtype
      case LceRdReq:
        HomeNode.state := H_CA;
        HomeNode.ack := 0; -- invalid, no acks required
        HomeNode.upgrade := false; -- not an upgrade
        HomeNode.transfer := false; -- not a transfer
        HomeNode.nextState := P_S; -- LCE will go to P_S
        HomeNode.nextHomeState := H_S; -- HomeNode will go to H_S after receiving coh ack
        HomeNode.reqLce := msg.src;
        undefine HomeNode.trLce;

        -- send commands
        --put "sending data cmd and set tag cmd from H_S\n";
        Send(DataCmdCce, msg.src, HomeType, VC2, HomeNode.val, false, UNDEFINED, UNDEFINED);
        Send(SetTagCmd, msg.src, HomeType, VC1, UNDEFINED, false, UNDEFINED, P_S);

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
            Send(SetTagWakeupCmd, msg.src, HomeType, VC1, UNDEFINED, false, UNDEFINED, P_M);
            HomeNode.state := H_CA;
          else
            HomeNode.state := H_IA;
          endif;
        else
          -- requestor does not have block cached, not an upgrade, all sharers will ack
          HomeNode.upgrade := false; -- not an upgrade
          HomeNode.ack := cnt;
          -- wait for acks
          HomeNode.state := H_IA;
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
    assert(cnt = 0) "home exclusive, but sharers count not 0";
    switch msg.mtype
      case LceRdReq:
        HomeNode.state := H_IA;
        -- send invalidation to owner
        --put "sending invalidations from H_E\n";
        Send(InvTagCmd, HomeNode.owner, HomeType, VC1, UNDEFINED, false, UNDEFINED, UNDEFINED);
        HomeNode.ack := 1; -- cached in E by single cache
        HomeNode.upgrade := false; -- not an upgrade
        HomeNode.transfer := true; -- transfer
        HomeNode.nextState := P_S; -- LCE will go to P_S
        HomeNode.nextHomeState := H_S; -- HomeNode will go to H_S after receiving tr ack
        HomeNode.reqLce := msg.src;
        HomeNode.trLce := HomeNode.owner;

      case LceWrReq:
        HomeNode.state := H_IA;
        -- send invalidations
        --put "sending invalidations from H_E\n";
        Send(InvTagCmd, HomeNode.owner, HomeType, VC1, UNDEFINED, false, UNDEFINED, UNDEFINED);
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
    assert(cnt = 0) "home modified, but sharers count not 0";
    switch msg.mtype
      case LceRdReq:
        HomeNode.state := H_IA;
        --put "sending invalidations from H_M\n";
        Send(InvTagCmd, HomeNode.owner, HomeType, VC1, UNDEFINED, false, UNDEFINED, UNDEFINED);
        HomeNode.ack := 1; -- cached in E by single cache
        HomeNode.upgrade := false; -- not an upgrade
        HomeNode.transfer := true; -- transfer
        HomeNode.nextState := P_S; -- LCE will go to P_S
        HomeNode.nextHomeState := H_S; -- HomeNode will go to H_S after receiving tr ack
        HomeNode.reqLce := msg.src;
        HomeNode.trLce := HomeNode.owner;

      case LceWrReq:
        HomeNode.state := H_IA;
        --put "sending invalidations from H_M\n";
        Send(InvTagCmd, HomeNode.owner, HomeType, VC1, UNDEFINED, false, UNDEFINED, UNDEFINED);
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



  -- "Transient" states

  -- waiting for invalidation acks
  case H_IA:
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
            --put "sending set tag wakeup from H_IA\n";
            Send(SetTagWakeupCmd, HomeNode.reqLce, HomeType, VC1, UNDEFINED, false, UNDEFINED, P_M);
            HomeNode.state := H_CA;
          elsif (HomeNode.transfer = true)
          then
            --put "sending set tag, tr, and writeback from H_IA\n";
            Send(SetTagCmd, HomeNode.reqLce, HomeType, VC1, UNDEFINED, false, UNDEFINED, HomeNode.nextState);
            Send(TrCmd, HomeNode.trLce, HomeType, VC1, UNDEFINED, false, HomeNode.reqLce, UNDEFINED);
            Send(WritebackCmd, HomeNode.trLce, HomeType, VC1, UNDEFINED, false, UNDEFINED, UNDEFINED);
            HomeNode.state := H_TWB;
          else
            --put "sending set tag and data cmd from H_IA\n";
            Send(DataCmdCce, HomeNode.reqLce, HomeType, VC2, HomeNode.val, false, UNDEFINED, UNDEFINED);
            Send(SetTagCmd, HomeNode.reqLce, HomeType, VC1, UNDEFINED, false, UNDEFINED, HomeNode.nextState);
            HomeNode.state := H_CA;
          endif;
        endif;
      else
        ErrorUnhandledMsg(msg, HomeType);
    endswitch;

  -- waiting for coherence ack
  case H_CA:
    switch msg.mtype
      case LceRdReq, LceWrReq:
        msg_processed := false;
      case CohAck:
        HomeNode.state := HomeNode.nextHomeState;
        assert(msg.src = HomeNode.reqLce) "Coh Ack arrived from other than requesting LCE";
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

  -- waiting for transfer ack
  case H_TA:
    switch msg.mtype
      case LceRdReq, LceWrReq:
        msg_processed := false;
      case TrAck:
        HomeNode.state := HomeNode.nextHomeState;
        HomeNode.transfer := false;
        assert(msg.src = HomeNode.reqLce) "Tr Ack arrived from other than requesting LCE";
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

  -- waiting for writeback from transfer LCE
  case H_TWB:
    switch msg.mtype
      case LceRdReq, LceWrReq, TrAck:
        msg_processed := false;
      case LceDataResp:
        HomeNode.state := H_TA;
        HomeNode.val := msg.val;
      case LceDataRespNull:
        HomeNode.state := H_TA;
        HomeNode.val := msg.val;
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
  alias pns:Procs[p].nextState do
  alias ptr:Procs[p].transfer do
  alias pb:Procs[p].blocked do

-- Processor states
-- P_I, P_ID, P_I_DT, P_I_D, P_I_T, P_S, P_S_U, P_E, P_M
-- Send(mtype, dst, src, vc, val, upgrade, replace, lruDirty, target, nextState)

  switch ps
    -- invalid, block is clean
    case P_I:
      switch msg.mtype
        case TrCmd:
          --put "sending data cmd lce from P_I\n";
          Send(DataCmdLce, msg.target, p, VC2, pv, false, UNDEFINED, UNDEFINED);
          -- stay in invalid
        case WritebackCmd:
          --put "sending null wb resp from P_I\n";
          Send(LceDataRespNull, msg.src, p, VC4, pv, false, UNDEFINED, UNDEFINED);
          --undefine pv;
          -- stay in invalid
        else
          ErrorUnhandledMsg(msg, p);
      endswitch;

    -- invalid, but still dirty (waiting for writeback)
    case P_ID:
      switch msg.mtype
        case TrCmd:
          --put "sending data cmd lce from P_ID\n";
          Send(DataCmdLce, msg.target, p, VC2, pv, false, UNDEFINED, UNDEFINED);
          -- stay in invalid dirty, transfer is not a writeback
        case WritebackCmd:
          --put "sending wb resp from P_ID\n";
          Send(LceDataResp, msg.src, p, VC4, pv, false, UNDEFINED, UNDEFINED);
          -- TODO: when in P_ID, becasuse no ordering on networks modeled here, could receive writbeack before transfer, thus transfer would send
          -- invalid (UNDEFINED) data
          --undefine pv;
          -- go to invalid, no longer dirty
          ps := P_I;
        else
          ErrorUnhandledMsg(msg, p);
      endswitch;

    -- invalid, waiting for tag or data
    case P_I_DT:
      switch msg.mtype
        case TrCmd:
          --put "sending data cmd lce from P_I_DT\n";
          Send(DataCmdLce, msg.target, p, VC2, pv, false, UNDEFINED, UNDEFINED);
          -- stay in current state
        case WritebackCmd:
          --put "sending null wb resp from P_I_DT\n";
          Send(LceDataRespNull, msg.src, p, VC4, pv, false, UNDEFINED, UNDEFINED);
          --undefine pv;
          -- stay in current state
        case SetTagCmd:
          -- record next state
          pns := msg.nextState;
          ps := P_I_D;
        case DataCmdCce:
          -- record data value received
          pv := msg.val;
          ps := P_I_T;
        case DataCmdLce:
          -- record data value received
          ptr := true;
          pv := msg.val;
          ps := P_I_T;
        else
          ErrorUnhandledMsg(msg, p);
      endswitch;

    -- invalid, waiting for data
    case P_I_D:
      switch msg.mtype
        case DataCmdCce:
          --put "sending coh ack from P_I_D\n";
          Send(CohAck, msg.src, p, VC3, UNDEFINED, false, UNDEFINED, UNDEFINED);
          -- next state was provided by set tag command already received
          ps := pns;
          pv := msg.val;
          pb := false;
        case DataCmdLce:
          --put "sending tr ack from P_I_D\n";
          Send(TrAck, HomeType, p, VC3, UNDEFINED, false, UNDEFINED, UNDEFINED);
          -- next state was provided by set tag command already received
          ps := pns;
          pv := msg.val;
          pb := false;
          --put "received val: "; put msg.val; put " HomeNode.val is: "; put HomeNode.val; put "LastWrite is: "; put LastWrite; put "\n";
        else
          ErrorUnhandledMsg(msg, p);
      endswitch;

    -- invalid, waiting for tag
    case P_I_T:
      switch msg.mtype
        case SetTagCmd:
          if (ptr)
          then
            --put "sending tr ack from P_I_T\n";
            Send(TrAck, msg.src, p, VC3, UNDEFINED, false, UNDEFINED, UNDEFINED);
            ptr := false;
            pb := false;
          else
            --put "sending coh ack from P_I_T\n";
            Send(CohAck, msg.src, p, VC3, UNDEFINED, false, UNDEFINED, UNDEFINED);
            pb := false;
          endif;
          ps := msg.nextState;
        else
          ErrorUnhandledMsg(msg, p);
      endswitch;

    -- shared
    case P_S:
    switch msg.mtype
      case InvTagCmd:
        --put "sending inv tag ack from P_S\n";
        Send(InvTagAck, msg.src, p, VC3, UNDEFINED, false, UNDEFINED, UNDEFINED);
        ps := P_I;
      else
        ErrorUnhandledMsg(msg, p);
    endswitch;

    -- shared, attempting to upgrade to modified
    case P_S_U:
    switch msg.mtype
      case InvTagCmd:
        --put "sending inv tag ack from P_S_U\n";
        Send(InvTagAck, msg.src, p, VC3, UNDEFINED, false, UNDEFINED, UNDEFINED);
        ps := P_I_DT;
      case SetTagWakeupCmd:
        --put "sending coh ack from P_S_U\n";
        Send(CohAck, msg.src, p, VC3, UNDEFINED, false, UNDEFINED, UNDEFINED);
        ps := P_M;
        pb := false;
      else
        ErrorUnhandledMsg(msg, p);
    endswitch;

    -- exclusive
    case P_E:
    switch msg.mtype
      case InvTagCmd:
        --put "sending inv tag ack from P_E\n";
        Send(InvTagAck, msg.src, p, VC3, UNDEFINED, false, UNDEFINED, UNDEFINED);
        -- block is clean, so go to invalid state
        ps := P_I;
      else
        ErrorUnhandledMsg(msg, p);
    endswitch;

    -- modified
    case P_M:
    switch msg.mtype
      case InvTagCmd:
        --put "sending inv tag ack from P_M\n";
        Send(InvTagAck, msg.src, p, VC3, UNDEFINED, false, UNDEFINED, UNDEFINED);
        -- block is dirty, go to invalid dirty state
        ps := P_ID;
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
  endalias;
  endalias;
  endalias;
End;

----------------------------------------------------------------------
-- Rules
----------------------------------------------------------------------

-- Processor states
-- P_M, P_S, P_I, P_E, P_I_DT, P_I_D, P_I_T, P_ID, P_S_U

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
    endrule;
    endruleset;

    ---------------------------------------------------------------
    -- load or stores with no replacement
    ---------------------------------------------------------------
    rule "read request"
      (p.state = P_I & p.blocked = false)
        ==>
      --put "LceRdReq from Proc "; put n; put " in state "; put p.state;
      Send(LceRdReq, HomeType, n, VC0, UNDEFINED, false, UNDEFINED, UNDEFINED);
      p.state := P_I_DT;
      p.blocked := true;
    endrule;

    rule "write request"
      (p.state = P_I & p.blocked = false)
        ==>
      --put "LceWrReq from Proc "; put n; put " in state "; put p.state;
      Send(LceWrReq, HomeType, n, VC0, UNDEFINED, false, UNDEFINED, UNDEFINED);
      p.state := P_I_DT;
      p.blocked := true;
    endrule;

    rule "upgrade request"
      (p.state = P_S & p.blocked = false)
        ==>
      --put "LceWrReq from Proc "; put n; put " in state "; put p.state;
      Send(LceWrReq, HomeType, n, VC0, UNDEFINED, true, UNDEFINED, UNDEFINED);
      p.state := P_S_U;
      p.blocked := true;
    endrule;

  endalias;
endruleset;

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
    undefine Procs[i].nextState;
    Procs[i].transfer := false;
    Procs[i].blocked := false;
  endfor;

  -- network initialization
  undefine Net;
endstartstate;

----------------------------------------------------------------------
-- Invariants
----------------------------------------------------------------------

-- Directory Invariants

invariant "Invalid implies empty owner"
  HomeNode.state = H_I
    ->
  IsUndefined(HomeNode.owner);

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

invariant "Value in memory must match the value of the last write in Invalid state"
  HomeNode.state = H_I
    ->
  HomeNode.val = LastWrite;

invariant "Home in Shared state implies Proc in Invalid or Shared"
  Forall n : Proc do
    HomeNode.state = H_S
      ->
      (Procs[n].state = P_S | Procs[n].state = P_S_U | Procs[n].state = P_I | Procs[n].state = P_I_DT | Procs[n].state = P_I_D
       | Procs[n].state = P_I_T | Procs[n].state = P_ID)
  end;

invariant "Values in shared state must match last write"
  Forall n : Proc do
    Procs[n].state = P_S
      ->
      Procs[n].val = LastWrite --LastWrite is updated whenever a new value is created
  end;

-- Not true in our system, CCE invalidates blocks and then requests writeback, so a block may be invalid and
-- still have a valid data value
--invariant "value is undefined while invalid"
--  Forall n : Proc do
--    Procs[n].state = P_I
--      ->
--      IsUndefined(Procs[n].val)
--  end;


invariant "Exclusive has a clean copy of data"
  Forall n : Proc do
    HomeNode.state = H_E & Procs[n].state = P_E
      ->
    HomeNode.val = Procs[n].val
  end;

--TODO: is there any variation of these rules that hold true?
--invariant "values in memory matches value of last write, when shared or invalid"
--  Forall n : Proc do
--    HomeNode.state = H_S | HomeNode.state = H_I
--      ->
--    HomeNode.val = LastWrite
--  end;

--invariant "values in memory matches value of last write, when shared"
--  Forall n : Proc do
--    HomeNode.state = H_S
--      ->
--    HomeNode.val = LastWrite
--  end;

invariant "values in shared state match memory"
  Forall n : Proc do
    HomeNode.state = H_S & Procs[n].state = P_S
      ->
    HomeNode.val = Procs[n].val
  end;

