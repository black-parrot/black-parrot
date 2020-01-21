-- Meghan Cowan (cowanmeg)
-- four-state, three-hop, MESI protocol

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------
const
  ProcCount: CFG_PROCS;  -- number processors
  ValueCount: 2;         -- number of data values.
  VC0: 0;                -- low priority
  VC1: 1;
  VC2: 2;
  QMax: 2;
  NumVCs: VC2 - VC0 + 1;
  NetMax: ProcCount+1;
 

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------
type
  Proc: scalarset(ProcCount);   -- unordered range of processors
  Value: scalarset(ValueCount); -- arbitrary values for tracking coherence
  Home: enum { HomeType };      -- need enumeration for IsMember calls
  Node: union { Home , Proc };
    Count: (1-ProcCount)..(ProcCount-1); -- integer range of number of sharers  

  VCType: VC0..NumVCs-1;

  MessageType: enum { GetS, -- req to dir for shared copy
                      GetM, -- req to dir for an exclsuive copy
                      Fwd_GetS, -- fwd req to owner for shared copy
                      Fwd_GetM, -- fwd req to owner for exclusive copy
                      DataDir, -- resp with value of line and num of inv-acks
                      DataCache, -- resp with data and serviced by a cache
                      Fwd_GetM_Ack, --fwd req serviced by remote proc                             
                      DataExclusive , -- data serviced by dir exclusive
                      Inv, -- invalidation request
                      Inv_Ack, -- acknowledgement of invalidation

                      PutS, -- notification of evicting a shared copy
                      PutM, -- notification of evicting modified copy + data
                      PutE, -- notification of evicting exclsuive copy (not modified)
                      PutAck -- acknowledgement of evicting

                      };

  Message:
    Record
      mtype: MessageType;
      src: Node;
      -- do not need a destination for verification; the destination is indicated by which array entry in the Net the message is placed
      vc: VCType;
      val: Value;
            ack: Count;
    End;

  HomeState:
    Record
      state: enum { H_M, H_S, H_I, H_E,         --stable states
                    HT_S_D, HT_M_A };           --transient states
      owner: Node;  
      sharers: multiset [ProcCount] of Node;  
      val: Value; 
    End;

  ProcState:
    Record
      state: enum { P_M, P_S, P_I, P_E,
                  PT_IS_D, PT_IM_AD, PT_IM_A, PT_SM_AD, PT_SM_A, PT_MI_A, PT_SI_A, PT_II_A, PT_EI_A
                  };
      val: Value;
            ack: Count; -- metadata, number of acknowledgements too wait for
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
Procedure Send(mtype:MessageType;
           dst:Node;
           src:Node;
         vc:VCType;
         val:Value;
                 ack:Count;
         );
