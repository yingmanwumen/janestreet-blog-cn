# Extracting an Exception From a Module
# 从模块中提取异常

模块 `Unix` 定义了一个名为 `Unix_error` 的异常构造器：

```ocaml
module Unix : sig
  exception Unix_error of error * string * string
  ...
end
```

假设你想创建你自己的 `My_unix` 模块，里面定义了一些 `Unix` 的工具函数，并且还要导出一样的 `Unix_error`。你要怎么做呢？你不能重新声明一个 `Unix_error`，因为这就是一个新的构造器了，和 `Unix.Unix_error` 没法匹配：

> 注：Ocaml 中的异常 exception 是名义类型。

```ocaml
module My_unix = struct
  exception Unix_error of error * string * string (* a new exception *)
  ...
end
```

你可以把一整个 `Unix` 模块都 include 进来，但是这会不必要地污染 `My_unix` 的 namespace。

```ocaml
module My_unix = struct
  include Unix
  ...
end
```

有一种技巧可以只把你需要的异常构造器导入到这个模块里，那就是使用带约束的 include:

```ocaml
module My_unix = struct
  include (Unix : sig exception Unix_error of Unix.error * string * string end)
  ...
end
```

这种做法需要在签名里重复一遍异常的定义，不过类型检查器将会理所当然地保证你写的类型声明和原来的那个相匹配，所以实际上这么写是不会出问题的。
