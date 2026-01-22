PHP_ARG_ENABLE(my_php_extension, whether to enable My PHP Extension,
[ --enable-my-php-extension   Enable My PHP Extension support])

if test "$PHP_MY_PHP_EXTENSION" != "no"; then
    dnl Check for Zig compiler
    AC_PATH_PROG(ZIG, zig, no)
    if test "$ZIG" = "no"; then
        AC_MSG_ERROR([Zig compiler not found. Please install Zig from https://ziglang.org/])
    fi

    dnl Get Zig version
    AC_MSG_CHECKING([for Zig version])
    ZIG_VERSION=$($ZIG version)
    AC_MSG_RESULT([ZIG Version: $ZIG_VERSION])

    dnl Export ZIG variable to Makefile
    PHP_SUBST(ZIG)

    dnl Register the C bridge file for compilation
    PHP_NEW_EXTENSION(my_php_extension, my_php_extension.c, $ext_shared,, -DZEND_ENABLE_STATIC_TSRMLS_CACHE=1)

    dnl Determine Zig library path based on build context
    if test -z "PHP_EXT_DIR(my_php_extension)"; then
        dnl Building standalone with phpize - use relative path
        ZIG_LIB_PATH="\$(srcdir)/zig-out/lib/libmy_php_extension.a"
    else
        dnl Building in PHP source tree - use extension directory path
        ZIG_LIB_PATH=PHP_EXT_DIR(my_php_extension)"/zig-out/lib/libmy_php_extension.a"
    fi

    dnl Add linker flags based on whether building shared or static
    if test "$ext_shared" = "yes"; then
        dnl Building as shared extension (.so)
        dnl Export all static symbols
        MY_PHP_EXTENSION_SHARED_LIBADD="-Wl,--whole-archive,$ZIG_LIB_PATH,--no-whole-archive"
        PHP_SUBST(MY_PHP_EXTENSION_SHARED_LIBADD)
        EXT_SHARED=true
        PHP_SUBST(EXT_SHARED)
    else
        dnl Building as static extension into PHP binary
        EXTRA_LIBS="$EXTRA_LIBS $ZIG_LIB_PATH"
        EXT_SHARED=false
        PHP_SUBST(EXT_SHARED)
    fi

    dnl Add custom build step for Zig static library
    PHP_ADD_MAKEFILE_FRAGMENT
fi
