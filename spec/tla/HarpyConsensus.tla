---------------------------- MODULE HarpyConsensus ----------------------------
(***************************************************************************)
(* A TLA+ specification of Harpy's cumulative-work fork choice (MIC-70).   *)
(*                                                                         *)
(* Harpy selects the canonical tip by *most cumulative proof-of-work*, and *)
(* only ever replaces its tip with a strictly-more-work chain              *)
(* (Chain#replace_if_more_work_valid! in src/harpy/chain.cr). This spec    *)
(* models a growing block tree and that replacement rule, then checks the  *)
(* core consensus safety property: the node never reorgs to a chain with   *)
(* less cumulative work.                                                   *)
(*                                                                         *)
(* Scope: consensus fork-choice safety. Transaction/UTXO validity and the  *)
(* per-block undo log (src/harpy/state.cr) are validated by the Crystal    *)
(* test suite; this abstracts a block to (parent, work).                   *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, TLC

CONSTANT MaxBlocks            \* bound on the number of blocks (model size)

VARIABLES
  blocks,                     \* set of block ids that exist; genesis = 0
  parent,                     \* parent[b] : the block b extends
  work,                       \* work[b]   : this block's own PoW weight (>= 1)
  tip                         \* the node's currently chosen canonical tip

vars == <<blocks, parent, work, tip>>

Genesis == 0

(* Cumulative work of the chain ending at b (root is genesis). Terminates    *)
(* because every non-genesis block's parent already exists and chains root   *)
(* at genesis.                                                               *)
RECURSIVE CumWork(_)
CumWork(b) == IF b = Genesis THEN work[b] ELSE work[b] + CumWork(parent[b])

TypeOK ==
  /\ Genesis \in blocks
  /\ parent \in [blocks -> blocks]
  /\ work \in [blocks -> Nat]
  /\ \A b \in blocks : work[b] >= 1
  /\ tip \in blocks

Init ==
  /\ blocks = {Genesis}
  /\ parent = (Genesis :> Genesis)
  /\ work = (Genesis :> 1)
  /\ tip = Genesis

(* Mine a new block extending any existing block, with a small PoW weight.  *)
(* The new id is the current block count, so ids are 0 .. MaxBlocks-1.      *)
Mine ==
  /\ Cardinality(blocks) < MaxBlocks
  /\ \E p \in blocks, w \in 1..2 :
       LET nb == Cardinality(blocks) IN
         /\ blocks' = blocks \cup {nb}
         /\ parent' = [x \in blocks' |-> IF x = nb THEN p ELSE parent[x]]
         /\ work'   = [x \in blocks' |-> IF x = nb THEN w ELSE work[x]]
         /\ UNCHANGED tip

(* Fork choice: adopt a tip only if it has *strictly more* cumulative work,  *)
(* exactly mirroring replace_if_more_work_valid!.                           *)
ReplaceTip ==
  /\ \E b \in blocks :
       /\ CumWork(b) > CumWork(tip)
       /\ tip' = b
  /\ UNCHANGED <<blocks, parent, work>>

Next == Mine \/ ReplaceTip

Spec == Init /\ [][Next]_vars /\ WF_vars(ReplaceTip)

(***************************************************************************)
(* Consensus safety: the node's tip never moves to a chain with less       *)
(* cumulative work — no reorg to a weaker chain. This is the property that  *)
(* makes selfish-mining / equal-work fork attacks unprofitable at the      *)
(* fork-choice layer.                                                      *)
(***************************************************************************)
WorkNeverDecreases == [][ CumWork(tip') >= CumWork(tip) ]_vars

(* Liveness (illustrative — not in the checked .cfg): if a strictly-heavier   *)
(* chain exists the node eventually adopts a tip at least that heavy. Written  *)
(* here for documentation; TLC cannot evaluate a temporal formula that        *)
(* quantifies over the growing state variable `blocks`, so it is omitted from *)
(* HarpyConsensus.cfg. WF_vars(ReplaceTip) provides the fairness it needs.     *)
HeaviestEventuallyChosen ==
  \A b \in blocks : (CumWork(b) > CumWork(tip)) ~> (CumWork(tip) >= CumWork(b))
===============================================================================
