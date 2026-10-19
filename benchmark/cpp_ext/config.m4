PHP_ARG_ENABLE([bench_cpp],
  [whether to enable bench_cpp support],
  [AS_HELP_STRING([--enable-bench_cpp], [Enable bench_cpp support])],
  [no])

if test "$PHP_BENCH_CPP" != "no"; then
  PHP_REQUIRE_CXX()
  PHP_NEW_EXTENSION(bench_cpp, bench_cpp.cpp, $ext_shared,, -DZEND_ENABLE_STATIC_TSRMLS_CACHE=1 -std=c++17, cxx)
fi
