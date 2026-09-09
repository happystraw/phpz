# stub only for php build system
.PHONY: my_php_extension-force clean-my_php_extension

all: $(MY_PHP_EXTENSION_TARGET)
build-modules: $(MY_PHP_EXTENSION_TARGET)
PHP_TEST_SHARED_EXTENSIONS += $(MY_PHP_EXTENSION_TEST_FLAGS)

$(MY_PHP_EXTENSION_TARGET): my_php_extension-force
	cd "$(MY_PHP_EXTENSION_SOURCE_DIR)" && "$(ZIG)" build \
		-Dshared=$(MY_PHP_EXTENSION_SHARED) \
		-Dphp-include-dir="$(MY_PHP_EXTENSION_PHP_INCLUDE_DIR)" \
		$(MY_PHP_EXTENSION_ZIG_FLAGS)
	$(mkinstalldirs) "$(@D)"
	if test "$(MY_PHP_EXTENSION_ZIG_OUTPUT)" != "$@"; then cp "$(MY_PHP_EXTENSION_ZIG_OUTPUT)" "$@"; fi

clean: clean-my_php_extension
clean-my_php_extension:
	rm -f "$(MY_PHP_EXTENSION_TARGET)"
