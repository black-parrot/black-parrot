
-- Three-state 3-hop MSI protocol

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------
const
  ProcCount: CFG_PROCS;  -- number processors
  ValueCount:   2;       -- number of data values.
  VC0: 0;                -- low priority
  VC1: 1;								 -- medium priority
  VC2: 2;								 -- high priority
  VC3: 3;								 -- very high priority
  QMax: 2;
  NumVCs: VC3 - VC0 + 1;
  NetMax: ProcCount+2;
  

----------------------------------------------------------------------
-- Types
----------------------------------------------------------------------
type
  Proc: scalarset(ProcCount);   -- unordered range of processors
  Value: scalarset(ValueCount); -- arbitrary values for tracking coherence
  Home: enum { HomeType };      -- need enumeration for IsMember calls
  Node: union { Home , Proc };

	CntrType: (0-ProcCount+1)..(ProcCount-1);

	AckType: -1..ProcCount-1;			-- -1 should be ignored, other values indicate number of expected ACKs during invalidation

  VCType: VC0..NumVCs-1;

  MessageType: enum { GetS,         	-- request for data / exclusivity
											GetM,						-- get data with permission to modify
                      Data, 					-- data reply with or without acks
                              
											FwdGetS,
											FwdGetM,
											PutS,						-- Clean evict notification
								      PutM,           -- writeback request (w/ data)
								      PutAck,         -- writeback ack 
								      PutAckWait,     -- writeback ack but wait until a FwdGet* reaches which is stale
                           
                      Inv,						-- Request & invalidate a valid copy
											InvAck					-- Ack for invalidation
                    };

  Message:
    Record
      mtype: MessageType;
      src: Node;
      -- do not need a destination for verification; the destination is indicated by which array entry in the Net the message is placed
      vc: VCType;
      val: Value;
			acks: AckType;
			rplyTo: Node;				-- Node to send InvAck to in case of Inv message. If don't care, send anything.
    End;

  HomeState:
    Record
      state: enum { H_S, H_I, H_M, 					--stable states
      							H_SD, H_MA, H_MD }; 		--transient states during recall
      owner: Node;	
      sharers: multiset [ProcCount] of Node;    --No need for sharers in this protocol, but this is a good way to represent them
      val: Value; 
			ackCntr: CntrType;
    End;

  ProcState:
    Record
      state: enum { P_S, P_I, P_M,																									-- Stable states
                  	P_SMA, P_IMA, P_ISD, P_MIA, P_IMAD, P_SMAD, P_SIA, P_IIA, P_IF	-- Transient states
                  };
      val: Value;
			ackCntr: CntrType;
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
				 numAcks:AckType;
				 rplyTo:Node;
         );
var msg:Message;
Begin
  Assert (MultiSetCount(i:Net[dst], true) < NetMax) "Too many messages";  -- where "i" is a new local variable, which counts the number of elements satisfying the predicate
  msg.mtype 	:= mtype;
  msg.src   	:= src;
  msg.vc    	:= vc;
  msg.val   	:= val;
	msg.acks		:= numAcks; 
	msg.rplyTo := rplyTo;
  MultiSetAdd(msg, Net[dst]);
End;

Procedure ErrorUnhandledMsg(msg:Message; n:Node);
Begin
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

Procedure ClearSharersList();
Begin
	Assert (MultiSetCount(i:HomeNode.sharers, true) > 0) "Trying to clear an empty sharer's list!";
  undefine HomeNode.sharers;
End;

-- Sends a message to all sharers except req --
Procedure SendInvReqToSharers(rqst:Node);
Begin
  for n:Node do
    if (IsMember(n, Proc) &
        MultiSetCount(i:HomeNode.sharers, HomeNode.sharers[i] = n) != 0)  -- for each node n that is a sharer
    then
      if n != rqst -- and the node n must not be the requester
      then 
        -- Send invalidation message --
				Send(Inv, n, HomeType, VC2, UNDEFINED, -1, rqst);
				--put "Sending Inv to "; put n; put ".\n";
      endif;
    endif;
  endfor;
End;