var msg:Message;
Begin
  Assert (MultiSetCount(i:Net[dst], true) < NetMax) "Too many messages";
  msg.mtype := mtype;
  msg.src   := src;
  msg.vc    := vc;
  msg.val   := val;
    msg.ack     := ack;
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
        Send(Inv, n, rqst, VC1, UNDEFINED, UNDEFINED);
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

  -- compiler barfs if we put this inside a switch, so it is useful to
  -- pre-calculate the sharer count here
  cnt := MultiSetCount(i:HomeNode.sharers, true);


  -- default to 'processing' message.  set to false otherwise
  msg_processed := true;

  switch HomeNode.state
  case H_M:
    switch msg.mtype
      case GetS:
        Send(Fwd_GetS, HomeNode.owner, msg.src, VC1, UNDEFINED, UNDEFINED);
        AddToSharersList(HomeNode.owner);
        AddToSharersList(msg.src);
        undefine HomeNode.owner;
        HomeNode.state := HT_S_D;
      case GetM:
        Send(Fwd_GetM, HomeNode.owner, msg.src, VC1, UNDEFINED, UNDEFINED);
        HomeNode.owner := msg.src;
        HomeNode.state := HT_M_A;
      case PutM:
        if(msg.src = HomeNode.owner)
        then
            HomeNode.val := msg.val;
            HomeNode.state := H_I;
            undefine HomeNode.owner;
        endif;
        Send(PutAck, msg.src, HomeType, VC1, UNDEFINED, UNDEFINED);
      case PutS, PutE:
        Send(PutAck, msg.src, HomeType, VC1, UNDEFINED, UNDEFINED);
      else
        ErrorUnhandledMsg(msg, HomeType);
    endswitch;

  case H_S:
    switch msg.mtype
      case GetS:
        AddToSharersList(msg.src);
        Send(DataDir, msg.src, HomeType, VC2, HomeNode.val, UNDEFINED);
      case GetM:
        HomeNode.owner := msg.src;
        if (IsSharer(msg.src))
        then
          cnt := cnt - 1;
        endif;
        SendInvReqToSharers(msg.src);
        Send(DataDir, msg.src, HomeType, VC2, HomeNode.val, cnt);
        undefine HomeNode.sharers;
        HomeNode.state := HT_M_A;
      case PutS:
        if (cnt = 1 & IsSharer(msg.src))
        then
            HomeNode.state := H_I;
        endif;              
        RemoveFromSharersList(msg.src);
        Send(PutAck, msg.src, HomeType, VC1, UNDEFINED, UNDEFINED);
      case PutM, PutE:
        RemoveFromSharersList(msg.src);
        Send(PutAck, msg.src, HomeType, VC1, UNDEFINED, UNDEFINED);
      else
        ErrorUnhandledMsg(msg, HomeType);   
    endswitch;

  case H_I:
    switch msg.mtype
      case GetS:
        HomeNode.owner := msg.src;
        HomeNode.state := H_E;
        Send(DataExclusive, msg.src, HomeType, VC2, HomeNode.val, UNDEFINED);
      case GetM:
        HomeNode.owner := msg.src;
        HomeNode.state := H_M;
        Send(DataExclusive, msg.src, HomeType, VC2, HomeNode.val, UNDEFINED);
      case PutS, PutM, PutE:
        Send(PutAck, msg.src, HomeType, VC1, UNDEFINED, UNDEFINED);
      else
        ErrorUnhandledMsg(msg, HomeType);
    endswitch;

    case H_E:
      switch msg.mtype
        case GetS:
          Send(Fwd_GetS, HomeNode.owner, msg.src, VC1, UNDEFINED, UNDEFINED);
          AddToSharersList(msg.src);
          AddToSharersList(HomeNode.owner);
          undefine HomeNode.owner;
          HomeNode.state := HT_S_D;
        case GetM:
          Send(Fwd_GetM, HomeNode.owner, msg.src, VC1, UNDEFINED, UNDEFINED);
          HomeNode.owner := msg.src;
          HomeNode.state := HT_M_A;
        case PutS:
          Send(PutAck, msg.src, HomeType, VC1, UNDEFINED, UNDEFINED);
        case PutM:
          Send(PutAck, msg.src, HomeType, VC1, UNDEFINED, UNDEFINED);
          if msg.src = HomeNode.owner
          then
            undefine HomeNode.owner;
            HomeNode.val := msg.val;
            HomeNode.state := H_I;  
          endif;
        case PutE:
          Send(PutAck, msg.src, HomeType, VC1, UNDEFINED, UNDEFINED);
          if msg.src = HomeNode.owner
          then
            undefine HomeNode.owner;
            HomeNode.state := H_I;
          endif;
        else
          ErrorUnhandledMsg(msg, HomeType);
      endswitch;

    case HT_S_D:
      switch msg.mtype
        case GetS, GetM, PutM, PutS, PutE:
          msg_processed := false;
        case DataCache:
          HomeNode.val := msg.val;
          HomeNode.state := H_S;
        else
          ErrorUnhandledMsg(msg, HomeType);
      endswitch;

    case HT_M_A:
      switch msg.mtype
        case GetS, GetM, PutM, PutS, PutE:
          msg_processed := false;
        case Fwd_GetM_Ack:
          HomeNode.state := H_M;
        else
          ErrorUnhandledMsg(msg, HomeType);
      endswitch;

    else
        ErrorUnhandledState();
  endswitch;
End;


