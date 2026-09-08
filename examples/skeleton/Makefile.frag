# stub only for php build system
.PHONY: skeleton-force clean-skeleton

all: $(SKELETON_TARGET)
build-modules: $(SKELETON_TARGET)
PHP_TEST_SHARED_EXTENSIONS += $(SKELETON_TEST_FLAGS)

$(SKELETON_TARGET): skeleton-force
	cd "$(SKELETON_SOURCE_DIR)" && "$(ZIG)" build \
		-Dshared=$(SKELETON_SHARED) \
		-Dphp-include-dir="$(SKELETON_PHP_INCLUDE_DIR)" \
		$(SKELETON_ZIG_FLAGS)
	$(mkinstalldirs) "$(@D)"
	if test "$(SKELETON_ZIG_OUTPUT)" != "$@"; then cp "$(SKELETON_ZIG_OUTPUT)" "$@"; fi

clean: clean-skeleton
clean-skeleton:
	rm -f "$(SKELETON_TARGET)"
