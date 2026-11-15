const c = @import("../c.zig").c;

pub const startup = c.zend_signal_startup;

pub const signal = if (@hasDecl(c, "ZEND_SIGNALS")) c.zend_signal else c.signal;
pub const sigaction = if (@hasDecl(c, "ZEND_SIGNALS")) c.zend_sigaction else c.sigaction;

test {
    _ = &startup;
    _ = &signal;
    if (@hasDecl(c, "ZEND_SIGNALS") or @hasDecl(c, "sigaction")) _ = &sigaction;
}
