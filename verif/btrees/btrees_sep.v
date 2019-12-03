(** * btrees_sep.v : Representation of btrees in Separation Logic *)

Require Import VST.floyd.proofauto.
Require Import VST.floyd.library.
Require Import relation_mem.
Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Require Import VST.msl.wand_frame.
Require Import VST.msl.iter_sepcon.
Require Import VST.floyd.reassoc_seq.
Require Import VST.floyd.field_at_wand.
Require Import FunInd.
Require Import btrees.
Require Import index.

(**
    REPRESENTATIONS IN SEPARATION LOGIC
 **)

Definition tbtnode:=      Tstruct _BtNode noattr.
Definition tentry:=       Tstruct _Entry noattr.
Definition tchildrecord:= Tunion _Child_or_Record noattr.
Definition trelation:=    Tstruct _Relation noattr.
Definition tcursor:=      Tstruct _Cursor noattr.

Definition value_repr (v:V) : val := Vptrofs v.
  
Definition value_rep (v:V) (p:val) : mpred := (* this should change if we change the type of Values? *)
  data_at Ews (tptr tvoid) (value_repr v) p.

Lemma value_rep_local_prop: forall v p,
    value_rep v p |-- !!(isptr p).
Proof.
  intros. unfold value_rep. entailer!.
Qed.

Hint Resolve value_rep_local_prop: saturate_local.

Lemma value_valid_pointer: forall v p,
    value_rep v p |-- valid_pointer p.
Proof.
  intros. unfold value_rep. entailer!.
Qed.

Hint Resolve value_valid_pointer: valid_pointer.

Definition key_repr (key:key) : val := Vptrofs key.

Definition isLeaf {X:Type} (n:node X) : bool :=
  match n with btnode ptr0 le b First Last w => b end.

Definition getval (n:node val): val :=
  match n with btnode _ _ _ _ _ x => x end.

Definition getvalr (r:relation val): val := snd r.

Definition entry_val_rep (e:entry val) :=
  match e with
  | keychild k c => (key_repr k,  inl (getval c))
  | keyval k v x => (key_repr k,  inr x)
  end.
    
Fixpoint le_to_list (le:listentry val) : list (val * (val + val)) :=
  match le with
  | nil => []
  | cons e le' => entry_val_rep e :: le_to_list le'
  end.

Lemma le_to_list_length: forall (le:listentry val),
    Zlength (le_to_list le) =
    Z.of_nat (numKeys_le le).
Proof.
  intros.
  induction le.
  - simpl. auto.
  - simpl. rewrite Zlength_cons. rewrite IHle.
    rewrite Zpos_P_of_succ_nat. auto.
Qed.

Lemma le_to_list_Znth0: forall e le,
    Znth 0 (d:=(Vundef,inl Vundef)) (le_to_list (cons val e le)) = entry_val_rep e.
Proof.
  intros. simpl. rewrite Znth_0_cons. auto.
Qed.

Lemma Znth_Zsucc: forall (X:Type) (i:Z) (e:X) (le:list X) d,
    i >= 0 -> Znth (d:=d) (Z.succ i) (e::le) = Znth i le.
Proof.
  intros. unfold Znth. rewrite if_false. rewrite if_false.
  simpl. rewrite Z2Nat.inj_succ. auto.
  omega. omega. omega.
Qed.
  
Lemma Znth_to_list: forall i le e endle d,
    nth_entry_le i le = Some e ->
    Znth (d:=d) (Z.of_nat i) (le_to_list le ++ endle) = entry_val_rep e.
Proof.
  intros. generalize dependent i.
  induction le; intros.
  - destruct i; inv H.
  - destruct i as [|ii].
    + simpl. rewrite Znth_0_cons. simpl in H. inv H. auto.
    + simpl. simpl in H. apply IHle in H.
      rewrite Zpos_P_of_succ_nat.
      rewrite Znth_Zsucc with (i:=Z.of_nat ii) (e:=entry_val_rep e0) (le:=le_to_list le ++ endle).
      auto. omega.
Qed.

Lemma le_to_list_app: forall l1 l2,
    le_to_list (le_app l1 l2) = le_to_list l1 ++ le_to_list l2.
Proof.
  intros.
  induction l1.
  - simpl. auto.
  - simpl. rewrite IHl1. auto.
Qed.

Fixpoint entry_rep (e:entry val): mpred:=
  match e with
  | keychild _ n => btnode_rep n
  | keyval _ v x => value_rep v x
  end
with btnode_rep (n:node val):mpred :=
  match n with btnode ptr0 le b First Last pn =>
  EX ent_end:list(val * (val + val)),
  malloc_token Ews tbtnode pn *
  data_at Ews tbtnode (Val.of_bool b,(
                       Val.of_bool First,(
                       Val.of_bool Last,(
                       Vint(Int.repr (Z.of_nat (numKeys n))),(
                       match ptr0 with
                       | None => nullval
                       | Some n' => getval n'
                       end,(
                       le_to_list le ++ ent_end)))))) pn *
  match ptr0 with
  | None => emp
  | Some n' => btnode_rep n'
  end *
  le_iter_sepcon le
  end
with le_iter_sepcon (le:listentry val):mpred :=
  match le with
  | nil => emp
  | cons e le' => entry_rep e * le_iter_sepcon le'
  end.

Lemma btnode_rep_local_prop: forall n,
    btnode_rep n |-- !!(isptr (getval n)).
Proof.
  intros. destruct n. unfold btnode_rep. Intros ent_end. entailer!.
Qed.
  
Hint Resolve btnode_rep_local_prop: saturate_local.

