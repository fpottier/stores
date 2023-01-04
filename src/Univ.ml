(* Our universal type is an extensible algebraic data type. *)

type univ =
  ..

(* [make] is implemented by generating a fresh data constructor [Tag].
   The functions [project] and [inject] respectively apply [Tag] and
   match against [Tag]. *)

let make (type a) () : (a -> univ) * (univ -> a) =

  let module T = struct

    type univ += Tag of a

    let inject (x : a) : univ =
      Tag x

    let project (u : univ) : a =
      match u with
      | Tag x -> x
      | _ -> failwith "Univ: tag mismatch"

  end in
  T.inject, T.project
