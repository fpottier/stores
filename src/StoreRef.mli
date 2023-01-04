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

(**This module offers {b mutable stores based on primitive mutable
   references}. These stores do not support [copy]. *)

include STORE
  with type 'a store = unit
   and type 'a rref = 'a ref