Procedure HomeReceive(msg:Message);
var cnt:0..ProcCount;  -- for counting sharers
Begin
-- Debug output may be helpful:
  --put "Receiving "; put msg.mtype; put " on VC"; put msg.vc; put " at home from "; put msg.src; put "; "; put HomeNode.state;

  -- The line below is not needed in Valid/Invalid protocol.  However, the 
  -- compiler barfs if we put this inside a switch, so it is useful to
  -- pre-calculate the sharer count here
  cnt := MultiSetCount(i:HomeNode.sharers, true);


  -- default to 'processing' message.  set to false otherwise
  msg_processed := true;

  switch HomeNode.state
	-- HomeNode in Invalid state --
  case H_I:
    switch msg.mtype
		-- Send data to req, add req to sharer's --
    case GetS:
      HomeNode.state := H_S;
			AddToSharersList(msg.src);
      Send(Data, msg.src, HomeType, VC1, HomeNode.val,0, HomeType);
			
		-- Send data to req, set owner to req --
		case GetM:
			HomeNode.state := H_M;
			HomeNode.owner := msg.src;
      Send(Data, msg.src, HomeType, VC1, HomeNode.val,0, HomeType);

		-- PutS/PutM - just ack it to subside the race (?) --
		case PutS:
			Send(PutAck, msg.src, HomeType, VC3, UNDEFINED,-1, HomeType);

		case PutM:
			Assert (msg.src != HomeNode.owner) "Put-M sender can possibly not be the owner. This is a race condition.";
			Send(PutAck, msg.src, HomeType, VC3, UNDEFINED,-1, HomeType);

		-- That's all for I --
    else
      ErrorUnhandledMsg(msg, HomeType);

    endswitch;

	-- HomeNode in Shared state --
  case H_S:
    switch msg.mtype
		-- Send data to req, add req to sharer's
    case GetS:
      HomeNode.state := H_S;
			AddToSharersList(msg.src);
      Send(Data, msg.src, HomeType, VC1, HomeNode.val,0, HomeType);

		-- Send data to req, send inv to sharers, clear sharers, set owner to req --
		case GetM:
			HomeNode.owner := msg.src;
			SendInvReqToSharers(msg.src);
			-- If req is the only sharer, go to H_M, else go to H_MA --
			if (IsSharer(msg.src))
			then
				if (cnt - 1 = 0)
				then
					Send(Data, msg.src, HomeType, VC1, HomeNode.val, 0, HomeType);
					HomeNode.state := H_M;
				else
					Send(Data, msg.src, HomeType, VC1, HomeNode.val, cnt - 1, HomeType);
					HomeNode.ackCntr := cnt - 1;
					HomeNode.state := H_MA;
				endif;
			else
				Send(Data, msg.src, HomeType, VC1, HomeNode.val, cnt, HomeType);
				HomeNode.ackCntr := cnt;
				HomeNode.state := H_MA;
			endif;
			ClearSharersList();

		case PutS:
			-- If this is the last PutS, then transition to Invalid --
			if (IsSharer(msg.src) & cnt = 1)
			then
				HomeNode.state := H_I;
			endif;
			RemoveFromSharersList(msg.src);
			Send(PutAck, msg.src, HomeType, VC3, UNDEFINED, -1, HomeType);
