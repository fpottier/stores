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

open Store

(**This module offers {b mutable stores based on mutable transactional
   references}. These stores support a simple form of transactions
   that can be either aborted or committed. Transactions cannot be
   nested. These stores do not support [copy]. *)

include STORE

(**[tentatively s f] runs the function [f] within a new transaction on the
   store [s]. If [f] raises an exception, then the transaction is aborted, and
   all updates performed by [f] on references in the store [s] are rolled
   back. If [f] terminates normally, then the updates performed by [f] are
   committed.

   Two transactions on a single store cannot be nested.

   A cell that is created during a transaction still exists after the
   transaction, even if the transaction is rolled back. In that case, its
   content should be considered undefined. *)
val tentatively: 'a store -> (unit -> 'b) -> 'b
