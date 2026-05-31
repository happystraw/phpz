dnl config.m4 for extension bench_c

dnl Comments in this file start with the string 'dnl'.
dnl Remove where necessary.

dnl If your extension references something external, use 'with':

dnl PHP_ARG_WITH([bench_c],
dnl   [for bench_c support],
dnl   [AS_HELP_STRING([--with-bench_c],
dnl     [Include bench_c support])])

dnl Otherwise use 'enable':

PHP_ARG_ENABLE([bench_c],
  [whether to enable bench_c support],
  [AS_HELP_STRING([--enable-bench_c],
    [Enable bench_c support])],
  [no])

if test "$PHP_BENCH_C" != "no"; then
  dnl Write more examples of tests here...

  dnl Remove this code block if the library does not support pkg-config.
  dnl PKG_CHECK_MODULES([LIBFOO], [foo])
  dnl PHP_EVAL_INCLINE($LIBFOO_CFLAGS)
  dnl PHP_EVAL_LIBLINE($LIBFOO_LIBS, BENCH_C_SHARED_LIBADD)

  dnl If you need to check for a particular library version using PKG_CHECK_MODULES,
  dnl you can use comparison operators. For example:
  dnl PKG_CHECK_MODULES([LIBFOO], [foo >= 1.2.3])
  dnl PKG_CHECK_MODULES([LIBFOO], [foo < 3.4])
  dnl PKG_CHECK_MODULES([LIBFOO], [foo = 1.2.3])

  dnl Remove this code block if the library supports pkg-config.
  dnl --with-bench_c -> check with-path
  dnl SEARCH_PATH="/usr/local /usr"     # you might want to change this
  dnl SEARCH_FOR="/include/bench_c.h"  # you most likely want to change this
  dnl if test -r $PHP_BENCH_C/$SEARCH_FOR; then # path given as parameter
  dnl   BENCH_C_DIR=$PHP_BENCH_C
  dnl else # search default path list
  dnl   AC_MSG_CHECKING([for bench_c files in default path])
  dnl   for i in $SEARCH_PATH ; do
  dnl     if test -r $i/$SEARCH_FOR; then
  dnl       BENCH_C_DIR=$i
  dnl       AC_MSG_RESULT(found in $i)
  dnl     fi
  dnl   done
  dnl fi
  dnl
  dnl if test -z "$BENCH_C_DIR"; then
  dnl   AC_MSG_RESULT([not found])
  dnl   AC_MSG_ERROR([Please reinstall the bench_c distribution])
  dnl fi

  dnl Remove this code block if the library supports pkg-config.
  dnl --with-bench_c -> add include path
  dnl PHP_ADD_INCLUDE($BENCH_C_DIR/include)

  dnl Remove this code block if the library supports pkg-config.
  dnl --with-bench_c -> check for lib and symbol presence
  dnl LIBNAME=BENCH_C # you may want to change this
  dnl LIBSYMBOL=BENCH_C # you most likely want to change this

  dnl If you need to check for a particular library function (e.g. a conditional
  dnl or version-dependent feature) and you are using pkg-config:
  dnl PHP_CHECK_LIBRARY($LIBNAME, $LIBSYMBOL,
  dnl [
  dnl   AC_DEFINE(HAVE_BENCH_C_FEATURE, 1, [ ])
  dnl ],[
  dnl   AC_MSG_ERROR([FEATURE not supported by your bench_c library.])
  dnl ], [
  dnl   $LIBFOO_LIBS
  dnl ])

  dnl If you need to check for a particular library function (e.g. a conditional
  dnl or version-dependent feature) and you are not using pkg-config:
  dnl PHP_CHECK_LIBRARY($LIBNAME, $LIBSYMBOL,
  dnl [
  dnl   PHP_ADD_LIBRARY_WITH_PATH($LIBNAME, $BENCH_C_DIR/$PHP_LIBDIR, BENCH_C_SHARED_LIBADD)
  dnl   AC_DEFINE(HAVE_BENCH_C_FEATURE, 1, [ ])
  dnl ],[
  dnl   AC_MSG_ERROR([FEATURE not supported by your bench_c library.])
  dnl ],[
  dnl   -L$BENCH_C_DIR/$PHP_LIBDIR -lm
  dnl ])
  dnl
  dnl PHP_SUBST(BENCH_C_SHARED_LIBADD)

  dnl In case of no dependencies
  AC_DEFINE(HAVE_BENCH_C, 1, [ Have bench_c support ])

  PHP_NEW_EXTENSION(bench_c, bench_c.c, $ext_shared)
fi
