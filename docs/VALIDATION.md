# 中文文档验证记录

## 2026-10-21：对齐当前接口与所有权契约

源码基线：`1631b39`。更新 11 个中文页面及中文维护说明；英文内容、共享模板、库源码和跟踪的示例工程未修改。

- 同步标量参数的 ZPP 弱／严格转换与 null 行为；补充数组 ListBuilder、symtable 键语义、迭代器及更新槽所有权，字符串可写存储，对象属性视图和下标接口。
- 同步高对齐分配、原生 OOM 致命错误、初始化／克隆失败的析构规则、LTO 与静态 TSRM 缓存选项，以及原生线程测试的覆盖边界。当前 C 翻译依赖为 `translate-c 2.0.2`。
- Zine `0.14.0` 构建通过；42 个中文页面的内部链接、锚点、源码路径和既有标题 ID 检查通过。仍有 33 个英文空文件警告。
- 在忽略目录 `.zig-cache/doc-update-20261021/extension/` 复制综合示例，依赖当前 checkout；从文档原样提取 `buildList`、`makeBytes`、`propertyCount`，补齐 Stubs 与绑定。Linux x86_64、Zig `0.17.0`、PHP `8.5.11` NTS 下构建 31/31 步通过；三个处理器循环调用 100 轮，返回值检查通过。
- 相关 PHPT 19 项通过，覆盖弱／严格参数、数组键与遍历、列表转换和所有权、字符串存储、对象属性／下标／生命周期，以及对齐分配与两类 OOM。`tsrm_native_threads.phpt` 因 NTS 跳过，本轮未验证 ZTS 线程运行。
- `git diff --check` 通过。未逐一运行全部文档片段，未验证其他 PHP 运行时、跨平台构建、浏览器布局或线上发布；LTO 和 TSRM 选项说明依据当前构建源码。

## 2026-10-12：编译期绑定与额度

源码基线：`6a96656`，本次对齐 `ba7de7d` 的声明表与编译期额度调整。更新函数、类、Stub、构建和工作原理共 5 页；英文与源码未修改。

- Zine `0.14.0` 构建通过；42 页链接、锚点、当前页标记和源码路径检查通过，既有标题 ID 保留。仍有 33 个英文空文件警告。
- 在忽略目录复制两个示例并依赖当前源码，未添加外层 `@setEvalBranchQuota`。Linux x86_64、Zig `0.17.0`、PHP `8.5.11` NTS 下，两次构建均为 34/34；骨架 3 项、综合示例 72 项 PHPT 通过，4 项因缺少 CGI 跳过。
- `git diff --check` 通过。未逐一运行全部文档片段，未验证跨平台、SAPI 宿主、浏览器布局或线上发布。

## 2026-10-09：接口命名与引用计数

源码基线：`a117815`。更新 12 个中文页面：同步闭包创建、Callable 释放和 zval 计数接口，补充 SAPI 响应头查询与 CI 配置，精简重复说明。英文、库源码和示例工程未修改。

- Zine `0.14.0` 构建通过；42 页的链接、锚点、当前页标记和源码路径检查通过，既有标题 ID 保留。仅有原有 33 个英文空文件警告。
- 从修改页提取代码，在忽略目录内补齐 Stub、绑定和测试入口。Linux x86_64、Zig `0.17.0`、PHP `8.5.11` NTS 下构建 31/31 步通过；闭包、Callable、临时值及属性读取共 10 项运行检查通过。
- `git diff --check` 通过。未运行完整 PHPT、跨平台 CI、SAPI 宿主或浏览器视觉回归；未发布站点。

## 2026-10-07：对齐当前源码

源码基线：`9e1e48d`。仅修改中文正文、中文维护记录及中文导航分支，英文正文与占位文件、库源码、示例工程和 CI 未修改。

### 内容范围

- 保留六组目录和既有页面路径、标题 ID，中文由 39 页增至 42 页；新增 PHP Stream、执行 PHP 代码与脚本、自定义 SAPI。
- 首页、导航和 SAPI 专页标明 **SAPI 为实验性支持**；其余扩展开发接口按正式功能维护。
- 按当前 `function.zig` / `ctx.zig` 补齐类型化处理器、直接返回、整数范围、`Nullable`、`Mixed`、Callable 和 Stream 参数。
- 修正手动规格中的 `as`、`one_of`、`reference.kind`、运行时 `class` / `out`；同步入门、类、闭包、引用和所有权示例。
- 按当前 `Sapi(T, options)` 说明宿主构建、上下文绑定、请求与进程生命周期、回调和退出状态，不沿用早期接口设计。
- 更新 Zig `0.17.0`、`translate-c 2.0.0`、arginfo 检查及现有 CI 仅发布 API 产物的说明。

### 站点检查

- Zine `0.14.0`：`cd docs && zine release --force` 通过，仅有原有 33 个英文空文件警告。
- 42 个中文 HTML 页的内部链接、标题锚点、当前页标记和源码文件路径检查通过；所有既有标题 ID 保留。
- 新页面加入中文导航，英文导航不新增入口；`git diff --check` 通过。
- 本轮未做浏览器视觉回归、移动端检查、API 资源生成或线上发布。

