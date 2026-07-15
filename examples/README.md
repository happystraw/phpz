# Examples

| Example | Description |
|---------|-------------|
| [skeleton](./skeleton/) | Minimal starter: hello, greet, Counter class |
| [my_php_extension](./my_php_extension/) | Full-featured extension: functions, classes, methods |

## Running

Each example has its own `build.zig` with a `run-tests` step:

```bash
cd examples/<name>
zig build run-tests
```

> PHP include path defaults to `/usr/include/php`. Override with `-Dphp-include-dir=<path>`.