/*
		case PutM:
			Assert (msg.src != HomeNode.owner) "Put-M sender can possibly not be the owner. This is a race condition.";
			-- If not sharers are left after removing the owner from sharer's list, then transition to Invalid --
			if (IsSharer(msg.src) & cnt = 1)
			then
				HomeNode.state := H_I;
			endif;
			RemoveFromSharersList(msg.src);
			Send(PutAck, msg.src, HomeType, VC3, UNDEFINED, -1, HomeType);
*/
    else
      ErrorUnhandledMsg(msg, HomeType);
		
		endswitch;

	-- HomeNode in Modified state --
  case H_M:
		Assert (IsUndefined(HomeNode.owner) = false) "HomeNode has no owner, but line is in Modified state.";

    switch msg.mtype
		-- Send Fwd-GetS to owner, add req and owner to sharer's, clear owner
    case GetS:
      HomeNode.state := H_SD;
			AddToSharersList(msg.src);
			AddToSharersList(HomeNode.owner);
      Send(FwdGetS, HomeNode.owner, HomeType, VC2, UNDEFINED, -1, msg.src);
			undefine HomeNode.owner;

		case GetM:
			Send(FwdGetM, HomeNode.owner, HomeType, VC2, UNDEFINED, -1, msg.src);
			HomeNode.owner := msg.src;
			HomeNode.state := H_MD;

		case PutS:
			Send(PutAck, msg.src, HomeType, VC3, UNDEFINED, -1, HomeType);

		case PutM:
			-- This is a writeback situation --
			Send(PutAck, msg.src, HomeType, VC3, UNDEFINED, -1, HomeType);
			if (msg.src = HomeNode.owner)
			then
				HomeNode.val := msg.val;
				undefine HomeNode.owner;
				HomeNode.state := H_I;
			endif;

    else
      ErrorUnhandledMsg(msg, HomeType);

    endswitch;

	-- HomeNode waiting for data to go to Shared --
  case H_SD:
    switch msg.mtype
    case GetS:
    	msg_processed := false;
		case GetM:
			msg_processed := false;
		case PutS:
			RemoveFromSharersList(msg.src);
			Send(PutAck, msg.src, HomeType, VC3, UNDEFINED, -1, HomeType);
		case PutM:
			Assert (msg.src != HomeNode.owner) "Put-M sender can possibly not be the owner. This is a race condition.";
			RemoveFromSharersList(msg.src);
			Send(PutAckWait, msg.src, HomeType, VC3, UNDEFINED, -1, HomeType);
			HomeNode.val := msg.val;
			-- Send data to all sharers --
			for n:Node do
				if (IsSharer(n))
				then
					Send(Data, n, HomeType, VC1, HomeNode.val, 0, HomeType);
				endif;
			endfor;
			HomeNode.state := H_S;
		case Data:
			Assert (msg.acks = 0) "This is data that is snarfed from the ex-owner. It can not have acks.";
			HomeNode.val := msg.val;
			if (cnt = 0)	-- If there are no sharers left
			then
				HomeNode.state := H_I;
			else
				HomeNode.state := H_S;
			endif;
    else
      ErrorUnhandledMsg(msg, HomeType);
    endswitch;

  case H_MD:
    switch msg.mtype
    case GetS:
    	msg_processed := false;
    case GetM:
    	msg_processed := false;
		case PutS:
			Send(PutAck, msg.src, HomeType, VC3, UNDEFINED, -1, HomeType);
		case PutM:
			if (msg.src != HomeNode.owner)
			then
				Send(PutAckWait, msg.src, HomeType, VC3, UNDEFINED, -1, HomeType);
				HomeNode.val := msg.val;
				Send(Data, HomeNode.owner, HomeType, VC1, HomeNode.val, 0, HomeType);
				HomeNode.state := H_M;
			else
				msg_processed := false;
			endif;
		case Data:
			-- No need to snarf the data here --
			HomeNode.state := H_M;
		else
			ErrorUnhandledMsg(msg, HomeType);
		endswitch;

  case H_MA:
    switch msg.mtype
    case GetS:
    	msg_processed := false;
    case GetM:
    	msg_processed := false;
		case PutS:
    	msg_processed := false;
		case PutM:
			if (msg.src != HomeNode.owner)
			then
				RemoveFromSharersList(msg.src);
				Send(PutAck, msg.src, HomeType, VC3, UNDEFINED, -1, HomeType);
			else
				msg_processed := false;
			endif;
		case InvAck:
			HomeNode.ackCntr := HomeNode.ackCntr - 1;
			if (HomeNode.ackCntr = 0)
			then
      	--Send(InvAck, HomeNode.owner, HomeType, VC3, UNDEFINED, -1, HomeType);
				HomeNode.state := H_M;
			endif;
		else
			ErrorUnhandledMsg(msg, HomeType);
    endswitch;
  endswitch;
End;