### 文档代码编译与运行

环境：Linux x86_64，Zig `0.17.0`，PHP CLI `8.5.11` NTS 与匹配头文件。直接使用本地缓存的 Zig 和 PHP-Parser；首次 `/tmp` 编译因配额不足停止，迁至仓库忽略的 `.zig-cache/doc-validation/` 后完成验证。

从文档提取 Zig 代码块，在临时骨架中补齐 Stub、导入、绑定和模块注册；依赖指向当前 checkout，未改动跟踪的示例文件。生成 arginfo 后执行 `zig build -Dphp-include-dir=/usr/include/php`，构建 31/31 步通过，再以 `php -n -dextension=./modules/skeleton.so check.php` 调用。

| 内容 | 结果 |
| --- | --- |
| Hello World 字符串与类型化 Counter | 问候语正确；默认构造值为 0，add 后为 8 |
| `?Nullable(i64)` 与 `Mixed` | 缺省返回 0，显式 null 保留，整数/字符串分支正确 |
| Callable、闭包 | 手动解析和类型化 Callable 两版分别构建运行通过；闭包返回 5 |
| 引用与数组 | 引用整数写回；空数组副本分离后原输入不变 |
| Stream | 打开内存流交给 PHP，写入并读取 `hel`；负长度触发 ValueError |
| `tryEval` | 表达式 `6 * 7` 返回 42 |

两版运行均输出 `document examples passed`。未逐一编译所有页面的全部片段，未运行完整扩展 PHPT 套件。

### 实验性 SAPI 验证

复制当前 `examples/custom_sapi` 到忽略的验证目录，使用文档中的 `runFile()` 片段替换示例对应文件执行段，保留原退出状态处理。链接本地 PHP `8.5.10` NTS embed 共享库，执行：

```sh
zig build install run-tests -Dshared=true \
  -Dphp-include-dir=/tmp/phpz-sapi-install/include/php \
  -Dphp-lib-dir=/tmp/phpz-sapi-install/lib
```

构建 30/30 步通过，24 项文件/`-r`、异常、致命错误、exit、shutdown 和输入错误检查全部通过。结果只证明本次 Linux NTS 共享库配置；未验证 HTTP 后端、工作线程、静态链接、ZTS、Windows、macOS 或其他 PHP 版本，也不改变 SAPI 的实验性定位。

## 2026-09-20：历史记录

日期：2026-09-20。本记录覆盖本轮中文文档修订，不代表所有页面的全部示例或此前建设阶段均已通过运行验证。

## 环境

- Linux x86_64。
- Zig `0.17.0-dev.1946+d813faaf0`。
- PHP `8.5.10` CLI，NTS，非 Debug 构建；使用匹配的开发头文件。
- Zine `0.14.0`。

## 内容修订的文档检查（目录调整前）

- `cd docs && zine release --force` 构建通过。
- 中文正文共 38 页；构建时跳过 33 个英文空文件，相关警告属于现有预留结构。
- 中文页面的内部链接、源码链接对应的本地文件和既有标题 ID 检查通过；本次未删除既有标题 ID。
- `git diff --check` 通过。
- 英文正文、库源码和示例工程未修改。

## 内容修订的示例编译与运行（目录调整前）

在仓库外的临时目录复制 `examples/skeleton`，将依赖指向当前 checkout。从修订后的中文页面提取 Stub 和 Zig 代码块，补齐 imports、模块配置、函数映射和测试入口，组合成临时扩展。没有把测试辅助代码或构建产物加入仓库。

使用随包提供的 `gen_stub.php` 生成 arginfo；特性依赖采用 php-src `php-8.5.10` 的 `Zend/zend_attributes.stub.php`，并在扩展头文件中包含 `Zend/zend_attributes.h`。在临时扩展目录执行：

```sh
php build/gen_stub.php skeleton.stub.php
zig build -Dphp-include-dir="$(php-config --include-dir)"
php -n -dextension=./modules/skeleton.so check.php
```

以下检查通过：

| 内容 | 验证结果 |
| --- | --- |
| Counter 自动绑定与显式 `.methods` 映射 | 两种配置分别构建；Zig `increment` 映射到 PHP `add` 后调用正常 |
| 对象工厂和 backing 访问 | `makeCounter(5)` 创建对象，`counterValue()` 返回 5，`add(3)` 后为 8 |
| PHP 构造器元数据 | `ReflectionMethod::getReturnType()` 返回 `null` |
| 默认克隆和 `.clone` 示例 | Counter 默认克隆抛出 `Error`；Point 克隆后 `x()` 返回 1 |
| 接口、抽象父类和子类注册 | User 继承属性并实现 `getId()`，接口 `instanceof` 判断成立 |
| Trait | PHP 用户类混入 Greets 后，`greet()` 返回 `Hello` |
| 特性 | Tag 构造器设置属性；Marker 使用 `ClassDecl`；反射实例化两者成功 |
| 枚举 | `Status::Active->value` 为 1 |
| 数组查询与删除 | 区分缺失键和 null 元素；删除副本不改变原数组；整数键使用 `findIndex` 查询 |
| 可空 zval 参数 | `optional + nullable + zval` 的编译期类型为 `?*Zval`，省略、null、整数输入均符合说明 |
| 标量参数检查 | `scale(2, 3.0, true)` 返回 6.0；整数 factor 被拒绝，不发生隐式浮点转换 |
| 属性写入所有权 | `setProperty(.object)` 借用输入；`Zval.Object.set(.object)` 消耗预先增加的一份引用；删除属性后引用计数恢复为 1 |
| 模块全局变量 | `init` / `deinit` 签名编译通过，NTS 下 `init` 设置的值可在处理器中读取 |

