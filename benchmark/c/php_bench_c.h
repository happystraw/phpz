/* bench_c extension for PHP */

#ifndef PHP_BENCH_C_H
# define PHP_BENCH_C_H

extern zend_module_entry bench_c_module_entry;
# define phpext_bench_c_ptr &bench_c_module_entry

# define PHP_BENCH_C_VERSION "0.1.0"

# if defined(ZTS) && defined(COMPILE_DL_BENCH_C)
ZEND_TSRMLS_CACHE_EXTERN()
# endif

#endif	/* PHP_BENCH_C_H */
