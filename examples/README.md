# Examples

| Example | Description |
|---------|-------------|
| [my_php_extension](./my_php_extension/) | Basic extension: functions, classes, methods |
| [pjs](./pjs/) | Embed QuickJS in PHP to run JavaScript |

## Running

Each example has its own `build.zig` with a `test` step:

```bash
cd examples/<name>
zig build test
```

> PHP include path defaults to `/usr/include/php`. Override with `-Dphp-include-dir=<path>`.
