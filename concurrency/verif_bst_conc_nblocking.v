Require Import bst.bst_conc_lemmas.
Require Import bst.bst_conc_nblocking_spec.
Require Import VST.floyd.proofauto.
Require Import VST.floyd.library.
Require Import bst.bst_conc_nblocking.
Require Import VST.atomics.general_locks.
Require Import VST.progs.conclib.
Require Import VST.atomics.SC_atomics.
Require Import VST.msl.iter_sepcon.

Section Proofs.
Notation ghost_snap := (ghost_snap(P := node_ghost)).

Notation empty := (@empty coPset _).
Notation top := (@top coPset _).


Lemma node_data_valid_pointer:
  forall (info: option ghost_info) g  tp lp rp (range:number *number), node_data info g tp lp rp range |-- valid_pointer tp.
Proof.
  intros; unfold node_data; destruct info.
  Intros sh; entailer!. entailer!.
Qed.
Hint Resolve node_data_valid_pointer : valid_pointer.

Lemma node_data_saturate_local:
  forall (info: option ghost_info) g  tp lp rp (range:number *number), node_data info g tp lp rp range  |-- !! is_pointer_or_null tp.
Proof.
  intros. unfold node_data; destruct info. Intros sh. entailer!. entailer!.
Qed.
Hint Resolve node_data_saturate_local: saturate_local.




 Definition insert_inv (b: val) (sh: share) (x: Z) (v: val) ( g_root:gname) gv (g:gname)  (inv_names : invG) (P:mpred) (AS:mpred) (ref:val): environ -> mpred :=
