# HOWTO: Static access control using phantom types
## 如何使用 Phantom Types 实现静态访问控制

> 原文：[HOWTO: Static access control using phantom types](https://blog.janestreet.com/howto-static-access-control-using-phantom-types/)

****

我们认为 phantom types 是我们的第一篇正式文章的合适的主题，因为 phantom types 很好体现了 Ocaml 中一项强大而有用的 feature，尽管这个 feature 在实际中几乎不用。

本文将介绍一个 phantom types 相当简单的用法：在编译期实现的一种 capability 风格的访问控制模型（a capability-style access-control policy）。具体而言，我将描述如何给一个可变数据结构构造一个易用的、只读的接口。我们将用 `int ref` 的例子来探讨这一点。`int ref` 只是一个示例，但是相同的方法也适用于其它更实际的场景，例如字符串库或者数据库的接口等。

我们将从基于 Ocaml 内置的 `ref` 实现一个 `int ref` 的模块开始。

```ocaml
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
```

获取一个只读接口的最简单的方式是创建一个不同的、有更多限制的模块签名。

```ocaml
module RORef : sig
  type t

  val import : Ref.t -> t
  val get : t -> int
end = struct
  type t = Ref.t

  let import x = x
  let get x = Ref.get x
end
```

`RORef.t` 底层本质上就是 `Ref.t`，但是这个签名通过把 `RORef.t` 设置为抽象类型来隐藏这一点。值得注意的是，`import` 这个函数能将 `Ref.t` 转换为 `RORef.t`，但是却不存在反向的操作。这提供了一种既能创造只读接口又防止其他人通过这个接口恢复底层读写接口的方法。这个方法的弊端在于：不可能编写同时支持 `Ref.t` 与 `RORef.t` 的多态代码，即使它仅支持二者均有的能力，例如仅读取操作。

一个更好的解决方法是使用 phantom type 来编码某个值所携带的访问权限。不过什么是 phantom type？不幸的是，它的定义比它自己的实际概念更复杂。一个 phantom type 就是一种作为类型参数出现（例如 `int list` 中的 `int` 就是类型参数）、但是又不在实际定义中使用的类型（例如 `type 'a t = int` 中的 `'a`）。 实际上，正因为 phantom 参数并没有在定义中被真的使用，你才能自由地利用它编码一些附加的类型信息，以便类型检查器能替你跟踪这些信息。由于 phantom type 实际上并不是其他类型的定义的一部分，因此它并不会对最终的代码生成产生任何副作用，即它在运行时是完全零成本的。要让类型检查器追踪你关注的信息，就在签名中使用 phantom types 来施加约束。

给一个能让你更容易理解的例子。

```ocaml
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
```

> 注：在 Rust 中，类似的代码不使用 `RefCell` 或 `Mutex` 是不可能实现的。因为 Rust 中规定了，当只读引用存在时，mutable 的引用是无法进行写入的。而 `RefCell` 和 `Mutex` 均会引入运行时开销。

在上述代码中，phantom type 告诉你你的权限是什么。`readwrite PRef.t` 能够同时读写，而 `readonly PRef.t` 是只读的。注意，函数 `get` 并不使用 phantom type，因而它能被 `readwrite` 和 `readonly PRef.t` 同时使用。唯一能修改引用的函数是 `set`，它需要使用 `readwrite PRef.t` 来进行标注。

注意，类型 `readonly` 和 `readwrite` 并没有定义。它们看起来像是抽象类型的定义，但是由于没有构造器，因而不可构造。它们实际上是 `uninhabited types` （无值类型）的例子——即没有关联值的类型。在此处，值的缺失并不会引起问题，因为我们只是把这些类型作为标记使用。

这种方法最牛的地方在于它在实践中用起来非常丝滑。库的使用者能用自然的方式编写代码，而类型系统将如预期般传播访问控制约束。例如，下面的定义：

```ocaml
let sumrefs reflist =
  List.fold_left (+) 0 (List.map PRef.get reflist)

let increfs reflist =
  List.iter (fun r -> PRef.set r (PRef.get r + 1)) reflist
```

将会推导出如下的类型：

```ocaml
val sumrefs : 'a PRef.t list -> int
val increfs : readwrite PRef.t list -> unit
```

换句话说，第一个函数只读，因此可以在所有类型的引用上进行操作；而第二个函数是可变的，因此只能在 `readwrite` 类型的引用上进行操作。

上面我们实现的权限控制策略有一个问题，即没有一个清晰的方式来保证一个给定的值是不可变的。具体而言，即使一个给定的值是 `readonly`，程序中仍然可能存在另一个 `readwrite` 的引用指向它。（显然地，不可变的 `int ref` 并非一个很有吸引力的应用场景，但是对于诸如字符串与数组的更加复杂的数据类型而言，同时有可变与不可变的版本是合理的）。

不过我们也可以获取到不可变的值，只是要让 phantom types 变得更复杂一点：

```ocaml
type immutable

module IRef : sig
  type 'a t

  val create_immutable : int -> immutable t
  val create_readwrite : int -> readwrite t
  val readonly : 'a t -> readonly t
  val set : readwrite t -> int -> unit
  val get : 'a t -> int
end = struct
  type 'a t = Ref.t

  let create_immutable x = Ref.create x
  let create_readwrite x = Ref.create x
  let readonly x = x
  let set = Ref.set
  let get = Ref.get
end
```

重要的是，一个已经建好的`IRef.t` 没办法变成 `immutable`——它必须一开始就是 `immutable` 的。

## 更加多态的访问控制

`IReft` 的签名中值得注意的是，没有任何其他方式能构建一个真正的多态的 `IRef.t`。两个 `create` 函数都从 `immutable` 或者 `readwrite` 来构建值。尽管这些特化的 `create` 函数严格来说并不是必要的。我们可以用以下签名来改写 `IRef`：

```ocaml
sig
  type 'a t
  val create : int -> 'a t
  val set : readwrite t -> int -> unit
  val get : 'a t -> int
  val readonly: 'a t -> readonly t
end
```

使用者可以通过添加约束来强制创建一个 `immutable` 或者 `readwrite` 的 `Ref`。
因此，比起这么写：

```ocaml
let r = IRef.create_immutable 3
```

可以这么写：

```ocaml
let r = (IRef.create 3 : immutable IRef.t)
```

这个多态构建函数的好处是它很直接：它允许你用更加多态的方式来编写函数，因而也能更加灵活。例如，你可以只写一个函数来根据上下文创建一个数组的 `readwrite` 引用、`readonly` 引用或者 `immutable` 引用。

它的缺陷是，当你想要显式的权限时，就需要写更多的类型注释。并且，这种方式还允许一些奇怪的类型出现…… 具体而言，你可以用任意一个 phantom type 来创建 `IRef.t`！没有什么东西能阻止你创建一个 `string IRef.t`，即便 `string` 作为权限控制符啥也不是。有趣的是，这个签名实际上并不真正创建任何 `immutable` 类型的引用，并且事实上，使用除`readonly`和`readwrite`外的 phantom 参数都会让这个引用是 `immutable` 的。这个权限控制约束仍然大致按照预期方式起作用，不过相较于最开始的签名，它的逻辑还是有一点复杂。