Lemma btnode_valid_pointer: forall n,
    btnode_rep n |-- valid_pointer (getval n).
Proof.
  intros. destruct n. unfold btnode_rep. Intros ent_end. entailer!.
Qed.

Hint Resolve btnode_valid_pointer: valid_pointer.

Lemma unfold_btnode_rep: forall n,
    btnode_rep n =
  match n with btnode ptr0 le b First Last pn =>
  EX ent_end:list (val * (val+val)),
  malloc_token Ews tbtnode pn *
  data_at Ews tbtnode (Val.of_bool b,(
                       Val.of_bool First,(
                       Val.of_bool Last,(
                       Vint(Int.repr (Z.of_nat (numKeys n))),(
                       match ptr0 with
                       | None => nullval
                       | Some n' => getval n'
                       end,(
                       le_to_list le ++ ent_end)))))) pn *
  match ptr0 with
  | None => emp
  | Some n' => btnode_rep n'
  end *
  le_iter_sepcon le
  end.
Proof.
  intros. destruct n as [ptr0 le b First Last x].
  apply pred_ext; simpl; Intros ent_end; Exists ent_end; entailer!.
Qed.

Arguments btnode_rep n : simpl never.

Lemma fold_btnode_rep:
  forall ptr0 le b First Last pn (ent_end: list (val * (val+val)))
    nk,
  nk = Z.of_nat (@numKeys val (btnode val ptr0 le b First Last pn)) ->
  malloc_token Ews tbtnode pn *
  data_at Ews tbtnode (Val.of_bool b,(
                       Val.of_bool First,(
                       Val.of_bool Last,(
                       Vint(Int.repr nk),(
                       match ptr0 with
                       | None => nullval
                       | Some n' => getval n'
                       end,(
                       le_to_list le ++ ent_end)))))) pn *
  match ptr0 with
  | None => emp
  | Some n' => btnode_rep n'
  end *
  le_iter_sepcon le |-- btnode_rep (btnode val ptr0 le b First Last pn).
Proof.
 intros. subst.
 rewrite unfold_btnode_rep.
 Exists ent_end. cancel.
Qed.

Lemma cons_le_iter_sepcon:
  forall e le, entry_rep e * le_iter_sepcon le |-- le_iter_sepcon (cons val e le).
Proof. intros. simpl. auto. Qed.

Lemma le_iter_sepcon_split: forall i le e,
    nth_entry_le i le = Some e ->
    le_iter_sepcon le = entry_rep e * (entry_rep e -* le_iter_sepcon le).
Proof.
  intros. assert(i < numKeys_le le)%nat by (apply nth_entry_le_some with (e:=e); auto).
  generalize dependent i.
  induction le as [|e' le']; intros.
  - simpl in H0. inv H0.
  - simpl. destruct i as [|ii].
    + simpl in H. inv H. apply pred_ext.
      * cancel. rewrite <- wand_sepcon_adjoint. cancel.
      * eapply derives_trans. apply wand_frame_elim. cancel.
    + simpl in H. simpl in H0. apply pred_ext.
      * rewrite IHle' at 1. cancel.
        rewrite <- wand_sepcon_adjoint. cancel. rewrite sepcon_comm. apply wand_frame_elim.
        eauto. omega.
      * eapply derives_trans. apply wand_frame_elim. cancel.
Qed.

Definition relation_rep (r:relation val) (numrec:nat) :mpred :=
  match r with
  (n,prel) =>
    malloc_token Ews trelation prel *
    data_at Ews trelation (getval n, (Vint(Int.repr(Z.of_nat(numrec))), (Vint (Int.repr (Z.of_nat(get_depth r)))))) prel *
    btnode_rep n
  end.

Lemma relation_rep_local_prop: forall r n,
    relation_rep r n |-- !!(isptr (getvalr r)).
Proof. 
  intros. destruct r. unfold relation_rep. entailer!.
Qed.

Hint Resolve relation_rep_local_prop: saturate_local.

Lemma relation_rep_valid_pointer: forall r n,
    relation_rep r n |-- valid_pointer (getvalr r).
Proof.
  intros. destruct r. unfold relation_rep. entailer!.
Qed.

Hint Resolve relation_rep_valid_pointer: valid_pointer.
  
Lemma fold_relation_rep:
  forall prel n nr d,
   d = Int.repr (Z.of_nat (get_depth (n, prel))) ->
  malloc_token Ews trelation prel * 
  data_at Ews trelation
           (getval n, (Vint (Int.repr (Z.of_nat nr)), Vint d)) prel *
  btnode_rep n 
  |-- relation_rep (n,prel) nr.
Proof. intros. subst. unfold relation_rep.  apply derives_refl. Qed.

Definition getCurrVal (c:cursor val): val :=
  match c with
  | [] => nullval
  | (n,_)::_ => getval n
  end.

Definition rep_index (i:index): Z :=
  match i with
  | im => -1
  | ip n => Z.of_nat n
  end.

Lemma next_rep: forall i,
    (rep_index i) + 1 = rep_index (next_index i).
Proof.
  intros. destruct i.
  - simpl. auto.
  - simpl. rewrite Zpos_P_of_succ_nat. omega.
Qed.

Definition cursor_rep (c:cursor val) (r:relation val) (p:val):mpred :=
  EX anc_end:list val, EX idx_end:list val,
  malloc_token Ews tcursor p *
  match r with (_,prel) =>
               data_at Ews tcursor (prel,(
                                    Vint(Int.repr((Zlength c) - 1)),(
                                    List.rev (map (fun x => (Vint(Int.repr(rep_index (snd x)))))  c) ++ idx_end,(
                                    List.rev (map getval (map fst c)) ++ anc_end)))) p end.

