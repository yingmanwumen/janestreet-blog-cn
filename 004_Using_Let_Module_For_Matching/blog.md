# Using let module for matching
# 使用 let 模块进行匹配

在 OCaml 中，引用定义在其他模块中的构造器可能会有一点麻烦。假设我们有一个像这样子的模块：

```ocaml
module Example = struct
  type t = Foo | Bar | Baz
end
```

为了写一个能模式匹配 `Example.t` 的函数，我们可以直接引用它的成员：

```ocaml
let f e =
  match e with
  | Example.Foo -> ...
  | Example.Bar -> ...
  | Example.Baz -> ...
```

这相当冗长。我们可以通过使用 `open` 来减轻这个问题：

```ocaml
open Example
let f e = 
  match e with
  | Foo -> ...
  | Bar -> ...
  | Baz -> ...
```

这样子看起来更好一点了，但是这个 `open`  有可能会把一堆东西带进来（并不是只是带到 `f` 里，而是带到这个文件剩下的部分里).使用 `open` 大体来说是一个不好的做法，因为它会让读者难以把定义和使用联系起来。如果我们能限制 `open` 的作用域，那么问题能环节一点。我们可以用 local module 来做到这一点：

```ocaml
let f e =
  let module M = struct
    open Example
    let res =
    match e with
    | Foo -> ...
    | Bar -> ...
    | Baz -> ...
  end in
  M.res

  ```

这样子还是有点冗长。我们在 Jane Street 里的做法是使用 `let module` 把模块重新绑定到一个更短的名字，以此让代码更加精炼，并且避免把一整个模块都 `open` 进来：

```ocaml
let f e =
  let module E = Example in
  match e with
  | E.Foo -> ...
  | E.Bar -> ...
  | E.Baz -> ...
```
