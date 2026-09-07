const std = @import("std");
const Integer = std.math.big.int.Managed;

const phpz = @import("phpz");
const Zval = phpz.Zval;
const allocator = phpz.heap.php_allocator;

const BigInteger = struct {
    integer: Integer,

    fn init() !BigInteger {
        return .{ .integer = try Integer.init(allocator) };
    }

    fn deinit(self: *BigInteger) void {
        self.integer.deinit();
    }

    fn clone(self: *const BigInteger) !BigInteger {
        return .{ .integer = try self.integer.clone() };
    }

    /// PHP: MyPHPExt\BigInteger::__construct(int|string $value = 0): void
    pub fn __construct(ctx: phpz.Ctx) !BigInteger {
        const args = try ctx.call.expectArgs(&.{
            .{ .mixed = .{ .optional = true, .unions = &.{ .int, .string } } },
        }, {});
        var self = try init();
        errdefer self.deinit();
        if (args[0]) |input| switch (input) {
            .int => |n| try self.integer.set(n),
            .string => |text| {
                // Managed.setString permits separators and empty input; the
                // PHP example deliberately accepts only [+-]?[0-9]+.
                var digits = text;
                const negative = text.len != 0 and text[0] == '-';
                if (text.len != 0 and (negative or text[0] == '+')) digits = text[1..];
                if (digits.len == 0) return phpz.errors.argumentValueError(1, "must be a decimal integer", .{});
                for (digits) |ch| {
                    if (!std.ascii.isDigit(ch)) return phpz.errors.argumentValueError(1, "must be a decimal integer", .{});
                }
                try self.integer.setString(10, digits);
                if (negative and !self.integer.eqlZero()) self.integer.setSign(false);
            },
        };
        return self;
    }

    /// PHP: MyPHPExt\BigInteger::value(): string
    pub fn value(self: *const BigInteger, ctx: phpz.Ctx) !void {
        const text = try self.integer.toString(allocator, 10, .lower);
        defer allocator.free(text);
        ctx.ret.set(.string, text);
    }

    const ops = struct {
        /// Borrow object limbs; scalar operands use caller-owned scratch storage.
        fn read(input: *Zval, scratch: *Integer) !*const Integer {
            var operand = input;
            while (operand.is(.reference)) operand = .from(operand.asUnchecked(.reference).val());
            if (operand.is(.int)) {
                try scratch.set(operand.asUnchecked(.int));
                return scratch;
            }
            const instance = Class.fromZval(operand) catch return error.Unsupported;
            return &(instance.backing() orelse return error.UninitializedBacking).integer;
        }

        /// Keep the new object locally owned until the arithmetic has succeeded.
        fn output() !*Class {
            const instance = Class.create();
            errdefer instance.object().release();
            if (phpz.errors.hasException()) return error.PhpException;
            _ = instance.backing() orelse return error.UninitializedBacking;
            return instance;
        }

        fn normalizeZero(number: *Integer) void {
            if (number.eqlZero()) number.setSign(true);
        }

        fn operate(op: phpz.Operator, lhs: *Zval, optional_rhs: ?*Zval, result: *Zval) !void {
            switch (op) {
                .bit_not => return bitNot(lhs, result),
                .concat => return concat(lhs, optional_rhs.?, result),
                .bool_not, .bool_xor => return error.Unsupported,
                _ => return error.Unsupported,
                else => {},
            }
            const rhs = optional_rhs.?;
            var left_scalar = try Integer.init(allocator);
            defer left_scalar.deinit();
            var right_scalar = try Integer.init(allocator);
            defer right_scalar.deinit();
            const a = try read(lhs, &left_scalar);
            const b = try read(rhs, &right_scalar);
            const instance = try output();
            errdefer instance.object().release();
            const out: *Integer = &instance.backing().?.integer;
            switch (op) {
                .add => try out.add(a, b),
                .sub => try out.sub(a, b),
                .mul => try out.mul(a, b),
                .div, .mod => {
                    if (b.eqlZero()) return error.DivisionByZero;
                    var other = try Integer.init(allocator);
                    defer other.deinit();
                    if (op == .div) {
                        try out.divTrunc(&other, a, b);
                    } else {
                        try other.divTrunc(out, a, b);
                    }
                },
                .pow => try out.pow(a, b.toInt(u32) catch return error.InvalidExponent),
                .shl => try out.shiftLeft(a, b.toInt(usize) catch return error.InvalidShift),
                .shr => try out.shiftRight(a, b.toInt(usize) catch return error.InvalidShift),
                .bit_and => try out.bitAnd(a, b),
                .bit_or => {
                    // The current stdlib may leave high limbs untouched for mixed signs.
                    // Copy the longer operand and use the supported in-place operation.
                    const longer = if (a.len() >= b.len()) a else b;
                    const shorter = if (longer == a) b else a;
                    try out.copy(longer.toConst());
                    try out.bitOr(out, shorter);
                },
                .bit_xor => try out.bitXor(a, b),
                else => unreachable,
            }
            normalizeZero(out);
            result.set(.object, instance.object());
        }

        fn bitNot(operand: *Zval, result: *Zval) !void {
            var scalar = try Integer.init(allocator);
            defer scalar.deinit();
            const a = try read(operand, &scalar);
            const instance = try output();
            errdefer instance.object().release();
            const out = &instance.backing().?.integer;
            // Infinite signed two's-complement complement: ~a = -a - 1.
            try out.copy(a.toConst());
            out.negate();
            try out.addScalar(out, -1);
            normalizeZero(out);
            result.set(.object, instance.object());
        }

        fn concat(lhs: *Zval, rhs: *Zval, result: *Zval) !void {
            var left_scalar = try Integer.init(allocator);
            defer left_scalar.deinit();
            var right_scalar = try Integer.init(allocator);
            defer right_scalar.deinit();
            const a = try read(lhs, &left_scalar);
            const b = try read(rhs, &right_scalar);
            const left_text = try a.toString(allocator, 10, .lower);
            defer allocator.free(left_text);
            const right_text = try b.toString(allocator, 10, .lower);
            defer allocator.free(right_text);
            const text = try std.mem.concat(allocator, u8, &.{ left_text, right_text });
            defer allocator.free(text);
            result.set(.string, text);
        }

        fn compare(lhs: *Zval, rhs: *Zval) !phpz.Comparison {
            var left_scalar = try Integer.init(allocator);
            defer left_scalar.deinit();
            var right_scalar = try Integer.init(allocator);
            defer right_scalar.deinit();
            const a = read(lhs, &left_scalar) catch |err| switch (err) {
                error.Unsupported => return error.Uncomparable,
                else => return err,
            };
            const b = read(rhs, &right_scalar) catch |err| switch (err) {
                error.Unsupported => return error.Uncomparable,
                else => return err,
            };
            return switch (Integer.order(a.*, b.*)) {
                .lt => .less,
                .eq => .equal,
                .gt => .greater,
            };
        }
    };
};

pub const Class = phpz.Class("MyPHPExt\\BigInteger", BigInteger, .{
    .init = BigInteger.init,
    .deinit = BigInteger.deinit,
    .clone = BigInteger.clone,
    .operate = BigInteger.ops.operate,
    .compare = BigInteger.ops.compare,
});
