# phpz 文档

文档使用 Zig `0.17.0`。

使用 Zine 原生 SuperMD（`.smd`）编写。采用 Zine 原生多语言配置，默认语言为 `en-US`。首版完成简体中文正文；英文已完成简介及 4 个入门页面，其余 35 个章节保留同名空文件。

## 安装与预览

从 [Zine v0.14.0 发布页](https://github.com/kristoff-it/zine/releases/tag/v0.14.0) 下载对应平台的二进制，解压后将 `zine` 放入 `PATH`。站点通过 Zine 独立构建和预览。需要同时提供 API 文档时，先用 `zig build docs` 生成，再作为 Zine build assets 传入。

在仓库根目录执行：

```sh
zine version
cd docs
zine
```

版本应为 `0.14.0`。英文入口为 <http://localhost:1990/phpz/>，中文文档为 <http://localhost:1990/phpz/zh-CN/>，修改内容或模板后开发服务器会重新构建。

## 生成静态站点

在仓库根目录运行：

```sh
cd docs
zine release --force
```

产物写入 `docs/public/`，该目录已忽略，不提交到仓库。此步骤使用 `zine release --force` 覆盖已有产物；删除或重命名页面后，先清空 `docs/public/`，再重新构建，避免保留旧文件。

### API 文档资源

在仓库根目录生成 API 文档：

```sh
zig build docs -Dphp-include-dir="$(php-config --include-dir)"
```

库 API 输出到 `zig-out/docs/lib/`。随后从仓库根目录进入 `docs/`，使用 Zine 原生参数构建完整站点：

```sh
cd docs
zine release --force \
  --build-asset=api/index.html ../zig-out/docs/lib/index.html --install-always=phpz/api/index.html \
  --build-asset=api/main.js ../zig-out/docs/lib/main.js --install-always=phpz/api/main.js \
  --build-asset=api/main.wasm ../zig-out/docs/lib/main.wasm --install-always=phpz/api/main.wasm \
  --build-asset=api/sources.tar ../zig-out/docs/lib/sources.tar --install-always=phpz/api/sources.tar
```

预览完整站点时，将上面命令中的 `zine release --force` 改为 `zine`，保留资源参数。API 入口为 <http://localhost:1990/phpz/api/>，对应产物为 `docs/public/phpz/api/`。

Zine 0.14 的 build assets 按文件注册；`--install-always` 确保 API HTML 和 JavaScript 间接使用的运行资源也被安装。两种语言共用同一个 API 入口，`zig-out/docs/build/` 不包含在此入口中。

修改 Zig/API 源码后，重新执行 `zig build docs` 并重启 Zine 预览。修改 `.smd` 或模板由 Zine 实时重建。直接运行不带资源参数的 `zine` 仅预览正文，不安装 API 资源。

站点地址已配置为 <https://happystraw.github.io/phpz/>，中文入口为 <https://happystraw.github.io/phpz/zh-CN/>：

- `.host_url`：`https://happystraw.github.io`，仅包含协议和主机。
- 英文 `.output_prefix_override`：`phpz`；中文：`phpz/zh-CN`。
- 共享样式放在 `assets/phpz/style.css`，通过 `$site.asset('phpz/style.css').link()` 引用，输出为 `/phpz/style.css`。

Zine 0.14 的多语言输出前缀同时影响 URL 和输出目录，因此英文首页生成在 `public/phpz/index.html`，中文首页在 `public/phpz/zh-CN/index.html`。本地使用 Zine 开发服务器即可预览。若另用静态服务器，应以 `public/` 为服务根目录，访问 `/phpz/`。

部署另行安排。未来发布到此 GitHub Pages 项目站点时，应以 **`docs/public/phpz/` 的内容作为发布产物根目录**，由 GitHub Pages 提供 `/phpz/` 项目前缀，避免路径重复。本次仅完成地址配置与本地验证。

## 目录与页面

```text
content/zh-CN/        中文内容
content/en-US/        英文简介、入门内容及 35 个同名空文件
i18n/                en-US、zh-CN 界面翻译
layouts/doc.shtml    两种语言共享的章节导航和正文布局
layouts/templates/   共享页面框架
assets/phpz/style.css     页面、代码高亮与响应式样式
assets/phpz/site.js       亮暗主题初始化、切换与保存
```

新增页面示例：

```smd
---
.title = "页面标题",
.date = .date("2026-09-16T00:00:00"),
.layout = "doc.shtml",
.translation_key = "reference/example",
.custom = { "section": "参考指南" },
---

介绍这个接口解决什么问题。

# [最小示例]($heading.id('minimal-example'))

正文从一级标题开始。
```

Zine 0.14 要求正文标题从 `#` 开始。配置中的 `.supermd.headings_h2 = true` 将它渲染为 `<h2>`，页面 `<h1>` 由模板中的 `.title` 提供。

### 标题锚点

正文标题使用 `$heading.id()` 声明稳定的英文 ID：

```smd
# [安装 PHP]($heading.id('install-php'))

[本页跳转]($link.ref('install-php'))
[跨页跳转]($link.page('getting-started/installation').ref('php-development-environment'))
```

同一页面的 ID 必须唯一；中英文对应内容使用相同 ID，标题改名时保留已有 ID。右侧目录通过 `$page.toc()` 原生生成链接，目录跳转不需要 JavaScript，标题文字本身不添加链接。英文空占位文件保持为空。

### 新增与修改章节

1. 在中文目录创建 `.smd`；有实质内容的章节概览可用 `index.smd`，其他文件使用小写英文和连字符；仅分组时直接使用目录和侧栏标题。
2. 在英文目录创建相同相对路径的零字节文件。
3. 为有正文的页面设置唯一的 `.translation_key`；译文使用同一个键。更新相关正文链接和 `layouts/doc.shtml` 中的导航。
4. 内部链接使用 `[标题]($link.page('reference/types/zval'))`，让 Zine 检查目标并处理路径前缀。
5. 用 `zig`、`php`、`sh` 等已支持的语言标记代码块。普通输出使用不带语言标记的代码块。
6. 在 `docs/` 目录运行 `zine release --force`，检查链接、当前章节标记及手机布局；需要 API 文档时按上文传入资源参数。

尚未完成的中文页面在 frontmatter 增加 `.draft = true`，并先从正式导航移除；使用 `zine --drafts` 预览。Zine 0.14 会警告并跳过英文零字节文件，不为其生成页面；这 35 条警告属于当前预留结构的预期输出。

补充英文时，为对应文件添加正文和 frontmatter，并在共享模板中启用对应的英文导航。两种语言保持相同相对路径，供 Zine 原生翻译关联使用。两种语言共用 `layouts/doc.shtml`。每个有正文的页面设置 `.translation_key`，值为不带 `.smd` 的语言目录内相对路径（保留 `index`），对应译文使用同一个值。顶部通过 `$page.locales()` 按此键枚举已完成的译文，语言切换保留当前章节；未翻译的页面不显示英文链接。共享界面文本通过 `$i18n.get()` 从 `i18n/` 读取。

Zine 0.14 的开发服务器不会处理共享资源的 `assets_prefix_path`，因此这里使用实际资源子目录保留 `/phpz/` 路径，让开发与发布输出一致。

## 页面风格

布局参考 [VitePress](https://vitepress.dev/)：顶部导航、左侧章节、中央正文和右侧原生目录，不提供搜索框。强调色使用 [Zig 官网](https://ziglang.org/) 的黄色 `#f7a41d`；亮色模式的文字链接使用较深的金色以保证可读性。

支持亮暗主题，首次访问按系统偏好选择，手动切换后保存到本地。`assets/phpz/site.js` 仅负责主题初始化、切换与保存；章节折叠使用原生 HTML `details`，目录由 Zine `$page.toc()` 生成。布局和响应式样式由 `assets/phpz/style.css` 与 SuperHTML 模板实现。

## 内容维护

- 示例工程的扩展名统一为 `my_php_extension`，中英文命令、文件名和加载路径同步更新。

- PHP API 声明以 Stub 为入口，实现行为以当前源码为准。
- 代码片段需说明是完整处理器还是函数体片段，完整工程参考 `examples/skeleton`。
- 重点核对引用计数、所有权转移、数组分离、对象 GC 与 bailout 边界。
- 修改代码示例后用对应 PHP 运行验证，不能仅以站点构建成功代替代码验证。
- 章节与实施范围见 [PLAN.md](./PLAN.md)，首版检查记录见 [VALIDATION.md](./VALIDATION.md)。
