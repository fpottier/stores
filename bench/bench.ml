(** A benchmark for the various implementations of reference stores
    (mutable, copyable, persistent etc.).

    Documentation comments throughout the code explain the user-facing interface. *)

open Stores

(** Work counts for the benchmark are given in log-value:
    NREADS=10 means 2^10 reference reads. *)
let from_log n =
  let res = 1 lsl n in
  let nmax =
    (* 1 lsl int_size is 0,
       1 lsl (int_size - 1) is negative. *)
    Sys.int_size - 2 in
  if n >= nmax then
    Printf.ksprintf failwith
      "from_log: unsupported log-value %d (maximum: %d)"
      n nmax;
  assert (0 < res && res <= max_int);
  res

(** The "Raw" benchmark simply checks basic store operations. *)
module BenchStore (S : STORE) = struct
  let run (store : int S.store) ~ncreate ~nread ~nwrite ~rounds =
    let create_count = from_log ncreate in
    let read_count = from_log nread in
    let write_count = from_log nwrite in
    let refs = Array.init create_count (fun i -> S.make store i) in
    let do_reads refs _round =
      let len = Array.length refs in
      for i = 1 to read_count do
        let r = refs.(i mod len) in
        ignore (S.get store r);
      done
    in
    let do_writes refs round =
      let len = Array.length refs in
      for i = 1 to write_count do
        let r = refs.(i mod len) in
        S.set store r (round + i);
      done
    in
    let rec loop round =
      do_reads refs round;
      do_writes refs round;
      if round = rounds then ()
      else loop (round + 1)
    in loop 0
end

module type STORE_TRANSACTIONAL =
  module type of StoreTransactionalRef

(** Benchmarks for stores supporting the transaction interface *)
module BenchStoreTransactional (S : STORE_TRANSACTIONAL) = struct

  (** The "Transactional-raw" benchmark runs the basic benchmark
      under the scope of a transaction. This lets us measure
      the effectiveness of fast paths when no transactions are
      active, by comparing Raw and Transactional-raw. *)
  let run_raw (store : int S.store) ~ncreate ~nread ~nwrite ~rounds =
    let module B = BenchStore(S) in
    S.tentatively store (fun () ->
      B.run store ~ncreate ~nread ~nwrite ~rounds
    )

  (** The "Transactional-full" benchmarks runs [O(rounds)] transactions,
      and exercises both succesful and failed transactions. *)
  let run_full (store : int S.store) ~ncreate ~nread ~nwrite ~rounds =
    let create_count = 1 lsl ncreate in
    let read_count = 1 lsl nread in
    let write_count = 1 lsl nwrite in
    let refs = Array.init create_count (fun i -> S.make store i) in
    let do_reads refs _round =
      let len = Array.length refs in
      for i = 1 to read_count do
        let r = refs.(i mod len) in
        ignore (S.get store r);
      done
    in
    let do_writes refs round =
      let len = Array.length refs in
      for i = 1 to write_count do
        let r = refs.(i mod len) in
        S.set store r (round + i);
      done
    in
    let rec loop round =
      (* succesful transaction *)
      S.tentatively store (fun () ->
        do_reads refs round;
        do_writes refs round
      );
      (* failed transaction *)
      begin match
          S.tentatively store (fun () ->
            do_reads refs round;
            do_writes refs round;
            raise Exit
          )
        with
        | () -> assert false
        | exception Exit -> ()
      end;
      if round = rounds then ()
      else loop (round + 1)
    in loop 0
end

type bench =
  | Raw
  | Transaction of [ `Raw | `Full ]

type raw_impl =
  | Ref
  | TransactionalRef
  | Map
  | MapDyn
  | Vector
  | VectorDyn

let assoc_of_env var assoc =
  let fail () =
    Printf.ksprintf failwith
      "Expected environment variable %s in [%s]"
      var
      (String.concat " | " (List.map fst assoc))
  in
  try List.assoc (Sys.getenv var) assoc
  with _ -> fail ()

let bench =
  assoc_of_env "BENCH" [
    "Raw", Raw;
    "Transactional-raw", (Transaction `Raw);
    "Transactional-full", (Transaction `Full);
  ]

let impl =
  assoc_of_env "IMPL" [
    "Ref", Ref;
    "TransactionalRef", TransactionalRef;
    "Map", Map;
    "MapDyn", MapDyn;
    "Vector", Vector;
    "VectorDyn", VectorDyn;
  ]

let int_of_env var =
  try int_of_string (Sys.getenv var)
  with _ ->
    Printf.ksprintf failwith
      "Expected a number for environment variable %s"
      var

(** [ncreate] is the log-count of reference creations to perform. *)
let ncreate = int_of_env "NCREATE"

(** [nread] is the log-count of reference reads to perform. *)
let nread = int_of_env "NREAD"

(** [nwrite] is the log-count of reference writes to perform. *)
let nwrite = int_of_env "NWRITE"

(** [rounds] is a multiplicative factor, the number of repetitions of
   the benchmark. It is a count, not a log-count. This gives more
   flexibility to compare implementations with different runtimes
   without blowing up the benchmark time: if an implementation is 10x
   slower, you can easily run it with 10x less rounds. *)
let rounds = int_of_env "ROUNDS"

let () =
  match bench with
  | Raw ->
    let (module S : STORE) = match impl with
      | Ref -> (module StoreRef)
      | TransactionalRef -> (module StoreTransactionalRef)
      | Map -> (module StoreMap)
      | MapDyn ->
        let module MapDyn =
          Homogeneous(Heterogeneous(StoreMap)) in
        (module MapDyn)
      | Vector -> (module StoreVector)
      | VectorDyn ->
        let module VectorDyn =
          Homogeneous(Heterogeneous(StoreVector)) in
        (module VectorDyn)
    in
    let module B = BenchStore(S) in
    let store = S.new_store () in
    B.run store ~ncreate ~nread ~nwrite ~rounds

  | Transaction mult ->
    let (module S : STORE_TRANSACTIONAL) = match impl with
      | TransactionalRef -> (module StoreTransactionalRef)
      | Ref | Map | MapDyn | Vector | VectorDyn ->
        failwith "selected IMPL does not support transactions"
    in
    let module B = BenchStoreTransactional(S) in
    let store = S.new_store () in
    begin match mult with
      | `Raw ->
        B.run_raw store ~ncreate ~nread ~nwrite ~rounds
      | `Full ->
        B.run_full store ~ncreate ~nread ~nwrite ~rounds
    end
