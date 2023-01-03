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

(**The signature {!STORE} describes an implementation of first-class stores. *)
module type STORE = sig

  (**A store can be thought of as a region of memory in which objects, known
     as references, can be dynamically allocated, read, and written. Stores
     are homogeneous: all references in a store of type ['a store] have the
     content type, namely ['a]. In general, a store should be thought of as a
     mutable object. Some stores support a cheap [copy] operation, because the
     underlying data structure allows it: for instance, a store implemented as
     a reference to a persistent map supports cheap copies. Some stores do not
     support [copy] at all: for instance, a store implemented using primitive
     references does not support copies. *)
  type 'a store

  (* We choose an API where stores are mutable, so an operation that updates
     the store does not need to return a new store. The API includes a [copy]
     operation; this allows to simulate a persistent store by a mutable store
     that supports cheap copies. A store that is fundamentally not persistent
     can choose to not implement [copy]. *)

  (* We restrict our attention to homogeneous stores, because this is
     simpler and allows a wider range of implementations. *)

  (**[new_store()] creates an empty store. *)
  val new_store: unit -> 'a store

  (**[copy s] returns a copy of the store [s]. Every reference that is valid
     in the store [s] is also valid in the new store, and has the same content
     in both stores. The two stores are independent of one another: updating
     one of them does not affect the other. When supported, [copy] is cheap:
     it can be expected to run in constant time. However, some stores does not
     support [copy]; in that case, an unspecified exception is raised. *)
  val copy: 'a store -> 'a store

  (**A reference of type ['a rref] can be thought of as (a pointer to) an
     object that exists in some store. *)
  type 'a rref

  (* The type parameter ['a] in ['a rref] could be considered redundant, as it
     is not really necessary that both [store] and [rref] be parameterized.
     However, one can think of instances where ['a store] is a phantom type
     and ['a rref] really depends on ['a] AND of instances where the converse
     holds. *)

  (* For regularity, each of the four operations below takes a store as a
     parameter and returns a store as a result. One might think that [eq]
     does not need a store parameter, and that [get] and [eq] do not need a
     store result. However, in some implementations where the store is
     self-organizing, this may be necessary, so we bite the bullet and pay
     the cost in runtime and verbosity. *)

  (**[make s v] creates a fresh reference in the store [s] and sets its
     content to [v]. It updates the store in place and returns the
     newly-created reference. *)
  val make: 'a store -> 'a -> 'a rref

  (**[get s x] reads the current content of the reference [x] in the store
     [s]. It may update the store in place, and returns the current content of
     the reference. *)
  val get:  'a store -> 'a rref -> 'a

  (**[set s x v] updates the store [s] so as to set the content of the
     reference [x] to [v]. It updates the store in place. *)
  val set:  'a store -> 'a rref -> 'a -> unit

  (**[eq s x y] determines whether the references [x] and [y] are the same
     reference. It may update the store in place, and returns a Boolean
     result. The references [x] and [y] must belong to the store [s]. *)
  val eq: 'a store -> 'a rref -> 'a rref -> bool

end

(**The signature {!HSTORE} describes an implementation of first-class
   *heterogeneous* stores, which can contain references of different types. *)
module type HSTORE = sig
  type store
  include STORE with type 'a store := store
end

(**A heterogeneous store can of course serve as a homogeneous store. *)
module Homogeneous (S : HSTORE)
  : STORE with type 'a store = S.store
           and type 'a rref = 'a S.rref
= struct
  type 'a store = S.store
  include (S : STORE with type 'a store := 'a store
                      and type 'a rref = 'a S.rref)
end

(**A homogeneous store can serve as a heterogeneous store. This requires
   dynamic tests, which have a runtime cost. *)
module Heterogeneous (S : STORE)
  : HSTORE
= struct

  (* Gabriel Scherer proposed an implementation where a heterogeneous
     reference is implemented as a pair of a dynamic type tag and a
     homogeneous reference. The following implementation is slightly simpler.
     A heterogeneous reference is implemented as a homogeneous reference to a
     value of universal type. *)

  open Univ

  type store =
    univ S.store

  type 'a rref = {
    inject: 'a -> univ;
    project: univ -> 'a option;
    content: univ S.rref;
  }

  let new_store =
    S.new_store

  let copy =
    S.copy

  let make s v =
    let inject, project = Univ.make() in
    let content = S.make s (inject v) in
    { inject; project; content }

  let get s r =
    match r.project (S.get s r.content) with
    | Some v ->
        v
    | None ->
        (* A dynamic type cast fails. This cannot happen. *)
        assert false

  let set s r v =
    S.set s r.content (r.inject v)

  let eq s r1 r2 =
    S.eq s r1.content r2.content

end
