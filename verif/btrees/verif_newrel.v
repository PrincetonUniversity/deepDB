(** * verif_newrel.v: Correctness proof of NewRelation *)

Require Import VST.floyd.proofauto.
Require Import VST.floyd.library.
Require Import relation_mem.
Require Import VST.msl.wand_frame.
Require Import VST.msl.iter_sepcon.
Require Import VST.floyd.reassoc_seq.
Require Import VST.floyd.field_at_wand.
Require Import FunInd.
Require Import btrees.
Require Import btrees_sep.
Require Import btrees_spec.

Lemma body_NewRelation: semax_body Vprog Gprog f_RL_NewRelation RL_NewRelation_spec.
Proof.
start_function.
assert (W: Vtrue <> Vundef) by easy.
forward_call(true,true,true,gv).
Intros vret.
forward_if(PROP (vret<>nullval)
     LOCAL (gvars gv; temp _pRootNode vret)
     SEP (mem_mgr gv; btnode_rep (empty_node true true true vret))).
- apply denote_tc_test_eq_split.
  + assert (vret = getval(empty_node true true true vret)). simpl. auto. rewrite H1. entailer!.
  + entailer!.
- forward.
- forward. entailer!.
- forward_call (trelation, gv).
  + split. unfold sizeof. simpl. rep_omega. split; auto.
  + Intros newrel.
    forward_if(PROP (newrel<>nullval)
     LOCAL (temp _pNewRelation newrel; temp _pRootNode vret)
     SEP (mem_mgr gv; malloc_token Ews trelation newrel; data_at_ Ews trelation newrel;
          btnode_rep (empty_node true true true vret))).
    * subst newrel.
      forward_call (tbtnode, vret, gv). (* free *)
      { rewrite if_false by auto.
        entailer!. }
      { forward. Exists (empty_relation nullval (Vint (Int.repr 0))). entailer!.
         unfold empty_relation_rel. exists nullval, (Vint (Int.repr 0)). auto.
        cancel. }
    * forward.
      entailer!.
    * Intros.
      forward.                  (* pnewrelation->root = prootnode *)
      forward.                  (* pnewrelation->numrecords=0 *)
      forward.                  (* pnewRelation->depth=0 *)
      forward.                  (* return pnewrelation *)
      Exists (empty_relation newrel vret). entailer!.
      unfold empty_relation_rel. exists newrel, vret. auto.
      unfold relation_rep. 
      unfold empty_relation. simpl. entailer!.
Qed.

