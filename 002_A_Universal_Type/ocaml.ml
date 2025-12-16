module type Univ = sig
  type t

  val embed : unit -> ('a -> t) * (t -> 'a option)
end

module Test (U : Univ) = struct
  let of_int, to_int = U.embed ()
  let of_string, to_string = U.embed ()
  let r : U.t ref = ref (of_int 13)

  let () =
    assert (to_int !r = Some 13);
    assert (to_string !r = None);
    r := of_string "foo";
    assert (to_int !r = None);
    assert (to_string !r = Some "foo")
  ;;
end

module UnivImpl : Univ = struct
  type t = ..

  let embed (type a) () : (a -> t) * (t -> a option) =
    let module M = struct
      type t += T : a -> t
    end
    in
    let to_t (x : a) : t = M.T x in
    let of_t (x : t) : a option =
      match x with
      | M.T y -> Some y
      | _ -> None
    in
    to_t, of_t
  ;;
end

module _ = Test (UnivImpl)