Procedure ProcReceive(msg:Message; p:Proc);
Begin
 -- put "Receiving "; put msg.mtype; put " on VC"; put msg.vc; 
 -- put " at proc "; put p; put " in state "; put Procs[p].state;

  -- default to 'processing' message.  set to false otherwise
  msg_processed := true;

  alias ps:Procs[p].state do
  alias pv:Procs[p].val do
    alias pa:Procs[p].ack do

  switch ps
    case P_I:
      switch msg.mtype
        case Inv:
          Send(Inv_Ack, msg.src, p, VC2, UNDEFINED, UNDEFINED);
        else
          ErrorUnhandledMsg(msg, p);
      endswitch;

    case P_M:
      switch msg.mtype
        case Fwd_GetS:
          Send(DataCache, msg.src, p, VC2, pv, UNDEFINED);
          Send(DataCache, HomeType, p, VC2, pv, UNDEFINED);
          ps := P_S;
        case Fwd_GetM:
          Send(DataCache, msg.src, p, VC2, pv, UNDEFINED);
          Send(Fwd_GetM_Ack, HomeType, p, VC2, UNDEFINED, UNDEFINED);
          ps := P_I;
          undefine pv;
        else
          ErrorUnhandledMsg(msg, p);
      endswitch;

    case P_S:
    switch msg.mtype
      case Inv:
        Send(Inv_Ack, msg.src, p, VC2, UNDEFINED, UNDEFINED);
        ps := P_I;
        undefine pv;
      else
        ErrorUnhandledMsg(msg, p);
    endswitch;

    case P_E:
    switch msg.mtype
      case Fwd_GetS:
        Send(DataCache, msg.src, p, VC2, pv, UNDEFINED);
        Send(DataCache, HomeType, p, VC2, pv, UNDEFINED);
        ps := P_S;
      case Fwd_GetM:
        Send(DataCache, msg.src, p, VC2, pv, UNDEFINED);
        Send(Fwd_GetM_Ack, HomeType, p, VC2, UNDEFINED, UNDEFINED);
        undefine pv;
        ps := P_I;
      else
        ErrorUnhandledMsg(msg, p);
    endswitch;

    case PT_IS_D:
      switch msg.mtype
        case Fwd_GetS, Fwd_GetM, Inv:
          msg_processed := false;
        case DataDir, DataCache:
          pv := msg.val;
          ps := P_S;
        case DataExclusive:
          pv := msg.val;
          ps := P_E;
        else
          ErrorUnhandledMsg(msg, p);
      endswitch;

    case PT_IM_AD:
      switch msg.mtype
        case Fwd_GetS, Fwd_GetM:
          msg_processed := false;
        case Inv:
          Send(Inv_Ack, msg.src, p, VC2, UNDEFINED, UNDEFINED);
        case DataCache, DataExclusive:
          pv := msg.val;
          ps := P_M;
        case DataDir:
          pv := msg.val;
          pa := pa + msg.ack;
          if (pa = 0)
          then
            ps := P_M;
            Send(Fwd_GetM_Ack, HomeType, p, VC2, UNDEFINED, UNDEFINED);
          else
            ps := PT_IM_A;
          endif;
        case Inv_Ack:
            pa := pa - 1;
        else
          ErrorUnhandledMsg(msg, p);
      endswitch;

    case PT_IM_A:
        switch msg.mtype
            case Fwd_GetS:
                msg_processed := false;
            case Fwd_GetM:
                msg_processed := false;
            case Inv_Ack:
                pa := pa - 1;
                if (pa = 0)
                then
                    ps := P_M;
                    Send(Fwd_GetM_Ack, HomeType, p, VC2, UNDEFINED, UNDEFINED);
                endif
            else
                ErrorUnhandledMsg(msg, p);
        endswitch;

    case PT_SM_AD:
      switch msg.mtype
        case Fwd_GetS, Fwd_GetM:
          msg_processed := false;
        case Inv:
          Send(Inv_Ack, msg.src, p, VC2, UNDEFINED, UNDEFINED);
          ps := PT_IM_AD;
        case DataCache:
          ps := P_M;
        case DataDir:
          pa := pa + msg.ack;
          if (pa = 0)
          then 
            ps := P_M;
            Send(Fwd_GetM_Ack, HomeType, p, VC2, UNDEFINED, UNDEFINED);
          else
            ps := PT_SM_A;
          endif;
        case Inv_Ack:
          pa := pa - 1;
        else
          ErrorUnhandledMsg(msg, p);
      endswitch;

    case PT_SM_A:
      switch msg.mtype
      case Fwd_GetS, Fwd_GetM:
        msg_processed := false;
      case Inv_Ack:
        pa := pa -1;
        if (pa = 0)
        then
          ps := P_M;
          Send(Fwd_GetM_Ack, HomeType, p, VC2, UNDEFINED, UNDEFINED);
        endif;
      else
        ErrorUnhandledMsg(msg, p);
      endswitch;

    case PT_MI_A:
      switch msg.mtype
        case Fwd_GetS:
          Send(DataCache, msg.src, p, VC2, pv, UNDEFINED);
          Send(DataCache, HomeType, p, VC2, pv, UNDEFINED);
          ps := PT_SI_A;
        case Fwd_GetM:
          Send(DataCache, msg.src, p, VC2, pv, UNDEFINED);
          Send(Fwd_GetM_Ack, HomeType, p, VC2, UNDEFINED, UNDEFINED);
          ps := PT_II_A;
        case PutAck:
          ps := P_I;
          undefine pv;
        else
          ErrorUnhandledMsg(msg, p);
      endswitch;

    case PT_SI_A:
      switch msg.mtype
        case Inv:
          Send(Inv_Ack, msg.src, p, VC2, UNDEFINED, UNDEFINED);
          ps := PT_II_A;
        case PutAck:
          ps := P_I;
          undefine pv;
        else
          ErrorUnhandledMsg(msg, p);
      endswitch;

    case PT_EI_A:
      switch msg.mtype
        case Fwd_GetS:
          Send(DataCache, msg.src, p, VC2, pv, UNDEFINED);
          Send(DataCache, HomeType, p, VC2, pv, UNDEFINED);
          ps := PT_SI_A;
        case Fwd_GetM:
          Send(DataCache, msg.src, p, VC2, pv, UNDEFINED);
          Send(Fwd_GetM_Ack, HomeType, p, VC2, UNDEFINED, UNDEFINED);
          ps := PT_II_A;
        case PutAck:
          ps:= P_I;
          undefine pv;
        else
          ErrorUnhandledMsg(msg, p);
      endswitch;

    case PT_II_A:
      if (msg.mtype = PutAck)
      then
        ps := P_I;  
        undefine pv;
      else
        ErrorUnhandledMsg(msg, p);
      endif;
    ----------------------------
  -- Error catch
  ----------------------------
  else
    ErrorUnhandledState();

  endswitch;

  endalias;  
  endalias;
  endalias;
