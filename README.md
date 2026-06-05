# easyob.el — 极简 DSL，为 Org-babel 快速添加新语言支持

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

`easyob.el` 提供了一套声明式宏，让你用**一行代码**为 Org-mode 的 Babel 模块增加任意语言的执行支持。  
无需深入了解 `ob-*.el` 的复杂内部机制，只需告诉它「用什么命令执行临时文件」，就能在 Org 文档中编写和运行该语言的代码块。

---

## 特性

- **简洁定义**：`(easyob-def clojure "clj -M $FILE" :extension ".clj")` 即可启用 Clojure 代码块。
- **自动补全/包裹**：自动为代码添加 `main` 函数、库引用等模板。
- **变量传递**：通过 `:var` 将 Org 表格或 Lisp 数据传入代码。
- **同步/异步执行**：支持 `:async t` 后台运行。
- **文件结果**：可将结果输出为文件链接（如图片）。
- **结果类型**：自动处理 table、vector 和标量结果。
- **零依赖**（除 `s` 库外，Emacs 内置）。

---

## 安装

### 手动安装
将 `easyob.el` 放入你的 `load-path`，然后在配置中添加：

```elisp
(require 'easyob)
```

### 使用 straight.el
```elisp
(straight-use-package
 '(easyob :type git :host github :repo "lyt0628/easyob"))
```

### 使用 use-package
```elisp
(use-package easyob
  :load-path "path/to/easyob")
```

> 要求：Emacs 24.4 及以上，已安装 `s` 库（可通过 `M-x package-install RET s RET` 安装）。

---

## 快速开始

以 **Clojure** 为例，在 Emacs 配置中添加：

```elisp
(easyob-def clojure "clj -M $FILE"
  :lang "clojure"
  :extension ".clj"
  :filename-prefix "ob-clj-"
  :head "(println (do "
  :tail "))")
```

重启 Emacs 后，即可在 Org 文件中执行 Clojure 代码：

```org
#+BEGIN_SRC clojure
(+ 1 2)
#+END_SRC
```

按 `C-c C-c` 执行，结果为 `3`。

---

## 选项说明

`easyob-def` 宏的完整语法：

```elisp
(easyob-def NAME COMMAND &rest OPTIONS)
```

| 关键字               | 类型     | 默认值               | 说明                                                                 |
|----------------------|----------|----------------------|----------------------------------------------------------------------|
| `:lang`              | string   | `(symbol-name NAME)` | 对应 `#+BEGIN_SRC` 的语言名                                          |
| `:extension`         | string   | `""`                 | 临时文件扩展名，如 `".py"`                                            |
| `:filename-prefix`   | string   | `""`                 | 临时文件前缀                                                         |
| `:head`              | string   | `""`                 | 始终添加到代码块内容之前（在所有补全包装之后）                       |
| `:tail`              | string   | `""`                 | 始终添加到代码块内容之后                                             |
| `:complete-check-regx` | regexp  | `nil`                | 如果代码块正文不匹配此正则，则自动包裹 `:complete-prefix` 和 `:complete-subfix` |
| `:complete-prefix`   | string   | `""`                 | 补全时添加的前缀                                                     |
| `:complete-subfix`   | string   | `""`                 | 补全时添加的后缀                                                     |
| `:file`              | string   | `""`                 | 结果文件模板，用于生成图片等输出（如 `"$FILE.png"`）                  |
| `:var`               | string   | `nil`                | 变量定义格式字符串，如 `"(def %s %s)"`                               |

> **顺序说明**：最终的代码块内容 = `head` + (可选 `complete-prefix` + 原始正文 + `complete-subfix`) + `tail`。

---

## 命令占位符

`COMMAND` 字符串支持以下占位符，它们会在执行前被替换为实际值：

| 占位符         | 说明                                 |
|----------------|--------------------------------------|
| `$FILE`        | 包含完整代码的临时文件路径           |
| `$FILE_BASE`   | 文件名（不含目录和扩展名）           |
| `$FILE_DIR`    | 临时文件所在目录                     |
| `$FILE_SIMPLE` | `$FILE_DIR/$FILE_BASE` 的快捷方式    |
| `$BODY`        | 最终的代码正文（包括 head/tail 等）  |

示例：
```elisp
(easyob-def python "python3 $FILE" ...)
(easyob-def dot "dot -Tpng $FILE -o $FILE.png" :file "$FILE.png" ...)
```

---

## 变量传递

