# Examples

| Example | Description |
|---------|-------------|
| [skeleton](./skeleton/) | Minimal starter: hello, greet, Counter class |
| [my_php_extension](./my_php_extension/) | Full-featured extension: functions, classes, methods |

## Running

Each example has its own `build.zig` with a `test` step:

```bash
cd examples/<name>
zig build test
```

> PHP include path defaults to `/usr/include/php`. Override with `-Dphp-include-dir=<path>`.