End;

----------------------------------------------------------------------
-- Rules
----------------------------------------------------------------------

-- Processor actions (affecting coherency)

ruleset n:Proc Do
  alias p:Procs[n] Do

    ruleset v:Value Do
    rule "store new value"
     (p.state = P_M)
        ==>
           p.val := v;      
           LastWrite := v;  --We use LastWrite to sanity check that reads receive the value of the last write
    endrule;
    endruleset;

    rule "read request"
      p.state = P_I 
    ==>
      Send(GetS, HomeType, n, VC0, UNDEFINED, UNDEFINED);
      p.state := PT_IS_D;
    endrule;

    rule "write request"
        p.state = P_I
    ==>
        Send(GetM, HomeType, n, VC0, UNDEFINED, UNDEFINED);
        p.state := PT_IM_AD;
    endrule;

    rule "upgrade request"
        p.state = P_S
    ==>
        Send(GetM, HomeType, n, VC0, UNDEFINED, UNDEFINED);
        p.state := PT_SM_AD;
    endrule;

  rule "silent upgrade"
        p.state = P_E
    ==>
        p.state := P_M;
    endrule;

  rule "evict shared"
      (p.state = P_S)
    ==>
      Send(PutS, HomeType, n, VC0, UNDEFINED, UNDEFINED); 
      p.state := PT_SI_A;
      undefine p.val;
  endrule;

    rule "evict modified"
        (p.state = P_M)
    ==>
        Send(PutM, HomeType, n, VC0, p.val, UNDEFINED);
        p.state := PT_MI_A;
    endrule;
        
  rule "evict exclusive"
        p.state = P_E
    ==>
        Send(PutE, HomeType, n, VC0, UNDEFINED, UNDEFINED);
        p.state := PT_EI_A;
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

    For v:Value do
  -- home node initialization
  HomeNode.state := H_I;
  undefine HomeNode.owner;
  HomeNode.val := v;
    endfor;
    LastWrite := HomeNode.val;
  
  -- processor initialization
  for i:Proc do
    Procs[i].state := P_I;
        Procs[i].ack := 0;
    undefine Procs[i].val;
  endfor;

  -- network initialization
  undefine Net;
endstartstate;

----------------------------------------------------------------------
-- Invariants
----------------------------------------------------------------------

invariant "Invalid implies empty owner"
  HomeNode.state = H_I
    ->
      IsUndefined(HomeNode.owner);

invariant "values in shared state match last write"
  Forall n : Proc Do    
     Procs[n].state = P_S
    ->
            Procs[n].val = LastWrite --LastWrite is updated whenever a new value is created 
    end;
    
invariant "value is undefined while invalid"
  Forall n : Proc Do    
     Procs[n].state = P_I
    ->
            IsUndefined(Procs[n].val)
    end;
    

invariant "modified or exclusive implies empty sharers list"
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

invariant "Exclusive has a clean copy of data"
  Forall n : Proc Do    
     HomeNode.state = H_E & Procs[n].state = P_E
    ->
            HomeNode.val = Procs[n].val
    end;

invariant "values in memory matches value of last write, when shared or invalid"
  Forall n : Proc Do    
     HomeNode.state = H_S | HomeNode.state = H_I
    ->
            HomeNode.val = LastWrite
    end;

invariant "values in shared state match memory"
  Forall n : Proc Do    
     HomeNode.state = H_S & Procs[n].state = P_S
    ->
            HomeNode.val = Procs[n].val
    end;