使用 `:var` 选项定义变量格式模板（`%s` 分别代表**变量名**和**值**）：

```elisp
(easyob-def python "python3 $FILE"
  :lang "python"
  :extension ".py"
  :var "%s = %s")
```

在 Org 中：

```org
#+BEGIN_SRC python :var x=10 :var name="Alice"
print(x, name)
#+END_SRC
```

会生成：
```python
x = 10
name = "Alice"
print(x, name)
```

> **注意**：默认不对值进行序列化。如需传递字符串、列表等复杂类型，请自行确保格式正确（字符串需手动加引号），或使用自定义的变量转换函数（见高级用法）。

---

## 同步与异步

- **同步执行**（默认）：结果在 `C-c C-c` 后直接插入到 Org 文档中。
- **异步执行**：添加 `:async t` 头部参数，代码将在后台运行，输出显示在名为 `*org-babel-execute:<LANG>*` 的缓冲区中，不会自动插入结果。

```org
#+BEGIN_SRC python :async t
# 耗时计算
#+END_SRC
```

---

## 文件输出

如果代码生成图片等文件，使用 `:file` 选项：

```elisp
(easyob-def dot "dot -Tpng $FILE -o $FILE.png"
  :extension ".dot"
  :file "$FILE.png")
```

然后在 Org 中：

```org
#+BEGIN_SRC dot :file result.png
graph { a -- b; }
#+END_SRC
```

执行后，Org 会显示图片 `result.png`。

---

## 代码补全/自动包装

有些语言需要代码必须包含某个特定语句（例如 C 需要 `main()` 函数），可以用 `:complete-check-regx` 检测，若缺失则自动包裹。

```elisp
(easyob-def c "gcc $FILE -o $FILE_SIMPLE && $FILE_SIMPLE"
  :extension ".c"
  :complete-check-regx "int main("
  :complete-prefix "#include <stdio.h>\nint main(int argc, char *argv[]) {"
  :complete-subfix ";\nreturn 0;}")
```

如果代码块中**没有** `int main(`，则自动补全为一个完整的 C 程序。

---

## 多语言配置示例

```elisp
;; Python
(easyob-def python "python3 $FILE"
  :extension ".py"
  :var "%s = %s")

;; Ruby
(easyob-def ruby "ruby $FILE"
  :extension ".rb"
  :var "%s = %s")

;; JavaScript (Node.js)
(easyob-def js "node $FILE"
  :extension ".js"
  :var "const %s = %s")

;; Rust (需要安装 rust-script 或 cargo-script)
(easyob-def rust "rust-script $FILE"
  :extension ".rs"
  :var "let %s = %s;")

;; PlantUML
(easyob-def plantuml "plantuml -tpng $FILE -o $FILE_DIR"
  :extension ".puml"
  :file "$FILE_SIMPLE.png")
```

---

## 注意事项

1. **Shell 注入风险**：`$BODY` 占位符直接将代码文本嵌入命令行，如果代码包含空格或特殊字符，可能导致意外行为。建议尽量使用 `$FILE`（临时文件方式）而非 `$BODY`。
2. **变量值未转义**：`%s` 格式化变量时，值直接插入代码。对于字符串，请确保在 Org 的 `:var` 中使用双引号包裹的值或自定义转换。
3. **兼容性**：`easyob` 仅在 Emacs 24.4+ 上测试，需要依赖 `s` 字符串操作库（可通过 ELPA 安装）。
4. **安全性**：不要对不可信的代码块使用 `easyob-def` 自动执行，以免任意代码执行。

---

## 对比原生 ob-*.el

| 功能                     | easyob                          | 原生 ob-*.el                      |
|--------------------------|---------------------------------|------------------------------------|
| 定义复杂度               | 一行宏调用                      | 需要编写数十行 Elisp              |
| 变量传递                 | 格式字符串                      | 复杂的序列化函数                  |
| 临时文件                 | 自动管理                        | 需要手动处理                      |
| 会话支持                 | ❌（当前不支持）                | ✅                                |
| 错误处理                 | 基础（stdout/stderr）           | 可定制                            |
| 适合场景                 | 快速原型、一次性语言、个人使用  | 复杂项目、需要完整支持的包        |

---

## 贡献

欢迎提交 Issue 和 Pull Request！  
项目主页：https://github.com/lyt0628/easyob

---

## 许可证

GPL v3，详见 [LICENSE](LICENSE) 文件。