Procedure ProcReceive(msg:Message; p:Proc);
Begin
  /*put "Receiving "; put msg.mtype; put " on VC"; put msg.vc; put " at proc "; put p; put "\n";
	if (msg.acks != -1)
	then
		put "Expecting "; put msg.acks; put " acks!\n";
	endif;*/

  -- default to 'processing' message.  set to false otherwise
  msg_processed := true;

  alias ps:Procs[p].state do
  alias pv:Procs[p].val do
	alias pc:Procs[p].ackCntr do

  switch ps
	-- Proc in Invalid state --
	case P_I:
		switch msg.mtype
		case Data:
		case Inv:
			-- "Yes, I have invalidated my 'copy'." --
      Send(InvAck, msg.rplyTo, p, VC3, UNDEFINED, -1, p);
      Send(InvAck, HomeType, p, VC3, UNDEFINED, -1, p);
		else
			ErrorUnhandledMsg(msg, p);
		endswitch;

	case P_ISD:
		switch msg.mtype
		case Inv:
			msg_processed := false;
		case Data:
			if (msg.acks = 0)
			then
				pv := msg.val;
				ps := P_S;
			else
				ErrorUnhandledMsg(msg, p);
			endif;
		else
			ErrorUnhandledMsg(msg, p);
		endswitch;

	case P_IMAD:
		switch msg.mtype
		case FwdGetS:
			msg_processed := false;
		case FwdGetM:
			msg_processed := false;
		case Data:
			pv := msg.val;
			if (msg.acks = 0)
			then
				-- Data came with no acks --
				ps := P_M;
			else
				-- Data came with nonzero number of acks --
				pc := pc+msg.acks;
				if (pc = 0)
				then
					ps := P_M;
				else
					ps := P_IMA;
				endif;
			endif;
		case Inv:
			msg_processed := false;
		case InvAck:
			pc := pc-1;
		else
			ErrorUnhandledMsg(msg, p);
		endswitch;

	case P_IMA:
		switch msg.mtype
		case FwdGetS:
			msg_processed := false;
		case FwdGetM:
			msg_processed := false;
		case InvAck:
			pc := pc-1;
			if (pc = 0)
			then
				ps := P_M;
			endif;
		else
			ErrorUnhandledMsg(msg, p);
		endswitch;

	-- Proc in Shared state --
  case P_S:
    switch msg.mtype
    case Inv:
      Send(InvAck, msg.rplyTo, p, VC3, UNDEFINED, -1, p);
      Send(InvAck, HomeType, p, VC3, UNDEFINED, -1, p);
      Undefine pv;
      ps := P_I;
    else
      ErrorUnhandledMsg(msg, p);
    endswitch;

  case P_SMAD:
    switch msg.mtype
		case FwdGetS:
			msg_processed := false;
		case FwdGetM:
			msg_processed := false;
    case Inv:
      Send(InvAck, msg.rplyTo, p, VC3, UNDEFINED, -1, p);
      Send(InvAck, HomeType, p, VC3, UNDEFINED, -1, p);
      Undefine pv;
      ps := P_IMAD;
		case Data:
			pv := msg.val;
			if (msg.acks = 0)
			then
				-- Data came with no acks --
				ps := P_M;
			else
				-- Data came with nonzero number of acks --
				pc := pc+msg.acks;
				if (pc = 0)
				then
					ps := P_M;
				else
					ps := P_SMA;
				endif;
			endif;
		case InvAck:
			pc := pc-1;
    else
      ErrorUnhandledMsg(msg, p);
    endswitch;

	case P_SMA:
		switch msg.mtype
		case FwdGetS:
			msg_processed := false;
		case FwdGetM:
			msg_processed := false;
		case InvAck:
			pc := pc-1;
			if (pc = 0)
			then
				ps := P_M;
			endif;
		else
			ErrorUnhandledMsg(msg, p);
		endswitch;

	-- Proc is in Modified state --
	case P_M:
		switch msg.mtype
		case FwdGetS:
      Send(Data, msg.src, p, VC2, pv, 0, p);
      Send(Data, msg.rplyTo, p, VC1, pv, 0, p);
			ps := P_S;
		case FwdGetM:
      Send(Data, msg.src, p, VC2, pv, 0, p);		-- This will not be snarfed
      Send(Data, msg.rplyTo, p, VC1, pv, 0, p);
			ps := P_I;
			undefine pv;
		else
			ErrorUnhandledMsg(msg, p);
		endswitch;

  case P_MIA:
    switch msg.mtype
		case FwdGetS:
			ps := P_SIA;
		case FwdGetM:
			ps := P_IIA;
			undefine pv;
    case PutAck:
      ps := P_I;
      undefine pv;
		case PutAckWait:
			-- Just consume the stale FwdGet* msg --
			ps := P_IF;
			undefine pv;
    else
      ErrorUnhandledMsg(msg, p);
		endswitch;

  case P_SIA:
    switch msg.mtype
		case Inv:
      Send(InvAck, msg.rplyTo, p, VC3, UNDEFINED, -1, p);
      Send(InvAck, HomeType, p, VC3, UNDEFINED, -1, p);
			ps := P_IIA;
    case PutAck:
      ps := P_I;
      undefine pv;
		case PutAckWait:
			-- Just consume the stale FwdGet* msg --
			ps := P_IF;
			undefine pv;
    else
      ErrorUnhandledMsg(msg, p);
		endswitch;

  case P_IIA:
    switch msg.mtype
    case PutAck:
      ps := P_I;
      undefine pv;
		case PutAckWait:
			-- Just consume the stale FwdGet* msg --
			ps := P_IF;
			undefine pv;
    else
      ErrorUnhandledMsg(msg, p);
		endswitch;

	-- This state is created to just consume a stale FwdGetS or FwdGetM msg --
	case P_IF:
		switch msg.mtype
		case FwdGetS:
			ps := P_I;
		case FwdGetM:
			ps := P_I;
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
End;

