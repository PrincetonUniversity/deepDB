Require Import VST.floyd.functional_base VST.floyd.proofauto.
Require Import VST.floyd.library.
Require Import indices.ordered_interface.
Require Import btrees.btrees.
Require Import btrees.btrees_sep.
Require Import btrees.btrees_spec. 
Require Import indices.btree_wrappers.

Import OrderedIndex.


Definition bt_relation := btrees.relation val.
Definition bt_cursor := btrees.cursor val.

Definition put_record_rel (c: (bt_relation * bt_cursor)%type) 
  (k: btrees.key) (v: btrees.V) (vptr: val) 
  (cnew: (bt_relation * bt_cursor)%type): Prop := 
RL_PutRecord_rel (snd c) (fst c) k v vptr (fst cnew) (snd cnew).


Definition btree_index : index :=
  {| key := btrees.key;
     key_val := fun k => (Vptrofs k);
     key_type := size_t;

     value := btrees.V;
     value_repr := value_rep;

     t := relation val;
     t_type := trelation;

     t_repr := fun m p => !!(snd m = p) && relation_rep m;

     cursor := (bt_relation * bt_cursor)%type;

     cursor_repr := fun '(m, c) p => relation_rep m * cursor_rep c m p;
     cursor_type := tcursor;

     (* helpers *)
     valid_cursor := fun '(m, c) => isValid c m;
     norm := fun '(m, c) => (m, normalize c m);

     (* Props *)
    create_cursor_props := fun m p => 
        snd m <> nullval /\ root_integrity (get_root m) /\ correct_depth m /\ getvalr m = p;

    move_to_next_props := fun '(m, c) =>
        complete_cursor c m /\ correct_depth m /\ 
        root_wf (get_root m) /\ root_integrity (get_root m);

    move_to_first_props := fun '(m, c) => (c = empty_cursor) /\
        partial_cursor c m /\ root_integrity (get_root m) /\
        correct_depth m /\ root_wf (get_root m) /\ 
        getval (get_root m) <> Vundef /\
        complete_cursor (moveToFirst (get_root m) c 0) m;

    move_to_last_props := fun '(m, c) => (c = empty_cursor) /\
        partial_cursor c m /\ root_integrity (get_root m) /\ 
        correct_depth m /\
        root_wf (get_root m) /\ 
        complete_cursor (moveToLast val (get_root m) c 0) m;

    move_to_previous_props := fun '(m, c) => complete_cursor c m;

    go_to_key_props := fun '(m, c) =>
        complete_cursor c m /\ correct_depth m /\ 
        root_integrity (get_root m) /\ root_wf (get_root m);

    get_record_props := fun '(m, c) => 
       complete_cursor c m /\ correct_depth m /\ (isValid c m = true) /\
       root_wf (get_root m) /\ root_integrity (get_root m);

    put_record_props :=  fun '(m, c) => 
        complete_cursor c m /\ Z.succ (get_depth m) < MaxTreeDepth /\
        root_integrity (get_root m) /\ root_wf (get_root m) /\
        get_numrec m < Int.max_signed - 1;

    (* interface *)

     cardinality := fun '(m, c) => get_numrec m;

     create_cursor := fun m => (m, (first_cursor (get_root m)));

     create_index := btrees_spec.empty_relation_rel;

     move_to_next := fun '(m, c) => (m, (RL_MoveToNext c m));

     move_to_previous := fun '(m, c) => (m, (RL_MoveToPrevious c m));

     go_to_key := fun '(m, c) k => (m, goToKey c m k);

     move_to_first := fun '(m, c) =>  let (n, p) := m in (m, moveToFirst n empty_cursor O);

     get_record := fun '(m, c) => RL_GetRecord c m;

     put_record := put_record_rel;

     (* needs C function *)
     move_to_last := fun '(m, c) =>  let (n, p) := m in (m, moveToLast val n c (Zlength c));

   |}. 


Lemma sub_cardinality: funspec_sub (snd btree_wrappers.RL_NumRecords_spec)
(cardinality_spec btree_index).
Proof.
  do_funspec_sub. destruct w; simpl. 
  destruct p; simpl. Exists (b, b0, v, (get_numrec b)) emp.
  rewrite emp_sepcon.
  apply andp_right. 
  { entailer!. }
  { entailer!. entailer!. }
