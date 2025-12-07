module Ref : sig
  type t

  val create : int -> t
  val set : t -> int -> unit
  val get : t -> int
end = struct
  type t = int ref

  let create x = ref x
  let set t x = t := x
  let get t = !t
end

module RORef : sig
  type t

  val import : Ref.t -> t
  val get : t -> int
end = struct
  type t = Ref.t

  let import x = x
  let get x = Ref.get x
end

type readonly
type readwrite

module PRef : sig
  type 'a t

  val create : int -> readwrite t
  val set : readwrite t -> int -> unit
  val get : 'a t -> int
  val readonly : 'a t -> readonly t
end = struct
  type 'a t = Ref.t

  let create = Ref.create
  let set = Ref.set
  let get = Ref.get
  let readonly x = x
end

let sumrefs reflist = List.fold_left ( + ) 0 (List.map PRef.get reflist)
let increfs reflist = List.iter (fun r -> PRef.set r (PRef.get r + 1)) reflist

type immutable

module IRef : sig
  type 'a t

  val create_immutable : int -> immutable t
  val create_readwrite : int -> readwrite t
  val create : int -> 'a t
  val readonly : 'a t -> readonly t
  val set : readwrite t -> int -> unit
  val get : 'a t -> int
end = struct
  type 'a t = Ref.t

  let create_immutable x = Ref.create x
  let create_readwrite x = Ref.create x
  let create x = Ref.create x
  let readonly x = x
  let set = Ref.set
  let get = Ref.get
end

let () =
  let prw = PRef.create 30 in
  PRef.set prw 40;
  Printf.printf "PRef (readwrite): %d\n" (PRef.get prw);
  let pro = PRef.readonly prw in
  Printf.printf "PRef (readonly): %d\n" (PRef.get pro);
  PRef.set prw 50;
  Printf.printf "PRef (readwrite): %d\n" (PRef.get prw);
  Printf.printf "PRef (readonly): %d\n" (PRef.get pro)
;;
