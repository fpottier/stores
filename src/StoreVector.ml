(***************************************************************************)
(*                                                                         *)
(*                                 UnionFind                               *)
(*                                                                         *)
(*                       François Pottier, Inria Paris                     *)
(*                                                                         *)
(*  Copyright Inria. All rights reserved. This file is distributed under   *)
(*  the terms of the GNU Library General Public License version 2, with a  *)
(*  special exception on linking, as described in the file LICENSE.        *)
(***************************************************************************)

(* A store is implemented as an extensible array, that is, a pair of an
   integer address and an array. We maintain the invariant that the length of
   the array is at least [limit]. The area of the array at index [limit] and
   beyond is considered uninitialized. *)

(* In the current implementation, this area is filled with arbitrary value(s)
   provided by the user in calls to [make] or [set]. This is not ideal, as it
   can cause a memory leak. *)

type 'a store = {
  (* The logical size of the array; also, the next available address. *)
  mutable limit:   int;
  (* The array, whose length is at least [limit]. *)
  mutable content: 'a array
}
(* Note: the invariant [s.limit <= Array.length s.content] is preserved
   under sequential usage, but it may be violated by racy concurrent
   uses of the store. We do not provide any correctness guarantee in this
   case, but we preserve memory safety -- this prevents us from using
   [unsafe_get] and [unsafe_set] on the [content] array. *)

(* The array is created with a size and length of zero. We have no other
   choice, since we do not have a value of type ['a] at hand. *)

let new_store () : 'a store = {
  limit = 0;
  content = [||]
}

(* Copying is supported, but is not cheap. Use at your own risk. *)

let copy (s : 'a store) : 'a store =
  { limit = s.limit; content = Array.copy s.content }

(* A reference is an index into the array. *)

type 'a rref =
  int

(* The array jumps from length zero to length [default_initial_length] as soon
   as a call to [make] is made. *)

let default_initial_length =
  256

(* [enlarge s v] increases the length of the array (if necessary) so as to
   ensure that [s.limit] becomes a valid index. The argument [v] is used as a
   default value to fill the uninitialized area. *)
let enlarge (s : 'a store) (v : 'a) : unit =
  let content = s.content in
  let length = Array.length content in
  if s.limit = length then begin
    let length' =
      if length = 0 then
        default_initial_length
      else
        2 * length
    in
    assert (s.limit < length');
    let content' = Array.make length' v in
    Array.blit content 0 content' 0 length;
    s.content <- content'
  end
(* Note: the [enlarge] function may violate the
     [s.limit <= Array.length s.content]
   invariant in preseence of racy concurrent callers.

   Consider a scenario when domain A makes a single call to [enlarge],
   and concurrently domain B makes many calls to [make] and
   [enlarge]. At the end of this parallel section, the (non-atomic)
   write to [s.content] from A wins the race, and the (non-atomic)
   write to [s.limit] from B wins the race; we may end up with
   [s.limit] larger than [s.content].

   We could protect against this by maintaining an atomic version
   count to detect racy updates to the backing store.
*)

exception InvalidRef

let check (s : 'a store) (x : 'a rref) : unit =
  (* We do not check that [x] is nonnegative. An overflow cannot occur,
     since that would imply that we have filled the memory with a huge
     array. *)
  if x >= s.limit then
    raise InvalidRef

let make (s : 'a store) (v : 'a) : 'a rref =
  enlarge s v;
  let x = s.limit in
  s.limit <- x + 1;
  Array.set s.content x v;
  x

let get (s : 'a store) (x : 'a rref) : 'a =
  check s x;
  Array.get s.content x

let set (s : 'a store) (x : 'a rref) (v : 'a) : unit =
  check s x;
  Array.set s.content x v

let eq  (s : 'a store) (x : 'a rref) (y : 'a rref) : bool =
  check s x;
  check s y;
  x = y