Definition subcursor_rep (c:cursor val) (r:relation val) (p:val):mpred :=
  EX anc_end:list val, EX idx_end:list val, EX length:Z,
  malloc_token Ews tcursor p *
  match r with (_,prel) =>
               data_at Ews tcursor (prel,(
                                    Vint(Int.repr(length )),(
                                    List.rev (map (fun x => (Vint(Int.repr(rep_index (snd x)))))  c) ++ idx_end,(
                                    List.rev (map getval (map fst c)) ++ anc_end)))) p end.
(* same as cursor_rep, but _length can contain anything *)

Lemma cursor_rep_local_prop: forall c r p,
    cursor_rep c r p |-- !!(isptr p).
Proof. 
  intros. unfold cursor_rep. Intros a. Intros i. destruct r. entailer!.
Qed.

Hint Resolve cursor_rep_local_prop: saturate_local.

Lemma cursor_rep_valid_pointer: forall c r p,
    cursor_rep c r p |-- valid_pointer p.
Proof.
  intros. unfold cursor_rep. Intros a. Intros i. entailer!.
Qed.    

Hint Resolve cursor_rep_valid_pointer: valid_pointer.

Lemma subcursor_rep_local_prop: forall c r p,
    subcursor_rep c r p |-- !!(isptr p).
Proof. 
  intros. unfold subcursor_rep. Intros a. Intros i. Intros l. destruct r. entailer!.
Qed.

Hint Resolve subcursor_rep_local_prop: saturate_local.

Lemma subcursor_rep_valid_pointer: forall c r p,
    subcursor_rep c r p |-- valid_pointer p.
Proof.
  intros. unfold subcursor_rep. Intros a. Intros i. Intros l. entailer!.
Qed.

Hint Resolve subcursor_rep_valid_pointer: valid_pointer.

Lemma cursor_subcursor_rep: forall c r pc,
    cursor_rep c r pc |-- subcursor_rep c r pc.
Proof.
  intros. unfold cursor_rep, subcursor_rep. Intros anc_end. Intros idx_end.
  Exists anc_end. Exists idx_end. Exists (Zlength c -1). cancel.
Qed.

Inductive subchild {X:Type} : node X -> listentry X -> Prop :=
| sc_eq: forall k n le, subchild n (cons X (keychild X k n) le)
| sc_cons: forall e n le, subchild n le -> subchild n (cons X e le).


Lemma subchild_nth {X}: forall (n: node X) le, subchild n le -> exists i, nth_node_le i le = Some n.
Proof.
  induction le.
  easy.
  intro h. inversion h. exists 0%nat. easy.
  specialize (IHle H1). destruct IHle.
  exists (S x)%nat.
  easy.
Qed.

Lemma nth_subchild: forall (X:Type) i le (child:node X),
    nth_node_le i le = Some child -> subchild child le.
Proof.
  intros. generalize dependent i.
  induction le; intros.
  - destruct i; inv H.
  - destruct i as [|ii].
    + simpl in H. destruct e; inv H. apply sc_eq.
    + simpl in H. apply IHle in H. apply sc_cons. auto.
Qed.

Inductive subnode {X : Type} : node X -> node X -> Prop :=
  sub_refl : forall n : node X, subnode n n
| sub_ptr0 : forall (n m : node X) (le : listentry X) (First Last : bool) (x : X),
    subnode n m -> subnode n (btnode X (Some m) le false First Last x)
| sub_child : forall (n m : node X) (le : listentry X) (ptr0 : node X) (First Last : bool) (x : X),
    subnode n m -> subchild m le -> subnode n (btnode X (Some ptr0) le false First Last x).

Lemma sub_trans {X: Type}: forall n m p: node X,
    subnode n m -> subnode m p -> subnode n p.
Proof.
  intros n m.
  apply (Fix (well_founded_ltof (node X) (fun n => node_depth n)) (fun p => subnode n m -> subnode m p -> subnode n p)).
  unfold ltof.
  intros p hind hnm hmp.
  inversion hmp.
  - now subst.
  - apply sub_ptr0.
    refine (hind m0 _ _ _).
    rewrite <- H1. simpl.
    apply index.lt_max_split_r. omega.
    assumption.
    assumption.
  - apply (sub_child _ m0). apply hind.
    rewrite <- H2. apply subchild_nth in H0. destruct H0.
    simpl.
    apply (Nat.lt_le_trans _ (listentry_depth le)).
    apply (nth_node_le_decrease _ le _ _ H0).
    apply index.le_l. 
    assumption.
    assumption.
    assumption.
Defined.

Lemma btnode_rep_simpl_ptr0: forall le b pn (p0:option (node val)) le0 b0 pn0 p0 First Last F L,
    btnode_rep (btnode val (Some (btnode val p0 le0 b0 F L pn0)) le b First Last pn) =
    EX ent_end:list (val * (val+val)),
  malloc_token Ews tbtnode pn *
  data_at Ews tbtnode (Val.of_bool b,(
                         Val.of_bool First,(
                           Val.of_bool Last,(
                             Vint(Int.repr (Z.of_nat (numKeys_le le))),(
                               pn0,(
                                 le_to_list le ++ ent_end)))))) pn *
  btnode_rep (btnode val p0 le0 b0 F L pn0) *
  le_iter_sepcon le.
Proof.
  intros. rewrite unfold_btnode_rep. apply pred_ext; Intros ent_end; Exists ent_end; entailer!.
Qed.

