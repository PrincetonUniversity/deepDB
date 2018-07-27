Require Import VST.floyd.proofauto.
Require Import VST.floyd.library.
Require Import VST.msl.iter_sepcon.

Require Import Lia. (* for nia tactic (nonlinear integer arithmetic) *)

Ltac start_function_hint ::= idtac. (* no hint reminder *)

(*+ miscellany *)

(* from VFA *)
Lemma beq_reflect : forall x y, reflect (x = y) (x =? y).
Proof. intros x y. apply iff_reflect. symmetry. apply Z.eqb_eq. Qed.
Hint Resolve ReflOmegaCore.ZOmega.IP.blt_reflect 
  ReflOmegaCore.ZOmega.IP.beq_reflect beq_reflect : bdestruct.
Ltac bdestruct X :=
  let H := fresh in let e := fresh "e" in
   evar (e: Prop); assert (H: reflect e X); subst e;
    [eauto with bdestruct
    | destruct H as [H|H];
       [ | try first [apply not_lt in H | apply not_le in H]]].

(* A bit of infrastructure for brute force proof of claim3.
   TODO consider using Zseq in place of seq in mm_inv. 
*)
Definition Zseq n := 
  if n <? 0 then [] else map Z.of_nat (seq 0 (Z.to_nat n)).

Lemma in_Zseq: forall len n : Z, len >= 0 -> ( In n (Zseq len) <-> (0 <= n < len) ). 
Proof.
  intros. unfold Zseq.  bdestruct (len <? 0); try omega. clear H0.
  rewrite in_map_iff. split.
  - intros. destruct H0. destruct H0. 
    rewrite in_seq in H1.
    rewrite <- H0. split. rep_omega. destruct H1. simpl in H2.
    apply inj_lt in H2.
    assert (0 <= len) by omega.
    assert (Z.of_nat (Z.to_nat len) =  len) by (apply Z2Nat.id; auto).
    subst. rep_omega.
  - intro. exists (Z.to_nat n).
    split; try rep_omega.
    rewrite in_seq.
    assert (0 <= Z.to_nat n)%nat by (destruct H0; omega). 
    simpl. split; try omega. rep_omega.
Qed.

Lemma forall_Forall_range: 
     forall (P : Z -> Prop) (n : Z), 0 <= n ->
       ( (forall x, 0 <= x < n -> P x) <-> Forall P (Zseq n) ).
Proof.
  intros.
  assert (Hi:  
          (forall x : Z, 0 <= x < n -> P x) <->  (forall x : Z, In x (Zseq n) -> P x)).
  { split. - intros; apply H0; rewrite <- in_Zseq; try omega; auto.
    - intros; apply H0; rewrite in_Zseq; try omega. }
  rewrite Hi. rewrite Forall_forall. reflexivity.
Qed.

(*+ helpers and data structures *)

(* 
ALERT: overriding the definition of malloc_token, malloc_spec', and free_spec' in floyd.library 
Current version is out of sync with floyd: malloc_token uses number of bytes
rather than a type expression.
*)

(* Note re CompCert 3: I'm currently using tuint for what in the code
is size_t.  That works for 32bit mode.  To generalize the proof
to 64bit as well, it may work to replace tuint by t_size_t defined like 
t_size_t := if Archi.ptr64 then tulong else tuint
*)

(* Note about clightgen:
Compiling malloc.c triggers a warning from a header file:
/usr/include/sys/cdefs.h:81:2: warning: "Unsupported compiler detected"
This is ok.
*)

Require Import malloc.
Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.
Local Open Scope Z.
Local Open Scope logic.  

(* Numeric constants *)

Definition WORD: Z := 4.  (* sizeof(size_t) is 4 for 32bit Clight *)
Definition ALIGN: Z := 2.
Definition BINS: Z := 8. 
Definition BIGBLOCK: Z := ((Z.pow 2 17) * WORD).
Definition WA: Z := (WORD*ALIGN) - WORD. (* WASTE at start of big block *)


Lemma WORD_ALIGN_aligned:
  (natural_alignment | WORD * ALIGN)%Z.
Proof. unfold natural_alignment, WORD, ALIGN; simpl. apply Z.divide_refl. Qed.


(* The following hints empower rep_omega and lessen the need for 
   manually unfolding the constant definitions. *)

Lemma BINS_eq: BINS=8.  Proof. reflexivity. Qed.
Hint Rewrite BINS_eq : rep_omega.
Global Opaque BINS. (* make rewrites only happen in rep_omega *)

Lemma BIGBLOCK_eq: BIGBLOCK=524288.  Proof. reflexivity. Qed.
Hint Rewrite BIGBLOCK_eq : rep_omega.
Global Opaque BIGBLOCK.

Lemma WORD_eq: WORD=4.  Proof. reflexivity. Qed.
Hint Rewrite WORD_eq : rep_omega.
Global Opaque WORD.

Lemma ALIGN_eq: ALIGN=2.  Proof. reflexivity. Qed.
Hint Rewrite ALIGN_eq : rep_omega.
Global Opaque ALIGN.

Lemma WA_eq: WA=4.  Proof. reflexivity. Qed.
Hint Rewrite WA_eq : rep_omega.
Global Opaque WA.

(* Note that following is Int.max_unsigned, not Ptrofs.max_unsigned.
   In fact, BIGBLOCK <= Int.max_signed. 
   Increasing BIGBLOCK could require the code to use long instead of int. *)
Lemma BIGBLOCK_size: 0 <= BIGBLOCK <= Int.max_unsigned.
Proof. rep_omega. Qed.

(* bin/size conversions and their properties *)

Definition bin2sizeZ := fun b: Z => (Z.mul ((Z.mul (b+1) ALIGN)-1) WORD).

Definition size2binZ' : Z -> Z := fun s => 
   if zlt (bin2sizeZ(BINS-1)) s then -1 
   else (s+(Z.mul WORD (ALIGN-1))-1) / (Z.mul WORD ALIGN).

Definition size2binZ : Z -> Z := fun s => 
   if (bin2sizeZ(BINS-1)) <? s then -1 
   else (s+(Z.mul WORD (ALIGN-1))-1) / (Z.mul WORD ALIGN).


Lemma bin2size_range: 
  forall b, 0 <= b < BINS -> 
    WORD <= bin2sizeZ b <= bin2sizeZ(BINS-1). 
 (* /\   bin2sizeZ b <= Ptrofs.max_unsigned. *)
Proof. intros. unfold bin2sizeZ in *. split; simpl in *; try rep_omega. Qed.

Lemma bin2size_rangeB: 
  forall b, 0 <= b < BINS -> 
    0 <= bin2sizeZ b <= Ptrofs.max_unsigned.
Proof. intros. unfold bin2sizeZ in *. split; simpl in *; try rep_omega. Qed.

Lemma  bin2sizeBINS_eq: bin2sizeZ(BINS-1) = 60.
Proof. reflexivity. Qed.
Hint Rewrite bin2sizeBINS_eq: rep_omega.

(* note: for larger s, size2binZ s = -1 *)
Lemma size2bin_range: 
  forall s, 0 <= s <= bin2sizeZ(BINS-1) -> 0 <= size2binZ s < BINS.
Proof. 
  intros. unfold size2binZ. 
  bdestruct (bin2sizeZ (BINS - 1) <? s); try omega.
  rewrite bin2sizeBINS_eq in *.
  rewrite WORD_eq. rewrite ALIGN_eq. rewrite BINS_eq. simpl. 
  replace (s + 4 - 1) with (s + 3) by omega.
  split.
  - apply Z.div_pos; rep_omega.
  - apply Z.div_lt_upper_bound; rep_omega.
Qed.


Lemma Z_DivFact:
  forall a b c, 0 <= b < c -> (a*c + b)/c = a.
Proof. 
  intros. 
  rewrite Z_div_plus_full_l; try omega. rewrite Zdiv.Zdiv_small; try omega.
Qed.

Lemma claim5: forall b, 
0 <= b < BINS -> size2binZ(bin2sizeZ(b)) = b.
Proof.
  intros. unfold size2binZ.
  assert (H1: (bin2sizeZ (BINS - 1) >= (bin2sizeZ b))) 
    by ( unfold bin2sizeZ; rep_omega).
  bdestruct ((bin2sizeZ (BINS - 1)) <? (bin2sizeZ b)); try omega.
  unfold bin2sizeZ. 
  assert (H3: 
     (((b + 1) * ALIGN - 1) * WORD + WORD * (ALIGN - 1) - 1) / (WORD * ALIGN)
     = (b*ALIGN*WORD + 2*ALIGN*WORD - 2*WORD -1)/(WORD*ALIGN))
    by (f_equal; f_equal; rep_omega).  rewrite H3.
  assert (H4:
     (b * ALIGN * WORD + 2 * ALIGN * WORD - 2 * WORD - 1)  
   = (b * (WORD * ALIGN) + (ALIGN*WORD-1))) by rep_omega.   rewrite H4.
  apply Z_DivFact.
  rep_omega.
Qed.


Lemma bin2size_size2bin: forall s, 
  s <= bin2sizeZ(BINS-1) -> 
  bin2sizeZ(size2binZ s) = s + ((WORD*ALIGN)-1) - (s + 3) mod (WORD*ALIGN).