自动绑定配置输出 `document examples passed`；显式映射及补充所有权检查输出 `document examples and ownership passed`。

## 目录调整验证

同日将中文导航整理为“入门、声明与注册、类型与值、运行时接口、构建与测试、进阶主题”六组，仍为 38 个页面。参数解析从函数绑定页拆出，可空参数并入参数解析；平台构建页合并，新增简明 PHPT 页。同步更新 PLAN、维护说明及内部链接。

- 清理旧站点产物后执行 `zine release --force`，构建通过；仍只有 33 条英文空文件警告。
- 检查生成 HTML 中的内部页面链接和标题锚点，全部有效；单独构建的 `/phpz/api/` 资源不在此次检查范围。
- 每个中文页面均包含六组导航、38 个不重复的页面入口和一个当前页标记。
- 中文骨架工具页移到 `development/tools`，保留原翻译键；与英文 `getting-started/tools` 的双向语言切换链接检查通过。英文正文、目录文件和界面翻译未修改。
- 中文页面引用的仓库源码路径检查通过，示例命名空间无 `Vendor` 残留。
- 已核对 PHP 官方 [Writing Tests](https://php.github.io/php-src/miscellaneous/writing-tests.html) 和 [Running Tests](https://php.github.io/php-src/miscellaneous/running-tests.html)，并在 PHPT 页链接两者。
- 在仓库外复制当前 `examples/skeleton`，使用本地 phpz 依赖，将文档的最小 PHPT 代码块原样写入 `tests/hello.phpt`。`zig build run-tests -Dphp-include-dir="$(php-config --include-dir)"` 构建成功，骨架 3 项测试全部通过；随后使用 `php run-tests.php -q --show-diff -d extension=modules/skeleton.so tests/hello.phpt` 单独运行文档示例，1 项通过。临时工程保留 `skeleton` 扩展名，加载路径相应替换。
- `git diff --check` 通过。未运行完整综合示例 PHPT 套件，未进行浏览器视觉检查或跨平台验证。

移动或合并页面的中文 URL 已更新，未为旧 URL 添加重定向；英文仍使用原有路径。

## 目录调整后的复查

- 函数绑定页补齐 Stub 生成器注解和 `Api` 容器，显式映射与 Stub 均只包含 `MyPHPExt\greet`。从页面提取 Stub 和 Zig 片段，补齐导入与模块注册，在临时骨架工程中分别构建自动绑定、显式映射两种版本。两次 PHP 调用均验证 `MyPHPExt\greet("Zig")` 返回 `"Zig"`。
- 对照源码修正 `this()` / `thisValue()` 的可选指针类型、资源引用计数说明，并补齐 `.clone` 与 `.handlers.clone_obj` 的冲突规则。
- 补充 Windows 单次加载命令和 PHPT 命令的组合方式；Windows 命令仅做静态核对，未在 Windows 运行。
- 重新构建站点，38 个中文页面的内部链接、标题锚点、导航分组、当前页标记及源码链接检查通过；英文文件保持未修改。
- 使用 Edge 打开本地站点，从首页导航进入 PHPT 页，并检查该页截图。正文、代码块、官方文档链接和当前章节标记显示正常；未进行移动端视口或全站视觉回归。
- `git diff --check` 通过。临时扩展与预览产物未加入仓库，检查结束后关闭预览服务。

## Windows 独立章节调整

按阅读需求将 Windows 从“构建与加载”拆出，放在“构建与测试”分组内，位于“构建与加载”之后。保留 MSVC 开发包、DLL 构建与加载、Linux 交叉编译及 PHPT 入口，中文页面总数为 39。导航、大纲、安装页、Hello World 和 PHPT 页的链接已同步。

站点构建、39 页内部链接与锚点、导航及当前页标记检查通过；`git diff --check` 通过。英文未修改，未新增 Windows 运行验证。

## 未覆盖范围

- 未逐一编译执行全部中文页面的所有代码片段，未运行完整 PHPT 套件。
- 未重建 PHP 本身，未验证 Windows、macOS、ZTS、PHP 8.2–8.4 或 PHP Debug 构建。
- 仅检查了桌面浏览器的首页导航和 PHPT 页面；未覆盖移动端与其他页面的视觉回归，未进行线上部署或 API 文档资源构建。
- 全局变量析构的资源释放效果、bailout 清理和并发线程行为未在本轮进行专项运行验证。
