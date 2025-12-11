# A universal Type?
# 通用类型？

在 Ocaml 中，有可能实现一种通用类型，使得其他任何类型都能被嵌入其中呢？更具体地说，是否有可能实现如下签名：

```ocaml
module type Univ = sig
  type t
  val embed: unit -> ('a -> t) * (t -> 'a option)
end
```

核心的思想在于：`t` 代表通用类型（泛型），函数 `embed` 返回的是一对 `(inj, prj)`，分别用于将类型注入 `t` 、从 `t` 中投影出原始的类型。投影是部分的（返回的是 `option`），原因是类型注入这个操作不是满射的。

下面有一个如何使用 `Univ` 的例子：

```ocaml
module Test (U : Univ) = struct
  let (of_int, to_int) = U.embed ()
  let (of_string, to_string) = U.embed ()
  let r : U.t ref = ref (of_int 13)
  let () = begin
    assert (to_int !r = Some 13);
    assert (to_string !r = None);
    r := of_string "foo";
    assert (to_int !r = None);
    assert (to_string !r = Some "foo");
  end
end
```

你可以亲自试试，看看你能不能实现这个 `module Univ : Univ` 以通过测试 `Test (Univ)`。禁止使用 `Obj.magic` 或者其他的 unsafe 特性！
