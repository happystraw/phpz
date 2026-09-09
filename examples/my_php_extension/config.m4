dnl stub only for php build system
PHP_ARG_ENABLE([my_php_extension],
  [whether to enable my_php_extension support],
  [AS_HELP_STRING([--enable-my_php_extension],
    [Enable my_php_extension support])],
  [no])

AS_VAR_IF([PHP_MY_PHP_EXTENSION], [no],, [
  AC_PATH_PROG([ZIG], [zig], [no])
  AS_VAR_IF([ZIG], [no], [
    AC_MSG_ERROR([zig is required to build my_php_extension])
  ])

  AC_ARG_VAR([MY_PHP_EXTENSION_ZIG_FLAGS], [Extra zig build arguments (default: -Doptimize=ReleaseSafe)])

  ext_srcdir=PHP_EXT_SRCDIR(my_php_extension)
  ext_builddir=PHP_EXT_BUILDDIR(my_php_extension)
  MY_PHP_EXTENSION_SOURCE_DIR="$ext_srcdir"
  MY_PHP_EXTENSION_BUILD_DIR="$abs_builddir/$ext_builddir"
  AS_VAR_IF([ext_builddir], [.], [
    MY_PHP_EXTENSION_PHP_INCLUDE_DIR="$phpincludedir"
  ], [
    MY_PHP_EXTENSION_PHP_INCLUDE_DIR="$abs_srcdir"
  ])
  : ${MY_PHP_EXTENSION_ZIG_FLAGS=-Doptimize=ReleaseSafe}

  AC_DEFINE([HAVE_MY_PHP_EXTENSION], [1],
    [Define to 1 if the PHP extension 'my_php_extension' is available.])

  AS_VAR_IF([ext_shared], [yes], [
    MY_PHP_EXTENSION_SHARED=true
    MY_PHP_EXTENSION_TARGET="$abs_builddir/modules/my_php_extension.so"
    MY_PHP_EXTENSION_ZIG_OUTPUT="$MY_PHP_EXTENSION_SOURCE_DIR/modules/my_php_extension.so"
    MY_PHP_EXTENSION_TEST_FLAGS="-d extension=$MY_PHP_EXTENSION_TARGET"
    install_modules=install-modules
  ], [
    MY_PHP_EXTENSION_SHARED=false
    MY_PHP_EXTENSION_TARGET="$MY_PHP_EXTENSION_BUILD_DIR/libmy_php_extension.a"
    MY_PHP_EXTENSION_ZIG_OUTPUT="$MY_PHP_EXTENSION_SOURCE_DIR/zig-out/lib/libmy_php_extension.a"
    PHP_NEW_EXTENSION([my_php_extension], [], [no])
    PHP_GLOBAL_OBJS="$PHP_GLOBAL_OBJS $MY_PHP_EXTENSION_TARGET"
  ])

  PHP_SUBST([ZIG])
  PHP_SUBST([MY_PHP_EXTENSION_SOURCE_DIR])
  PHP_SUBST([MY_PHP_EXTENSION_PHP_INCLUDE_DIR])
  PHP_SUBST([MY_PHP_EXTENSION_ZIG_FLAGS])
  PHP_SUBST([MY_PHP_EXTENSION_BUILD_DIR])
  PHP_SUBST([MY_PHP_EXTENSION_SHARED])
  PHP_SUBST([MY_PHP_EXTENSION_TARGET])
  PHP_SUBST([MY_PHP_EXTENSION_ZIG_OUTPUT])
  PHP_SUBST([MY_PHP_EXTENSION_TEST_FLAGS])
  PHP_ADD_MAKEFILE_FRAGMENT
])
