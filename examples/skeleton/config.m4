dnl stub only for php build system
PHP_ARG_ENABLE([skeleton],
  [whether to enable skeleton support],
  [AS_HELP_STRING([--enable-skeleton],
    [Enable skeleton support])],
  [no])

AS_VAR_IF([PHP_SKELETON], [no],, [
  AC_PATH_PROG([ZIG], [zig], [no])
  AS_VAR_IF([ZIG], [no], [
    AC_MSG_ERROR([zig is required to build skeleton])
  ])

  AC_ARG_VAR([SKELETON_ZIG_FLAGS], [Extra zig build arguments (default: -Doptimize=ReleaseSafe)])

  ext_srcdir=PHP_EXT_SRCDIR(skeleton)
  ext_builddir=PHP_EXT_BUILDDIR(skeleton)
  SKELETON_SOURCE_DIR="$ext_srcdir"
  SKELETON_BUILD_DIR="$abs_builddir/$ext_builddir"
  AS_VAR_IF([ext_builddir], [.], [
    SKELETON_PHP_INCLUDE_DIR="$phpincludedir"
  ], [
    SKELETON_PHP_INCLUDE_DIR="$abs_srcdir"
  ])
  : ${SKELETON_ZIG_FLAGS=-Doptimize=ReleaseSafe}

  AC_DEFINE([HAVE_SKELETON], [1],
    [Define to 1 if the PHP extension 'skeleton' is available.])

  AS_VAR_IF([ext_shared], [yes], [
    SKELETON_SHARED=true
    SKELETON_TARGET="$abs_builddir/modules/skeleton.so"
    SKELETON_ZIG_OUTPUT="$SKELETON_SOURCE_DIR/modules/skeleton.so"
    SKELETON_TEST_FLAGS="-d extension=$SKELETON_TARGET"
    install_modules=install-modules
  ], [
    SKELETON_SHARED=false
    SKELETON_TARGET="$SKELETON_BUILD_DIR/libskeleton.a"
    SKELETON_ZIG_OUTPUT="$SKELETON_SOURCE_DIR/zig-out/lib/libskeleton.a"
    PHP_NEW_EXTENSION([skeleton], [], [no])
    PHP_GLOBAL_OBJS="$PHP_GLOBAL_OBJS $SKELETON_TARGET"
  ])

  PHP_SUBST([ZIG])
  PHP_SUBST([SKELETON_SOURCE_DIR])
  PHP_SUBST([SKELETON_PHP_INCLUDE_DIR])
  PHP_SUBST([SKELETON_ZIG_FLAGS])
  PHP_SUBST([SKELETON_BUILD_DIR])
  PHP_SUBST([SKELETON_SHARED])
  PHP_SUBST([SKELETON_TARGET])
  PHP_SUBST([SKELETON_ZIG_OUTPUT])
  PHP_SUBST([SKELETON_TEST_FLAGS])
  PHP_ADD_MAKEFILE_FRAGMENT
])
