
# easyob.el — 极简 DSL，为 Org‑babel 快速添加新语言支持

**easyob** 是一个基于 Org‑babel 的轻量级宏库，只需几行声明，即可在 Org 文件中执行任何语言（如 Clojure、Lua、Ruby、Haskell 等），并自动支持**临时文件执行**和**REPL 会话**。  
它封装了变量注入、代码块包裹、结果捕获、提示符过滤等繁琐细节，让你专注于“写代码”而非“搭架子”。

## 安装

将 `easyob.el` 及其依赖文件放置在 Emacs 的 `load-path` 中，然后在配置中加载：

```elisp
(require 'easyob)
```

或直接下载整个项目，在 `init.el` 中添加路径并加载。

## 快速开始 — 添加一个语言（以 Clojure 为例）

只需要写一个宏调用：

```elisp
(easyob-def-session clojure
  "clj -M $FILE"       ; 临时文件执行命令
  "clj"                ; REPL 启动命令
  "user=>[ \t]*"       ; 提示符正则（兼容 ANSI）
  :lang "clojure"
  :extension ".clj"
  :filename-prefix "ob-clj-"
  :head "(prn (do "     ; 非会话时包裹开头
  :tail "))"            ; 非会话时包裹结尾
  :var "(def %s %s)"    ; 变量格式
  :session-async t)     ; 允许异步会话（可选）
```

保存为 `ob-clojure.el` 并加载后，即可在 Org 中使用 `clojure` 语言。

## 两种执行模式

### 1. 临时文件执行（默认）

代码块内容写入临时文件，通过命令执行，标准输出成为结果。

```org
#+BEGIN_SRC clojure
  (+ 1 2)
#+END_SRC

#+RESULTS:
: 3
```

内部过程：`(prn (do (+ 1 2)))` → 写入 `.clj` 文件 → `clj -M /tmp/...clj` → 捕获 stdout。

### 2. REPL 会话（需要 `:session`）

代码块在同一个持久化的 REPL 中依次执行，共享状态。

```org
#+BEGIN_SRC clojure :session my-repl
  (def counter (atom 0))
  (swap! counter inc)
#+END_SRC

#+RESULTS:
: #'user/counter

#+BEGIN_SRC clojure :session my-repl
  (prn @counter)
#+END_SRC

#+RESULTS:
: 1
```

**无会话？** 如果没写 `:session`，即使语言定义了会话命令，也会走临时文件执行，确保纯函数式代码块不受干扰。

## 支持的特性

### 变量注入（`:var`）

```org
#+BEGIN_SRC clojure :var x=10
  (* x x)
#+END_SRC

#+RESULTS:
: 100
```

语言定义中的 `:var "(def %s %s)"` 决定变量声明格式。easyob 自动解析 `:var` 头参数，拼接到代码体前。

### 代码完整性包裹（`:head` / `:tail`）

对于需要打印返回值的语言（如 Clojure），`easyob` 在非会话模式下会自动包裹 `(prn (do ...))`，确保最后一个表达式的结果被输出。  
`head` 和 `tail` 可以是空字符串，也可以从 `:prologue` / `:epilogue` 头参数动态覆盖。

### 异步会话（`:async yes`）

在语言定义中启用 `:session-async t` 后，用户可通过 `:async yes` 让代码在 REPL 中异步执行，结果稍后自动插入到 `#+RESULTS`，不阻塞 Emacs。

```org
#+BEGIN_SRC ruby :session r :async yes
  sleep 2
  "Done"
#+END_SRC
```

### 智能提示符匹配

`easyob` 自动剥离 ANSI 转义序列，并过滤 REPL 回显的输入行，确保结果纯净（不再包含 `user=>` 或重复的代码）。

### 输出文件（`:file`）

如果需要将结果写入文件，可以指定 `:file "result.txt"`，结果将替换为该文件的路径。  
模板变量 `$FILE`、`$BODY` 等可在命令或文件路径中使用。

## 语言配置参数速查

调用 `easyob-def-session` 时，前四个参数分别是 `名称`、`非会话命令`、`会话命令`、`提示符正则`。之后的 `:key val` 参数都可用：

| 参数 | 说明 | 示例 |
|------|------|------|
| `:lang` | 语言名（符号名默认） | `"ruby"` |
| `:extension` | 临时文件扩展名 | `".rb"` |
| `:filename-prefix` | 临时文件前缀 | `"ob-ruby-"` |
| `:head` | 包裹头部 | `"puts ("` |
| `:tail` | 包裹尾部 | `")"` |
| `:var` | 变量声明格式 | `"%s = %s"` |
| `:var-mode` | `'format`（默认）或自定义函数 | `'format` |
| `:complete-check-regx` | 判断代码是否需要额外包裹 | `"prn\\|@results"` |
| `:complete-prefix` / `:complete-subfix` | 完整性包裹 | `"print("` / `")"` |
| `:session-cmd` | REPL 启动命令 | `'("lua" "-i")` |
| `:prompt-regexp` | 提示符正则 | `">[ \t]*"` |
| `:eval-cmd` | 发送给 REPL 的包装格式 | `"%s\\n"` |
| `:session-async` | 默认开启异步会话 | `t` |
| `:no-session` | 明确禁止会话 | `t` |
| `:alias` | 语言别名 | `"js"` |
| `:default-header-args` | 默认头参数 | `'(:results "output")` |
| `:header-args-def` | 定义可用的头参数 | `'(:var :results :session)` |
| `:edit-prep` | 编辑代码块时的回调函数 | `(lambda (info) ...)` |
| `:execute-fn` | 完全自定义执行函数 | `(lambda (body params) ...)` |
| `:file` | 默认输出文件模板 | `"$FILE_DIR/output.txt"` |

若不需要会话，可使用 `easyob-def` 宏，它不包含会话相关参数，但其他参数完全一致。

## 测试

项目包含完整的 `make test` 命令，在 `Makefile` 中已配置字节编译和 32 个测试用例，覆盖工具函数、执行流程、会话同步/异步、回显过滤等。  
运行前请确保系统中存在 `python`、`clj` 等测试所需的可执行文件，否则部分测试会自动跳过。

## 许可

本项目遵循自由软件许可，欢迎提交 issue 和 pull request.
