module Example = struct
  type t =
    | Foo
    | Bar
    | Baz
end

let f1 e =
  match e with
  | Example.Foo -> ()
  | Example.Bar -> ()
  | Example.Baz -> ()
;;

let f2 e =
  let module M = struct
    open Example

    let res =
      match e with
      | Foo -> ()
      | Bar -> ()
      | Baz -> ()
    ;;
  end
  in
  M.res
;;

let f3 e =
  let module E = Example in
  match e with
  | E.Foo -> ()
  | E.Bar -> ()
  | E.Baz -> ()
;;