Theorem subchild_rep: forall n le,
    subchild n le ->
    le_iter_sepcon le |-- btnode_rep n * (btnode_rep n -* le_iter_sepcon le).
Proof.
  intros.
  induction le. inv H.
  inversion H.
  - simpl. destruct n as [ptr0 nle isLeaf First Last x].
    cancel. rewrite <- wand_sepcon_adjoint. cancel.
  - apply IHle in H2. simpl. eapply derives_trans.
    apply cancel_left. apply H2. cancel.
    rewrite <- wand_sepcon_adjoint. cancel. rewrite sepcon_comm.
    apply wand_frame_elim.
Qed.

Theorem subnode_rep: forall n root,
    subnode n root ->
    btnode_rep root = btnode_rep n * (btnode_rep n -* btnode_rep root).
Proof.
  intros. apply pred_ext.
  induction H; intros.
  - cancel. rewrite <- wand_sepcon_adjoint. cancel.
  - destruct m. rewrite btnode_rep_simpl_ptr0 by auto. entailer.
    sep_apply IHsubnode. entailer!.
    rewrite <- wand_sepcon_adjoint. Exists ent_end. entailer!.
    rewrite sepcon_comm. apply modus_ponens_wand.
  - apply subchild_rep in H0. rewrite unfold_btnode_rep at 1.
    Intros ent_end. eapply derives_trans. apply cancel_left. apply H0.
    sep_apply IHsubnode. cancel. rewrite <- wand_sepcon_adjoint.
    autorewrite with norm. rewrite unfold_btnode_rep with (n:=btnode val (Some ptr0) le false First Last x).
    Exists ent_end. cancel. rewrite wand_sepcon_adjoint. apply wand_frame_ver.
  - apply wand_frame_elim.
Qed.