Qed. 

Lemma sub_create_index: funspec_sub (snd btrees_spec.RL_NewRelation_spec)
 (create_index_spec btree_index).
Proof. 
  do_funspec_sub. Exists w emp. destruct w; simpl.
  rewrite emp_sepcon.
  apply andp_right. 
  { entailer!. }
  { entailer!. entailer!. Exists x0 (getvalr x0). simpl. entailer!. }
Qed. 

Lemma sub_create_cursor: funspec_sub (snd btrees_spec.RL_NewCursor_spec)
(create_cursor_spec btree_index).
Proof.
  do_funspec_sub. destruct w; simpl. 
  destruct p; simpl. simpl in H. 
  Exists (r, g0) emp.
  rewrite emp_sepcon.
  apply andp_right. 
  { entailer!. }
  { entailer!. entailer!. Exists (eval_id ret_temp x). simpl. entailer!. }
Qed.

Lemma sub_get_record: funspec_sub (snd btrees_spec.RL_GetRecord_spec) 
(get_record_spec btree_index).
Proof. 
  do_funspec_sub. destruct w; simpl. destruct p; simpl.
  simpl in H. Exists (b, b0, v) emp.
  rewrite emp_sepcon. 
  apply andp_right.
  { entailer!. }
  { entailer!. entailer!. }
Qed. 

Lemma sub_move_to_first: funspec_sub (snd btree_wrappers.RL_MoveToFirst_spec)
  (move_to_first_spec btree_index) .
Proof. 
  do_funspec_sub. destruct w; simpl. destruct p; simpl.
  destruct p0; simpl. simpl in H. 
  Exists (b, b0, v, (get_root b), g0) emp.
  rewrite emp_sepcon.
  apply andp_right.
  { entailer!. }
  { entailer!. entailer!; destruct b; simpl; try auto; try entailer!. }
Qed.

Lemma sub_move_to_last: funspec_sub (btree_wrappers.RL_MoveToLast_spec) 
  (move_to_last_spec btree_index).
Proof. 
  do_funspec_sub. destruct w; simpl. destruct p; simpl.
  destruct p0; simpl. simpl in H. 
  Exists (b, b0, v, (get_root b), g0) emp.
  rewrite emp_sepcon.
  apply andp_right.
  { entailer. }
  { entailer!. entailer!; destruct b; simpl; try auto; try entailer!. 
     unfold empty_cursor. rewrite Zlength_nil. cancel. }
Qed.


Lemma sub_go_to_key: funspec_sub (snd btrees_spec.goToKey_spec)
  (go_to_key_spec btree_index).
Proof. 
  do_funspec_sub. destruct w; simpl. 
  destruct p; destruct p; simpl.
  simpl in H.
  Exists (b0, v, b, k) emp.
  rewrite emp_sepcon.
  apply andp_right.
  { entailer!. }
  { entailer!. }
Qed.


Lemma sub_move_to_next: funspec_sub (snd btrees_spec.RL_MoveToNext_spec)
  (move_to_next_spec btree_index).
Proof. 
  do_funspec_sub. destruct w; simpl. 
  destruct p; simpl.
  simpl in H.
  Exists (b0, v, b) emp.
  rewrite emp_sepcon.
  apply andp_right.
  { entailer!. }
  { entailer!. }
Qed.

Lemma sub_move_to_previous: funspec_sub (snd btrees_spec.RL_MoveToPrevious_spec)
  (move_to_previous_spec btree_index).
Proof. 
  do_funspec_sub. destruct w; simpl. 
  destruct p; simpl.
  simpl in H.
  Exists (b0, v, b) emp.
  rewrite emp_sepcon.
  apply andp_right.
  { entailer!. }
  { entailer!. }
Qed.

Lemma sub_put_record: funspec_sub (snd btrees_spec.RL_PutRecord_spec)
  (put_record_spec btree_index).
Proof. 
  do_funspec_sub. simpl in H. 
  Exists w emp.
  rewrite emp_sepcon.
  apply andp_right.
  { destruct w; try repeat destruct p.
    simpl; entailer!. }
  { destruct w; try repeat destruct p. entailer!. entailer!.
     Exists (x1, x0). entailer!. }
Qed.