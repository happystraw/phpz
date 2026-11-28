# Phpz - 用 Zig 编写 PHP 扩展

phpz 为 PHP C API 提供 Zig 绑定，让你可以用 Zig 编写 PHP 扩展。

[English](./README.md)

## 文档

[phpz 文档](https://happystraw.github.io/phpz/zh-CN)

## 环境要求

- Zig 0.17.0
- PHP 8.2–8.6，支持 NTS 和 ZTS。支持的平台包括 Linux（x86_64、aarch64）、macOS（x86_64、aarch64）和 Windows（MSVC x64）。

## 功能

- **模块** — 声明扩展元数据、生命周期钩子、phpinfo、INI 配置、全局变量、观察器和导出符号。
- **PHP 声明文件集成** — 根据 stub 文件中的声明生成 arginfo、函数表、常量、特性（attributes）和类元数据，并支持校验 arginfo。[PHP stub 文件文档](https://php.github.io/php-src/miscellaneous/stubs.html)
- **函数与方法** — 通过 `Ctx` 读取带类型的参数、设置返回值、处理可空值和原始 zval。标量参数遵循 Zend 参数解析（ZPP）规则，包括弱类型转换、`strict_types`、整数到浮点数的拓宽转换，以及传入 `null` 时的弃用提示。参数错误使用 Zend 原生错误信息。
- **类与对象** — 将 Zig `struct` 的生命周期绑定到 PHP 对象，支持类条目、方法、继承、接口、枚举、异常和对象处理器，也可自定义运算符和比较行为。
- **运行时状态** — 在 NTS 和 ZTS 构建中访问带类型的模块全局变量、PHP/Zend 全局变量和 PHP 超全局变量。
- **zval 与 Zend API** — 提供 zval 转换和所有权管理，支持数组、字符串、对象、可调用值、函数和资源。可用 `ListBuilder` 按 `ZEND_HASH_FILL_PACKED` 的方式构建紧凑数组，用 `symtable*` 按 PHP 的数组键规则查找元素。
- **原生闭包** — 使用 `Function.createClosure()`、`closure.createFromHandler()` 或 `closure.createFromFn()` 创建 PHP `Closure` 对象。
- **INI、phpinfo 与错误处理** — 读取带类型的 INI 配置、输出 phpinfo、处理 PHP 错误和异常，并在 Zend bailout 时安全地清理资源。
- **观察器** — 通过函数调用、错误和异常钩子进行性能分析与监控。
- **内存管理** — 基于 PHP 内存分配器提供 Zig 分配器，支持任意对齐要求。调试时可启用兼容 ZTS 的内存泄漏追踪。
- **构建集成** — 处理 PHP C 头文件转换、扩展链接和平台配置。
- **PHP 构建系统** — 向 `phpz_skel.php` 传入 `--with-php-build-system`，即可生成将扩展编译为 PHP 内置模块或共享模块所需的文件。[骨架项目构建指南](./examples/skeleton/README.md#php-build-system)
- **交叉编译** — 使用 [Bash 脚本](./scripts/build-unix.sh)或 [PowerShell 脚本](./scripts/build-unix.ps1) 构建 Linux（glibc、musl）和 macOS 的 x86_64、ARM64 扩展，也可在 [Linux](./scripts/build-windows.sh) 或 [Windows PowerShell](./scripts/build-windows.ps1) 中构建 Windows x86_64 MSVC 扩展。

## 快速开始

使用 phpz 0.1.0 的骨架生成器创建扩展。

```bash
curl -fsSL https://github.com/happystraw/phpz/releases/download/0.1.0/phpz_skel.php | \
  php -- --ext my_php_extension
```

使用 PHP 8.2 时，先下载脚本，再在本地运行。

```bash
curl -fsSLO https://github.com/happystraw/phpz/releases/download/0.1.0/phpz_skel.php
php phpz_skel.php --ext my_php_extension
```

进入生成的项目后，可以运行测试。

```bash
cd my_php_extension
zig build run-tests
```

## 手动配置

完整的最小项目见 [扩展骨架示例](./examples/skeleton)。

### 1. 添加 phpz 依赖

```bash
zig fetch --save git+https://github.com/happystraw/phpz
```

### 2. 创建扩展文件

一个典型的 phpz 扩展包含以下文件。

- `build.zig.zon` — 声明 `phpz` 依赖。
- `build.zig` — 初始化 `Phpz` 并调用 `phpz.addExtension`。
- `<name>.stub.php` — 声明扩展对 PHP 暴露的 API。
- `<name>_arginfo.h` — 由 PHP 的 `gen_stub.php` 生成。
- `<name>.h` — 包含 `phpz.h` 和生成的 arginfo 头文件。
- `src/root.zig` — 注册函数、类和模块。

### 3. 生成 arginfo

以下命令中的 `<name>` 为扩展名。

```bash
php /path/to/php-src/build/gen_stub.php <name>.stub.php
```

### 4. 构建扩展

```bash
zig build -Dphp-include-dir="$(php-config --include-dir)"
```

完整的 `build.zig`、stub 文件声明、C 头文件、Zig 模块和 PHPT 测试可参考 [扩展骨架示例](./examples/skeleton)。

## 示例

[examples 目录](./examples/) 中提供了可运行的完整示例。

## 工作原理

```text
扩展的 .stub.php
  └─ gen_stub.php → arginfo.h
       ├─ ext_functions
       ├─ register_class_*
       └─ register_{name}_symbols

PHP C 头文件（含 arginfo.h）
  └─ translate-c → Zig 绑定（php_c 模块）

Zig 绑定与扩展的 Zig 源码
  ├─ phpz.function() / phpz.functions() → 导出 zif_* 函数
  ├─ phpz.Class()                       → 生成包装类型并导出 zim_* 方法
  └─ phpz.module()                      → 导出 get_module()

PHP 加载扩展 → 读取模块条目 → 注册函数 → 执行模块启动钩子
```

1. **构建阶段** — `gen_stub.php` 根据 `.stub.php` 生成包含函数元数据和 `register_*` 符号的 `arginfo.h`。`translate-c` 将 PHP C 头文件转换为 Zig 绑定。
2. **编译阶段** — `phpz.function()` 和 `phpz.functions()` 导出 `zif_*` 包装函数，`phpz.Class()` 创建包装类型，`phpz.module()` 导出动态加载器所需的 `get_module()`。
3. **运行阶段** — PHP 加载扩展共享库后，调用 `get_module()` 获取模块条目，并按下表注册函数、常量和类。

| 注册对象 | 使用的符号                | 注册时机          | 注册方式                                           |
| -------- | ------------------------- | ----------------- | -------------------------------------------------- |
| 函数     | `ext_functions`           | 模块初始化        | PHP 读取模块条目中的函数表。                       |
| 常量     | `register_{name}_symbols` | 模块启动（MINIT） | `module_startup_func` 自动调用生成的注册函数。     |
| 类       | `register_class_*`        | 模块启动（MINIT） | phpz 按 `phpz.module` 的 `.classes` 列表顺序注册。 |

模块启动时，phpz 还会注册 INI 配置项。`.classes` 中的类会在用户的 `module_startup_fn` 执行前完成注册。若类依赖父类或接口，应将父类和接口放在列表前面，并通过该类的 `.register` 选项传入对应的类条目。需要手动注册的类可在用户钩子中调用其 `register()` 方法。

## 致谢

phpz 的设计受到 [ext-php-rs](https://github.com/extphprs/ext-php-rs) 的启发。

## 许可证

[MIT 许可证](./LICENSE)
