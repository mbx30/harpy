------------------------------ MODULE HarpyPoW ------------------------------
(***************************************************************************)
(* PoW-specific model check of Harpy's consensus (MIC-78), following the   *)
(* approach of DiGiacomo-Castillo et al., "Model checking blockchain       *)
(* consensus protocols" (IEEE Blockchain 2020): an explicit adversary      *)
(* races the honest chain, and we check whether a block that an observer   *)
(* has *committed* (accepted at ConfirmDepth confirmations) can later be   *)
(* reorged out.                                                            *)
(*                                                                         *)
(* Complements HarpyConsensus.tla (MIC-70): that module checks the fork-   *)
(* choice rule in isolation (work never decreases); this one checks the    *)
(* economic property built on top of it — k-deep confirmation — against a  *)
(* withholding attacker.                                                   *)
(*                                                                         *)
(* Model: one honest miner that always extends its tip, and an adversary   *)
(* that may privately extend *any* block and release later. All blocks     *)
(* carry equal work (one retarget window at fixed difficulty), so Harpy's  *)
(* cumulative-work rule (Chain#replace_if_more_work_valid!, strictly more  *)
(* work) reduces to strictly-longer chain.                                 *)
(*                                                                         *)
(* Expected results (see README):                                         *)
(*   HarpyPoW.cfg          MaxAdvBlocks <= ConfirmDepth  -> no violation   *)
(*   HarpyPoWAttack.cfg    MaxAdvBlocks >  ConfirmDepth  -> TLC exhibits   *)
(*     the classic double-spend trace: commit at depth k, then a longer    *)
(*     private fork orphans the committed block.                           *)
(* This is the qualitative shape behind docs/CONFIRMATION_DEPTH.md: depth  *)
(* must exceed the adversary's plausible private-lead, which the Gervais   *)
(* MDP framework quantifies probabilistically.                             *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, TLC

CONSTANTS
  MaxHonestBlocks,            \* honest blocks the model may mine
  MaxAdvBlocks,               \* adversarial blocks the model may mine
  ConfirmDepth                \* confirmations before an observer commits

VARIABLES
  blocks,                     \* set of block ids that exist; genesis = 0
  parent,                     \* parent[b] : the block b extends
  adv,                        \* subset of blocks mined by the adversary
  tip,                        \* honest node's current canonical tip
  committed                   \* blocks an observer has accepted at depth k

vars == <<blocks, parent, adv, tip, committed>>

Genesis == 0

RECURSIVE Height(_)
Height(b) == IF b = Genesis THEN 0 ELSE 1 + Height(parent[b])

RECURSIVE IsAncestor(_, _)
IsAncestor(a, b) ==
  \/ a = b
  \/ b /= Genesis /\ IsAncestor(a, parent[b])

NewId == Cardinality(blocks)

TypeOK ==
  /\ Genesis \in blocks
  /\ parent \in [blocks -> blocks]
  /\ adv \subseteq blocks
  /\ Genesis \notin adv
  /\ tip \in blocks
  /\ committed \subseteq blocks

Init ==
  /\ blocks = {Genesis}
  /\ parent = (Genesis :> Genesis)
  /\ adv = {}
  /\ tip = Genesis
  /\ committed = {}

(* The honest miner extends its current tip and adopts the new block.      *)
HonestMine ==
  /\ Cardinality(blocks \ adv) - 1 < MaxHonestBlocks
  /\ LET nb == NewId IN
       /\ blocks' = blocks \cup {nb}
       /\ parent' = [x \in blocks' |-> IF x = nb THEN tip ELSE parent[x]]
       /\ adv' = adv
       /\ tip' = nb
       /\ UNCHANGED committed

(* The adversary privately extends *any* existing block — selfish-mining   *)
(* style withholding is subsumed: released blocks only take effect via     *)
(* Adopt below.                                                            *)
AdvMine ==
  /\ Cardinality(adv) < MaxAdvBlocks
  /\ \E p \in blocks :
       LET nb == NewId IN
         /\ blocks' = blocks \cup {nb}
         /\ parent' = [x \in blocks' |-> IF x = nb THEN p ELSE parent[x]]
         /\ adv' = adv \cup {nb}
         /\ UNCHANGED <<tip, committed>>

(* Harpy's fork choice at equal per-block work: adopt a strictly longer    *)
(* (strictly more cumulative work) chain, whoever mined it.                *)
Adopt ==
  /\ \E c \in blocks :
       /\ Height(c) > Height(tip)
       /\ tip' = c
  /\ UNCHANGED <<blocks, parent, adv, committed>>

(* An observer commits a block once it sits ConfirmDepth below the honest  *)
(* tip (e.g. releases goods against a payment at k confirmations).         *)
Commit ==
  /\ \E b \in blocks :
       /\ b \notin committed
       /\ IsAncestor(b, tip)
       /\ Height(tip) - Height(b) >= ConfirmDepth
       /\ committed' = committed \cup {b}
  /\ UNCHANGED <<blocks, parent, adv, tip>>

Next == HonestMine \/ AdvMine \/ Adopt \/ Commit

Spec == Init /\ [][Next]_vars

(* Safety: nothing an observer committed is ever reorged off the honest    *)
(* chain. Holds iff the adversary cannot out-mine the confirmation depth.  *)
CommittedStable == \A b \in committed : IsAncestor(b, tip)

==============================================================================
