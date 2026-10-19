PHP_ARG_ENABLE([bench_c],
  [whether to enable bench_c support],
  [AS_HELP_STRING([--enable-bench_c], [Enable bench_c support])],
  [no])

if test "$PHP_BENCH_C" != "no"; then
  PHP_NEW_EXTENSION(bench_c, bench_c.c, $ext_shared,, -DZEND_ENABLE_STATIC_TSRMLS_CACHE=1)
fi
