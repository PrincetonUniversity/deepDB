Require Import VST.progs.conclib.
Require Import VST.floyd.proofauto.
Require Import VST.floyd.library.
Require Import bst.bst_conc_lemmas2.
Require Import VST.atomics.general_locks.
Require Import VST.atomics.SC_atomics.
Require Import Coq.Sets.Ensembles.
Require Import VST.msl.iter_sepcon.
Require Import bst.bst_conc_nblocking4.


Definition atomic_ptr := Tstruct _atom_ptr noattr.
Variable atomic_ptr_at : share -> val -> val -> mpred.
Hypothesis atomic_ptr_at__ : forall sh v p, atomic_ptr_at sh v p |-- atomic_ptr_at sh Vundef p.
Definition t_struct_tree := Tstruct _tree noattr.
(* Definition t_struct_list := Tstruct _list noattr. *)
Definition t_struct_operation := Tstruct _operation noattr.
Definition t_struct_child_cas_operation := Tstruct _child_cas_operation noattr.
Definition t_struct_relocate_operation := Tstruct _relocate_operation noattr.
(* Definition t_arr := Tarray (tptr t_struct_list ) 5 noattr. *)



 Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.


(* Definition surely_malloc_spec :=
  DECLARE _surely_malloc
   WITH t:type, gv: globals
   PRE [ _n OF tuint ]
       PROP (0 <= sizeof t <= Int.max_unsigned;
                complete_legal_cosu_type t = true;
                natural_aligned natural_alignment t = true)
       LOCAL (temp _n (Vint (Int.repr (sizeof t))); gvars gv)
       SEP (mem_mgr gv)
    POST [ tptr tvoid ] EX p:_,
       PROP ()
       LOCAL (temp ret_temp p)
       SEP (mem_mgr gv; malloc_token Ews t p * data_at_ Ews t p). *)