(* Partial cursor c is correct and points to n *)
Fixpoint partial_cursor_correct {X:Type} (c:cursor X) (n:node X) (root:node X): Prop :=
  match c with
  | [] => n = root
  | (n',i)::c' => (partial_cursor_correct c' n' root) /\ (nth_node i n' = Some n)
  end.

Lemma partial_correct_index : forall (X:Type) (c:cursor X) n i n' root,
    partial_cursor_correct ((n,i)::c) n' root -> idx_to_Z i < Z.of_nat (numKeys n).
Proof.
  intros. unfold partial_cursor_correct in H. destruct H.
  apply nth_node_some in H0. auto.
Qed.

(* Complete cursor is correct and points to (keyval k v x) *)
Definition complete_cursor_correct {X:Type} (c:cursor X) k v x (root:node X): Prop :=
  match c with
  | [] => False
  | (n,i)::c' => match i with
                 | im => False
                 | ip ii => partial_cursor_correct c' n root /\ nth_entry ii n = Some (keyval X k v x)
                 end
  end.

Lemma complete_correct_index : forall {X:Type} (c:cursor X) n i k v x root,
    complete_cursor_correct ((n,i)::c) k v x root -> idx_to_Z i < Z.of_nat (numKeys n).
Proof.
  intros. unfold complete_cursor_correct in H. destruct i.
  omega. destruct H. apply nth_entry_some in H0. simpl. omega.
Qed.

(* Cursor is complete and correct for relation *)
Definition complete_cursor_correct_rel {X:Type} (c:cursor X) (rel:relation X): Prop :=
  match getCEntry c with
  | None => False
  | Some e => match e with
              | keychild _ _ => False
              | keyval k v x => complete_cursor_correct c k v x (get_root rel)
              end
  end.

Lemma complete_correct_rel_index : forall (X:Type) (c:cursor X) n i r,
    complete_cursor_correct_rel ((n,i)::c) r -> idx_to_Z i < Z.of_nat (numKeys n).
Proof.
  intros. unfold complete_cursor_correct_rel in H. destruct (getCEntry ((n,i)::c)); try contradiction.
  destruct e; try contradiction. eapply complete_correct_index. eauto.
Qed.

(* Cursor is partial but correct for the relation *)
Definition partial_cursor_correct_rel {X:Type} (c:cursor X) (rel:relation X) : Prop :=
  match c with
  | [] => True
  | (n,i)::c' =>
    match nth_node i n with
    | None => False
    | Some n' => partial_cursor_correct c n' (get_root rel)
    end
  end.

Lemma partial_correct_rel_index: forall (X:Type) (c:cursor X) n i r,
    partial_cursor_correct_rel ((n,i)::c) r -> idx_to_Z i < Z.of_nat (numKeys n).
Proof.
  intros. unfold partial_cursor_correct_rel in H. destruct (nth_node i n); try contradiction.
  eapply partial_correct_index. eauto.
Qed.

(* Cursor is correct for relation. Either partial or complete *)
Definition cursor_correct_rel {X:Type} (c:cursor X) (rel:relation X) : Prop :=
  complete_cursor_correct_rel c rel \/ partial_cursor_correct_rel c rel.

Lemma nth_le_subchild: forall X i (n:node X) le,
    nth_node_le i le = Some n -> subchild n le.
Proof.
  intros. generalize dependent le. induction i.
  - intros. simpl in H. destruct le; try inv H. destruct e; try inv H1.
    apply sc_eq.
  - intros. simpl in H. destruct le; try inv H. apply IHi in H1.
    apply sc_cons. auto.
Qed.

Lemma nth_subnode: forall X i (n n':node X),
    nth_node i n' = Some n -> subnode n n'.
Proof.
  intros.
  destruct n' as [ptr0 le isLeaf x].
  destruct isLeaf, ptr0; try easy.
  induction i.
  - unfold nth_node in H. destruct n. subst. inversion H.
    constructor. constructor.
  - simpl in H.
    generalize dependent n. generalize dependent le. destruct n1.
    + intros. destruct le; simpl in H. inv H.
      apply (sub_child _ n). constructor.
      destruct e. easy. inv H. apply sc_eq.
    + intros. simpl in H. destruct le. inv H.
      apply nth_le_subchild in H.
      apply (sub_child _ n). constructor. apply sc_cons. auto.
Qed.
    
(* if n is pointed to by a partial cursor, then it is a subnode of the root *)
Theorem partial_cursor_subnode': forall X (c:cursor X) root n,
    partial_cursor_correct c n root ->
    subnode n root.
Proof.
  intros. generalize dependent n.
  induction c.
  - intros. simpl in H. subst. apply sub_refl.
  - intros. destruct a as [n' i]. simpl in H.
    destruct H. apply IHc in H. apply nth_subnode in H0.
    eapply sub_trans; eauto.
Qed.

(* The current node of a complete cursor is a subnode of the root *)
Theorem complete_cursor_subnode: forall X (c:cursor X) r,
    complete_cursor_correct_rel c r ->
    subnode (currNode c r) (get_root r).
Proof.
  destruct r as [root prel].
  pose (r:=(root,prel)). intros. unfold get_root. simpl.
  destruct c as [|[n i] c']. inv H.
  unfold complete_cursor_correct_rel in H.
  destruct (getCEntry ((n,i)::c')); try inv H.
  destruct e; try inv H. unfold complete_cursor_correct in H.
  destruct i. inv H. destruct H. apply partial_cursor_subnode' in H. unfold get_root in H. simpl in H.
  simpl. auto.
Qed.

(* Current node of a partial cursor is a subnode of the root *)
Theorem partial_cursor_subnode: forall X (c:cursor X) r,
    partial_cursor_correct_rel c r ->
    subnode (currNode c r) (get_root r).
Proof. 
  intros. unfold partial_cursor_correct_rel in H.
  destruct c as [|[n i] c']. simpl. apply sub_refl.
  simpl. simpl in H. destruct (nth_node i n).
  destruct H. apply partial_cursor_subnode' in H. auto. inv H.
Qed.

(* The currnode of a correct cursor is a subnode of the root *)
Theorem cursor_subnode: forall X (c:cursor X) r,
    cursor_correct_rel c r -> subnode (currNode c r) (get_root r).
Proof.
  intros. unfold cursor_correct_rel in H.
  destruct H. apply complete_cursor_subnode. auto.
  apply partial_cursor_subnode. auto.
Qed.

(* This is modified to include the balancing property. *)
Inductive intern_le {X:Type}: listentry X -> nat -> Prop :=
| ileo: forall k n, intern_le (cons X (keychild X k n) (nil X)) (node_depth n)
| iles: forall k n le d, intern_le le d -> node_depth n = d -> intern_le (cons X (keychild X k n) le) d.

Inductive leaf_le {X:Type}: listentry X -> Prop :=
| llen: leaf_le (nil X)
| llec: forall k v x le, leaf_le le -> leaf_le (cons X (keyval X k v x) le).  

Lemma intern_no_keyval: forall X i le d k v x,
    intern_le le d -> nth_entry_le i le = Some (keyval X k v x) -> False.
Proof.
  intros. generalize dependent i.
  induction H.
  - intros. destruct i as [|ii].
    + simpl in H0. inv H0.
    + simpl in H0. destruct ii; inv H0.
  - intros. destruct i as [|ii].
    + simpl in H1. inv H1.
    + simpl in H1. eapply IHintern_le. eauto.
Qed.

(* An intern node should have a defined ptr0, and leaf nodes should not *)
Definition node_integrity {X:Type} (n:node X) : Prop :=
  match n with
    btnode ptr0 le isLeaf First Last x =>
    match isLeaf with
    | true => ptr0 = None /\ leaf_le le
    | false => match ptr0 with
               | None => False
               | Some ptr0 => intern_le le (node_depth ptr0)
              end
    end
  end.

(* node integrity of every subnode *)
Definition root_integrity {X:Type} (root:node X) : Prop :=
  forall n, subnode n root -> node_integrity n.

Lemma node_of_root_integrity {X} (root: node X):
  root_integrity root -> node_integrity root.
Proof.
  unfold root_integrity. intro H. 
  apply H. constructor.
Qed.

Lemma entry_subnode: forall X i (n:node X) n' k,
    node_integrity n ->
    nth_entry i n = Some (keychild X k n') ->
    subnode n' n.
Proof.
  intros X i n n' k hint h. destruct n. simpl in h, hint.
  destruct b, o; try easy.
  - destruct hint as [_ hleaf].
    exfalso. generalize dependent l; induction i; destruct l; try easy; intros.
    inversion h. subst e. inversion hleaf.
    simpl in h. inversion hleaf. apply (IHi l); easy.
  - apply (sub_child _ n'); [constructor | ]; generalize dependent i; induction l; intros.
    easy.
    destruct i. inversion h. constructor.
    constructor. simpl in h. refine (IHl _ i h).
    inversion hint. subst l. destruct i; easy. assumption.
Qed.

(* integrity of every child of an entry *)
Definition entry_integrity {X:Type} (e:entry X) : Prop :=
  match e with
  | keyval k v x => True
  | keychild k child => root_integrity child
  end.

(* leaf nodes have None ptr0 *)
Lemma leaf_ptr0: forall {X:Type} ptr0 le b F L pn,
    node_integrity (btnode X ptr0 le b F L pn) ->
    LeafNode (btnode X ptr0 le b F L pn) ->
    ptr0 = None.
Proof.
  intros. simpl in H. simpl in H0. destruct b; try inv H0. destruct H. auto.
Qed.

(* Intern nodes have Some ptr0 *)
Lemma intern_ptr0: forall {X:Type} ptr0 le b F L pn,
    node_integrity (btnode X ptr0 le b F L pn) ->
    InternNode (btnode X ptr0 le b F L pn) ->
    exists n, ptr0 = Some n.
Proof.
  intros. simpl in H. simpl in H0. destruct b. inv H0.
  destruct ptr0. exists n. auto. inv H.
Qed.

(* Intern nodes have non-empty le *)
Lemma intern_le_cons: forall {X:Type} ptr0 le b F L pn,
    node_integrity (btnode X ptr0 le b F L pn) ->
    InternNode (btnode X ptr0 le b F L pn) ->
    exists e le', le = cons X e le'.
Proof.
  intros. simpl in H. simpl in H0. destruct b. inv H0.
  destruct le. destruct ptr0; inv H. exists e. exists le. auto.
Qed.

Lemma integrity_nth: forall (X:Type) (n:node X) e i,
    node_integrity n ->
    InternNode n ->
    nth_entry i n = Some e ->
    exists k c, e = keychild X k c.
Proof.
  intros. destruct n. generalize dependent i.
  destruct b; simpl in H0. contradiction. simpl.
  induction l; intros.
  - simpl in H1. destruct i; simpl in H1; inv H1.
  - destruct i.
    + simpl in H. destruct o; try contradiction. inv H.
      simpl in H1. inv H1. exists k. exists n0. auto. simpl in H1.
      exists k. exists n0. inv H1. auto.
    + simpl in H1. apply IHl in H1. auto. simpl in H. simpl.
      destruct o; try contradiction. inv H. destruct i; inv H1. auto.
Qed.

Lemma integrity_nth_leaf: forall (X:Type) (n:node X) e i,
    node_integrity n ->
    LeafNode n ->
    nth_entry i n = Some e ->
    exists k v x, e = keyval X k v x.
Proof.
  intros. destruct n. generalize dependent i.
  destruct b; simpl in H0; try contradiction. simpl.
  induction l; intros.
  - destruct i; simpl in H1; inv H1.
  - destruct i.
    + simpl in H. destruct H. inv H2. simpl in H1. inv H1.
      exists k. exists v. exists x0. auto.
    + simpl in H1. apply IHl in H1. auto. simpl in H.
      simpl. destruct H. split; auto. inv H2. auto.
Qed.
  
Lemma Zsuccminusone: forall x,
    (Z.succ x) -1 = x.
Proof. intros. rep_omega. Qed.

Definition node_wf (n:node val) : Prop := (numKeys n <= Fanout)%nat.
Definition root_wf (root:node val) : Prop := forall n, subnode n root -> node_wf n.
Definition entry_wf (e:entry val) : Prop :=
  match e with
  | keyval _ _ _ => True
  | keychild _ c => root_wf c
  end. 

Lemma subchild_depth X (n ptr0: node X) le isLeaf First Last (x: X)
      (h: subchild n le):
  (node_depth n < node_depth (btnode X (Some ptr0) le isLeaf First Last x))%nat.
Proof.
  induction le; inversion h; simpl.
  + apply index.lt_max_split_l. destruct (listentry_depth). omega.
    apply lt_le_trans with (m := S (node_depth n)). omega.
    apply le_n_S, index.le_max_split_l. omega.
  + rewrite <- index.max_nat_assoc.
    apply index.lt_max_split_r.
    simpl in IHle.
    apply IHle. assumption.
Qed.

Lemma subnode_depth X: forall (n n': node X) (h: subnode n' n),
  (node_depth n' <= node_depth n)%nat.
Proof.
  induction 1.
 - omega.
 - transitivity (node_depth m); auto.
    simpl. apply index.le_max_split_r. omega. 
 - transitivity (node_depth m). auto.
    apply Nat.lt_le_incl, subchild_depth. assumption.
Qed.

Lemma subnode_equal_depth X (n root: node X) (hsub: subnode n root) (hdepth: node_depth n = node_depth root):
  n = root.
Proof.
  inversion hsub.
  - reflexivity.
  - apply subnode_depth in H.
    subst. simpl in hdepth.
    assert (h := index.le_r (listentry_depth le) (S (node_depth m))).
    rewrite <- hdepth in h. omega.
  - apply (subchild_depth X _ ptr0 le false First Last x) in H0.
    rewrite H2 in H0. apply subnode_depth in H. omega.
Qed.

(* With the new intern_le predicate, this <= can actually be =. TODO *)
Lemma partial_length': forall (X:Type) (c:cursor X) (root:node X) (n:node X),
    partial_cursor_correct c n root -> (length c <= node_depth root - node_depth n)%nat.
Proof.
  intros X c root n h.
  generalize dependent n.
  induction c.
  + intros n h.
    simpl in h. subst. simpl. omega.
  + intros n h. simpl. destruct a as [n' i]. simpl in h.
    specialize (IHc n' (proj1 h)).
    pose proof (subnode_depth _ _ _ (partial_cursor_subnode' _ _ _ _ (proj1 h))).
    pose proof (nth_node_decrease _ _ _ _ (proj2 h)). 
    omega.
Qed.

Lemma integrity_depth X (ptr0: node X) le F L x:
  let n := btnode X (Some ptr0) le false F L x in
  node_integrity n ->
  node_depth n = S (node_depth ptr0).
Proof.
  simpl.
  intro h.
  induction le. inversion h.
  inversion h.
  + subst. simpl. now rewrite max_refl.
  + subst. specialize (IHle H1).
    simpl. rewrite H3. case_eq (listentry_depth le).
    rewrite max_refl. easy.
    intros n0 hn0. rewrite hn0 in IHle.
    simpl in IHle |-*. rewrite (max_flip _ n0).
    injection IHle.
    intro heq. rewrite heq. now rewrite max_refl.
Qed.

Lemma node_depth_succ X (n n': node X) i (nint: node_integrity n) (n'int: node_integrity n') (h: nth_node i n' = Some n):
  node_depth n' = S (node_depth n).
Proof.
  pose proof (nth_subnode _ _ _ _ h) as nn'sub.
  pose proof (nth_node_decrease _ _ _ _ h) as nn'depth.
  (* n' is an internal node. *) 
  destruct n' as [[ptr0|] le [] F L x]; try easy.
  rewrite integrity_depth. f_equal.
  simpl in h.
  destruct i as [|i]. now inversion h.
  simpl in n'int.
  { clear -n'int h.
    generalize dependent le.
    induction i; destruct le; try easy; intros.
    inv n'int; now inv h.
    simpl in h. apply (IHi le).
    inv n'int. now destruct i. assumption. assumption. }
  assumption.
Qed.

Lemma partial_length'': forall (X:Type) (c:cursor X) (root:node X) (n:node X),
    root_integrity root ->
    partial_cursor_correct c n root -> (length c = node_depth root - node_depth n)%nat.
Proof.
  intros X c root n rint h.
  generalize dependent c. revert n.
  apply (Fix (well_founded_ltof (node X) (fun n => (node_depth root - node_depth n)%nat))
       (fun n => 
       forall c,
         partial_cursor_correct c n root -> Datatypes.length c = (node_depth root - node_depth n)%nat)).
  unfold ltof.
  intros n hind c hc.
  destruct c as [|[n' i'] c].
  - simpl in hc |-*. subst. omega.
  - pose proof (partial_cursor_subnode' _ _ _ _ hc) as hsub.
    pose proof (subnode_depth _ _ _ (partial_cursor_subnode' _ _ _ _ hc)).
    pose proof (nth_node_decrease _ _ _ _ (proj2 hc)).
    pose proof (subnode_depth _ _ _ (partial_cursor_subnode' _ _ _ _ (proj1 hc))).
    unshelve epose proof (hind n' _ c (proj1 hc)).
    omega.
    simpl. replace (node_depth n) with (node_depth n' - 1)%nat.
    omega. simpl in hc.
    rewrite (node_depth_succ _ n n' i').
    + omega.
    + now apply rint.
    + pose proof (partial_cursor_subnode' _ _ _ _ (proj1 hc)). now apply rint.
    + easy.
Qed.

Lemma partial_length: forall (X:Type) (c:cursor X) (root:node X) (n:node X),
    partial_cursor_correct c n root -> (length c <= node_depth root)%nat.
Proof.
  intros X c root n h.
  pose proof (partial_length' _ _ _ _ h).
  omega.
Qed.

Lemma partial_rel_length: forall (X:Type) (c:cursor X) (r:relation X),
    partial_cursor_correct_rel c r -> (0 <= length c <= get_depth r)%nat.
Proof.
  intros. unfold partial_cursor_correct_rel in H.
  destruct c as [|[n i] c']. simpl. omega.
  destruct (nth_node i n); try contradiction.
  apply partial_length in H. unfold get_depth. split. omega. auto.
Qed.

Lemma leaf_depth X (n: node X) (hintegrity: node_integrity n) (hleaf: LeafNode n): node_depth n = 0%nat.
Proof.
  destruct n as [[ptr0|] le [] F L x]; try easy.
  now simpl in hintegrity.
  simpl.
  replace (listentry_depth le) with 0%nat. easy.
  induction le. easy.
  simpl in hintegrity |-*. destruct hintegrity as [_ hintegrity].
  inversion hintegrity. simpl.
  now apply IHle.
Qed.

Lemma nth_entry_keyval_leaf X i (n: node X) k v x:
  node_integrity n -> nth_entry i n = Some (keyval X k v x) -> LeafNode n.
Proof.
  intros hint hentry.
  destruct n as [[ptr0|] le [] F L x']; try easy.
  exfalso. simpl in hint.
  generalize dependent le. induction i; destruct le; try easy.
  intro h. now inversion h.
  intros h hentry.
  simpl in hentry. inv h. now destruct i.
  now apply (IHi le).
Qed.

Lemma complete_rel_length: forall (X:Type) (c:cursor X) (r:relation X),
    root_integrity (get_root r) -> complete_cursor_correct_rel c r -> length c = S (get_depth r).
Proof.
  intros X c [rootnode prel] hint h.
  pose proof (hint _ (complete_cursor_subnode _ _ _ h)).
  unfold complete_cursor_correct_rel in h.
  destruct (getCEntry c); try contradiction.
  destruct e; try contradiction.
  destruct c as [|[n [|i]] c]; try easy.
  simpl in H, h |-*. f_equal.
  rewrite (partial_length'' _ c rootnode n); try easy.
  rewrite (leaf_depth _ n). unfold get_depth. simpl. omega. assumption.
  apply (nth_entry_keyval_leaf _ _ _ _ _ _ H (proj2 h)).
Qed.    

Definition complete_cursor (c:cursor val) (r:relation val) : Prop :=
  complete_cursor_correct_rel c r /\ root_integrity (get_root r).
Definition partial_cursor (c:cursor val) (r:relation val) : Prop :=
  partial_cursor_correct_rel c r /\ root_integrity (get_root r).
(* non-empty partial cursor: the level 0 has to be set *)
Definition ne_partial_cursor (c:cursor val) (r:relation val) : Prop :=
  partial_cursor_correct_rel c r /\ (O < length c)%nat.

Definition correct_depth (r:relation val) : Prop :=
  (get_depth r < MaxTreeDepth)%nat.

Lemma partial_complete_length: forall (c:cursor val) (r:relation val),
    ne_partial_cursor c r \/ complete_cursor c r ->
    correct_depth r ->
    (0 <= Zlength c - 1 < 20).
Proof.
  intros. destruct H.
  - unfold ne_partial_cursor in H. destruct H.
    split. destruct c. inv H1. rewrite Zlength_cons.
    rewrite Zsuccminusone. apply Zlength_nonneg.
    unfold correct_depth in H0.
    assert (length c < 20)%nat. rewrite MTD_eq in H0. apply partial_rel_length in H. omega.
    rewrite Zlength_correct. omega.
  - unfold complete_cursor in H. destruct H. rewrite Zlength_correct. apply complete_rel_length in H.
    rewrite H.
    split; rewrite Nat2Z.inj_succ; rewrite Zsuccminusone. omega.
    unfold correct_depth in H0. rep_omega. auto.
Qed.

Lemma partial_complete_length': forall (c:cursor val) (r:relation val),
    complete_cursor c r \/ partial_cursor c r->
    correct_depth r ->
    (0 <= Zlength c <= 20).
Proof.
  intros. destruct H.
  - unfold complete_cursor in H. destruct H. rewrite Zlength_correct. apply complete_rel_length in H.
    rewrite H.
    split; rewrite Nat2Z.inj_succ. omega.
    unfold correct_depth in H0. rep_omega. auto.
  - unfold partial_cursor in H. destruct H.
    split. destruct c. apply Zlength_nonneg. rewrite Zlength_cons. rep_omega.
    unfold correct_depth in H0.
    assert (length c < 20)%nat. rewrite MTD_eq in H0. apply partial_rel_length in H. omega.
    rewrite Zlength_correct. omega.
Qed.

Lemma complete_leaf: forall n i c r,
    complete_cursor ((n,i)::c) r ->
    root_integrity (get_root r) ->
    LeafNode n.
Proof.
  intros n i c r hcomplete hintegrity.
  destruct r as [rootnode prel], hcomplete as [hcomplete _].
  unshelve eassert (nintegrity := hintegrity n _). 
  replace n with (currNode ((n, i) :: c) (rootnode, prel)) by reflexivity. now apply complete_cursor_subnode.
  unfold complete_cursor_correct_rel in hcomplete.
  case_eq (getCEntry ((n, i) :: c)).
  + intros e he. rewrite he in hcomplete.
    destruct e; try contradiction.
    destruct i as [|i]; try contradiction.
    simpl in hcomplete.
    destruct n as [[ptr0|] le [] First Last x]; try easy. exfalso.
    simpl in nintegrity, he.
    apply (intern_no_keyval _ _ _ _ _ _ _ nintegrity he).
  + intro hnone.
    now rewrite hnone in hcomplete.
Qed.

(* This lemma shows that the isValid predicate is not what it should be: all complete cursors are valid. *)
Lemma complete_valid (r: relation val) (c: cursor val)
  (hcomplete: complete_cursor c r) (hint: root_integrity (get_root r)): isValid c r = true.
Proof.
  destruct r as [rootnode prel], c as [|[[ptr0 le [] First [] x] [|i]] c]; try easy;
    unfold isValid; simpl.
  + now compute in hcomplete.
  + replace (i =? numKeys_le le)%nat with false. reflexivity.
    symmetry. rewrite Nat.eqb_neq.
    pose proof (complete_correct_rel_index _ _ _ _ _ (proj1 hcomplete)) as h.
    simpl in h. rewrite <- Nat2Z.inj_lt in h. omega.
  + pose proof (complete_leaf _ _ _ _ hcomplete hint). easy.
Qed.
  
Lemma complete_partial_leaf: forall n i c r,
    complete_cursor ((n,i)::c) r \/
    partial_cursor ((n,i)::c) r ->
    LeafNode n ->
    complete_cursor ((n,i)::c) r.
Proof.
  intros n i c r h hleaf.
  destruct h as [h | h]. assumption. exfalso.
  unfold partial_cursor, partial_cursor_correct_rel in h.
  case_eq (nth_node i n).
  - now destruct n as [[ptr0|] le [] F L x].
  - intro hnone. now rewrite hnone in h.
Qed.

Lemma int_unsigned_ptrofs_toint: (* move these two into Floyd? *)
  Archi.ptr64 = false ->
  forall n : ptrofs,
  Int.unsigned (Ptrofs.to_int n) = Ptrofs.unsigned n.
Proof.
intros.
unfold Ptrofs.to_int.
rewrite Int.unsigned_repr; auto.
pose proof (Ptrofs.unsigned_range n).
rewrite Ptrofs.modulus_eq32 in H0 by auto.
rep_omega.
Qed.

Lemma int64_unsigned_ptrofs_toint:
  Archi.ptr64 = true ->
  forall n : ptrofs,
  Int64.unsigned (Ptrofs.to_int64 n) = Ptrofs.unsigned n.
Proof.
intros.
unfold Ptrofs.to_int64.
rewrite Int64.unsigned_repr; auto.
pose proof (Ptrofs.unsigned_range n).
rewrite Ptrofs.modulus_eq64 in H0 by auto.
rep_omega.
Qed.
