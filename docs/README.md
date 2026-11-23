# phpz documentation

This directory contains the source for the [phpz documentation](https://happystraw.github.io/phpz/). Zine builds the English and Simplified Chinese guides from SuperMD (`.smd`) files. Both editions share a [Zig API reference](https://happystraw.github.io/phpz/api/).

## Preview the guides

Install [Zine 0.14.0](https://github.com/kristoff-it/zine/releases/tag/v0.14.0) and put the `zine` executable on your `PATH`. From the repository root, run:

```sh
cd docs
zine
```

Open the [English preview](http://localhost:1990/phpz/) or the [Simplified Chinese preview](http://localhost:1990/phpz/zh-CN/). Zine rebuilds the guides as you edit. To preview the generated API reference and search index as well, use the full site build below.

## Edit a page

Edit the corresponding `.smd` file under [content/en-US](./content/en-US/) or [content/zh-CN](./content/zh-CN/). For a new page, copy the front matter from a nearby page in the same section. The [English Hello World guide](./content/en-US/getting-started/hello-world.smd) shows the page layout, heading syntax, and code blocks.

- Give each page a stable `.translation_key`. Use the same key for its translation so the language switcher can connect the two pages, even when their paths differ.
- Put the page title in `.title` and start body headings with `#`. The template renders the title as `<h1>`, and Zine renders the first level of body headings as `<h2>`.
- Give headings stable IDs, such as `$heading.id('generate-extension')`. Link to another page with `$link.page('getting-started/hello-world')` and append `.ref('generate-extension')` to target that heading.
- When adding or moving a page, update its entry in the [chapter navigation](./layouts/doc.shtml). Shared interface labels live in [i18n](./i18n/), the page shell in [base.shtml](./layouts/templates/base.shtml), and styles and scripts in [assets/phpz](./assets/phpz/).

## Build the full site

The release build uses Zig, Zine, PHP development headers (`php-config`), and Node.js with `npx`. Run these commands from the repository root:

```sh
zig build docs -Dphp-include-dir="$(php-config --include-dir)"
npx --yes pagefind@1.6.0 --site docs/public/phpz
```

The first command builds the guides and installs the Zig library reference under `docs/public/phpz/api/`. The second builds the Pagefind search index for the guides. To check the result locally, serve the parent directory so the project’s `/phpz/` URL prefix resolves correctly:

```sh
python3 -m http.server 8000 --directory docs/public
```

Open the [local release build](http://localhost:8000/phpz/). The [GitHub Pages workflow](../.github/workflows/docs.yml) runs the same build and indexing commands when documentation or build inputs change on `dev`, then deploys the contents of `docs/public/phpz/`.

## Publish the skeleton generator

To write the release notes in advance, save a GitHub Release draft for the planned tag, such as `0.1.0`. Push the new `MAJOR.MINOR.PATCH` tag on the commit you want to release. The [release workflow](../.github/workflows/release.yml) runs the Linux, macOS, Windows, built-in extension, SAPI and skeleton tests against that commit. If a test fails, publication is skipped. For a transient failure, rerun the failed jobs in Actions.

After all six suites pass, CI packages the tagged generator as `phpz_skel.php`. If a draft exists, CI uploads the asset and publishes the draft with its existing title and notes. Otherwise it creates the release with the asset and automatically generated notes. The generator defaults to the release tag and accepts an explicit `--phpz` override.

The homepage and quick-start guides use the versioned release URL. Publish those docs once the asset is available.
