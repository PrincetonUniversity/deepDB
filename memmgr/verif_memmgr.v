(* main file for memmgr *)

Require Import malloc_lemmas. (* background independent of the program *)
Require Import mmap0. (* shim code *)
Require Import malloc. (* the code *)
Require Import malloc_shares. (* general results about shares [belongs in VST?] *)
Require Import spec_malloc. (* specs and data structures *)
Require Import malloc_sep. (* lemmas about data structures etc *)

Require Import verif_malloc_free. (* bodies of malloc and free *)
Require Import verif_malloc_large. 
Require Import verif_malloc_small. 
Require Import verif_free_large. 
Require Import verif_free_small. 
Require Import verif_fill_bin.
Require Import verif_pre_fill.
Require Import verif_try_pre_fill.
Require Import verif_list_from_block.
Require Import verif_bin2size2bin. (* bodies of bin2size and size2bin *) 
Require Import verif_external. (* library and mmap0 shim *)


(* linking of clients *)
Require Import main. (* a simple main that uses malloc and free *)
Require Import spec_main. 
Require Import verif_main. (* correctness of main, using resource-tracking specs *)
Require Import link_main. (* correctness of main linked with memmgr and mmap0 *)

Require Import verif_main_alt. (* correctness using non-resource-tracking specs *)

Require Import main_R. (* a simple main that uses malloc, free, pre_fill *)
Require Import verif_main_R. (* its correctness, verified two ways *)