Proof.
  intros.
  intros. unfold bin2sizeZ in *. unfold size2binZ in *. simpl in *.
  bdestruct (bin2sizeZ (BINS - 1) <? s); try rep_omega.
  rewrite WORD_eq in *.  rewrite ALIGN_eq in *. rewrite BINS_eq in *. 
  simpl in *.
  replace ((((s + 4 - 1) / 8 + 1) * 2 - 1) * 4)%Z
     with ((s + 4 - 1) / 8 * 8 + 4)%Z by omega.
  replace (s + 4 - 1)%Z with (s + 3) by omega.
  assert (Zmod_eq': forall a b, b > 0 -> (a / b * b)%Z = a - a mod b) 
      by (intros; rewrite Zmod_eq; omega).
  rewrite Zmod_eq' by omega; clear Zmod_eq'. omega.
Qed.

Lemma claim1: forall s, 
  s <= bin2sizeZ(BINS-1) -> s <= bin2sizeZ(size2binZ s).
Proof. 
  intros. 
  (* ? streamline first few steps using rewrite bin2size_size2bin by auto. *)
  unfold bin2sizeZ in *. unfold size2binZ in *. simpl in *.
  assert (H1: bin2sizeZ (BINS-1) = 60) by normalize. rewrite H1. 
  bdestruct (60 <? s); try rep_omega.
  rewrite WORD_eq in *.  rewrite ALIGN_eq in *. rewrite BINS_eq in *.
  simpl in *. clear H0 H1. 
  replace ((((s + 4 - 1) / 8 + 1) * 2 - 1) * 4)%Z
     with ((s + 4 - 1) / 8 * 8 + 4)%Z by omega.
  replace (s + 4 - 1)%Z with (s + 3) by omega.
  assert (Zmod_eq': forall a b, b > 0 -> (a / b * b)%Z = a - a mod b) 
     by (intros; rewrite Zmod_eq; omega).
  rewrite Zmod_eq' by omega; clear Zmod_eq'.
  replace (s + 3 - (s + 3) mod 8 + 4)%Z  with (s + 7 - (s + 3) mod 8)%Z by omega.
  assert (H1: 0 <= (s+3) mod 8 < 8) by (apply Z_mod_lt; omega); omega.
Qed.

Lemma claim2: forall s, 
  0 <= s <= bin2sizeZ(BINS-1) -> 0 <= size2binZ s < BINS.
Proof. 
  intros. unfold bin2sizeZ in *. unfold size2binZ.
  rewrite WORD_eq in *.  rewrite ALIGN_eq in *. 
  rewrite bin2sizeBINS_eq. rewrite BINS_eq in *.
  change (((8 - 1 + 1) * 2 - 1) * 4)%Z with 60 in *.
  bdestruct (60 <? s); try rep_omega.
  simpl. split.
  apply Z.div_pos. replace (s+4-1) with (s+3) by omega.
  apply Z.add_nonneg_nonneg; try omega. omega.
  replace (s+4-1) with (s+3) by omega.
  apply Z.div_lt_upper_bound. omega. simpl.
  change 64 with (61 + 3). apply Zplus_lt_compat_r. omega.
Qed.

Lemma claim3: forall s, 0 <= s <= bin2sizeZ(BINS-1) 
    -> size2binZ(bin2sizeZ(size2binZ(s))) = size2binZ(s).
Proof. 
  intros. 
  pose proof ((size2bin_range s) H). 
  pose proof ((bin2size_range (size2binZ(s))) H0).
  unfold size2binZ.
  bdestruct (bin2sizeZ (BINS - 1) <? s).
  bdestruct (bin2sizeZ (BINS - 1) <? bin2sizeZ (-1)); try omega.
  bdestruct (bin2sizeZ (BINS - 1) <?
             bin2sizeZ ((s + WORD * (ALIGN - 1) - 1) / (WORD * ALIGN))).
  - rewrite WORD_eq in *.  rewrite ALIGN_eq in *.  simpl.
    replace (s + 4 - 1) with (s + 3) by omega.
    exfalso. clear H2.
    replace  ((s + 4 * (2 - 1) - 1) / (4 * 2)) with (size2binZ s) in H3; try omega. 
    unfold size2binZ. bdestruct (bin2sizeZ (BINS - 1) <? s); try omega.
    rewrite WORD_eq in *.  rewrite ALIGN_eq in *. omega.
  - unfold bin2sizeZ. rewrite WORD_eq in *.  rewrite ALIGN_eq in *. simpl.

(* gave up fumbling with algebra; 
   finish by evaluation, of enumerating the values of s in a list *)

    assert (Htest: forall s,  0 <= s < bin2sizeZ(BINS-1) + 1 -> 
      ((((s + 4 - 1) / 8 + 1) * 2 - 1) * 4 + 4 - 1) / 8  = (s + 4 - 1) / 8).
    { set (Q:=fun t => 
                ((((t + 4 - 1) / 8 + 1) * 2 - 1) * 4 + 4 - 1) / 8  = (t + 4 - 1) / 8).
      assert (Hs: 0 <= s < bin2sizeZ(BINS - 1) + 1) by omega.
      assert (Hb: 0 <= bin2sizeZ(BINS - 1) + 1) by omega.
      pose proof (forall_Forall_range Q ((bin2sizeZ (BINS - 1))+1) Hb). 
      clear H1 H2 H3 Hb. unfold Q in H4. rewrite H4.
      rewrite bin2sizeBINS_eq. simpl. cbn.
      repeat constructor.
    }
    apply (Htest s). omega.
Qed.

(* BIGBLOCK needs to be big enough for at least one chunk of the 
largest size, because fill_bin unconditionally initializes the last chunk. *)
Lemma BIGBLOCK_enough: (* and not too big *)
  forall s, 0 <= s <= bin2sizeZ(BINS-1) ->  
            0 < (BIGBLOCK - WA) / (s + WORD) < Int.max_signed.
Proof.
  intros. rewrite bin2sizeBINS_eq in *. split. 
  apply Z.div_str_pos; rep_omega.
  rewrite Z_div_lt; rep_omega.
Qed.

Lemma BIGBLOCK_enough_j: 
  forall s j, 0 <= s <= bin2sizeZ(BINS-1) -> j < (BIGBLOCK-WA) / (s+WORD) ->
              (s+WORD) <= (BIGBLOCK-WA) - (j * (s+WORD)).
Proof.
  intros. 
  assert (H0a: j+1 <= (BIGBLOCK-WA)/(s+WORD)) by rep_omega.
  assert (H0b: (s+WORD) * (j+1) <= (s+WORD) * ((BIGBLOCK-WA)/(s+WORD)))
    by (apply Zmult_le_compat_l; rep_omega).
  assert (H1: (s+WORD) * ((BIGBLOCK-WA)/(s+WORD)) <= (BIGBLOCK-WA))
    by (apply Z.mul_div_le; rep_omega).
  assert (H2: (s+WORD) * (j+1) <= (BIGBLOCK-WA)) by rep_omega.
  assert (H3: ((s+WORD) * (j+1) = (s+WORD) * j + (s+WORD) * 1)%Z) 
    by apply Z.mul_add_distr_l.
  rewrite Z.mul_1_r in H3.
  rewrite H3 in H2.
  assert (H4 : (s+WORD) * j + (s+WORD) - (s+WORD) * j  <= BIGBLOCK-WA - (s+WORD)*j) 
    by (apply Z.sub_le_mono; omega).
  replace ((s+WORD) * j + (s+WORD) - (s+WORD) * j)
     with (s+WORD) in H4 by omega.
  replace (j * (s+WORD))%Z with ((s+WORD) * j)%Z by apply Z.mul_comm.
  auto.
Qed.


(* Specifications for posix mmap0 and munmap as used by this memory manager.
   Using wrapper mmap0 which returns 0 on failure, because mmap returns -1,
   and pointer comparisons with non-zero literals violate the C standard.
   Aside from that, mmap0's spec is the same as mmap's.

   The posix spec says the pointer will be aligned on page boundary.  Our
   spec uses malloc_compatible which says it's on the machines natural 
   alignment. 
*)

Definition mmap_align: Z := 4. 

Definition mmap0_spec := 
   DECLARE _mmap0
   WITH n:Z
   PRE [ 1%positive (*_addr*) OF (tptr tvoid), 
         2%positive (*_len*) OF tuint, 
         3%positive (*_prot*) OF tint,
         4%positive (*_flags*) OF tint,
         5%positive (*_fildes*) OF tint,
         6%positive (*_off*) OF tlong ]
     PROP (0 <= n <= Ptrofs.max_unsigned)
     LOCAL (temp 1%positive nullval; 
            temp 2%positive (Vptrofs (Ptrofs.repr n));
            temp 3%positive (Vint (Int.repr 3)); (* PROT_READ|PROT_WRITE *)
            temp 4%positive (Vint (Int.repr 4098)); (* MAP_PRIVATE|MAP_ANONYMOUS *)
            temp 5%positive (Vint (Int.repr (-1)));
            temp 6%positive (Vlong (Int64.repr 0)))
     SEP ()
   POST [ tptr tvoid ] EX p:_, 
     PROP ( if eq_dec p nullval
            then True else malloc_compatible n p )
     LOCAL (temp ret_temp p)
     SEP ( if eq_dec p nullval
           then emp else memory_block Tsh n p).

(* NOTE: the postcondition should be if ret==0 then the memory was freed. *)
Definition munmap_spec := 
   DECLARE _munmap
   WITH p:val, n:Z
   PRE [ 1%positive (*_addr*) OF (tptr tvoid), 
         2%positive (*_len*) OF tuint ]
     PROP (0 <= n <= Ptrofs.max_unsigned)
     LOCAL (temp 1%positive p; 
            temp 2%positive (Vptrofs (Ptrofs.repr n)) )
     SEP ( memory_block Tsh n p )
   POST [ tint ] EX res: Z,
     PROP ()
     LOCAL (temp ret_temp (Vint (Int.repr res)))
     SEP ( emp ).


Definition bin2size_spec :=
 DECLARE _bin2size
  WITH b: Z
  PRE [ _b OF tint ] 
     PROP( 0 <= b < BINS ) 
     LOCAL (temp _b (Vint (Int.repr b))) SEP ()
  POST [ tuint ] 
     PROP() LOCAL(temp ret_temp (Vptrofs (Ptrofs.repr (bin2sizeZ b)))) SEP ().

Definition size2bin_spec :=
 DECLARE _size2bin
  WITH s: Z
  PRE [ _s OF tuint ]    
     PROP( 0 <= s <= Ptrofs.max_unsigned ) 
     LOCAL (temp _s (Vptrofs (Ptrofs.repr s))) SEP ()
  POST [ tint ]
     PROP() LOCAL(temp ret_temp (Vint (Int.repr (size2binZ s)))) SEP ().



(* malloc token: accounts for both the size field and alignment padding. 

n is the number of bytes requested 
(currently must be > 0 so the returned pointer is valid, but this 
should be changed).
  
Unfolding the definition reveals the stored size value s, which 
is not the request n but rather the size of the block (not 
counting the size field itself).

The constraint s + WA + WORD <= Ptrofs.max_unsigned caters for 
padding and is used e.g. in proof of body_free.

About waste: for small blocks, there is only waste at the beginning of each
big block used by fill_bin, and mm_inv accounts for it.
For large blocks, each has its own waste, accounted for by malloc_token.

Note that offset_val is in bytes, not like C pointer arith. 

PENDING: n > 0 currently required, to ensure valid_pointer p.
An alternate way to achieve that would be for the token to have partial share
of the user data, and to exploit that bin2sizeZ(size2binZ(0)) > 0.
*)

Definition malloc_tok (sh: share) (n: Z) (s: Z) (p: val): mpred := 
   !! (0 < n <= s /\ s + WA + WORD <= Ptrofs.max_unsigned /\
       (s <= bin2sizeZ(BINS-1) -> s = bin2sizeZ(size2binZ(n))) /\
       malloc_compatible n p ) &&
    data_at Tsh tuint (Vptrofs (Ptrofs.repr s)) (offset_val (- WORD) p)
  * memory_block Tsh (s - n) (offset_val n p)
  * (if zle s (bin2sizeZ(BINS-1)) 
    then emp
    else memory_block Tsh WA (offset_val (-(WA+WORD)) p)).

Definition malloc_token (sh: share) (n: Z) (p: val): mpred := 
   EX s:Z, malloc_tok sh n s p.

(* NOTE:
Following are currently part of floyd/library.v but don't make sense.
See VST issue #231.
Parameter malloc_token_valid_pointer
Parameter malloc_token_precise
*)

Lemma malloc_token_valid_pointer_size:
  forall sh n p, malloc_token sh n p |-- valid_pointer (offset_val (- WORD) p).
Proof.
  intros. unfold malloc_token, malloc_tok. entailer!.
  sep_apply (data_at_valid_ptr Tsh tuint (Vint (Int.repr s)) (offset_val(-WORD) p)).
  normalize. simpl. omega. entailer!.
Qed.

Lemma malloc_token_local_facts:
  forall sh n p, malloc_token sh n p 
  |-- !!( malloc_compatible n p /\ 0 <= n <= Ptrofs.max_unsigned - WORD ).
Proof.
  intros; unfold malloc_token; Intro s; unfold malloc_tok; entailer!.
Qed.

Hint Resolve malloc_token_valid_pointer_size : valid_pointer.
Hint Resolve malloc_token_local_facts : saturate_local.


(* PENDING maybe belongs in floyd *)
Lemma malloc_compatible_offset:
  forall n m p, 0 <= n -> 0 <= m ->
  malloc_compatible (n+m) p -> (natural_alignment | m) -> 
  malloc_compatible n (offset_val m p).
Proof.
  intros n m p Hn Hm Hp Ha. unfold malloc_compatible in *.
  destruct p; try auto. destruct Hp as [Hi Hinm]. simpl. 
  split.
- replace (Ptrofs.unsigned (Ptrofs.add i (Ptrofs.repr m)))
     with (m + (Ptrofs.unsigned i)).
  apply Z.divide_add_r; auto.
  rewrite Ptrofs.add_unsigned.
  rewrite Ptrofs.unsigned_repr; rewrite Ptrofs.unsigned_repr;
     try omega; try split; try rep_omega. 
- replace (Ptrofs.unsigned (Ptrofs.add i (Ptrofs.repr m)))
     with (m + (Ptrofs.unsigned i)). 
  rep_omega. rewrite Ptrofs.add_unsigned.
  rewrite Ptrofs.unsigned_repr; rewrite Ptrofs.unsigned_repr;
     try omega; try split; try rep_omega. 
Qed. 


(* linked list segment, for free blocks of a fixed size.

p points to a linked list of len blocks, terminated at r.

Blocks are viewed as (sz,nxt,remainder) where nxt points to the
next block in the list.  Each block begins with the stored size
value sz.  Each pointer, including p, points to the nxt field, 
not to sz.
The value of sz should be the number of bytes in (nxt,remainder)

A segment predicate is needed to cater for fill_bin which grows 
the list at its tail. For non-empty segment, terminated at r means 
that r is the nxt field of the last block -- which may be null or 
a valid pointer to not-necessarily-initialized memory. 

The definition uses nat, for ease of termination check, at cost 
of Z conversions.  

TODO simplify base case using lemma ptr_eq_is_pointer_or_null ?

Note on range of sz:  Since the bins are for moderate sizes,
there's no need for sz > Int.max_unsigned, but the malloc/free API
uses size_t for the size, and jumbo blocks need to be parsed by
free even though they won't be in a bin, so this spec uses 
Ptrofs in conformance with the code's use of size_t.

TODO - parsing of big blocks has nothing to do with mmlist. 

*)

Fixpoint mmlist (sz: Z) (len: nat) (p: val) (r: val): mpred :=
 match len with
 | O => !! (0 <= sz <= Ptrofs.max_unsigned 
            /\ is_pointer_or_null p /\ ptr_eq p r) && emp 
 | (S n) => EX q:val, !! (is_pointer_or_null q /\ malloc_compatible sz p) && 
         data_at Tsh tuint (Vptrofs (Ptrofs.repr sz)) (offset_val (- WORD) p) *
         data_at Tsh (tptr tvoid) q p *
         memory_block Tsh (sz - WORD) (offset_val WORD p) *
         mmlist sz n q r
 end.

(* an uncurried variant, caters for use with iter_sepcon *)
Definition mmlist' (it: nat * val * Z) :=
  mmlist (bin2sizeZ (snd it)) (fst (fst it)) (snd (fst it)) nullval. 

Lemma mmlist_local_facts:
  forall sz len p r,
   mmlist sz len p r |--
   !! (0 <= sz <= Ptrofs.max_unsigned /\ 
       is_pointer_or_null p /\ is_pointer_or_null r /\ (p=r <-> len=O)).
Proof.
  intros. destruct len. 
  - (* len 0 *)
    destruct p; try contradiction; simpl; entailer!.
    -- (* p is 0 *)
      destruct r; try contradiction; simpl.
      destruct H0 as [? [? ?]].
      assert (Hiz: i = Int.zero) by (apply int_eq_e in H1; auto).
      split; auto. 
      split; auto. 
      intros; f_equal; auto.
    -- (* p is Vptr b i *)
      split.
      + destruct r; try contradiction; simpl; auto.
      + destruct r; try contradiction; simpl; auto.

split; auto. intros. destruct H0.
rewrite H0.

Search Ptrofs.eq true.

admit.
- (* len > 0 *) 
admit.
Admitted.
Hint Resolve mmlist_local_facts : saturate_local.

(*
Lemma mmlist_local_facts_Zlen:
  forall sz len p r,
   mmlist sz (Z.to_nat len) p r |--
   !! (0 <= sz <= Ptrofs.max_unsigned /\ 
       is_pointer_or_null p /\ is_pointer_or_null r /\ (p=r <-> len=0)).
Admitted.
Hint Resolve mmlist_local_facts_Zlen : saturate_local.
*)

Lemma mmlist_ne_valid_pointer:
  forall sz len p r,  (len > 0)%nat ->
   mmlist sz len p r |-- valid_pointer p.
Proof.
  destruct len; unfold mmlist; fold mmlist; intros; normalize.
  omega.  auto with valid_pointer.
Qed.
Hint Resolve mmlist_ne_valid_pointer : valid_pointer.


Lemma mmlist_ne_len:
  forall sz len p q, p<>q ->
    mmlist sz (Z.to_nat len) p q |-- !! (len > 0).
Proof. 
  intros. destruct len.
  simpl; normalize. entailer!; omega. simpl. entailer!.
Qed.

(* ?? TODO fix this abomination:
The following is formulated as an equality so it can be used in 
both directions.  It's written using Nat.pred instead of len-1 because
Coq couldn't infer the type for len-1 in scripts that rely on this lemma.
(One workaround would involve replacing len by (Z.to_nat len).)

Note that by type of len, and mmlist_local_facts, 
p <> nullval and (mmlist sz len p nullval) imply (Z.of_nat len) > 0,
so that antecedent is only needed for the RHS-to-LHS direction.
*)

Lemma mmlist_unroll_nonempty:
  forall sz len p, p <> nullval -> isptr p -> (Z.of_nat len) > 0 ->
      mmlist sz len p nullval
  =   EX q:val,
      !!malloc_compatible sz p && 
      data_at Tsh tuint (Vptrofs (Ptrofs.repr sz)) (offset_val (- WORD) p) *
      data_at Tsh (tptr tvoid) q p *
      memory_block Tsh (sz - WORD) (offset_val WORD p) *
      mmlist sz (Nat.pred len) q nullval.
Proof.
  intros. apply pred_ext.
  - (* LHS |-- RHS *)
    destruct len. elimtype False; simpl in H1; omega.
    simpl. Intros q. Exists q. entailer.
  - (* RHS |-- LHS *)
    Intros q. destruct len. elimtype False; simpl in H1; omega.
    simpl. Exists q. entailer!.
Qed.

Lemma mmlist_empty: 
  forall sz, 0 <= sz <= Ptrofs.max_unsigned ->
             mmlist sz 0 nullval nullval = emp.
Proof.
  intros. apply pred_ext; simpl; entailer!.
Qed.

(* lemmas on constructing an mmlist from a big block (used in fill_bin) *)

(* FOLD an mmlist with tail pointing to initialized next object. *)
Lemma fill_bin_mmlist:
  forall s j r q,
malloc_compatible s (offset_val WORD q) ->
  mmlist s (Z.to_nat j) r (offset_val WORD q) * 
  field_at Tsh (tarray tuint 1) [] [(Vint (Int.repr s))] q * 
  memory_block Tsh (s-WORD) (offset_val (WORD+WORD) q) *
  field_at Tsh (tptr tvoid) [] (offset_val (WORD+s+WORD) q) (offset_val WORD q)  
  =
  mmlist s (Z.to_nat (j+1)) r (offset_val (s+WORD+WORD) q ).
Proof.
(* TODO only used L to R, could be entailment though at the cost of using
sep_apply rather than rewrite .*)
(* 
The LHS uses (tarray tuint 1) for the size field because 
that's how the store instruction is written. But mmlist is currently 
defined using simply tuint; change mmlist before proving this?
The lemmas also probably need antecedents about integer ranges.
*)
Admitted.






(* fold an mmlist with tail pointing to null
TODO ugh! quick hack for now; clean up after verifying malloc&free 
Also: I've ordered the conjuncts to match where used; it would be 
nicer to order same as in def of mmlist. 
*)
Lemma fill_bin_mmlist_null: 
  forall s j r q,
  (mmlist s (Z.to_nat j) r (offset_val WORD q) * 
(*  field_at Tsh (tarray tuint 1) [] [(Vint (Int.repr s))] q * *)
  (data_at Tsh (tarray tuint 1) [(Vint (Int.repr s))] q * 
  (field_at Tsh (tptr tvoid) [] nullval (offset_val WORD q) *
  memory_block Tsh (s-WORD) (offset_val (WORD+WORD) q) )))
  = 
  mmlist s (Z.to_nat (j+1)) r nullval.
Proof.
Admitted.

(* variations on VST's memory_block_split *)

Lemma memory_block_split_repr:
  forall (sh : share) (b : block) (ofs : ptrofs) (n m : Z),
       0 <= n ->
       0 <= m ->
       n + m <= n + m + (Ptrofs.unsigned ofs) < Ptrofs.modulus -> 
       memory_block sh (n + m) (Vptr b ofs) =
       memory_block sh n (Vptr b ofs) *
       memory_block sh m (Vptr b (Ptrofs.add ofs (Ptrofs.repr n))).
Proof.
  intros sh b ofs n m Hn Hm Hnm.
  assert (Hofs: ofs = (Ptrofs.repr (Ptrofs.unsigned ofs)))
    by (rewrite Ptrofs.repr_unsigned; auto). 
  rewrite Hofs.
  normalize.
  erewrite memory_block_split; try assumption.
  reflexivity.
Qed.

Lemma memory_block_split_offset:
  forall (sh : share) (p : val) (n m : Z),
       0 <= n ->
       0 <= m ->
       memory_block sh (n + m) p =
       memory_block sh n p *
       memory_block sh m (offset_val n p).
Proof.
  intros sh p n m Hn Hm.
  apply pred_ext. (* to enable use of entailer - at cost of duplicate proof *)
  - (* LHS |-- RHS *)
    destruct p; try entailer!.
    rewrite <- offset_val_unsigned_repr.
    simpl.
    rewrite memory_block_split_repr. 
    + entailer!. 
      rewrite Ptrofs.unsigned_repr. cancel.
      unfold size_compatible' in *. rep_omega. 
    + assumption. 
    + assumption.
    + unfold size_compatible' in *. rep_omega.
  - (* RHS |-- LHS 
       TODO almost same proof, followed by clumsy finish *)
    destruct p; try entailer!. 
    rewrite <- offset_val_unsigned_repr.
    simpl.  rewrite memory_block_split_repr. 
    entailer!. rewrite Ptrofs.unsigned_repr. cancel.
    unfold size_compatible' in *. rep_omega. assumption.  assumption.
    unfold size_compatible' in *.
    split. rep_omega. 
    simpl in H0.
    rewrite Ptrofs.modulus_eq32.
    replace (n+m+Ptrofs.unsigned i) with ((n + Ptrofs.unsigned i)+m) by omega.
    assert (Hni: 
              n + Ptrofs.unsigned i = (Ptrofs.unsigned (Ptrofs.add i (Ptrofs.repr n)))).
    { rewrite Ptrofs.add_unsigned. rewrite Ptrofs.unsigned_repr.
      rewrite Ptrofs.unsigned_repr. rep_omega. rep_omega.
      split. rep_omega. rewrite Ptrofs.unsigned_repr. rep_omega. rep_omega.
    }
    rewrite Hni. rep_omega.
    unfold Archi.ptr64; reflexivity.
Qed.


Lemma memory_block_split_block:
  forall s m q, 0 <= s /\ s+WORD <= m -> 
(*  field_compatible (tarray tuint 1) [] q ->
  field_compatible (tptr tvoid) [] (offset_val WORD q) -> *)
   malloc_compatible (s+WORD) q ->
   memory_block Tsh m q = 
   data_at_ Tsh (tarray tuint 1) q * (*size*)
   data_at_ Tsh (tptr tvoid) (offset_val WORD q) * (*nxt*)   
   memory_block Tsh (s - WORD) (offset_val (WORD+WORD) q) * (*rest of block*)
   memory_block Tsh (m-(s+WORD)) (offset_val (s+WORD) q). (*rest of large*)
Proof.
intros s m q [Hs Hm].
(* Since entailer has heuristics for field_compatible, 
which is needed for memory_block_data_at_, try to proceed
in entailment form even though that may duplicate steps. *)


(*
apply pred_ext.
- (* LHS |-- RHS *)
assert_PROP( field_compatible (tptr tvoid) [] (offset_val WORD q) ).
entailer!.
unfold size_compatible' in *.
unfold field_compatible.

rewrite <- memory_block_data_at_; try assumption. 
rewrite <- memory_block_data_at_; try assumption. 

red.
simpl.
intuition.


admit.
- (* RHS |-- LHS *)
rewrite <- memory_block_data_at_; try assumption. 
rewrite <- memory_block_data_at_; try assumption. 
simpl.
entailer!.

destruct q; try entailer!.

admit.
*) 
admit.
Admitted. 

Lemma free_large_memory_block: 
  (* TODO overly specific, for malloc_large. 
     And may need tighter bound on s. Also: don't need to 
     separate nxt from data since nxt not used (?). *)
  forall s p, 0 <= s <= Ptrofs.max_unsigned -> 
  memory_block Tsh (s + WA + WORD) (offset_val (- (WA + WORD)) p) 
  = 
  data_at_ Tsh tuint (offset_val (- WORD) p) *        (* size *)
  data_at_ Tsh (tptr tvoid) p *                       (* nxt *)
  memory_block Tsh (s - WORD) (offset_val WORD p) *   (* data *)
  memory_block Tsh WA (offset_val (- (WA + WORD)) p). (* waste *)
Proof. admit.
Admitted.

(* TODO following only used L to R but this form convenient *)
Lemma malloc_large_memory_block: 
  forall n p, 0 <= (n + WA + WORD) <= Ptrofs.max_unsigned -> 
  memory_block Tsh (n + WA + WORD) p
  = 
  memory_block Tsh WA p *                      (* waste *)
  data_at_ Tsh tuint (offset_val WA p) *       (* size *)
  memory_block Tsh n (offset_val (WA+WORD) p). (* data *)
Proof. 
intros. destruct p; try normalize.
apply pred_ext.
- (* L to R *)
rewrite data_at__memory_block.
normalize.
entailer!.
(* memory_block_field_compatible_tarraytuchar_ent Tsh (n+WA+WORD)(Vptr b i)).*)
(* TODO lost antecedent block; and need field_compatible lemma for subfield *)
(* TODO use memory_block_split but Ptrofs.repr form *)
admit.
Admitted.



(* TODO background for upd_Znth_same_val, belongs in a library *)
Lemma list_extensional {A}{d: Inhabitant A}: 
  forall (xs ys: list A),
  Zlength xs = Zlength ys ->
  (forall i, 0 <= i < Zlength xs -> Znth i xs = Znth i ys) -> xs = ys.
Proof.
intros xs.
induction xs. (*generalize dependent ys.*)
- intros. destruct ys. reflexivity.
  rewrite Zlength_nil in H. rewrite Zlength_cons in H. 
  assert (0 <= Zlength ys) by apply Zlength_nonneg. omega.
- intros. destruct ys as [|w ws]. 
  rewrite Zlength_nil in H. rewrite Zlength_cons in H. 
  assert (0 <= Zlength xs) by apply Zlength_nonneg. omega.
  specialize (IHxs ws). 
  assert (Zlength xs = Zlength ws) by 
    ( do 2 rewrite Zlength_cons in H; apply Z.succ_inj in H; auto).
  + (* first elts equal *)
    assert (0<=0<Zlength (a::xs)) by 
        (split; try omega; rewrite Zlength_cons; rep_omega).
    assert (Znth 0 (a :: xs) = Znth 0 (w :: ws)).
    apply H0; auto.
    apply IHxs in H1. subst.
    apply H0 in H2. do 2 rewrite Znth_0_cons in H2.  subst. reflexivity.
    intros. 
    clear H H3.
    specialize (H0 (i+1)).
    do 2 rewrite Znth_pos_cons in H0; try omega.
    replace (i+1-1) with i in H0 by omega.
    apply H0. split; try omega. rewrite Zlength_cons. rep_omega.
Qed.


(* module invariant mm_inv 

There is an array,
its elements point to null-terminated lists of right size blocks, 
and there is some wasted memory.
*) 

Definition zip3 (bs:list nat) (cs:list val) (ds:list Z) := (combine (combine bs cs) ds).

Lemma Zlength_zip3:
   forall bs cs ds,
   Zlength bs = Zlength cs -> Zlength cs = Zlength ds ->
   Zlength (zip3 bs cs ds) = Zlength bs.
Proof.
  intros.  unfold zip3.  do 2 rewrite Zlength_correct in *.
  do 2 rewrite combine_length.  
  do 2 rewrite Nat2Z.inj_min. rewrite H. rewrite <- H0.  
  rewrite Z.min_r; try reflexivity.  rewrite Z.min_r; try reflexivity.
Qed.

Lemma Znth_zip3:
   forall bs cs ds n,
   Zlength bs = Zlength cs -> Zlength cs = Zlength ds ->
   0 <= n < Zlength bs ->
   Znth n (zip3 bs cs ds) = (Znth n bs, Znth n cs, Znth n ds).
Proof.
  intros.
  pose proof (Zlength_zip3 bs cs ds H H0).
  unfold zip3. rewrite <- nth_Znth.
- rewrite combine_nth. rewrite combine_nth.
  rewrite nth_Znth; try omega. 
  rewrite nth_Znth; try omega.
  rewrite nth_Znth; try omega; reflexivity.
  repeat rewrite Zlength_correct in *; omega.
  rewrite combine_length. 
  assert (H3: length bs = length cs) by (repeat rewrite Zlength_correct in *; omega).
  assert (H4: length cs = length ds) by (repeat rewrite Zlength_correct in *; omega).
  rewrite H3. rewrite H4. rewrite Nat.min_id; reflexivity.
- unfold zip3 in H2; omega.
Qed.


Lemma sublist_zip3:
forall i j bs cs ds, 
  0 <= i <= j -> j <= Zlength bs ->
  Zlength bs = Zlength cs -> Zlength cs = Zlength ds ->
(sublist i j (zip3 bs cs ds)) = 
(zip3 (sublist i j bs) (sublist i j cs) (sublist i j ds)).
Proof. 
  intros.
  destruct H as [Hi Hij].
  apply list_extensional.
- rewrite Zlength_sublist; try omega.
  rewrite Zlength_zip3; try omega.
  rewrite Zlength_sublist; try omega.
  repeat rewrite Zlength_sublist; try omega.
  repeat rewrite Zlength_sublist; try omega.
  rewrite Zlength_zip3; try rep_omega.
- intros.
  destruct H as [Hi0lo Hi0hi].
  assert (Hi0: i0 < j - i) by
    (rewrite Zlength_sublist in  Hi0hi; auto; rewrite Zlength_zip3; try omega).
  rewrite Znth_sublist; try omega.
  rewrite Znth_zip3; try omega.  rewrite Znth_zip3; try omega.
  rewrite Znth_sublist; try omega.  rewrite Znth_sublist; try omega.
  rewrite Znth_sublist; try omega.  reflexivity.
  rewrite Zlength_sublist; try omega. rewrite Zlength_sublist; try omega.
  rewrite Zlength_sublist; try omega. rewrite Zlength_sublist; try omega.
  rewrite Zlength_sublist;  omega.
Qed.

Definition mm_inv (gv: globals): mpred := 
  EX bins: list val, EX lens: list nat, EX idxs: list Z,
    !! (Zlength bins = BINS /\ Zlength lens = BINS /\
        idxs = map Z.of_nat (seq 0 (Z.to_nat BINS))) &&
  data_at Tsh (tarray (tptr tvoid) BINS) bins (gv _bin) * 
  iter_sepcon mmlist' (zip3 lens bins idxs) * 
  TT. (* waste, which arises due to alignment in bins *)


(* Two lemmas from hashtable exercise *)
Lemma iter_sepcon_1:
  forall {A}{d: Inhabitant A} (a: A) (f: A -> mpred), iter_sepcon f [a] = f a.
Proof. intros. unfold iter_sepcon. normalize. 
Qed.

Lemma iter_sepcon_split3: 
  forall {A}{d: Inhabitant A} (i: Z) (al: list A) (f: A -> mpred),
   0 <= i < Zlength al   -> 
  iter_sepcon f al = 
  iter_sepcon f (sublist 0 i al) * f (Znth i al) * iter_sepcon f (sublist (i+1) (Zlength al) al).
Proof. 
  intros. rewrite <- (sublist_same 0 (Zlength al) al) at 1 by auto.
  rewrite (sublist_split 0 i (Zlength al)) by rep_omega.
  rewrite (sublist_split i (i+1) (Zlength al)) by rep_omega.
  rewrite sublist_len_1 by rep_omega.
  rewrite iter_sepcon_app. rewrite iter_sepcon_app. rewrite iter_sepcon_1.
  rewrite sepcon_assoc. reflexivity.
Qed.

Lemma mm_inv_split':
 forall b:Z, forall bins lens idxs,
     0 <= b < BINS -> Zlength bins = BINS -> Zlength lens = BINS -> 
     idxs = map Z.of_nat (seq 0 (Z.to_nat BINS)) ->
 iter_sepcon mmlist' (sublist 0 b (zip3 lens bins idxs)) * 
 iter_sepcon mmlist' (sublist (b+1) BINS (zip3 lens bins idxs)) *
 mmlist (bin2sizeZ b) (Znth b lens) (Znth b bins) nullval 
  =
 iter_sepcon mmlist' (zip3 lens bins idxs). 
Proof. 
  intros.
  replace (mmlist (bin2sizeZ b) (Znth b lens) (Znth b bins) nullval)
     with (mmlist' ((Znth b lens), (Znth b bins), b)) by (unfold mmlist'; auto).
  assert (Hassoc: 
      iter_sepcon mmlist' (sublist 0 b (zip3 lens bins idxs)) *
      iter_sepcon mmlist' (sublist (b + 1) BINS (zip3 lens bins idxs)) *
      mmlist' (Znth b lens, Znth b bins, b) 
    = 
      iter_sepcon mmlist' (sublist 0 b (zip3 lens bins idxs)) *
      mmlist' (Znth b lens, Znth b bins, b) * 
      iter_sepcon mmlist' (sublist (b + 1) BINS (zip3 lens bins idxs)) )
    by ( apply pred_ext; entailer!).
  rewrite Hassoc; clear Hassoc.
  assert (Hidxs: Zlength idxs = BINS) 
    by  (subst; rewrite Zlength_map; rewrite Zlength_correct; 
         rewrite seq_length; try rep_omega).
  replace (Znth b lens, Znth b bins, b) with (Znth b (zip3 lens bins idxs)).
  replace BINS with (Zlength (zip3 lens bins idxs)).
  erewrite <- (iter_sepcon_split3 b _ mmlist'); auto.
  split. 
  - omega.
  - rewrite Zlength_zip3; try rep_omega. 
  - rewrite Zlength_zip3; try rep_omega. 
  - rewrite Znth_zip3 by rep_omega. replace b with (Znth b idxs) at 6; auto.
    subst. rewrite Znth_map. unfold Znth. if_tac. omega.
    rewrite seq_nth. simpl. rep_omega. rep_omega.
    rewrite Zlength_correct. rewrite seq_length. rep_omega.
Qed.


Lemma mm_inv_split: 
 forall gv:globals, forall b:Z, 0 <= b < BINS ->
   mm_inv gv
 = 
  EX bins: list val, EX lens: list nat, EX idxs: list Z,
    !! (Zlength bins = BINS /\ Zlength lens = BINS /\ Zlength idxs = BINS 
        /\ idxs = map Z.of_nat (seq 0 (Z.to_nat BINS))) &&
  data_at Tsh (tarray (tptr tvoid) BINS) bins (gv _bin) * 
  iter_sepcon mmlist' (sublist 0 b (zip3 lens bins idxs)) * 
  mmlist (bin2sizeZ b) (Znth b lens) (Znth b bins) nullval * 
  iter_sepcon mmlist' (sublist (b+1) BINS (zip3 lens bins idxs)) *  
  TT. 
Proof. 
  intros. apply pred_ext.
  - (* LHS -> RHS *)
    unfold mm_inv.
    Intros bins lens idxs. Exists bins lens idxs. entailer!.
    rewrite <- (mm_inv_split' b). 
    entailer!. assumption. assumption.  assumption. reflexivity.
  - (* RHS -> LHS *)
    Intros bins lens idxs. 
    unfold mm_inv. Exists bins lens idxs. 
    entailer!.
    set (idxs:=(map Z.of_nat (seq 0 (Z.to_nat BINS)))).
    replace (
        iter_sepcon mmlist' (sublist 0 b (zip3 lens bins idxs)) *
        mmlist (bin2sizeZ b) (Znth b lens) (Znth b bins) nullval *
        iter_sepcon mmlist' (sublist (b + 1) BINS (zip3 lens bins idxs)) )
      with (
          iter_sepcon mmlist' (sublist 0 b (zip3 lens bins idxs)) *
          iter_sepcon mmlist' (sublist (b + 1) BINS (zip3 lens bins idxs)) *
          mmlist (bin2sizeZ b) (Znth b lens) (Znth b bins) nullval )
      by (apply pred_ext; entailer!).  
    rewrite (mm_inv_split' b).
    cancel. assumption. assumption. assumption. auto.
Qed.


(* Note: In the antecedent in the following entailment, the conjunct
   data_at Tsh (tptr tvoid) _ p
   ensures that p is aligned for its type, but noted in comment in the 
   proof, that alignment is modulo 4 rather than natural_alignment (8). 

   PENDING: should probably just include malloc_compatible as an antecedent,
   but that will require strengthening mm_inv (via mmlist) as noted in proof of 
   body_malloc_small.
*)
Lemma to_malloc_token_and_block:
forall n p q s, 0 < n <= bin2sizeZ(BINS-1) -> s = bin2sizeZ(size2binZ(n)) -> 
(*     (malloc_compatible n p) -> *)
  (  data_at Tsh tuint (Vptrofs (Ptrofs.repr s)) (offset_val (- WORD) p) *
     ( data_at Tsh (tptr tvoid) q p *
     memory_block Tsh (s - WORD) (offset_val WORD p) )
|--  malloc_token Tsh n p * memory_block Tsh n p).
Proof.
intros n p q s Hn Hs.
unfold malloc_token.
Exists s.
unfold malloc_tok.
if_tac.
- (* small block *)
  entailer!. split.
  -- pose proof (claim1 n (proj2 Hn)). rep_omega.
  -- unfold field_compatible in H2.
     destruct H2 as [? [? [? [? ?]]]].
     destruct p; auto; try (apply claim1; rep_omega).
(* TODO needs malloc_compatible antecedent *)
admit.
(*
     unfold malloc_compatible.
     split.
     ++ unfold align_compatible in H8.
        inv H8.
(* note: H11 : (Memdata.align_chunk ch | Ptrofs.unsigned i) *)

     ++ (* TODO clean up and remove dependence on named hyp *)
       (* i + n < modulus, follows from H5 size_compatible' at n *)
       unfold size_compatible' in H5.
       simpl in H5.
       assert(Hiw: (* need for following rewrites *)
                Ptrofs.unsigned i + WORD <= Ptrofs.max_unsigned )
         by (unfold size_compatible in H7; simpl in H7; rep_omega). 
       rewrite Ptrofs.add_unsigned in H5.
       rewrite Ptrofs.unsigned_repr in H5. 
       2: (rewrite Ptrofs.unsigned_repr by rep_omega; rep_omega).
       rewrite Ptrofs.unsigned_repr in H5 by rep_omega. 
       replace (Ptrofs.unsigned i + WORD + (bin2sizeZ (size2binZ n) - WORD))
             with (Ptrofs.unsigned i + (bin2sizeZ (size2binZ n))) 
             in H5 by omega.
       pose proof (claim1 n (proj2 Hn)). rep_omega. 
*)
  -- set (s:=(bin2sizeZ(size2binZ(n)))).
     sep_apply (data_at_memory_block Tsh (tptr tvoid) q p).
     simpl.
     rewrite <- memory_block_split_offset.
     2: rep_omega.
     rewrite sepcon_comm by omega.
     rewrite <- memory_block_split_offset.
     2: rep_omega.
     replace (WORD+(s-WORD)) with s by omega.
     replace (n+(s-n)) with s by omega.
     entailer!.
     subst s.
     assert (Hnn: n <= bin2sizeZ (size2binZ n)) by (apply claim1; rep_omega).
     rep_omega.
     assert (Hn' : 0 <= n <= bin2sizeZ (BINS - 1)) by rep_omega.
     pose proof (size2bin_range n Hn').
     pose proof (bin2size_range (size2binZ n) H6).
     subst s; rep_omega.
- (* large block *)
(* TODO similar to above, so wait til that's done *)
admit.
Admitted.


Lemma from_malloc_token_and_block:  
forall n p,
  0 <= n <= Ptrofs.max_unsigned - WORD -> 
    (malloc_token Tsh n p * memory_block Tsh n p)
  = (EX s:Z,
      !! ( n <= s /\ s + WA + WORD <= Ptrofs.max_unsigned /\ 
           malloc_compatible n p /\ 
           (s <= bin2sizeZ(BINS-1) -> s = bin2sizeZ(size2binZ(n)))) && 
      data_at Tsh tuint (Vptrofs (Ptrofs.repr s)) (offset_val (- WORD) p) * (* size *)
      data_at_ Tsh (tptr tvoid) p *                                         (* nxt *)
      memory_block Tsh (s - WORD) (offset_val WORD p) *                     (* data *)
      (if zle s (bin2sizeZ(BINS-1)) then emp                                (* waste *)
       else memory_block Tsh WA (offset_val (-(WA+WORD)) p))).
Admitted.
(* Maybe prove in two steps: 
from (malloc_token Tsh n p * memory_block Tsh n p)
get (data_at Tsh tuint (Vptrofs (Ptrofs.repr sz)) (offset_val (- WORD) p) *
     memory_block Tsh n p) * 
     memory_block Tsh (bin2sizeZ(size2binZ(n)) - n) (offset_val n p). 
whence 
    (data_at Tsh tuint (Vptrofs (Ptrofs.repr sz)) (offset_val (- WORD) p) *
     memory_block Tsh sz p) *
     memory_block Tsh (bin2sizeZ(size2binZ(n)) - n) (offset_val n p). 
and finally, carve off the pointer field at p and catenate the remainder block.
*)


(*+ code specs *)


(* copy of malloc_spec' from floyd/library, with mm_inv added
and size bound revised to refer to Ptrofs and to account for
the header of size WORD.  
Also n > 0 so memory_block p implies valid_pointer p.
*)
Definition malloc_spec' := 
   DECLARE _malloc
   WITH n:Z, bin:val, gv:globals
   PRE [ _nbytes OF tuint ]
       PROP (0 < n <= Ptrofs.max_unsigned - (WA+WORD))
       LOCAL (temp _nbytes (Vptrofs (Ptrofs.repr n)); gvars gv)
       SEP ( mm_inv gv )
   POST [ tptr tvoid ] EX p:_,
       PROP ()
       LOCAL (temp ret_temp p)
       SEP ( mm_inv gv;
             if eq_dec p nullval then emp
             else (malloc_token Tsh n p * memory_block Tsh n p)).

(* copy from floyd lib, revised to allow NULL as per posix std,
and with mm_inv added.
n is the requested size, not the actual block size *)
Definition free_spec' := 
   DECLARE _free
   WITH p:_, n:_, gv:globals
   PRE [ _p OF tptr tvoid ]
       PROP ()
       LOCAL (temp _p p; gvars gv)
       SEP (mm_inv gv; 
            if eq_dec p nullval then emp
            else (malloc_token Tsh n p * memory_block Tsh n p))
   POST [ Tvoid ]
       PROP ()
       LOCAL ( )
       SEP (mm_inv gv).

Definition malloc_small_spec :=
   DECLARE _malloc_small
   WITH n:Z, gv:globals
   PRE [ _nbytes OF tuint ]
       PROP (0 < n <= bin2sizeZ(BINS-1))
       LOCAL (temp _nbytes (Vptrofs (Ptrofs.repr n)); gvars gv)
       SEP ( mm_inv gv )
   POST [ tptr tvoid ] EX p:_,
       PROP ()
       LOCAL (temp ret_temp p)
       SEP ( mm_inv gv; 
            if eq_dec p nullval then emp
            else (malloc_token Tsh n p * memory_block Tsh n p)).

(* Note that this is a static function so there's no need to hide
globals in its spec; but that seems to be needed, given the definition 
of mm_inv.*)
Definition malloc_large_spec :=
   DECLARE _malloc_large
   WITH n:Z, gv:globals
   PRE [ _nbytes OF tuint ]
       PROP (bin2sizeZ(BINS-1) < n <= Ptrofs.max_unsigned - (WA+WORD))
       LOCAL (temp _nbytes (Vptrofs (Ptrofs.repr n)); gvars gv)
       SEP ( mm_inv gv )
   POST [ tptr tvoid ] EX p:_,
       PROP ()
       LOCAL (temp ret_temp p)
       SEP ( mm_inv gv; 
            if eq_dec p nullval then emp
            else (malloc_token Tsh n p * memory_block Tsh n p)).


(* s is the stored block size and n is the original request amount. *)
Definition free_small_spec :=
   DECLARE _free_small
   WITH p:_, s:_, n:_, gv:globals
   PRE [ _p OF tptr tvoid, _s OF tuint ]
       PROP (0 <= n <= bin2sizeZ(BINS-1) /\ s = bin2sizeZ(size2binZ(n)))
       LOCAL (temp _p p; temp _s (Vptrofs (Ptrofs.repr s)); gvars gv)
       SEP ( data_at Tsh tuint (Vptrofs (Ptrofs.repr s)) (offset_val (- WORD) p); 
            data_at_ Tsh (tptr tvoid) p;
            memory_block Tsh (s - WORD) (offset_val WORD p);
            mm_inv gv)
   POST [ tvoid ]
       PROP ()
       LOCAL ()
       SEP (mm_inv gv).

(* The postcondition describes the list returned, together with
   TT for the wasted space at the beginning and end of the big block from mmap. *)
Definition fill_bin_spec :=
 DECLARE _fill_bin
  WITH b: _
  PRE [ _b OF tint ]
     PROP(0 <= b < BINS) LOCAL (temp _b (Vint (Int.repr b))) SEP ()
  POST [ (tptr tvoid) ] EX p:_, EX len:Z,
     PROP( if eq_dec p nullval then True else len > 0 ) 
     LOCAL(temp ret_temp p)
     SEP ( if eq_dec p nullval then emp
           else mmlist (bin2sizeZ b) (Z.to_nat len) p nullval * TT).

(* 
Definition main_spec :=
 DECLARE _main
  WITH u : unit
  PRE  [] main_pre prog nil u
  POST [ tint ]  main_post prog nil u.
*)

Definition Gprog : funspecs := 
 ltac:(with_library prog [ 
   mmap0_spec; munmap_spec; bin2size_spec; size2bin_spec; fill_bin_spec;
   malloc_small_spec; malloc_large_spec; free_small_spec; malloc_spec'; 
   free_spec']).

(*+ code correctness *)

Lemma body_bin2size: semax_body Vprog Gprog f_bin2size bin2size_spec.
Proof. start_function. forward. 
Qed.


Lemma body_size2bin: semax_body Vprog Gprog f_size2bin size2bin_spec.
Proof. start_function. 
  forward_call (BINS-1). rep_omega. 
  forward_if.
  - (* then *) 
    forward. entailer!. f_equal. f_equal. unfold size2binZ; simpl. 
    bdestruct (bin2sizeZ (BINS - 1) <? s); try omega.
  - (* else *)
    forward.  entailer!. f_equal. unfold size2binZ. 
    bdestruct (bin2sizeZ (BINS - 1) <? s); try omega.
    unfold Int.divu. do 2 rewrite Int.unsigned_repr by rep_omega. 
    f_equal. normalize.  f_equal. rep_omega.
Qed.


(* Invariant for loop in fill_bin.
p, N, s are fixed
s + WORD is size of a (small) block (including header)
p is start of the big block
N is the number of blocks that fit following the waste prefix of size s
q points to the beginning of a list block (size field), unlike the link field
which points to the link field of the following list block. 
(Recall that the mmlist predicate also refers to link field addresses.)

The condition s + WORD <= BIGBLOCK - WA - j*(s+WORD) says there is room
for another block.  This is true even after the last iteration; the last
block is finalized following the loop.  The condition may be a consequence 
of the other invariants, but maintaining it is an easier way to prove it 
where needed.
*)

Definition fill_bin_Inv (p:val) (s:Z) (N:Z) := 
  EX j:_,
  PROP ( N = (BIGBLOCK-WA) / (s+WORD) /\ 
         0 <= s <= bin2sizeZ(BINS-1) /\ 
         0 <= j < N /\ 
         s + WORD <= BIGBLOCK - WA - j*(s+WORD)  
       )  
(* j remains strictly smaller than N because j is the number 
of finished blocks and the last block gets finished following the loop. *)
  LOCAL( temp _q (offset_val (WA+(j*(s+WORD))) p);
         temp _p p; 
         temp _s       (Vint (Int.repr s));
         temp _Nblocks (Vint (Int.repr N));
         temp _j       (Vint (Int.repr j)))  
(* (offset_val (WA + M + WORD) p) accounts for waste plus M many blocks plus
the offset for size field.  The last block's nxt points one word _inside_ 
the remaining part of the big block. *)
  SEP (memory_block Tsh WA p; (* initial waste *)
       mmlist s (Z.to_nat j) (offset_val (WA + WORD) p) 
                             (offset_val (WA + (j*(s+WORD)) + WORD) p); 
       memory_block Tsh (BIGBLOCK-(WA+j*(s+WORD))) (offset_val (WA+(j*(s+WORD))) p)). 

(* a propositional consequence of the invariant *)
Lemma malloc_compat_q:
forall N j p s q,
  malloc_compatible BIGBLOCK p ->
  N = (BIGBLOCK-WA) / (s+WORD) -> 
  0 <= j < N ->
  0 <= s <= bin2sizeZ(BINS-1) -> 
  q = (offset_val (WA+(j*(s+WORD))) p) -> 
  malloc_compatible s (offset_val WORD q).
Admitted.

Lemma weak_valid_pointer_end:
forall p,
valid_pointer (offset_val (-1) p) |-- weak_valid_pointer p.
Proof.
Admitted.

Lemma sepcon_weak_valid_pointer1: 
 forall (P Q : mpred) (p : val),
   P |-- weak_valid_pointer p -> P * Q |-- weak_valid_pointer p.
Admitted.

Lemma sepcon_weak_valid_pointer2:
  forall (P Q : mpred) (p : val),
    P |-- weak_valid_pointer p -> Q * P |-- weak_valid_pointer p.
Admitted.

Hint Resolve weak_valid_pointer_end: valid_pointer. 
Hint Resolve sepcon_weak_valid_pointer1: valid_pointer. 
Hint Resolve sepcon_weak_valid_pointer2: valid_pointer. 

Lemma memory_block_weak_valid_pointer:
forall n p sh,
 sepalg.nonidentity sh ->
 memory_block sh n p
  |-- weak_valid_pointer p.
Admitted.

Lemma memory_block_weak_valid_pointer2:
forall (sh : share) (n : Z) (p : val) (i : Z),
       0 <= i <= n ->
       sepalg.nonidentity sh ->
       memory_block sh n p |-- weak_valid_pointer (offset_val i p).
Admitted.

Hint Resolve memory_block_weak_valid_pointer: valid_pointer. 

(* maybe: *)
Hint Resolve memory_block_weak_valid_pointer2: valid_pointer.

(* TODO background for upd_Znth_same_val, belongs in a library *)

Lemma upd_Znth_same_val {A} {d: Inhabitant A}:
  forall n (xs: list A), 0 <= n < Zlength xs ->
   (upd_Znth n xs (Znth n xs)) = xs.
Proof.
  intros. 
  symmetry. apply (list_extensional xs (upd_Znth n xs (Znth n xs))).
  rewrite upd_Znth_Zlength; auto.
  intros.  bdestruct (Z.eqb n i).
  - subst. rewrite upd_Znth_same. reflexivity. auto.
  - rewrite upd_Znth_diff; try reflexivity; auto.
Qed.


Lemma upd_Znth_twice {A} {d: Inhabitant A}:
forall n x y (xs:list A),
   0 <= n < Zlength xs ->
   (upd_Znth n (upd_Znth n xs x) y) = (upd_Znth n xs y).
Proof.
  intros. symmetry.
  apply (list_extensional (upd_Znth n xs y) (upd_Znth n (upd_Znth n xs x) y)).
  repeat (rewrite upd_Znth_Zlength; auto).
  intros.  bdestruct (Z.eqb n i).
  - subst. repeat rewrite upd_Znth_same; auto. 
    rewrite upd_Znth_Zlength in *; auto.
  - assert (0 <= i < Zlength xs) by (rewrite upd_Znth_Zlength in H0; auto). 
    repeat rewrite upd_Znth_diff; auto;
    rewrite upd_Znth_Zlength in *; auto.
Qed. 


Lemma succ_pos: forall n:nat,   Z.of_nat (Nat.succ n) > 0.
Proof. intros. rewrite Nat2Z.inj_succ. rep_omega. 
Qed.


Lemma body_malloc:  semax_body Vprog Gprog f_malloc malloc_spec'.
Proof. 
start_function. 
forward_call (BINS-1). (* ** t'3 = bin2size(BINS-1) ** *)
rep_omega. 
forward_if. (* ** if nbytes > t'3 ** *)
- (* case nbytes > bin2size(BINS-1) *)
  forward_call (n,gv).  (* ** t'1 = malloc_large(nbytes) ** *)
  { (* precond *) rep_omega.  }
  Intros p.
  forward. (* ** return t'1 ** *) 
  if_tac.
  + (* case p = null *) Exists nullval. entailer!.
    if_tac; try contradiction. entailer!. (* line added after latest VST *)
  + Exists p. if_tac. contradiction. 
    entailer!.  
- (* case nbytes <= bin2size(BINS-1) *)
  forward_call(n,gv).  (* ** t'2 = malloc_small(nbytes) ** *)
  { (* precond *) rep_omega. }
  Intros p.
  forward. (* ** result = t'2 ** *)
  Exists p. 
  entailer!.
Qed.

Lemma body_free:  semax_body Vprog Gprog f_free free_spec'.
Proof. 
start_function. 
forward_if (PROP()LOCAL()SEP(mm_inv gv)). (* ** if (p != NULL) ** *)
- (* typecheck *) if_tac. entailer!.
  (* non-null case *)
  assert_PROP( 0 < n ) by (unfold malloc_token;  unfold malloc_tok; entailer).
  entailer!.
- (* case p!=NULL *)
  apply semax_pre with 
   (PROP ( )
     LOCAL (temp _p p; gvars gv)
     SEP (mm_inv gv;  malloc_token Tsh n p * memory_block Tsh n p)).
  { if_tac; entailer!. }
  assert_PROP ( 0 <= n <= Ptrofs.max_unsigned - WORD ) by entailer!.
  rewrite (from_malloc_token_and_block n p H0).
  Intros s.
  assert_PROP( 
     (force_val
     (sem_add_ptr_int tuint Signed (force_val (sem_cast_pointer p))
        (eval_unop Oneg tint (Vint (Int.repr 1)))) 
    = field_address tuint [] (offset_val (- WORD) p))).
    { entailer!. simpl. unfold field_address. if_tac. normalize. contradiction. }
  forward. (* ** t'2 = p[-1] ** *)
  forward. (* ** s = t'2 ** *) 
  forward_call(BINS - 1). (* ** t'1 = bin2size(BINS - 1) ** *)
  { (* precond *) rep_omega. } 
  forward_if (PROP () LOCAL () SEP (mm_inv gv)). (* ** if s <= t'1 ** *)
  -- (* case s <= bin2sizeZ(BINS-1) *)
    forward_call(p,s,n,gv). (* ** free_small(p,s) ** *) 
    { (* preconds *) split. split;  omega. omega. } 
    entailer!. if_tac. entailer. omega.
  -- (* case s > bin2sizeZ(BINS-1) *)
    if_tac. omega.
    (* ** munmap( p-(WASTE+WORD), s+WASTE+WORD ) ** *)
    forward_call( (offset_val (-(WA+WORD)) p), (s+WA+WORD) ).
    + entailer!.
       destruct p; try contradiction; simpl. normalize.
       rewrite Ptrofs.sub_add_opp. reflexivity.
    + (* munmap pre *)
      entailer!. rewrite free_large_memory_block. entailer!. rep_omega.
    + rep_omega.
    + entailer!.
- (* case p == NULL *) 
  forward. (* ** skip ** *)
  entailer!.
- (* after if *)
  forward. (* ** return ** *)
Qed.


Lemma body_malloc_large: semax_body Vprog Gprog f_malloc_large malloc_large_spec.
Proof.
start_function. 
forward_call (n+WA+WORD). (* ** t'1 = mmap0(nbytes+WASTE+WORD ...) ** *)
{ rep_omega. }
Intros p.
(* TODO could split cases here; then two symbolic executions but simpler ones *)
forward_if. (* ** if (p==NULL) ** *)
- (* typecheck guard *) 
  if_tac; entailer!.
- (* case p == NULL *) 
  forward. (* ** return NULL  ** *)
  Exists (Vint (Int.repr 0)).
  if_tac; entailer!. (* cases in post of mmap *)
- (* case p <> NULL *) 
  if_tac. (* cases in post of mmap *)
  + (* impossible case *)
    elimtype False. destruct p; try contradiction; simpl in *; try inversion H2.
  + (* note to QinXiang: forward here fails without nice message *)
    assert_PROP (
    (force_val
     (sem_add_ptr_int tuint Signed
        (force_val
           (sem_cast_pointer
              (force_val
                 (sem_add_ptr_int tschar Unsigned p
                    (Vint
                       (Int.sub
                          (Int.mul (Ptrofs.to_int (Ptrofs.repr 4)) (Int.repr 2))
                          (Ptrofs.to_int (Ptrofs.repr 4))))))))
         (Vint (Int.repr 0))) = field_address tuint [] (offset_val WA p)) ).
    (* painful pointer reasoning to enable forward p+WASTE)[0] = nbytes *)
     { entailer!. 
       destruct p; try contradiction; simpl.
       normalize.
       unfold field_address.
       rewrite if_true.
       simpl. 
       normalize. 
       hnf. (* drill down *) 
       repeat split; auto.
       (* size compat *)
       red. red in H3. unfold Ptrofs.add.
       rewrite (Ptrofs.unsigned_repr WA) by rep_omega.
       rewrite Ptrofs.unsigned_repr by rep_omega.
       simpl sizeof. rep_omega.
       (* align compat *)
       red.
       eapply align_compatible_rec_by_value; try reflexivity.
       simpl in *. unfold natural_alignment in *. unfold Z.divide in *.
       destruct H0 as [Hz Hlim]. inv Hz.
       rewrite <- (Ptrofs.repr_unsigned i).  rewrite H0.
       exists (2*x+1). change WA with 4.
       rewrite ptrofs_add_repr. rewrite Ptrofs.unsigned_repr.
       omega. rep_omega.
     }
     rewrite malloc_large_memory_block; try rep_omega. 
    Intros. (* flatten sep *)
    forward. (* ** (p+WASTE)[0] = nbytes;  ** *)
    (* { (* typecheck *) entailer!. destruct p; try contradiction; simpl; auto. } *)
    forward. (* ** return (p+WASTE+WORD);  ** *)
    Exists (offset_val (WA+WORD) p).
    entailer!.  destruct p; try contradiction; simpl; auto. normalize.
    if_tac. entailer!. 
    elimtype False. destruct p; try contradiction; simpl in *. 
    match goal with | HA: Vptr _ _  = nullval |- _ => inv HA end.
    entailer!.
    unfold malloc_token.
    Exists n.
    unfold malloc_tok.
    if_tac. rep_omega. entailer!. 
    { apply malloc_compatible_offset; try rep_omega; try apply WORD_ALIGN_aligned.
      replace (n+(WA+WORD)) with (n + WA + WORD) by omega. assumption. }
    cancel.
    replace (n - n) with 0 by omega.
    rewrite memory_block_zero.
    entailer!.
Qed.


Lemma body_fill_bin: semax_body Vprog Gprog f_fill_bin fill_bin_spec.
Proof. 
start_function. 
forward_call b.  (* ** s = bin2size(b) ** *)
set (s:=bin2sizeZ b).
assert (0 <= s <= bin2sizeZ(BINS-1))
  by (pose proof (bin2size_range b); rep_omega).
forward_call BIGBLOCK.  (* ** *p = mmap0(BIGBLOCK ...) ** *)  
{ apply BIGBLOCK_size. }
Intros p.
if_tac in H1. (* split cases on mmap post *)
(* case p = nullval *)
forward_if. (* ** if p == NULL ** *)
(* case p <> nullval *)
  forward. (* ** return NULL ** *)
  Exists nullval. Exists 1. 
  entailer!.  if_tac; try contradiction. entailer!. contradiction.
(* case p <> nullval *)
assert_PROP (isptr p) by entailer!.
destruct p;  try contradiction. 
rename b0 into pblk. rename i into poff. (* p as blk+ofs *)
assert_PROP (Ptrofs.unsigned poff + BIGBLOCK < Ptrofs.modulus) by entailer!.
forward_if. (* entailer now took care of typecheck (issue #201 closed) *)
- contradiction.
- forward. (* ** Nblocks = (BIGBLOCK-WASTE) / (s+WORD) ** *)
  { (* nonzero divisor *) entailer!.
    match goal with 
    | HA: Int.repr _ = _  |- _  
      => apply repr_inj_unsigned in HA; rep_omega end. }
  deadvars!. 
  simpl in H0,H1|-*.  (* should be simpl in * but that would mess up postcond *)
  forward. (* ** q = p + WASTE ** *)
  rewrite ptrofs_of_intu_unfold. rewrite ptrofs_mul_repr. normalize.
  forward. (* ** j = 0 ** *) 
  forward_while (* ** while (j != Nblocks - 1) ** *) 
    (fill_bin_Inv (Vptr pblk poff) s ((BIGBLOCK-WA) / (s+WORD)) ).
* (* pre implies inv *)
  Exists 0. 
  entailer!. split3. split; try rep_omega.
  apply BIGBLOCK_enough; auto. unfold Int.divu. normalize. apply Ptrofs.eq_true.
  replace BIGBLOCK with (WA + (BIGBLOCK - WA)) at 1 by rep_omega.
  rewrite memory_block_split_repr; try rep_omega. 
  entailer!.
* (* pre implies guard defined *)
  entailer!.
  pose proof BIGBLOCK_enough as HB. specialize (HB s H0).
  change (Int.signed (Int.repr 1)) with 1.
  rewrite Int.signed_repr; rep_omega.
* (* body preserves inv *)
  match goal with | HA: _ /\ _ /\ _ /\ _ |- _ =>
                    destruct HA as [? [? [? ?]]] end.
  freeze [0] Fwaste. clear H.
  rewrite (memory_block_split_block s (BIGBLOCK - (WA + j * (s + WORD))) 
             (offset_val (WA + j * (s + WORD)) (Vptr pblk poff))).
  2: split; rep_omega.
  (* TODO better to do the other antecedent of memory_block_split_block here too*) 

  Intros. (* flattens the SEP clause *) 
  normalize. (* rewrite offset_offset_val.  *)
  forward. (* ** q[0] = s; ** *)
  freeze [1; 2; 4; 5] fr1. 
  (* prepare for next assignment, as suggested by hint from forward tactic *)
  assert_PROP ( 
  (Vptr pblk
      (Ptrofs.add (Ptrofs.add poff (Ptrofs.repr (WA + j * (s + WORD))))
        (Ptrofs.mul (Ptrofs.repr 4) (Ptrofs.of_ints (Int.repr 1))))) 
    = field_address (tptr tvoid) [] 
        (offset_val (WA + j * (s + WORD) + WORD) (Vptr pblk poff))).
  { entailer!. unfold field_address. simpl. normalize.
    if_tac. reflexivity. contradiction. }
  forward. (* ** *(q+WORD) = q+WORD+(s+WORD); ** *)
  forward. (* ** q += s+WORD; ** *)
  forward. (* ** j++; ** *) 
  { entailer!.
    pose proof BIGBLOCK_enough. specialize (H12 s H0).
    assert (Hx: Int.min_signed <= j+1) by rep_omega.
    split. rewrite Int.signed_repr. rewrite Int.signed_repr. assumption.
    rep_omega. rep_omega. rewrite Int.signed_repr. rewrite Int.signed_repr.
    assert (Hxx: j + 1 <= (BIGBLOCK-WA)/(s+WORD)) by omega.
    apply (Z.le_trans (j+1) ((BIGBLOCK-WA)/(s+WORD))).
    assumption. rep_omega. rep_omega. rep_omega. } 
  (* reestablish inv *)  
  Exists (j+1).  
  assert (Hdist: ((j+1)*(s+WORD))%Z = j*(s+WORD) + (s+WORD))
    by (rewrite Z.mul_add_distr_r; omega). 
  entailer!. 
  normalize. 
  { assert (HRE' : j <> ((BIGBLOCK - WA) / (s + WORD) - 1)) 
       by (apply repr_neq_e; assumption). 
    assert (HRE2: j+1 < (BIGBLOCK-WA)/(s+WORD)) by rep_omega.  
    split. split. 
    rep_omega.
    assert (H': 
              BIGBLOCK - WA - ((BIGBLOCK-WA)/(s+WORD)) * (s + WORD) 
              < BIGBLOCK - WA - (j + 1) * (s + WORD))
      by (apply Z.sub_lt_mono_l; apply Z.mul_lt_mono_pos_r; rep_omega).
    apply BIGBLOCK_enough_j. rep_omega. auto.
    do 3 f_equal. rep_omega.
  }
  thaw fr1. 
  thaw Fwaste; cancel. (* thaw and cancel the waste *)
  normalize. 
  (* cancel the big block, prior to folding the list *)
  assert (Hassoc: BIGBLOCK - (WA + j * (s + WORD)) - (s + WORD) 
                = BIGBLOCK - (WA + j * (s + WORD) + (s + WORD))) by omega.
  assert (Hbsz: (BIGBLOCK - (WA + j * (s + WORD)) - (s + WORD))
              = (BIGBLOCK - (WA + (j + 1) * (s + WORD)))) 
     by ( rewrite Hassoc; rewrite Hdist; rep_omega ). 
  rewrite Hbsz; clear Hbsz.  clear Hassoc. 
  assert (Hbpt:
     (offset_val (WA + j * (s + WORD) + (s + WORD)) (Vptr pblk poff))
   = (Vptr pblk (Ptrofs.add poff (Ptrofs.repr (WA + (j + 1) * (s + WORD)))))).
  { simpl. do 3 f_equal. rewrite Hdist. rep_omega. }
  rewrite <- Hbpt; clear Hbpt.
  cancel.
  (* fold list; aiming for lemma fill_bin_mmlist, first rewrite conjuncts, in order *)
  set (q':= (offset_val (WA + j * (s + WORD)) (Vptr pblk poff))). (* q' is prev val of q *)
  set (r:=(offset_val (WA + WORD) (Vptr pblk poff))). (* r is start of list *)
  change (offset_val (WA + WORD) (Vptr pblk poff)) with r.
  replace (offset_val (WA + j * (s + WORD) + WORD) (Vptr pblk poff)) 
     with (offset_val WORD q') by (unfold q'; normalize).
  replace (upd_Znth 0 (default_val (tarray tuint 1) ) (Vint (Int.repr s)))
    with [(Vint (Int.repr s))] by (unfold default_val; normalize).
  replace (offset_val (WA + j * (s + WORD) + (WORD + WORD)) (Vptr pblk poff))
    with  (offset_val (WORD+WORD) q' ) by (unfold q'; normalize). 
  change 4 with WORD in *. (* ugh *)
  assert (HnxtContents: 
    (Vptr pblk
       (Ptrofs.add poff
          (Ptrofs.repr (WA + j * (s + WORD) + (WORD + (s + WORD))))))
    = (offset_val (WORD + s + WORD) q')). 
  { simpl. f_equal. rewrite Ptrofs.add_assoc. f_equal. normalize.
    f_equal. omega. }
  rewrite HnxtContents; clear HnxtContents.
  replace (Vptr pblk (Ptrofs.add poff (Ptrofs.repr (WA + j*(s+WORD) + WORD))))
    with  (offset_val WORD q') by (unfold q'; normalize). 
  rewrite fill_bin_mmlist. (* finally, use lemma to rewrite antecedent *)
  replace (Vptr pblk (Ptrofs.add poff (Ptrofs.repr (WA + WORD)))) with r  
    by (unfold r; normalize).
  assert (Hto: 
    (Vptr pblk (Ptrofs.add poff (Ptrofs.repr (WA + (j+1)*(s+WORD) + WORD))))
  = (offset_val (s+WORD+WORD) (offset_val (WA + j*(s+WORD)) (Vptr pblk poff)))).
  { simpl. f_equal. rewrite Ptrofs.add_assoc. f_equal. normalize.
    rewrite Hdist. f_equal. rep_omega. }
  rewrite Hto; clear Hto.
  subst q'.
  entailer.

(* TODO add'l proof obligations from memory_block_split_block; 
better to discharge earlier *)
  apply (malloc_compat_q ((BIGBLOCK-WA)/(s+WORD)) j (Vptr pblk poff) s q'); auto.
(* TODO should be getting this from the loop inv *)

admit.

(* 
unfold field_compatible.
simpl.
intuition.
admit. (* TODO arith *)
constructor.
intros.
assert (Hi: i = 0) by omega.
subst.
normalize.
admit. (* TODO stuck *)
constructor.
normalize.
simpl.
intuition.
admit. (* TODO arith *)
normalize.
admit. (* TODO stuck *)
*)

* (* after the loop *) 
(* TODO eventually: here we're setting up the assignments 
to finish the last block; this is like setting up in the loop body.
Then we fold into the list, like at the end of the loop body. 
It would be nice to factor commonalities. *)
  rewrite (memory_block_split_block s (BIGBLOCK - (WA + j * (s + WORD))) 
           (offset_val (WA + j * (s + WORD)) (Vptr pblk poff))).
  Intros. (* flattens the SEP clause *) 
  rewrite offset_offset_val.
  freeze [0;5] Fwaste. (* discard what's not needed for post *)
  forward. (* ** q[0] = s ** *)
  replace (upd_Znth 0 (default_val (tarray tuint 1) ) (Vint (Int.repr s)))
    with [(Vint (Int.repr s))] by (unfold default_val; normalize).
  assert_PROP (
      (Vptr pblk
        (Ptrofs.add (Ptrofs.add poff (Ptrofs.repr (WA + j * (s + WORD))))
           (Ptrofs.mul (Ptrofs.repr 4) (Ptrofs.of_ints (Int.repr 1)))) 
    = field_address (tptr tvoid) []
        (offset_val (WA + j * (s + WORD) + WORD) (Vptr pblk poff)))).
  { entailer!. normalize. 
    unfold field_address. if_tac. simpl. f_equal.
    rewrite Ptrofs.add_assoc. f_equal. normalize. contradiction. }
  forward. (* **   *(q+WORD) = NULL ** *)
  normalize.
  set (q:= (offset_val (WA + j * (s + WORD)) (Vptr pblk poff))). 
  set (r:=(offset_val (WA + WORD) (Vptr pblk poff))).   
  gather_SEP 1 2 3 4. (* prepare for fill_bin_mmlist_null rewrite *)
  apply semax_pre with
   (PROP ( )
     LOCAL (temp _q q; temp _p (Vptr pblk poff); temp _s (Vint (Int.repr s));
     temp _Nblocks (Vint (Int.repr ((BIGBLOCK - WA) / (s + WORD))));
     temp _j (Vint (Int.repr j)))
     SEP (FRZL Fwaste; (mmlist s (Z.to_nat (j+1)) r nullval))).
  { replace (offset_val (WA + j * (s + WORD) + WORD) (Vptr pblk poff))
       with (offset_val WORD q) by (unfold q; normalize).
    change (Vint (Int.repr 0)) with nullval.
    replace (offset_val (WA + j * (s + WORD) + (WORD + WORD)) (Vptr pblk poff))
       with (offset_val (WORD + WORD) q) by (unfold q; normalize).
    rewrite (fill_bin_mmlist_null s j r q).
    entailer!.
  }
  forward. (* **   return p+WASTE+WORD ** *) 
  Exists r.  Exists (j+1).
  entailer!. if_tac; auto. rep_omega.
  if_tac. entailer!.
  match goal with | HA: offset_val _ _ = nullval |- _ => inv HA end.
  unfold s. entailer!.
  split; try rep_omega.

(* TODO new side conditions from memory_block_split_block 
Roughly same as preceding similar *)
admit.
Admitted.


Lemma body_malloc_small:  semax_body Vprog Gprog f_malloc_small malloc_small_spec.
Proof. 
start_function. 
rewrite <- seq_assoc. 
forward_call n. (* ** t'1 = size2bin(nbytes) ** *)
{ assert (Hn: bin2sizeZ(BINS-1) <= Ptrofs.max_unsigned)
    by (apply bin2size_rangeB; rep_omega). rep_omega.  }
forward. (* ** b = t'1 ** *)
set (b:=size2binZ n).
assert (Hb: 0 <= b < BINS) by (apply (claim2 n); omega). 
rewrite (mm_inv_split gv b) by apply Hb. (* expose bins[b] in mm_inv *)
Intros bins lens idxs.
freeze [1; 3] Otherlists.
deadvars!.
forward. (* ** p = bin[b] ** *)
(* pose proof H2 as HidxsLen.  (* prevent following step from losing this *) *)
forward_if(
    EX p:val, EX len:Z,
     PROP(p <> nullval)
     LOCAL(temp _p p; temp _b (Vint (Int.repr b))(* ; gvar _bin (gv _bin) *); gvars gv)
     SEP(FRZL Otherlists; TT; 
         data_at Tsh (tarray (tptr tvoid) BINS) (upd_Znth b bins p) (gv _bin);
         mmlist (bin2sizeZ b) (Z.to_nat len) p nullval)). 

  + (* typecheck guard *)
  destruct (Znth b lens). 
  (*Set Printing Implicit. -- to see the need for following step. *)
  change Inhabitant_val with Vundef in H11.
  rewrite (proj2 H11 (eq_refl _)).  auto with valid_pointer. 
  assert (S n0 > 0)%nat by omega.  auto with valid_pointer.
  (* TODO add hints for mmlist *)
  + (* case p==NULL *) 
    change Inhabitant_val with Vundef in *.
    rewrite H4. 
    assert_PROP(Znth b lens = 0%nat) as Hlen0
        by (entailer!; apply H9; reflexivity).
    rewrite Hlen0.
    rewrite mmlist_empty.
    forward_call b. (* ** p = fill_bin(b) ** *) 
    Intro r_with_l; destruct r_with_l as [root len]; simpl.
    forward_if. (* ** if p==NULL ** *)
    { apply denote_tc_test_eq_split; auto with valid_pointer.
      if_tac. entailer!.
      sep_apply (mmlist_ne_valid_pointer (bin2sizeZ b) (Z.to_nat len) root nullval).
      change (Z.to_nat len > 0)%nat with (0 < Z.to_nat len)%nat.
      change 0%nat with (Z.to_nat 0). apply Z2Nat.inj_lt; rep_omega.
      entailer!.
    }
    ++ (* case p==NULL after fill_bin() *) 
      forward.
      Exists nullval.  entailer!. clear H6.
      thaw Otherlists.
      set (idxs:= (map Z.of_nat (seq 0 (Z.to_nat BINS)))).
      replace (data_at Tsh (tarray (tptr tvoid) BINS) bins (gv _bin))
         with (data_at Tsh (tarray (tptr tvoid) BINS) bins (gv _bin) * emp) 
         by normalize.
      rewrite <- (mmlist_empty (bin2sizeZ b)) at 2.
      rewrite <- Hlen0 at 1.
      unfold mm_inv. Exists bins. Exists lens. Exists idxs.
      entailer!. 
      match goal with | HA: (Znth b bins = _) |- _ => rewrite <- HA at 1 end.
      rewrite (mm_inv_split' b); auto.  apply bin2size_rangeB; auto.
    ++ (* case p<>NULL *)
      if_tac. contradiction.
      gather_SEP 0 1.  (* gather_SEP 1 2. rewrite TT_sepcon_TT. *) 
      Intros.
      forward. (* ** bin[b] = p ** *)
      Exists root. Exists len.  
      entailer. cancel. 
    ++ apply bin2size_rangeB; auto.
  + (* else branch p!=NULL *)
    forward. (* ** skip ** *)
    Exists (Znth b bins).  
    Exists (Z.of_nat (nth (Z.to_nat b) lens 0%nat)). (* annoying conversion *)
    rewrite Nat2Z.id.  
    rewrite upd_Znth_same_val by (rewrite H0; assumption). 
    entailer!.
    rewrite <- nth_Znth by (rewrite H1; assumption).  
    entailer.
  + (* after if: unroll and pop mmlist *)
    Intros p len.
    set (s:=bin2sizeZ b).  
    assert_PROP (len > 0).
    { entailer. sep_apply (mmlist_ne_len s len p nullval); auto.
      rewrite prop_sepcon. entailer!.  }
    assert_PROP (isptr p).
    { entailer!. unfold nullval in *.
      simpl in H4. (* not Archi.ptr64 *)
      unfold is_pointer_or_null in *. simpl in *.
      destruct p; try contradiction; simpl.
      subst. contradiction. auto. }
    rewrite (mmlist_unroll_nonempty s (Z.to_nat len) p);
       try (rewrite Z2Nat.id; rep_omega); try assumption.
    Intros q.
    assert_PROP(force_val (sem_cast_pointer p) = field_address (tptr tvoid) [] p).
    { entailer!. unfold field_address. if_tac. normalize. contradiction. }
    forward. (* ** q = *p ** *)
    forward. (* ** bin[b]=q ** *)
    (* prepare token+block to return *)
    deadvars!.
    thaw Otherlists.  gather_SEP 4 5 6.
    replace_SEP 0 (malloc_token Tsh n p * memory_block Tsh n p).
    go_lower.  change (-4) with (-WORD). (* ugh *)
(* TODO may need mm_inv to remember malloc_compatible, so that 
   can be added to antecedent of following lemma. *)
    apply (to_malloc_token_and_block n p q s). 
    assumption. unfold s; unfold b; reflexivity. 
    (* refold invariant *)
    rewrite upd_Znth_twice by (rewrite H0; apply Hb).
    gather_SEP 4 1 5.
    set (lens':=(upd_Znth b lens (Nat.pred (Z.to_nat len)))).
    set (bins':=(upd_Znth b bins (force_val (sem_cast_pointer q)))).
    assert (Hlens: Nat.pred (Z.to_nat len) = (Znth b lens')).
    { unfold lens'. rewrite upd_Znth_same. reflexivity. rewrite H1. assumption. }
    rewrite Hlens; clear Hlens.
    change s with (bin2sizeZ b).
    forward. (* ** return p ** *)
    Exists p. entailer!. if_tac. contradiction. cancel.
    unfold mm_inv. Exists bins'. Exists lens'. 
    set (idxs:= (map Z.of_nat (seq 0 (Z.to_nat BINS)))).
    Exists idxs. cancel.
    entailer!.
    subst lens'; rewrite upd_Znth_Zlength; rewrite H1; auto.
    assert (Hbins': sublist 0 b bins' = sublist 0 b bins) by
      (unfold bins'; rewrite sublist_upd_Znth_l; try reflexivity; try rep_omega).
    assert (Hlens': sublist 0 b lens' = sublist 0 b lens) by 
      (unfold lens'; rewrite sublist_upd_Znth_l; try reflexivity; try rep_omega).
    assert (Hbins'': sublist (b+1) BINS bins' = sublist (b+1) BINS bins) by
      (unfold bins'; rewrite sublist_upd_Znth_r; try reflexivity; try rep_omega).
    assert (Hlens'': sublist (b+1) BINS lens' = sublist (b+1) BINS lens) by
      (unfold lens'; rewrite sublist_upd_Znth_r; try reflexivity; try rep_omega).
    assert (Hsub:  sublist 0 b (zip3 lens bins idxs)
                 = sublist 0 b (zip3 lens' bins' idxs)).
    { repeat rewrite sublist_zip3; try rep_omega.
      - rewrite Hbins'. rewrite Hlens'.  reflexivity.
      - unfold lens'; rewrite upd_Znth_Zlength; repeat rep_omega.
      - unfold lens'; unfold bins'; rewrite upd_Znth_Zlength.
        rewrite upd_Znth_Zlength; rep_omega. rep_omega.
      - replace (Zlength bins') with BINS by auto. unfold idxs; auto.
      - unfold idxs; auto.   } 
    assert (Hsub':  sublist (b + 1) BINS (zip3 lens bins idxs)  
                  = sublist (b + 1) BINS (zip3 lens' bins' idxs)).
    { repeat rewrite sublist_zip3; try rep_omega.
      - rewrite Hbins''. rewrite Hlens''.  reflexivity.
      - unfold lens'; rewrite upd_Znth_Zlength; repeat rep_omega.
      - unfold lens'; unfold bins'; rewrite upd_Znth_Zlength.
        rewrite upd_Znth_Zlength; rep_omega. rep_omega.
      - replace (Zlength bins') with BINS by auto. unfold idxs; auto.
      - unfold idxs; auto.   } 
    rewrite Hsub. rewrite Hsub'.
    (* Here's a place where it would be nice if sep_apply could do rewriting *)
    rewrite pull_right.
    assert (Hq: q = (Znth b bins')). (* TODO clean this mess *)
    { unfold bins'. rewrite upd_Znth_same.  
      destruct q; auto 10  with valid_pointer.
      auto 10  with valid_pointer; (* destruct PNq. destruct PNq. destruct PNq. *)
      rewrite H0; assumption. }
    rewrite Hq.
    (* Annoying rewrite, but can't use replace_SEP because that's for 
       preconditions; would have to do use it back at the last forward. *)
    assert (Hassoc:
        iter_sepcon mmlist' (sublist 0 b (zip3 lens' bins' idxs)) *
        mmlist (bin2sizeZ b) (Znth b lens') (Znth b bins') nullval * TT *
        iter_sepcon mmlist' (sublist (b + 1) BINS (zip3 lens' bins' idxs))
      = iter_sepcon mmlist' (sublist 0 b (zip3 lens' bins' idxs)) *
        iter_sepcon mmlist' (sublist (b + 1) BINS (zip3 lens' bins' idxs)) *
        mmlist (bin2sizeZ b) (Znth b lens') (Znth b bins') nullval * TT)
           by (apply pred_ext; entailer!).
    rewrite Hassoc; clear Hassoc.
    rewrite mm_inv_split'; try entailer!; auto.
    subst lens'; rewrite upd_Znth_Zlength; rewrite H1; auto.
Qed.



Lemma body_free_small:  semax_body Vprog Gprog f_free_small free_small_spec.
Proof. 
start_function. 
destruct H as [[Hn Hn'] Hs].
forward_call s. (* ** b = size2bin(s) ** *)
{ subst; apply bin2size_rangeB; apply claim2; auto.  }
set (b:=(size2binZ n)). 
assert (Hb: b = size2binZ s) by (subst; rewrite claim3; auto).
rewrite <- Hb.
assert (Hb': 0 <= b < BINS) 
  by (change b with (size2binZ n); apply claim2; split; assumption).
rewrite (mm_inv_split gv b Hb'). (* to expose bins[b] in mm_inv *)
Intros bins lens idxs.
forward. (* **  void *q = bin[b] ** *) 
assert_PROP( (force_val (sem_cast_pointer p) = field_address (tptr tvoid) [] p) ). 
entailer!.
unfold field_address; normalize; if_tac; auto; contradiction.
forward. (* **  *((void ** )p) = q ** *)
gather_SEP 0 1 2 5.
set (q:=(Znth b bins)).
assert_PROP (p <> nullval) by entailer!.
apply semax_pre with 
    (PROP ( )
     LOCAL (temp _q q; temp _b (Vint (Int.repr b)); 
     temp _p p; temp _s (Vptrofs (Ptrofs.repr s)); 
     (* gvar _bin (gv _bin); *) gvars gv)
     SEP ((EX q': val, 
!!malloc_compatible s p &&
          data_at Tsh tuint (Vptrofs (Ptrofs.repr s)) (offset_val (- WORD) p) *
          data_at Tsh (tptr tvoid) q' p *
          memory_block Tsh (s - WORD) (offset_val WORD p) *
          mmlist (bin2sizeZ b) (Znth b lens) q' nullval) ;
     data_at Tsh (tarray (tptr tvoid) BINS) bins (gv _bin);
     iter_sepcon mmlist' (sublist 0 b (zip3 lens bins idxs)) ;
     iter_sepcon mmlist' (sublist (b + 1) BINS (zip3 lens bins idxs)) ;
     TT)).
{ Exists q. entailer!.  

admit. (* TODO new condition: malloc_compatible
          Add that to free_small_spec, and get it from  *)

(* entailer. *) } 
replace (bin2sizeZ b) with s by auto. 
change (Znth b lens)
  with (Nat.pred (Nat.succ (Znth b lens))).

assert_PROP( isptr p ). 
{ entailer!. unfold nullval in *.
  simpl in H4. (* not Archi.ptr64 *)
  unfold is_pointer_or_null in *. simpl in *.
  destruct p; try contradiction; simpl. subst. contradiction. auto. 
}
rewrite <- (mmlist_unroll_nonempty s (Nat.succ (Znth b lens)) p).
4: apply succ_pos.
3: assumption. 
2: assumption.
forward. (* **  bin[b] = p ** *)
set (bins':=(upd_Znth b bins p)).
set (lens':=(upd_Znth b lens (Nat.succ (Znth b lens)))).
gather_SEP 1 2 3 0. 
apply semax_pre with 
    (PROP ( )
     LOCAL (temp _q q; temp _b (Vint (Int.repr b)); 
     temp _p p; temp _s (Vptrofs (Ptrofs.repr s)); 
     (* gvar _bin (gv _bin); *) gvars gv)
     SEP (
  EX bins1: list val, EX lens1: list nat, EX idxs1: list Z,
  !! (Zlength bins1 = BINS /\ Zlength lens1 = BINS /\ Zlength idxs1 = BINS
      /\ idxs1 = map Z.of_nat (seq 0 (Z.to_nat BINS))) &&
    data_at Tsh (tarray (tptr tvoid) BINS) bins1 (gv _bin) * 
    iter_sepcon mmlist' (sublist 0 b (zip3 lens1 bins1 idxs1)) *
    mmlist (bin2sizeZ b) (Znth b lens1) (Znth b bins1) nullval *
    iter_sepcon mmlist' (sublist (b + 1) BINS (zip3 lens1 bins1 idxs1)) *
    TT )).
{ Exists bins'. Exists lens'. Exists idxs.
  assert_PROP(Zlength bins' = BINS /\ Zlength lens' = BINS).
  { unfold bins'.  unfold lens'.  
    rewrite (upd_Znth_Zlength b bins p); try omega.
    match goal with |- context [upd_Znth b lens ?X] => set (foo:=X) end.
    rewrite (upd_Znth_Zlength b lens foo); try omega. 
    entailer!. 
  }
  replace (bin2sizeZ b) with s by auto. 
  replace (bin2sizeZ b) with s by auto. 
  replace (Znth b bins') with p 
    by (unfold bins'; rewrite upd_Znth_same; auto; rewrite H; assumption). 
  replace (Nat.succ (Znth b lens)) with (Znth b lens') 
    by (unfold lens'; rewrite upd_Znth_same; try reflexivity; omega).
  entailer!.
  change (upd_Znth (size2binZ n) bins p) with bins'.  entailer!.
  (* remains to show bins' and lens' are same as originals aside from n *)
  set (idxs:=(map Z.of_nat (seq 0 (Z.to_nat BINS)))) in *.
  repeat rewrite sublist_zip3; try rep_omega.
  replace (sublist 0 (size2binZ n) lens') 
     with (sublist 0 (size2binZ n) lens) by
   (unfold lens'; rewrite sublist_upd_Znth_l; try reflexivity; try rep_omega).
  replace (sublist (size2binZ n + 1) BINS lens') 
     with (sublist (size2binZ n + 1) BINS lens) by 
   (unfold lens'; rewrite sublist_upd_Znth_r; try reflexivity; try rep_omega).
  replace (sublist 0 (size2binZ n) bins')
     with (sublist 0 (size2binZ n) bins) by 
   (unfold bins'; rewrite sublist_upd_Znth_l; try reflexivity; try rep_omega).
  replace (sublist (size2binZ n + 1) BINS bins')
     with (sublist (size2binZ n + 1) BINS bins) by 
   (unfold bins'; rewrite sublist_upd_Znth_r; try reflexivity; try rep_omega).
  entailer!.
}
rewrite <- (mm_inv_split gv b Hb'). 
forward. (* ** return ** *) 
Admitted. 

(* TODO Complete implementation of malloc and free,
   and an interesting main, before verifying these. 
Lemma body_main:  semax_body Vprog Gprog f_main main_spec.
Admitted.


Lemma prog_correct:
  semax_prog prog Vprog Gprog.
Proof.
prove_semax_prog.
semax_func_cons body_size2bin.
semax_func_cons body_bin2size.
semax_func_cons body_fill_bin.
semax_func_cons body_malloc_small.
semax_func_cons body_malloc_large.
semax_func_cons body_free_small.
semax_func_cons body_malloc.
semax_func_cons body_free.
semax_func_cons body_main.
Qed.

*)
