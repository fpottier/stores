(* A universal type. *)

type univ

(* [make] creates a new injection-projection pair. One could say that
   [make] creates a new tag, and returns a pair of functions [inject]
   and [project], where [inject] applies the tag and [project] removes
   the tag. [project] raises [Failure] if it finds a different tag. *)

val make: unit -> ('a -> univ) * (univ -> 'a)
