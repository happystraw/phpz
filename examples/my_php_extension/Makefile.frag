# Makefile.frag - Build Zig static library for php build system

# Ensure Zig static library is built before compiling C bridge
$(builddir)/my_php_extension.lo: $(srcdir)/zig-out/lib/libmy_php_extension.a

$(srcdir)/zig-out/lib/libmy_php_extension.a:
	@echo "Building Zig static library for phpize..."
	cd $(srcdir) && $(ZIG) build -Dext-shared=$(EXT_SHARED) -Dbuild-static=true -Dphp-include-root=$(phpincludedir) -Doptimize=ReleaseFast
	@echo "Zig static library built: zig-out/lib/libmy_php_extension.a"

# Hook into clean target to clean Zig artifacts
clean: clean-zig

clean-zig:
	@echo "Cleaning Zig build artifacts..."
	@cd $(srcdir) && rm -rf .zig-cache zig-out
	@echo "Zig artifacts cleaned"
