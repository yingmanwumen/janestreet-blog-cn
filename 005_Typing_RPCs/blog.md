# Typing RPCs
# RPC 中的类型

在 Jane Street 里，我们最终写了大量的消息协议，这些协议中很多最终都演变为简单的 RPC 风格的协议，也就是说，有一个客户端和一个服务端、并且它们之间的通讯使用一种简单的 query/response 风格的协议。

我经常觉得写这些协议非常让人不满，因为我永远也没办法找到一种清爽的方式来写类型。在下面的部分，我将描述一些我最近学到的不错的技巧来用更清爽的方式描述这些协议。

## 一个简单的例子

我将从一个具体的例子开始：一批访问远程文件系统的 RPC。以下是我们想用 RPC 实现的一些函数的签名：

```ocaml
type path = path of string list with sexp
type 'a result = Ok of 'a | Error of string with sexp

val listdir : path -> string list result
val read_file : path -> string result
val move : path * path -> unit result
val put_file : path * string -> unit result
val file_size : path -> int result
val file_exists : path -> bool
```

> 译者注：
> - `with sexp` 其实是 `[@@deriving sexp]` 的旧语法，现代 OCaml 推荐写法是：
>   ```ocaml
>   type path = Path of string list [@@deriving sexp]
>   ```

类型定义末尾的 `with sexp` 是从 Jane Street's 的公共仓库 `sexplib` 里的宏。这些宏生成一些能把值和 s-expression 相互转换的函数。在写消息协议的时候这非常有帮助，因为它给了你一个简单的、省心省力的机制来在传输的过程中序列化值。（不幸的是，s-expression 的生成并不快，这也是为什么我们还写了一些二进制序列化的宏来应对高性能消息应用，这些宏我们也打算发布。）

接下来一般要构建两个类型，一个是给请求用的，另一个是响应用的。一下是你可能需要写的关于上面那些函数的类型：

```ocaml
module Request = struct
  type t = | Listdir of path
      | Read_file of path
      | Move of path * path
      | Put_file of path * string
      | File_size of path
      | File_exists of path
  with sexp
end

module Response = struct
  type t = | Ok
      | Error of string
      | File_size of int
      | Contents of string list
      | File_exists of bool
  with sexp
end
```

在某些方面来说，这还不错。这些类型写起来很简单也很容易理解，并且从 s-expression 转换器中获取该传输协议几乎无需成本。并且服务器代码和客户端代码都非常容易写。让我们看看这个代码看起来可能会是什么样的。

首先，我们假设有我们基于一些连接对象的发送和接收 s-expression 的函数，它们的签名是：

```ocaml
val send: conn -> Sexp.t -> unit
val recv: conn -> Sexp.t
```

接下来，服务端的代码应该是这样的:

```ocaml
let handle_query conn =
  let module Q = Query in
  let module R = Response in
  let msg = Q.t_of_sexp(recv conn) in
  let resp =
    match query with
    | Q.Listdir path ->
      begin match listdir path with
      | Ok x -> R.Contents x
      | Error s -> R.Error s
      end
    | Q.Read_file path ->
    ...
  in
  send (R.sexp_of_t resp)
```

客户端的代码应该是这样的:

```ocaml
let rpc_listdir conn path =
  let module Q = Query in
  let module R = Response in
  send conn (Q.sexp_of_t (Q.Listdir path));
  match R.t_of_sexp (recv conn) with
  | R.Contents x -> Ok x
  | R.Error s -> Error s
  | _ -> assert false
```

不幸的是，为了让这些代码能跑起来，你将被迫将类型定义横向调整：和在普通的函数类型中为每个 RPC 分别指定请求类型和响应类型不同，你必须一次性指定所有的请求类型和响应类型。而没有任何东西能将两边的类型联系起来。这意味着服务端代码和客户端代码之间没有任何的一致性校验。具体而言，服务端代码可能接收到一个 `File_size` 的请求然后返回 `Contents` 或者 `Ok`，而实际上它应该返回 `File_size` 或者 `Error`，而你只能在运行时捕获到这个错误。

## 使用 embedding 来指定 RPC

不过还有得救！只需要一点基建，我们就能把服务端和客户端的协议绑到一起。我们需要的第一个东西是所谓的 embedding，不过在其他地方它可能被称之为 embedding-projection pair。一个 embedding 基本上就是一对函数，一个用来把值转为一些泛型，另一个用来把泛型转化回去。我们将使用的这个泛型是一个 s-expression：

```ocaml
type 'a embedding = {
  inj: 'a -> Sexp.t;
  prj: Sexp.t -> 'a;
}
```

