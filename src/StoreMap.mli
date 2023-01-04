(***************************************************************************)
(*                                                                         *)
(*                                 Stores                                  *)
(*                                                                         *)
(*                       François Pottier, Inria Paris                     *)
(*                                                                         *)
(*  Copyright Inria. All rights reserved. This file is distributed under   *)
(*  the terms of the GNU Library General Public License version 2, with a  *)
(*  special exception on linking, as described in the file LICENSE.        *)
(***************************************************************************)

(**This module offers {b stores based on immutable integer maps}. These stores
   support a constant-time [copy] operation. The module [Stores.StoreMap]
   itself is an implementation of stores based on OCaml's [Map] module. The
   functor [Stores.StoreMap.Make] can also be used to construct an
   implementation of stores based on a user-provided implementation of
   immutable maps. *)

open Store

(* The easiest way of instantiating the functor [Make] below is with integer
   maps found in the standard library. This is done here. *)

include STORE

(**{!Make} constructs persistent stores based on immutable integer maps. *)
module Make (IntMap : sig
  type 'a t
  val empty: 'a t
  val find: int -> 'a t -> 'a
  val add: int -> 'a -> 'a t -> 'a t
end) : STORE