Fixpoint ghost_tree_rep (t: @ ghost_op_tree val ) (nb:val) (g_current:gname) (g:gname) (g_op:gname) range : mpred := 
 match t, range with
 | E_op , _ => atomic_ptr_at Ews nullval nb * ghost_master1 (ORD := range_order)  (range,  (@None ghost_info)) g_current 
 | (T_op a ga lp x v vp o aop b gb rp ), (l, r) =>  (EX tp, EX op, EX sh, !!(readable_share sh  /\ Int.min_signed <= x <= Int.max_signed/\ is_pointer_or_null lp /\ is_pointer_or_null rp /\ is_pointer_or_null vp  ) && 
   atomic_ptr_at Ews tp nb * atomic_ptr_at Ews v vp * atomic_ptr_at Ews op aop *
  (match o with | Some o' => in_tree_op g_op o' *  match o' with |ADD_op b' x' v' => EX rop, EX t, EX e, EX u, EX vp', EX aop', EX lp', EX rp', EX op', malloc_token Ews t_struct_operation op * data_at Ews t_struct_operation (rop, Vint (Int.repr t)) op * data_at Ews t_struct_child_cas_operation (Vint (Int.repr (if(b') then 1 else 0 )), (e, u)) rop 
  																																									* data_at sh t_struct_tree (Vint (Int.repr x'),(vp',(aop',(lp',rp')))) u * atomic_ptr_at Ews v' vp' * atomic_ptr_at Ews op' aop' * data_at Ews t_struct_operation (nullval, Vint (Int.repr 0)) op' * atomic_ptr_at Ews nullval lp' * atomic_ptr_at Ews nullval rp' 
                                           | DELETE_op b' x' => EX rop, EX t, malloc_token Ews t_struct_operation op * data_at Ews t_struct_operation (rop, Vint (Int.repr t)) op  end
                | None => !!(op = nullval) && emp end) * 
   data_at sh t_struct_tree (Vint (Int.repr x),(vp,(aop,(lp,rp)))) tp * malloc_token Ews t_struct_tree tp *
   ghost_master1 (ORD := range_order)  (range,  (@Some ghost_info (x,vp,ga,gb))) g_current *
   in_tree ga (l, Finite_Integer x) lp g * in_tree gb ( Finite_Integer x, r) rp g *
   ghost_tree_rep a  lp ga g g_op(l, Finite_Integer x) * ghost_tree_rep b rp gb g g_op (Finite_Integer x, r)
  ) end.


Definition tree_rep2 (g:gname) (g_op:gname) (g_root:gname) (nb:val) (sh:share) (t: @tree val  ) : mpred := EX (tg:ghost_op_tree), !! (find_pure_tree2 tg = t) && ghost_tree_rep tg  nb g_root g g_op (Neg_Infinity, Pos_Infinity) 
                                                                                                                                 * bst_conc_lemmas2.ghost_ref g (find_ghost_set2 tg g_root ( Neg_Infinity, Pos_Infinity) nb) 
                                                                                                                                 * bst_conc_lemmas2.ghost_ref_op g_op (find_op_set tg).                                    


Definition nodebox_rep (sh : share) (nb: val) ( rnb: val) (g_root: gname) (g:gname)  :=  EX tp:val, EX rtp:val, EX vp:val, EX aop:val, EX lp:val,  EX lop: list val,  atomic_ptr_at sh tp nb * malloc_token Ews t_struct_tree tp * data_at sh t_struct_tree (Vint (Int.repr (-1)),(vp,(aop,(lp,rnb)))) tp *  atomic_ptr_at sh rtp rnb * iter_sepcon ( fun p => EX sh1:share, data_at_ sh1 t_struct_tree p ) lop * in_tree g_root (Neg_Infinity, Pos_Infinity) rnb g.

Program Definition find_spec :=
  DECLARE _find
  ATOMIC TYPE (rmaps.ConstType ( val * val * share* Z * val * val * val * val * Z * val * globals * gname * gname * gname))
         OBJ BST INVS base.empty base.top
  WITH b, nb, sh, x, pred, pred_op, curr, curr_op, n, v, gv, g, g_op, g_root
  PRE [ _key OF tint, _pred OF (tptr (tptr atomic_ptr)), _pred_op OF (tptr (tptr tvoid)), _curr OF (tptr (tptr atomic_ptr)), _curr_op OF (tptr (tptr tvoid)), _auxRoot OF (tptr atomic_ptr), _thread_num OF tint, _v OF (tptr (tptr tvoid)) ]
    PROP (
          Int.min_signed <= x <= Int.max_signed)
    LOCAL (temp _auxRoot b; temp _key (Vint (Int.repr x)); temp _pred pred; temp _pred pred; temp _pred_op pred_op; temp _curr curr; temp _curr_op curr_op; temp _thread_num (Vint (Int.repr n)); temp _v v; gvars gv)
    SEP  (mem_mgr gv; nodebox_rep sh b nb g_root g) |
  (!! sorted_tree BST && data_at_ Ews (tptr tvoid) v * tree_rep2 g g_op g_root nb sh BST)
  POST [tint ]
    EX ret: Z,
    PROP ()
    LOCAL (temp ret_temp (vint ret))
    SEP (mem_mgr gv; nodebox_rep sh b nb g_root g) |
        ( EX vp:val,  !! (sorted_tree BST /\ (if eq_dec ret 3 then vp <> Vundef else vp <> Vundef ) /\ vp = (bst_conc_lemmas2.lookup nullval x BST)) &&  data_at Ews (tptr tvoid) vp v * tree_rep2 g g_op g_root nb sh BST).
 
Program Definition add_spec :=
  DECLARE _add
  ATOMIC TYPE (rmaps.ConstType ( val * share* Z * Z * val * globals * gname * gname * gname))
         OBJ BST INVS base.empty base.top
  WITH  nb, sh, x,  n, v, gv, g, g_op, g_root
  PRE [ _key OF tint,  _value OF (tptr tvoid), _thread_num OF tint ]
    PROP (
          Int.min_signed <= x <= Int.max_signed)
    LOCAL (temp _key (Vint (Int.repr x)); temp _thread_num (Vint (Int.repr n)); temp _value v; gvars gv)
    SEP  (mem_mgr gv; nodebox_rep sh (gv _base_root) nb g_root g) |(!! sorted_tree BST && tree_rep2 g g_op g_root nb sh BST)
  POST [Tvoid ]
    PROP ()
    LOCAL ()
    SEP (mem_mgr gv; nodebox_rep sh (gv _base_root) nb g_root g) | (!!(sorted_tree (bst_conc_lemmas2.insert x v BST))&& tree_rep2 g g_op g_root nb sh (bst_conc_lemmas2.insert x v BST)).

Program Definition delete_spec :=
  DECLARE _delete
  ATOMIC TYPE (rmaps.ConstType ( val * share* Z * Z * val * globals * gname * gname * gname))
         OBJ BST INVS base.empty base.top
  WITH nb, sh, x,  n, v, gv, g, g_op, g_root
  PRE [ _key OF tint, _thread_num OF tint ]
    PROP (
          Int.min_signed <= x <= Int.max_signed)
    LOCAL (temp _key (Vint (Int.repr x)); temp _thread_num (Vint (Int.repr n)); gvars gv)
    SEP  (mem_mgr gv; nodebox_rep sh (gv _base_root) nb g_root g) |(!! sorted_tree BST && tree_rep2 g g_op g_root nb sh BST)
  POST [Tvoid ]
    PROP ()
    LOCAL ()
    SEP (mem_mgr gv; nodebox_rep sh (gv _base_root) nb g_root g) | (!!(sorted_tree (bst_conc_lemmas2.delete x BST))&& tree_rep2 g  g_op g_root nb sh (bst_conc_lemmas2.delete x BST)).

 
 (* Program Definition helpMarked_spec :=
  DECLARE _helpMarked
  ATOMIC TYPE (rmaps.ConstType ( val * val * Z * val * val * val* val * val * val * Z * val * val * val * val  * Z * share * gname * gname * globals)) OBJ BST INVS base.empty base.top
  WITH  nb, pred, x, vp, op, lp, rp, pred_op, curr, x', vp', op', lp', rp', n, sh, g, g_root, gv
  PRE [  _pred OF (tptr t_struct_tree), _pred_op OF  (tptr Tvoid), _curr OF (tptr t_struct_tree), _thread_num OF tint ]
          PROP (readable_share sh;Int.min_signed <= x <= Int.max_signed; Int.min_signed <= x' <= Int.max_signed)
          LOCAL (temp _pred pred ; temp _pred_op pred_op; temp _curr curr; temp _thread_num (Vint (Int.repr n));  gvars gv )
          SEP  (mem_mgr gv; data_at sh t_struct_tree (Vint (Int.repr x),(op,(vp,(lp,rp)))) pred; data_at sh t_struct_tree (Vint (Int.repr x'),(op',(vp',(lp',rp')))) curr; atomic_ptr_at Ews pred_op op (* field_at Ews t_arr (SUB _thread_num) l (gv _rp); listrep Ews lv l *)  ) | (!!(sorted_tree BST)&&tree_rep2 g g_root nb sh BST )
  POST[ tvoid ]
  EX o':val,
        PROP ()
        LOCAL ()
       SEP (mem_mgr gv; data_at sh t_struct_tree (Vint (Int.repr x),(op,(vp,(lp,rp)))) pred; data_at sh t_struct_tree (Vint (Int.repr x'),(op',(vp',(lp',rp')))) curr; atomic_ptr_at Ews o' op (* ;   field_at Ews t_arr (SUB _thread_num) l (gv _rp);  listrep Ews lv' l *) ) | (!!(sorted_tree  BST)&&tree_rep2 g g_root  nb sh BST).


Program Definition helpRelocate_spec :=
  DECLARE _helpRelocate
  ATOMIC TYPE (rmaps.ConstType ( val * val * val * val * val * Z * Z * val * val * Z * val * val * val* val * val * val * Z * val * val * val * val  * Z * share * gname * gname * globals)) OBJ BST INVS base.empty base.top
  WITH  nb, ro, s, d, d_op, rem_k, rep_key, rep_val, pred, x, vp, o, lp, rp, pred_op, curr, x', vp', op', lp', rp', n, sh, g, g_root, gv
  PRE [  _op OF (tptr t_struct_relocate_operation), _pred OF (tptr t_struct_tree), _pred_op OF  (tptr tvoid), _curr OF (tptr t_struct_tree), _thread_num OF tint ]
          PROP (readable_share sh;Int.min_signed <= x <= Int.max_signed; Int.min_signed <= x' <= Int.max_signed)
          LOCAL (temp _op ro; temp _pred pred;temp _pred_op pred_op; temp _curr curr; temp _thread_num (Vint (Int.repr n));  gvars gv )
          SEP  (mem_mgr gv;  @data_at CompSpecs sh t_struct_relocate_operation (s,(d,(d_op,( Vint(Int.repr rem_k),(Vint(Int.repr rep_key),rep_val ))))) ro; @data_at CompSpecs sh t_struct_tree (Vint (Int.repr x),(o,(vp,(lp,rp)))) pred; @data_at CompSpecs sh t_struct_tree (Vint (Int.repr x'),(op',(vp',(lp',rp')))) curr (* field_at Ews t_arr (SUB _thread_num) l (gv _rp); listrep Ews lv l *)  ) | (!!(sorted_tree BST)&&tree_rep2 g g_root nb sh BST )
  POST [tint] 
  EX v:Z,
        PROP ()
        LOCAL (temp ret_temp (vint v))
       SEP (mem_mgr gv;  data_at sh t_struct_relocate_operation (s,(d,(d_op,( Vint(Int.repr rem_k),(Vint(Int.repr rep_key),rep_val ))))) ro; data_at sh t_struct_tree (Vint (Int.repr x),(o,(vp,(lp,rp)))) pred; data_at sh t_struct_tree (Vint (Int.repr x'),(op',(vp',(lp',rp')))) curr (* ;   field_at Ews t_arr (SUB _thread_num) l (gv _rp);  listrep Ews lv' l *) ) | ( if eq_dec v 0 then (!!(sorted_tree BST)&&tree_rep2 g g_root nb sh BST ) else (!!(sorted_tree (bst_conc_lemmas2.delete rem_k BST))&&tree_rep2 g g_root  nb sh (bst_conc_lemmas2.delete rem_k BST))). 
 *)
Definition main_spec :=
 DECLARE _main
  WITH gv : globals
  PRE  [] main_pre prog tt nil gv
  POST [ tint ] main_post prog nil gv.
  
Definition acquire_spec := DECLARE _acquire acquire_spec.
Definition release2_spec := DECLARE _release2 release2_spec.
Definition makelock_spec := DECLARE _makelock (makelock_spec _).
Definition freelock2_spec := DECLARE _freelock2 (freelock2_spec _).
Definition spawn_spec := DECLARE _spawn spawn_spec.
Definition atomic_load_ptr_spec := DECLARE _atomic_load_ptr (atomic_load_ptr_spec atomic_ptr atomic_ptr_at).
Definition atomic_store_ptr_spec := DECLARE _atomic_store_ptr (atomic_store_ptr_spec atomic_ptr atomic_ptr_at).
Definition atomic_CAS_ptr_spec := DECLARE _atomic_CAS_ptr (atomic_CAS_ptr_spec atomic_ptr atomic_ptr_at).
Definition make_atomic_ptr_spec := DECLARE _make_atomic_ptr ( make_atomic_ptr_spec atomic_ptr atomic_ptr_at).
(* Definition free_atomic_ptr_spec := DECLARE _free_atomic_ptr ( free_atomic_ptr_spec atomic_ptr atomic_ptr_at). *)

Definition Gprog : funspecs :=
    ltac:(with_library prog [acquire_spec; release2_spec; makelock_spec;
    freelock2_spec;
    atomic_load_ptr_spec;
    atomic_store_ptr_spec;
    atomic_CAS_ptr_spec;
    make_atomic_ptr_spec;
    spawn_spec;
    main_spec 
  ]).
  
  Lemma split_non_bot_share sh :
   (sh <> Share.bot) ->
  exists sh1, exists sh2,
     (sh1 <> Share.bot) /\
     (sh2 <> Share.bot) /\
    sepalg.join sh1 sh2 sh.
Proof.
  intros.
  destruct (Share.split sh) as (sh1, sh2) eqn: Hsplit.
  exists sh1, sh2; split; [|split]; auto.
  intro X. contradiction H. apply (Share.split_nontrivial sh1 sh2 sh) . auto. left. auto.
  intro X. contradiction H. apply (Share.split_nontrivial sh1 sh2 sh) . auto. right. auto.
  apply split_join; auto.
Qed.
   
Lemma in_tree_split: forall g_in range p g, in_tree g_in range p g |-- in_tree g_in range p g * in_tree g_in range p g.
Proof.
intros. unfold in_tree. Intro sh. assert_PROP ( sh <> Share.bot).  { unfold ghost_part. sep_apply (own_valid (RA := ref_PCM (@ map_PCM gname range_info )) g ((Some (sh, ghosts.singleton  g_in (range, p)), None) ) compcert_rmaps.RML.R.NoneP). entailer!. inv H. simpl in H0. contradiction. } apply split_non_bot_share in H. destruct H as ( sh1 & sh2 & H1 & H2 & H).
Exists sh1 sh2. rewrite <- (ghost_part_join (P := @ map_PCM gname range_info)  sh1 sh2 sh  (ghosts.singleton g_in (range, p))  (ghosts.singleton  g_in (range, p))).
cancel. auto. { unfold sepalg.join. hnf. intro. hnf. simpl. destruct (ghosts.singleton  g_in (range, p) k). 
  -  apply psepalg.lower_Some. unfold sepalg.join. hnf. split; hnf. rewrite merge_self;auto. split;auto.
  - apply psepalg.lower_None1. 
  } auto. auto. 
 Qed.
 
Definition node_data (info: option ghost_info) g  tp lp rp aop v (range:number * number)  :=  
(match info with Some data =>  EX sh, !!(readable_share sh  /\ Int.min_signed <= data.1.1.1 <= Int.max_signed/\ is_pointer_or_null lp /\ is_pointer_or_null rp /\ is_pointer_or_null data.1.1.2 /\  is_pointer_or_null data.1.1.2  ) &&  atomic_ptr_at Ews v data.1.1.2  * malloc_token Ews t_struct_tree tp *
 data_at sh t_struct_tree (Vint (Int.repr data.1.1.1),(data.1.1.2,(aop,(lp,rp)))) tp * in_tree  data.1.2 ( fst range, Finite_Integer (data.1.1.1)) lp g * in_tree data.2 ( Finite_Integer (data.1.1.1), snd range) rp g | None => !!(tp = nullval /\ lp = nullval /\ rp = nullval /\ v = nullval /\ aop = nullval) && emp end).  

Definition node_information (info: option ghost_info) range g g_current tp lp rp aop v np  :=  atomic_ptr_at Ews tp np * ghost_master1 (ORD := range_order)  (range, info) g_current * 
node_data info g tp lp rp aop v range.

Lemma node_data_R: forall (info: option ghost_info) g  tp lp rp aop v (range:number *number),  node_data info g tp  lp rp aop v range |-- if (eq_dec tp nullval) then !!(info = None /\ lp = nullval /\ rp = nullval /\ v = nullval) && emp  else 
EX data, EX sh, !!(readable_share sh/\ info = Some data  /\ Int.min_signed <= data.1.1.1 <= Int.max_signed/\ is_pointer_or_null lp /\ is_pointer_or_null rp /\ is_pointer_or_null data.1.1.2) &&  atomic_ptr_at Ews v data.1.1.2* malloc_token Ews t_struct_tree tp*  data_at sh t_struct_tree (Vint (Int.repr data.1.1.1),(data.1.1.2, ( aop,(lp,rp)))) tp * in_tree data.1.2( fst range, Finite_Integer data.1.1.1) lp g * in_tree data.2 ( Finite_Integer data.1.1.1, snd range) rp g.
Proof.
(* intros. unfold node_data.
destruct info.
- Intros sh.  assert_PROP (tp <> nullval).  { entailer!. } destruct (eq_dec tp nullval). contradiction. Exists g0 sh. entailer!.
- Intros. destruct (eq_dec tp nullval). entailer!. contradiction. *)
Admitted.

Definition node_data_op (info: option ghost_info) g g_op  tp lp rp aop op v (range:number * number) (o:option(@operation val)) :=  
(match info with Some data =>  EX sh, !!(readable_share sh  /\ Int.min_signed <= data.1.1.1 <= Int.max_signed/\ is_pointer_or_null lp /\ is_pointer_or_null rp /\ is_pointer_or_null data.1.1.2 /\  is_pointer_or_null data.1.1.2  ) &&  atomic_ptr_at Ews v data.1.1.2  * malloc_token Ews t_struct_tree tp *
 atomic_ptr_at Ews op aop * ( match o with |Some o' => in_tree_op g_op o' * match o' with | ADD_op b' x' v' => EX rop, EX t, EX e, EX u,EX vp', EX aop', EX lp', EX rp', EX op', malloc_token Ews t_struct_operation op * data_at Ews t_struct_operation (rop, Vint (Int.repr t)) op * data_at Ews t_struct_child_cas_operation (Vint (Int.repr (if b' then 1 else 0 )), (e, u)) rop
                                                        * data_at sh t_struct_tree (Vint (Int.repr x'),(vp',(aop',(lp',rp')))) u * atomic_ptr_at Ews v' vp' * atomic_ptr_at Ews op' aop' * data_at Ews t_struct_operation (nullval, Vint (Int.repr 0)) op' * atomic_ptr_at Ews nullval lp' * atomic_ptr_at Ews nullval rp'             
                                                       | DELETE_op b' x' => EX rop, EX t, malloc_token Ews t_struct_operation op * data_at Ews t_struct_operation (rop, Vint (Int.repr t)) op   end
                                            |None => emp end) *
 data_at sh t_struct_tree (Vint (Int.repr data.1.1.1),(data.1.1.2,(aop,(lp,rp)))) tp * in_tree  data.1.2 ( fst range, Finite_Integer (data.1.1.1)) lp g * in_tree data.2 ( Finite_Integer (data.1.1.1), snd range) rp g | None => !!(tp = nullval /\ lp = nullval /\ rp = nullval /\ v = nullval /\ aop = nullval/\ op = nullval ) && emp end).  

Definition node_information_op (info: option ghost_info) range g g_op g_current tp lp rp aop op v np o  :=   atomic_ptr_at Ews tp np * ghost_master1 (ORD := range_order)  (range, info) g_current * 
node_data_op info g g_op tp lp rp aop op v range o.

Definition node_information_of_child (is_left:bool) (info_parent: option ghost_info) (info_child:option ghost_info) n n0 g  np tp lp rp aop v := match info_parent with 
| Some data => (atomic_ptr_at Ews tp np *  ghost_master1 (ORD := range_order)  (if is_left then (Finite_Integer data.1.1.1, n0) else (n, Finite_Integer data.1.1.1), info_child) (if is_left then data.1.2 else data.2 ) *
               (match info_child with |Some data1 => EX sh, !!(readable_share sh /\ Int.min_signed <= data1.1.1.1 <= Int.max_signed/\ is_pointer_or_null lp /\ is_pointer_or_null rp /\ is_pointer_or_null data1.1.1.2 ) && atomic_ptr_at Ews v data1.1.1.2  * malloc_token Ews t_struct_tree tp * atomic_ptr_at Ews nullval aop *  data_at sh t_struct_tree (Vint (Int.repr data1.1.1.1),(data1.1.1.2,(aop,(lp,rp)))) tp * in_tree  data1.1.2 ( (if is_left  then Finite_Integer data.1.1.1 else n), Finite_Integer data1.1.1.1) lp g * in_tree data1.2 ( Finite_Integer data1.1.1.1, (if is_left then n0 else Finite_Integer data.1.1.1)) rp g
                                     | None => emp end))
| None =>  emp end. 
Definition get_range_from_parent (is_left:bool) (n n0:number) (o:option ghost_info) := match o with 
                  | Some data => if is_left then ( Finite_Integer data.1.1.1, n0) else  (n, Finite_Integer data.1.1.1) 
                  | None => (n0,n) end.
Lemma in_tree_delete : forall g s (o:@operation val), in_tree_op g o  * ghost_ref_op g s |-- (|==> ghost_ref_op g (Ensembles.Subtract s o ))%I.
Proof.
Admitted.

Lemma extract_node_info_op_from_ghost_tree_rep:  forall  tg np nb g_root g_current g g_op (r_root: number * number) n n0 (o': @operation val) lp rp,
   Ensembles.In (find_op_set tg ) o' -> (find_ghost_set2 tg g_root r_root nb) g_current = Some (n, n0,np) -> ghost_tree_rep tg nb g_root g g_op r_root  |--  EX tp:val,  EX o:option ghost_info, EX aop: val, EX v:val, EX op,
    node_information_op o (n, n0) g g_op g_current tp  lp rp aop v np op  ( Some o') * 
   ( match o' with | ADD_op b' x' v' => node_information_of_child b' o None n n0 g (if b' then rp else lp) nullval nullval nullval nullval nullval *  ((ALL g1 g2:gname,ALL tp1:val, ALL lp1:val, ALL rp1:val, ALL vp:val, ALL aop:val,
                                        node_information_op o (n, n0) g g_op g_current tp  lp rp aop v np op None * node_information_of_child b' o (Some(x',vp,g1,g2)) n n0 g (if b' then rp else lp) tp1 lp1 rp1 aop v' * node_information_op None (left (get_range_from_parent b' n n0 o), Finite_Integer x') g g_op g1 nullval nullval nullval nullval nullval nullval lp1 None *
                                       node_information_op None (Finite_Integer x', right(get_range_from_parent b' n n0 o)) g g_op g2 nullval nullval nullval nullval nullval nullval rp1 None) -* (EX tg', !!(find_pure_tree2 tg = find_pure_tree2 tg' /\ find_op_set tg' = Ensembles.Subtract (find_op_set tg) o') && ghost_tree_rep tg' nb g_root g g_op r_root))
                  | DELETE_op b' x' => EX lp1, EX rp1, EX v, EX aop, EX tp1, EX vp, EX g1, EX g2, node_information_of_child b' o (Some(x',vp,g1,g2)) n n0 g (if b' then rp else lp) tp1 lp1 rp1 aop v * (node_information_op o (n, n0) g g_op g_current tp  lp rp aop v np nullval  None -* (EX tg', !!(find_pure_tree2 tg = find_pure_tree2 tg' /\ find_op_set tg' = Ensembles.Subtract (find_op_set tg) o') && ghost_tree_rep tg' nb g_root g g_op r_root)) end).

Proof.
intros.
revert dependent g_root.
revert dependent r_root.
induction tg;intros.  
Admitted.

Lemma ghost_master1_alloc : forall r:node_info,
  emp |-- (|==> (EX g, ghost_master1 r g))%I.
Proof.
 intros.
 unfold ghost_master1, ghost_master.
 iIntros "e".
  iMod (own_alloc (RA := snap_PCM) (Tsh,r) compcert_rmaps.RML.R.NoneP with "e") as (g) "p".
 simpl;auto.
 iModIntro.
 iExists g.
 iFrame. 
Qed.


Inductive range_info_in_tree (ri: node_info)
          (range: number * number) (v :val) : ghost_op_tree -> Prop :=
| riit_none: (ri = (range, None)) /\ v = nullval -> range_info_in_tree ri range v E_op
| riit_root: forall (l r: ghost_op_tree) (g1 g2: gname) (lp rp:val) k vp aop o v',
    (ri = (range, Some (k, vp, g1, g2)) /\ v = v')  ->
    range_info_in_tree ri range v (T_op l g1 lp k v' vp aop o r g2 rp)
| riit_left: forall (l r: ghost_op_tree) (g1 g2: gname) (lp rp:val) k vp aop o v',
    range_info_in_tree ri (range.1, Finite_Integer k) v l ->
    range_info_in_tree ri range v (T_op l g1 lp k v' vp aop o r g2 rp)
| riit_right: forall (l r: ghost_op_tree) (g1 g2: gname) (lp rp:val) k vp aop o v',
    range_info_in_tree ri (Finite_Integer k, range.2) v r ->
    range_info_in_tree ri range v (T_op l g1 lp k v' vp aop o r g2 rp).

(*Lemma extract_node_info_from_ghost_tree_rep:  forall  tg np b g_root g_current g (r_root: number * number) (range:number*number),
   (find_ghost_set2 tg g_root r_root b) g_current = Some (range,np) -> ghost_tree_rep tg b g_root g r_root  |--  EX tp:val,  EX o:option ghost_info, EX lp:val, EX rp:val, EX aop: val, EX v:val, 
    node_information o range g g_current tp  lp rp aop v np  *
   (node_information o range g g_current tp  lp rp aop v np  -* ghost_tree_rep tg b g_root g r_root).
Proof.
 intros.
revert dependent b.
revert dependent g_root.
revert dependent r_root.
induction tg;intros. 
  -  inv H. destruct r_root. destruct range. unfold ghosts.singleton in H1. Exists nullval.  Exists (@None ghost_info) nullval nullval nullval nullval. unfold node_information;simpl. simpl in *. entailer!.
    (*  { apply  riit_none. destruct (eq_dec g_current g_root). inv H1. split;auto. discriminate. } *) destruct (eq_dec g_current g_root). inv H1. cancel. apply wand_frame_intro'. rewrite sepcon_emp;rewrite pull_left_special0. Intros. cancel. discriminate.
  -  intros. simpl in H. unfold map_upd in H. destruct (eq_dec g_current g_root). 
     * inv H. destruct range. simpl in *.  Intros tp op sh . Exists  tp (Some ( k, v1, g0, g1)) v v3 v2 v0. unfold node_information. simpl in *. Exists sh . entailer!.
       (* { apply riit_root. split;auto. } *) rewrite <- wand_sepcon_adjoint. Intros sh1.  Exists tp op sh1. entailer!.
     * unfold map_add in H. destruct r_root. simpl in *. remember (find_ghost_set2 tg1 g0 (n0, Finite_Integer k) v g_current) as left_set. destruct left_set.
        ** Intros rtp op sh. sep_apply IHtg1. rewrite <- Heqleft_set. apply H.  Intros tp o0 lp rp aop v4 . Exists tp o0 lp rp aop v4 . entailer!.
            (* { apply  riit_left. auto. } *)
             rewrite -> 8sepcon_assoc.  rewrite <- (emp_wand (atomic_ptr_at Ews rtp b * _)) . rewrite wand_sepcon_wand. apply wand_derives.
             rewrite -> sepcon_emp;auto. Exists rtp op sh . entailer!.
        ** Intros rtp op sh. sep_apply IHtg2.  Intros tp o0 lp rp aop v4 . Exists tp o0 lp rp aop v4. entailer!. 
            (* { apply  riit_right. auto. } *)
              rewrite -> 8sepcon_assoc.  rewrite <- (emp_wand (atomic_ptr_at Ews rtp b * _)) . rewrite wand_sepcon_wand. apply wand_derives.
             rewrite -> sepcon_emp;auto. Exists rtp op sh . entailer!.
Qed. 

*)
(*
Lemma range_info_in_tree_In: forall tg x vp ga gb range v r_root,
    range_info_in_tree (range,  Some (x, vp, ga, gb)) r_root v tg ->
   bst.bst_conc_lemmas.In x (find_pure_tree tg).
Proof.
  intros. revert tg range r_root H. induction tg; intros;inversion H; inversion H0;
  simpl. inv H1.
  - inv H1.  apply InRoot. inv H11;auto.
  - apply InLeft. eapply IHtg1; eauto.
  - apply InRight. eapply IHtg2; eauto.
Qed.

Lemma sorted_tree_look_up_in: forall x v vp ga gb tg range r_root,
    sorted_tree (find_pure_tree tg) ->
    range_info_in_tree (range, Some (x, vp, ga, gb)) r_root v tg ->
    bst.bst_conc_lemmas.lookup nullval x (find_pure_tree tg) = v.
Proof.
  intros. revert tg range r_root H H0. induction tg; intros;
  inversion H0; inversion H1. inv H. simpl. auto.
  - inv H2. inv H12. simpl. now rewrite Z.ltb_irrefl.
  - inv H.  specialize (IHtg1 _ _ H16 H2). red in H18. apply range_info_in_tree_In in H2.
    specialize (H18 _ H2). cut (x <? k = true).
    + intros. simpl. now rewrite H.
    + rewrite Z.ltb_lt. lia.
  - inv H. specialize (IHtg2 _ _ H17 H2). red in H19. apply range_info_in_tree_In in H2.
    specialize (H19 _ H2). assert (k <? x = true) by now rewrite Z.ltb_lt. simpl.  rewrite H.
    intros. assert (x <? k = false) by (rewrite Z.ltb_ge; lia). now rewrite H1.
Qed.

Lemma range_info_in_tree_IsEmptyNode: forall ri range tg,
    range_info_in_tree (ri, None) range nullval tg -> IsEmptyNode ri (find_pure_tree tg) range.
Proof.
  intros. destruct range as [l r]. revert tg l r H.
  induction tg; intros; inv H; simpl in *.
  - inv H0. inv H. now apply InEmptyTree.
  - inv H1. inv H.
  - specialize (IHtg1 _ _ H1). now apply InLeftSubTree.
  - specialize (IHtg2 _ _ H1). now apply InRightSubTree.
Qed.

Lemma range_info_in_tree_not_In: forall tg x range r_root,
    sorted_tree (find_pure_tree tg) -> check_key_exist' x range = true ->
    (forall k : key,  bst.bst_conc_lemmas.In k (find_pure_tree tg) -> check_key_exist' k r_root = true) ->
    range_info_in_tree (range, None) r_root nullval tg -> ~  bst.bst_conc_lemmas.In x (find_pure_tree tg).
Proof.
  intros. revert tg r_root H H1 H2. induction tg; intros; simpl in *.
  1: intro; inv H3. inv H. inv H2. 1: inv H3. inv H.
  - assert (forall y : key,  bst.bst_conc_lemmas.In y (find_pure_tree tg1) ->
                            check_key_exist' y (r_root.1, Finite_Integer k) = true). {
      intros. rewrite andb_true_iff. split.
      - assert (check_key_exist' y r_root = true) by now apply H1, InLeft.
        destruct r_root as [r1 r2]. simpl. apply andb_true_iff in H2.
        now destruct H3.
      - red in H9. simpl. specialize (H9 _ H). rewrite Z.ltb_lt. lia. }
    assert (range_inclusion range (r_root.1, Finite_Integer k) = true). {
        eapply range_inside_range with (t := find_pure_tree tg1); auto.
        now apply range_info_in_tree_IsEmptyNode. } destruct range as [r1 r2].
     apply andb_true_iff in H2. destruct H2.
    apply andb_true_iff in H0. destruct H0. specialize (IHtg1 _ H7 H H3).
    intro. inv H6; auto.
    + assert (less_than (Finite_Integer k) (Finite_Integer k) = true) by
          (eapply less_than_less_than_equal_transitivity; eauto).
      rewrite less_than_irrefl in H6. inv H6.
    + assert (less_than (Finite_Integer x) (Finite_Integer k) = true) by
          (eapply less_than_less_than_equal_transitivity; eauto). simpl in H6.
      apply Z.ltb_lt in H6. specialize (H10 _ H12). lia.
  - assert (forall y : key, bst.bst_conc_lemmas.In y (find_pure_tree tg2) ->
                            check_key_exist' y (Finite_Integer k, r_root.2) = true). {
      intros. rewrite andb_true_iff. split.
      - red in H10. simpl. specialize (H10 _ H). now rewrite Z.ltb_lt.
      - assert (check_key_exist' y r_root = true) by now apply H1, InRight.
        destruct r_root as [r1 r2]. simpl. apply andb_true_iff in H2.
        now destruct H2. }
    assert (range_inclusion range (Finite_Integer k, r_root.2) = true). {
        eapply range_inside_range with (t := find_pure_tree tg2); auto.
        now apply range_info_in_tree_IsEmptyNode. } destruct range as [r1 r2].
    apply andb_true_iff in H2. destruct H2. apply andb_true_iff in H0. destruct H0.
    specialize (IHtg2 _ H8 H H3). intro. inv H6; auto.
    + assert (less_than (Finite_Integer k) (Finite_Integer k) = true) by
          (eapply less_than_equal_less_than_transitivity; eauto).
      rewrite less_than_irrefl in H6. inv H6.
    + assert (less_than (Finite_Integer k) (Finite_Integer x) = true) by
          (eapply less_than_equal_less_than_transitivity; eauto).
      simpl in H6. apply Z.ltb_lt in H6. specialize (H9 _ H12). lia.
Qed.

Lemma lookup_not_in: forall t x, ~ bst.bst_conc_lemmas.In x t -> bst.bst_conc_lemmas.lookup nullval x t = nullval.
Proof.
  intros. revert t H. induction t; intros; simpl; auto. destruct (x <? k) eqn: ?.
  - apply IHt1. intro. now apply H, InLeft.
  - destruct (k <? x) eqn: ?.
    + apply IHt2. intro. now apply H, InRight.
    + exfalso. apply H. apply Z.ltb_ge in Heqb. apply Z.ltb_ge in Heqb0.
      assert (x = k) by lia. subst. now apply InRoot.
Qed.



Lemma extract_node_info_from_ghost_tree_rep_2:  forall  tg np b g_root x v  g_current g (r_root: number * number) n n0, 
  (find_ghost_set tg g_root r_root b) g_current = Some (n,n0,np)-> (forall k, In_ghost k tg -> check_key_exist' k r_root = true) -> sorted_ghost_tree tg-> ghost_tree_rep tg b g_root g r_root  |--  EX tp:val,  EX o:option ghost_info, EX lp:val, EX rp:val, EX v0:val,
     !!(range_inclusion (n,n0) r_root = true ) && node_information o (n, n0) g g_current tp lp rp v0 np  *
      (( node_information o (n, n0) g g_current tp lp rp v0 np  -* ghost_tree_rep tg b g_root g r_root)
    && (ALL g1 g2:gname,ALL tp1:val, ALL lp1:val, ALL rp1:val, ALL vp:val, ( !!(o = None /\ tp = nullval /\ lp = nullval /\ rp = nullval /\ (check_key_exist' x (n,n0) = true) ) &&
        node_information (Some (x,vp,g1,g2)) (n, n0) g g_current tp1 lp1 rp1 v np * node_information None (n, Finite_Integer x) g g1 nullval nullval nullval nullval lp1 * 
        node_information None (Finite_Integer x, n0) g g2 nullval nullval nullval nullval rp1)  -* (!! IsEmptyGhostNode (n,n0,o) tg r_root && ghost_tree_rep (insert_ghost x v vp tg g1 lp1 g2 rp1 ) b g_root g r_root))
    && (ALL g1 g2:gname, ALL (vp:val), ( !!(o = Some(x,vp,g1,g2) /\ (check_key_exist' x (n,n0) = true)) && node_information (Some (x,vp,g1,g2)) (n, n0) g g_current tp lp rp v np  )
        -* ( !! In_ghost x tg &&ghost_tree_rep (insert_ghost x v vp tg g1 lp g2 rp ) b g_root g r_root)) ).
Proof.
intros. 
revert dependent r_root. 
revert dependent b.
revert dependent g_root.
induction tg.
 - intros. destruct r_root. simpl in H. unfold ghosts.singleton in H.  destruct (eq_dec g_current g_root). inv H. Exists nullval (@None ghost_info) nullval nullval nullval. unfold node_information at 1, node_data at 1. simpl. entailer!.
  { rewrite less_than_equal_itself. rewrite less_than_equal_itself. repeat (split;auto). } repeat apply andp_right.
    * unfold node_information, node_data;simpl. entailer!. rewrite prop_true_andp. apply wand_refl_cancel_right. auto.
    *  apply allp_right; intro g1. apply allp_right;intro g2. apply allp_right;intro tp1.  apply allp_right;intro lp1.  apply allp_right;intro rp1. apply allp_right;intro vp. rewrite <- wand_sepcon_adjoint. unfold node_information, node_data;simpl. Intro sh.  rewrite <-!sepcon_assoc. Exists tp1 sh. cancel. entailer!. apply InEmptyGhostTree;auto.
    *  apply allp_right; intro g1. apply allp_right;intro g2. apply allp_right;intro vp.  rewrite <- wand_sepcon_adjoint. Intros. 
    * discriminate.
 - intros.  simpl in H. unfold map_upd in H. destruct (eq_dec g_current g_root) eqn: Eqn.
   * inv H. simpl. Intros tp sh.  Exists  tp (Some (k, v2, g0, g1)) v0 v3 v1.  unfold node_information at 1, node_data at 1. Exists sh. entailer!. repeat rewrite less_than_equal_itself. simpl;auto. cancel.  repeat  apply andp_right.
     +   rewrite <- wand_sepcon_adjoint. unfold node_information, node_data. simpl.  Intro sh1. Exists  tp sh1. entailer!.
     + apply allp_right; intro g2. apply allp_right;intro g3. apply allp_right;intro tp1. apply allp_right;intro lp1.  apply allp_right;intro rp1.  apply allp_right;intro vp.  rewrite <- wand_sepcon_adjoint. Intros a.
     + apply allp_right; intro g2. apply allp_right;intro g3. apply allp_right;intro vp. rewrite <- wand_sepcon_adjoint. assert_PROP (Some (k, v2, g0, g1) = Some (x, vp, g2, g3)). { entailer!. } inv H6;subst. simpl.
      destruct (x <? x) eqn: E1. apply Z.ltb_lt in E1. omega. simpl. unfold node_information, node_data. Intros sh1.  entailer!. apply InRoot_ghost.  auto. Exists tp sh1. simpl. entailer!.
 * unfold map_add in H. rename n1 into eq. destruct r_root as [n1 n2]. simpl in H. remember (find_ghost_set tg1 g0 (n1, Finite_Integer k) v0 g_current) as left_set. destruct left_set.  rename g2 into g_left.
    ** simpl.  Intros tp sh. destruct (x <? k) eqn: E1.
        + simpl. inv H1.  sep_apply IHtg1. rewrite <- Heqleft_set;apply H.
         {  intros. assert (check_key_exist' k0 (n1, n2) = true). { apply H0. apply InLeft_ghost. apply H1. } unfold check_key_exist' in * . apply andb_prop in H4. destruct H4.
             unfold gt_ghost in H15. apply H15 in H1. rewrite H4;simpl. apply Zaux.Zlt_bool_true. omega. }
             rewrite sepcon_comm. Intros  tp0 o lp rp v4. Exists tp0 o lp rp v4. entailer!. 
            { simpl in H1.  apply andb_prop in H1. destruct H1. assert (check_key_exist' k (n1, n2) = true). { apply H0. apply InRoot_ghost. auto. } unfold check_key_exist' in H9.  apply andb_prop in H9. destruct H9. rewrite H1;simpl. apply less_than_to_less_than_equal in H10. apply less_than_equal_transitivity with (b := (Finite_Integer k) ). apply H7. apply H10. }
             rewrite distrib_sepcon_andp.  rewrite distrib_sepcon_andp.  repeat apply andp_derives.
          ++ rewrite <- ( emp_wand (bst_conc_nblocking_spec.atomic_ptr_at Ews tp b * _ * _ * _ * _* _ * _ * _)). rewrite wand_sepcon_wand. apply wand_derives. cancel. Exists tp sh. entailer!.
          ++ apply allp_right; intro g2. apply allp_right;intro g3. apply allp_right;intro tp1. apply allp_right;intro lp1.  apply allp_right;intro rp1. apply allp_right;intro vp. repeat (rewrite allp_sepcon2; eapply allp_left). instantiate(1:= rp1). instantiate(1:= g3). instantiate(1:= lp1).   instantiate(1:= g2).  instantiate(1:= vp). instantiate (1:= tp1).  rewrite <- ( emp_wand (bst_conc_nblocking_spec.atomic_ptr_at Ews tp b * _ * _ * _ * _* _ * _* _)).
             rewrite wand_sepcon_wand. apply wand_derives. cancel. simpl. Exists tp sh. entailer!. apply InLeftGhostSubTree. apply H7.
          ++ apply allp_right; intro g2. apply allp_right;intro g3. apply allp_right;intro vp. repeat (rewrite allp_sepcon2; eapply allp_left). instantiate(1:= g3).  instantiate(1:= g2).  instantiate(1:= vp).  rewrite <- ( emp_wand (bst_conc_nblocking_spec.atomic_ptr_at Ews tp b * _ * _ * _ * _* _*_*_)).
             rewrite wand_sepcon_wand. apply wand_derives. cancel. simpl. Exists tp sh. entailer!. apply InLeft_ghost. apply H7. 
       +  simpl. inv H1. sep_apply IHtg1.  rewrite <- Heqleft_set;apply H.
            { intros. assert (check_key_exist' k0 (n1, n2) = true). { apply H0. apply InLeft_ghost. apply H1. } unfold check_key_exist' in * . apply andb_prop in H4. destruct H4.
             unfold gt_ghost in H15. apply H15 in H1. rewrite H4;simpl. apply Zaux.Zlt_bool_true. omega. }  
         Intros tp0 o lp rp v4. Exists  tp0 o lp rp v4. entailer!.
         { simpl in H1.  apply andb_prop in H1. destruct H1. assert (check_key_exist' k (n1, n2) = true). { apply H0. apply InRoot_ghost. auto. } unfold check_key_exist' in H9.  apply andb_prop in H9. destruct H9. rewrite H1;simpl. apply less_than_to_less_than_equal in H10. apply less_than_equal_transitivity with (b := (Finite_Integer k) ). apply H7. apply H10. }
              rewrite -> 7sepcon_assoc, sepcon_comm.  rewrite distrib_sepcon_andp.  rewrite distrib_sepcon_andp.  repeat  apply andp_derives.
         ++  rewrite <- !sepcon_assoc. rewrite <- ( emp_wand (bst_conc_nblocking_spec.atomic_ptr_at Ews tp b * _ * _ * _ * _* _ * _ * _)). rewrite wand_sepcon_wand. apply wand_derives. cancel. Exists tp sh. entailer!.
         ++ apply allp_right; intro g2. apply allp_right;intro g3. apply allp_right;intro tp1. apply allp_right;intro lp1.  apply allp_right;intro rp1. apply allp_right;intro vp.  repeat (rewrite allp_sepcon2; eapply allp_left). instantiate(1:= rp1). instantiate(1:= g3). instantiate(1:= lp1). instantiate(1:= g2).  instantiate(1:= vp).  instantiate(1:= tp1). 
              rewrite <- wand_sepcon_adjoint. assert_PROP (check_key_exist' x (n,n0) = true). { simpl. entailer!. } 
              assert (x < k). { simpl in H1. apply andb_prop in H1. apply andb_prop in H7.  destruct H1,H7. unfold less_than_equal, less_than in *. destruct n0.  apply Z.ltb_lt in H10. apply Zle_bool_imp_le in H9. omega. discriminate. discriminate.  } 
              apply Z.ltb_nlt in E1. omega. 
         ++ apply allp_right; intro g2. apply allp_right;intro g3. apply allp_right;intro vp. repeat (rewrite allp_sepcon2; eapply allp_left). instantiate(1:= g2).  instantiate(1:= g3).  instantiate(1:= vp). 
              rewrite <- wand_sepcon_adjoint. assert_PROP (check_key_exist' x (n,n0) = true). { simpl. entailer!. } 
              assert (x < k). { simpl in H1. apply andb_prop in H7. apply andb_prop in H1.  destruct H1,H7. unfold less_than_equal, less_than in *. destruct n0.  apply Z.ltb_lt in H10. apply Zle_bool_imp_le in H9. omega. discriminate. discriminate.  } 
             apply Z.ltb_nlt in E1. omega. 
  ** simpl. Intros tp sh. destruct (x <? k) eqn: E1.
       + simpl. inv H1.  unfold lt_ghost in H14. sep_apply IHtg2.
         { intros. assert (check_key_exist' k0 (n1, n2) = true). { apply H0. apply InRight_ghost. apply H1. } unfold check_key_exist' in * . apply andb_prop in H4. destruct H4.
         apply H16 in H1. rewrite H5;simpl. rewrite andb_comm;simpl. apply Zaux.Zlt_bool_true. omega. }       
       Intros tp0 o lp rp v4. Exists tp0 o lp rp v4. entailer!. 
         { simpl in H1.  apply andb_prop in H1. destruct H1. assert (check_key_exist' k (n1, n2) = true). { apply H0. apply InRoot_ghost. auto. } unfold check_key_exist' in H9.  apply andb_prop in H9. destruct H9. rewrite H7;simpl. rewrite andb_comm;simpl. apply less_than_to_less_than_equal in H9. apply less_than_equal_transitivity with (b := (Finite_Integer k) ). apply H9. apply H1. }
          rewrite -> 7sepcon_assoc, sepcon_comm.  rewrite distrib_sepcon_andp.  rewrite distrib_sepcon_andp.  repeat  apply andp_derives.
         ++  rewrite <- !sepcon_assoc. rewrite <- ( emp_wand (bst_conc_nblocking_spec.atomic_ptr_at Ews tp b * _ * _ * _ * _* _ * _*_)). rewrite wand_sepcon_wand. apply wand_derives. cancel. Exists tp sh. entailer!.
         ++ apply allp_right; intro g2. apply allp_right;intro g3. apply allp_right;intro tp1. apply allp_right;intro lp1.  apply allp_right;intro rp1. apply allp_right;intro vp.  repeat (rewrite allp_sepcon2; eapply allp_left). instantiate(1:= rp1). instantiate(1:= g3). instantiate(1:= lp1).   instantiate(1:= g2). instantiate(1:= vp).  instantiate (1:= tp1).
              rewrite <- wand_sepcon_adjoint. assert_PROP (check_key_exist' x (n,n0) = true). { simpl. entailer!. }  
              assert (k < x). { simpl in H1. apply andb_prop in H7. apply andb_prop in H1.  destruct H1,H7. unfold less_than_equal, less_than in *. destruct n.  apply Zle_bool_imp_le in H1. apply Z.ltb_lt in H7. omega. discriminate. discriminate.  } 
             apply Z.ltb_lt in E1. omega. 
         ++ apply allp_right; intro g2. apply allp_right;intro g3. apply allp_right;intro vp0. repeat (rewrite allp_sepcon2; eapply allp_left). instantiate(1:= g2).  instantiate(1:= g3). instantiate(1:= vp0). 
              rewrite <- wand_sepcon_adjoint. assert_PROP (check_key_exist' x (n,n0) = true). { simpl. entailer!. }  
              assert (k < x). { simpl in H1. apply andb_prop in H7. apply andb_prop in H1.  destruct H1,H7. unfold less_than_equal, less_than in *. destruct n.  apply Zle_bool_imp_le in H1. apply Z.ltb_lt in H7. omega. discriminate. discriminate.  } 
              apply Z.ltb_lt in E1. omega.  
        + destruct (k <? x) eqn:E2. simpl;inv H1.  
          ++ sep_apply IHtg2.
            {  intros. assert (check_key_exist' k0 (n1, n2) = true). { apply H0. apply InRight_ghost. apply H1. } unfold check_key_exist' in * . apply andb_prop in H4. destruct H4.
                apply H16 in H1. rewrite H5;simpl. rewrite andb_comm;simpl. apply Zaux.Zlt_bool_true. omega. }
            Intros tp0 o lp rp v4. Exists  tp0 o lp rp v4. entailer!.
            { simpl in H1.  apply andb_prop in H1. destruct H1. assert (check_key_exist' k (n1, n2) = true). { apply H0. apply InRoot_ghost. auto. } unfold check_key_exist' in H6.  apply andb_prop in H9. destruct H9. rewrite H7;simpl. rewrite andb_comm;simpl.  apply less_than_to_less_than_equal in H9. apply less_than_equal_transitivity with (b := (Finite_Integer k) ). apply H9. apply H1. }
           rewrite -> 7sepcon_assoc, sepcon_comm.  rewrite distrib_sepcon_andp.  rewrite distrib_sepcon_andp.  repeat apply andp_derives.
            +++  rewrite <- !sepcon_assoc.  rewrite <- ( emp_wand (bst_conc_nblocking_spec.atomic_ptr_at Ews tp b * _ * _ * _ * _* _ * _*_)). rewrite wand_sepcon_wand. apply wand_derives. cancel. Exists tp sh. entailer!.
            +++  apply allp_right; intro g2. apply allp_right;intro g3. apply allp_right;intro tp1. apply allp_right;intro lp1.  apply allp_right;intro rp1. apply allp_right;intro vp. repeat (rewrite allp_sepcon2; eapply allp_left). instantiate(1:= rp1). instantiate(1:= g3). instantiate(1:= lp1). instantiate(1:= g2). instantiate (1 := vp).  instantiate(1:= tp1). rewrite <- !sepcon_assoc.   rewrite <- ( emp_wand (bst_conc_nblocking_spec.atomic_ptr_at Ews tp b * _ * _ * _ * _* _ * _*_)).
             rewrite wand_sepcon_wand. apply wand_derives. cancel. simpl. Exists tp sh. entailer!.  apply InRightGhostSubTree. apply H7. 
            +++ apply allp_right; intro g2. apply allp_right;intro g3. apply allp_right;intro v5. repeat (rewrite allp_sepcon2; eapply allp_left). instantiate(1:= g3).  instantiate(1:= g2).  instantiate(1:= v5). rewrite <- !sepcon_assoc.  rewrite <- ( emp_wand (bst_conc_nblocking_spec.atomic_ptr_at Ews tp b * _ * _ * _ * _* _ *_*_)).
             rewrite wand_sepcon_wand. apply wand_derives. cancel. simpl. Exists tp sh. entailer!. apply InRight_ghost. apply H7. 
         ++   inv H1.  assert (k = x ). { apply Z.ltb_nlt in E1. apply Z.ltb_nlt in E2. omega. } sep_apply IHtg2. 
            { intros. assert (check_key_exist' k0 (n1, n2) = true). { apply H0. apply InRight_ghost. apply H4. } unfold check_key_exist' in * . apply andb_prop in H5. destruct H5.
               apply H16 in H4. rewrite H6;simpl. rewrite andb_comm;simpl. apply Zaux.Zlt_bool_true. omega. }
            Intros  tp0 o lp rp v4. Exists  tp0 o lp rp v4. entailer!. 
            { simpl in H3.  apply andb_prop in H4. destruct H4. assert (check_key_exist' x (n1, n2) = true). { apply H0. apply InRoot_ghost. auto. } unfold check_key_exist' in H9.  apply andb_prop in H9. destruct H9. rewrite H4;simpl. rewrite andb_comm;simpl. apply less_than_to_less_than_equal in H9. apply less_than_equal_transitivity with (b := (Finite_Integer x) ). apply H9. apply H1. }
             rewrite -> 7sepcon_assoc, sepcon_comm.  rewrite distrib_sepcon_andp.  rewrite distrib_sepcon_andp.  repeat  apply andp_derives.
            +++  rewrite <- !sepcon_assoc.  rewrite <- ( emp_wand (bst_conc_nblocking_spec.atomic_ptr_at Ews tp b * _ * _ * _ * _* _ * _*_)). rewrite wand_sepcon_wand. apply wand_derives. cancel. Exists tp sh. entailer!.
            +++ apply allp_right; intro g2. apply allp_right;intro g3. apply allp_right;intro tp1. apply allp_right;intro lp1.  apply allp_right;intro rp1. apply allp_right;intro vp. repeat (rewrite allp_sepcon2; eapply allp_left). instantiate(1:= rp1). instantiate(1:= g3). instantiate(1:= lp1).  instantiate(1:= g2). instantiate(1:= vp).  instantiate(1:= tp1). 
                   rewrite <- wand_sepcon_adjoint. assert_PROP (check_key_exist' x (n,n0) = true). { simpl. entailer!. } 
                   simpl in H2.  apply andb_prop in H4. apply andb_prop in H1.  destruct H4, H1. destruct n. simpl in H1. apply Z.ltb_lt in H1. apply Zle_bool_imp_le in H4. omega. discriminate. simpl in H1. discriminate. 
        
            +++ apply allp_right; intro g2. apply allp_right;intro g3. apply allp_right;intro v5. repeat (rewrite allp_sepcon2; eapply allp_left). instantiate(1:= g2).  instantiate(1:= g3).  instantiate(1:= v5). 
                  rewrite <- wand_sepcon_adjoint. assert_PROP (check_key_exist' x (n, n0) = true). { simpl. entailer!. } 
                 simpl in H3.  apply andb_prop in H4. apply andb_prop in H1.  destruct H4, H1. destruct n. simpl in H1. apply Z.ltb_lt in H1. apply Zle_bool_imp_le in H4. omega. discriminate. simpl in H1. discriminate.     
Qed. *)


  