值得注意的是，投影函数始终是 partial 的，意味着它对某些输入回失效。在这个例子里，我们将使用 exception 来处理失效的情况，因为我们的 s-expression 的宏生成的转化函数会在值无法解析的时候抛出 exception。不过一般来说显式地在投影函数的返回值中编码这种情况会更好。

我们现在可以定义 RPC 的类型，并且我们可以基于它得到客户端和服务端的代码：

```ocaml
module RPC = struct
  type ('a, 'b) t = {
    tag: string;
    query: 'a embedding;
    resp: 'b embedding;
  }
end
```
以下是如何基于 `RPC.t` 来实现对应的 `listdir` 函数的方法：

```ocaml
module RPC_specs = struct
  type listdir_resp = string list result with sexp
  let listdir = { RPC.
    tag = "listdir";
    query = {
      inj = sexp_of_path;
      prj = path_of_sexp;
    };
    resp = {
      inj = sexp_of_listdir_resp;
      prj = listdir_resp_of_sexp;
    }
  }
  ...
end
```

上面的例子里一个让人有点烦的地方是我们不得不专门定义 `listdir_resp` 以便得到对应的 s-expression 的转换函数。以后的某个时候，我们应该写一篇关于类型索引值的文件来解释如何避免这种声明。

注意，上述的代码只写了接口而不是真正实现了 RPC 功能的服务器代码。这层 embedding 基本上定义了请求和响应的类型，还有一个 `tag` 用于在传输过程中区分不同类型的 RPC。

正如你可能会注意到的一样，一个 `('a, 'b) RPC.t` 对应一个函数 `'a -> 'b`。我们可以通过写一个函数来实现这种对应关系，这个函数接收一个 `('a, 'b) RPC.t` 和一个平凡的函数：
```
'a -> 'b
```

然后产生一个 RPC 的handler。我们将在下面使用 `RPC.t` 给出一个简单的实现：

```ocaml
type full_query = string * Sexp.t with sexp

module Handler : sig
  type t
  val implement : ('a, 'b) RPC.t -> ('a -> 'b) -> t
  val handle : t list -> Sexp.t -> Sexp.t
end
  =
  struct
    type t = {
      tag : string;
      handle: Sexp.t -> Sexp.t;
    }

    let implement rpc f = {
      tag = rpc.RPC.tag;
      handle = (fun sexp ->
        let query = rpc.RPC.query.prj sexp in
        rpc.RPC.resp.inj (f query)
      );
    }

    let handle handlers sexp =
      let (tag, query_sexp) = full_query_of_sexp sexp in
      let handler = List.find ~f:(fun x -> x.tag = tag) handlers in
      handler.handle query_sexp
  end
```

我们已经开始写 `RPC_specs` 的一部分了。我们可以用如下的方式来写服务端代码：

```ocaml
let handle_query conn =
  let query = recv conn in
  let resp =
    Handler.handle [
      Handler.implement RPC_specs.listdir listdir;
      Handler.implement RPC_specs.read_file read_file;
      Handler.implement RPC_specs.move move;
      Handler.implement RPC_specs.put_file put_file;
      Handler.implement RPC_specs.file_size file_size;
    ]
    query
  in
  send conn resp
```

实现客户端代码也很简单：

```ocaml
let query rpc conn x =
  let query_sexp = rpc.RPC.query.inj x in
  send conn (sexp_of_full_query (rpc.RPC.tag, query_sexp));
  rpc.RPC.resp.prj (recv conn)

module Client = sig
  val listdir : path -> string list result
  val read_file : path -> string result
  val move : path -> path -> unit result
  val put_file : path -> string -> unit result
  val file_size : path -> int result
  val file_exists : path -> bool
end
  =
  struct
    let listdir = query RPC_specs.listdir
    let read_file = query RPC_specs.read_file
    let move = query RPC_specs.move
    let put_file = query RPC_specs.put_file
    let file_size = query RPC_specs.file_size
    let file_exists = query RPC_specs.file_exists
  end
```

令人欣慰的是，这样一来客户端模块的签名就和我们通过RPC暴露的签名完全一致了。

需要澄清的是，上面的代码离一个完全的实现还远得很远 —— 尤其值得注意的是，错误处理机制还相当薄弱，并且我们并没有提到如何处理协议的版本控制问题等等。但是即使我们勾勒出的实现方案只是一个简单模型，它仍然是可以被扩充为一个完整实现的。

我们还有很多问题没有解决。虽然我们已经为一些错误添加了静态检查，我们也消除了一些其他的问题。例如，现在用户有可能指定具有相同的 `tag` 的不同的 `RPC.t``，此时并没有任何措施保证服务端实现了所有的 `RPC.t`。我尚未发现一种简洁的方法来让所有的这些静态检查在同一个实现中完美协作。