----------------------------------------------------------------------
-- Rules
----------------------------------------------------------------------

-- Processor actions (affecting coherency)

ruleset n:Proc Do
  alias p:Procs[n] Do

	-- I state --
  rule "Processor load in I"
    (p.state = P_I)
  ==>
    Send(GetS, HomeType, n, VC0, UNDEFINED,-1, n);
    p.state := P_ISD;
  endrule;

	rule "Processor store in I"
	 	(p.state = P_I)
	==>
		Send(GetM, HomeType, n, VC0, UNDEFINED,-1, n);
		p.state := P_IMAD;
	endrule;

	-- S state --
	rule "Processor store in S"
	 	(p.state = P_S)
	==>
		Send(GetM, HomeType, n, VC0, UNDEFINED,-1, n); 
		p.state := P_SMAD;
	endrule;

	rule "Processor evict in S"
		(p.state = P_S)
  ==>
		Send(PutS, HomeType, n, VC1, UNDEFINED,-1, n);	-- Shouldn't have to send the data because HomeNode should already have it
		p.state := P_SIA;
	endrule;

	-- M state --
	ruleset v:Value Do
  	rule "Processor store in M"
   	 (p.state = P_M)
    	==>
 		   p.val := v;      
 		   LastWrite := v;  --We use LastWrite to sanity check that reads receive the value of the last write
  	endrule;
	endruleset;

  rule "Processor evict in M"
    (p.state = P_M)
  ==>
    Send(PutM, HomeType, n, VC1, p.val,-1, n); 
    p.state := P_MIA;
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
	HomeNode.ackCntr := 0;
  
  -- processor initialization
  for i:Proc do
    Procs[i].state := P_I;
    undefine Procs[i].val;
		Procs[i].ackCntr := 0;
  endfor;

  -- network initialization
  undefine Net;
endstartstate;

----------------------------------------------------------------------
-- Invariants
----------------------------------------------------------------------

invariant "Invalid implies that there is no owner!"
  HomeNode.state = H_I
    ->
      IsUndefined(HomeNode.owner);

invariant "Must have an owner when home is in M!"
	HomeNode.state = H_M
		->
			!IsUndefined(HomeNode.owner);

invariant "Value in memory must match the value of the last write, in Invalid state!"
     HomeNode.state = H_I 
    ->
			HomeNode.val = LastWrite;

invariant "Processor must have the last written value in Shared state!"
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
	
-- Here are some invariants that are helpful for validating shared state.

invariant "Shared implies non-empty sharers list!"
  HomeNode.state = H_S
    ->
      MultiSetCount(i:HomeNode.sharers, true) != 0;

invariant "Modified implies empty sharers list!"
  HomeNode.state = H_M
    ->
      MultiSetCount(i:HomeNode.sharers, true) = 0;

invariant "Invalid implies empty sharer list!"
  HomeNode.state = H_I
    ->
      MultiSetCount(i:HomeNode.sharers, true) = 0;

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

