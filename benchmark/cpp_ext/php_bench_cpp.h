/* bench_cpp extension for PHP */

#ifndef PHP_BENCH_CPP_H
# define PHP_BENCH_CPP_H

extern zend_module_entry bench_cpp_module_entry;
# define phpext_bench_cpp_ptr &bench_cpp_module_entry

# define PHP_BENCH_CPP_VERSION "0.1.0"

# if defined(ZTS) && defined(COMPILE_DL_BENCH_CPP)
ZEND_TSRMLS_CACHE_EXTERN()
# endif

#endif	/* PHP_BENCH_CPP_H */
