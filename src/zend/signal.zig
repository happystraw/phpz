const c = @import("../c.zig").c;

pub const activate = c.zend_signal_activate;
pub const deactivate = c.zend_signal_deactivate;
pub const startup = c.zend_signal_startup;
pub const init = c.zend_signal_init;

pub const signal = if (@hasDecl(c, "ZEND_SIGNALS")) c.zend_signal else c.signal;
pub const sigaction = if (@hasDecl(c, "ZEND_SIGNALS")) c.zend_sigaction else c.sigaction;

test {
    _ = &activate;
    _ = &deactivate;
    _ = &startup;
    _ = &init;
    _ = &signal;
    if (@hasDecl(c, "ZEND_SIGNALS") or @hasDecl(c, "sigaction")) _ = &sigaction;
}