( EX np: val, EX g_current:gname, EX nodeinfos: list(gname*node_info), EX n1:number, EX n2:number,
PROP (check_key_exist' x (n1,n2) = true)
LOCAL (temp _ref ref; temp _temp np; temp _t b; temp _x (vint x); temp _value v; gvars gv)
SEP ( |>P; AS && cored;in_tree g_current (n1,n2) np g; mem_mgr gv; malloc_token Ews (tptr Tvoid) ref * data_at Ews (tptr Tvoid) (vint 0) ref; 
   nodebox_rep sh b g_root g ; iter_sepcon (fun info => ghost_snap  (snd info) (fst info)) nodeinfos
   ))%assert.
  


Lemma body_insert: semax_body Vprog Gprog f_insert insert_spec.
Proof.
start_function. 
unfold atomic_shift. Intros P.
 set (AS := ashift _ _ _ _ _ _).
forward.
forward_call ( (tptr Tvoid), gv).
{ simpl. repeat (split; auto); rep_omega. }
Intros ref. 
forward.
 eapply semax_pre; [
    | apply (semax_loop _ (insert_inv b sh x v g_root gv g inv_names P AS ref) (insert_inv b sh x v g_root gv g inv_names P AS ref) )]. 
{ intros. unfold insert_inv.  Exists b g_root (@nil (gname *node_info)).  unfold nodebox_rep in *. Intros tp lp. Exists Neg_Infinity Pos_Infinity tp lp. sep_apply (in_tree_split g_root ( Neg_Infinity, Pos_Infinity) b g) . entailer!. unfold check_key_exist'. simpl. cancel. 
}
* unfold insert_inv. Intros np g_current nodeinfos n1 n2.
   forward. 
   sep_apply cored_dup.
   sep_apply in_tree_split. 
   Intros.
   forward_call (np, top, empty, fun tp : val => |> P * EX n n0:number, EX lp:val, EX rp:val, EX info: option ghost_info, !! (check_key_exist' x (n, n0) = true) && ghost_snap (n, n0,info) g_current * node_data info g tp lp rp (n, n0), inv_names).
    { subst Frame;instantiate (1 := [AS && cored; in_tree g_current (n1, n2) np g; mem_mgr gv; malloc_token Ews (tptr Tvoid) ref;  data_at Ews (tptr Tvoid) (vint 0) ref ; nodebox_rep sh b g_root g; iter_sepcon (λ info : own.gname * (number * number * option ghost_info), ghost_snap info.2 info.1)
      nodeinfos]).  simpl;cancel.
     iIntros "(( in & [AS1 _]) & P)". 
      iMod ("AS1" with "P") as (BST) "[Tree Tclose]". 
      iDestruct "Tree" as "(% & Tree)".
      unfold tree_rep2 at 1.
      iDestruct "Tree" as (tg) "((% & Tree) & gref)".
      iPoseProof (node_exist_in_tree with "[gref in]") as "%". iFrame. destruct H4 as [r H4]. destruct r as [n n0]. destruct H4.
      iPoseProof ( extract_node_info_from_ghost_tree_rep_2 with "Tree") as "Hadd". apply H4. intros. simpl;auto. apply (sortedness_preserved__in_ghosttree BST tg);auto.
      iDestruct "Hadd" as ( tp o lp rp) "(info & Tree)".
      unfold node_information at 1.
      iDestruct "info" as "(% & ((p & master) & info))". 
       iModIntro; iExists Ews, tp; iFrame "p".
       iSplitL ""; [iSplit; auto; iPureIntro; split; auto; tauto|].
        iIntros "p".
        iDestruct "Tclose" as "[Tclose _]".
        iPoseProof (make_snap with "[master]") as "master". iFrame.
        iMod ("master") as "[snap master]".  
        iDestruct "in" as (sh2) "in".
       iMod (own_dealloc with "in") as "_". 
       iPoseProof (node_data_split with "info") as "(info1 & info2)". 
        rewrite -> exp_sepcon2.  iExists n.  rewrite -> exp_sepcon2.  iExists n0.  rewrite -> exp_sepcon2.  iExists lp. rewrite -> exp_sepcon2. iExists rp. rewrite -> exp_sepcon2. iExists o. simpl. rewrite <- !sepcon_assoc. 
        rewrite (prop_true_andp _ (ghost_snap (n, n0, o) g_current) ).
        iFrame . 
       iApply "Tclose". 
       iFrame.
       iSplit. iPureIntro;auto.
       unfold tree_rep2.
       iExists tg.
       iFrame;iSplit;auto.
       iApply "Tree".
       unfold node_information.
       iFrame.
       unfold range_inclusion, check_key_exist' in *. apply andb_prop in H1. apply andb_prop in H5. destruct H1, H5. apply andb_true_intro. split. apply less_than_equal_less_than_transitivity with (b := n1). apply H5. apply H1. assert (less_than (Finite_Integer x) n0 = true). { apply less_than_less_than_equal_transitivity with (b := n2). apply H7. apply H8. } apply H9.
  }
 Intro tp.
 Intros n n0 lp rp info. 
 forward_if.
 - intros. 
  forward_call (t_struct_tree, gv).
  { split; simpl; [ rep_omega | auto ]. }
  Intros p.
  forward.
 forward_call(v).
 Intro v1.
 forward.
 forward_call(vint 0).
 Intro lp1.
 forward.
 forward_call( vint 0).
 Intro rp1.
 forward.
 sep_apply node_data_R. subst. simpl. Intros.
 sep_apply cored_dup.
 forward_call (np, Ews, ref, (vint 0), p, top, empty,
        fun vp : val =>   (if eq_dec vp (vint 0) then  Q else ( |> P * EX o1: node_info, ghost_snap o1 g_current * bst_conc_nblocking_spec.atomic_ptr_at Ews (vint 0) rp1 * bst_conc_nblocking_spec.atomic_ptr_at Ews (vint 0) lp1 * bst_conc_nblocking_spec.atomic_ptr_at Ews v v1 * malloc_token Ews t_struct_tree p * data_at Ews t_struct_tree (vint x, (v1, (lp1, rp1))) p ))  *
          (iter_sepcon (λ info : own.gname * node_info,
        ghost_snap info.2 info.1) nodeinfos), inv_names).
        {  subst Frame; instantiate (1 := [AS && cored; mem_mgr gv; malloc_token Ews (tptr Tvoid) ref; nodebox_rep sh b g_root g]). unfold fold_right_sepcon. cancel.
         iIntros "((((((((([AS1 _] & rp1) & lp1) & v1 ) & token ) & p ) &P) &snap) & in)&snaps)".
         iMod ("AS1" with "P") as (BST) "[Tree Tclose]". 
         iDestruct "Tree" as "(% & Tree)".
         unfold tree_rep2 at 1.
         iDestruct "Tree" as (tg) "((% & Tree) & gref)".
         iPoseProof (node_exist_in_tree with "[gref in]") as "%". iFrame. destruct H6 as [r H6]. destruct r as [n3 n4]. destruct H6.
         iPoseProof ( extract_node_info_from_ghost_tree_rep_2 with "Tree") as "Hadd". eauto. intros. simpl;auto. apply (sortedness_preserved__in_ghosttree BST tg );auto.
        iDestruct "Hadd" as ( tp o1 l r) "(info & Tree)".
        unfold node_information at 1.
       iDestruct "info" as "(% & ((ap & master) & info))". 
       iModIntro; iExists Ews, tp; iFrame "ap".
       iSplitL ""; [iSplit; auto; iPureIntro; split; auto; tauto|].
       destruct (eq_dec tp (vint 0)).
       { 
        iIntros "np".
       iDestruct "Tclose" as "[_ Tclose ]".
       iMod (ghost_node_alloc with "[$]") as (gl) "lg". unfold finite. auto.
       iDestruct "lg" as "(((lg & ref) & in) & inl)".
        iMod (ghost_node_alloc with "[ref in]") as (gr) "rg". unfold finite. auto. iFrame.
        iDestruct "rg" as "(((rg & ref) & in) & inr)".
        instantiate(1 := rp1).  instantiate(1 := (Finite_Integer x, n4)). instantiate (1 := lp1).
        instantiate(1 := (n3, Finite_Integer x)). instantiate (1 := None). instantiate (1 := None).
        iFrame. 
        iApply ("Tclose"  $! tt). simpl.
        iSplitL. iSplit. iPureIntro. apply insert_sorted. auto.
        iPoseProof ( bi.and_elim_l with "Tree") as "Tree".  iPoseProof ( bi.and_elim_r with "Tree") as "Tree".
        instantiate (1 := v).  instantiate (1 := x). 
        iSpecialize ("Tree" $! gl gr p).
        unfold tree_rep2. iExists  (insert_ghost x v tg gl lp1 gr rp1).
        iFrame.
        iCombine "snap" "master" as "master".
        iPoseProof (snap_master_join1 with "master") as "master". 
        iPoseProof (node_data_R with "info") as "info". 
        subst tp. iSimpl in "info". iDestruct "info" as "[% _]". admit. *)
        admit.
       }
       iIntros "np".
       iMod (snap_master_update1(ORD := range_order) _ _ _ (n3, n4, o1) with "[$snap $master]") as "[snap master]".
       {  split. apply range_iteself. simpl. destruct o1;auto. }
        iDestruct "Tclose" as "[Tclose _]".
         iDestruct "in" as (sh2) "in".
       iMod (own_dealloc with "in") as "_". 
        rewrite -> exp_sepcon2.  rewrite exp_sepcon1. iExists (n3,n4,o1). iFrame.
        iApply "Tclose". 
       iSplit. iPureIntro;auto.
       unfold tree_rep2.
       iExists tg.
       iFrame;iSplit;auto.
       iApply "Tree".
       unfold node_information.
       iFrame.
     } 
       
       
  
Admitted.






End Proofs.