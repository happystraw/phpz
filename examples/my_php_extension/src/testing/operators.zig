const phpz = @import("phpz");
const Zval = phpz.Zval;

/// An operand whose callback breaks the `.operate` contract on purpose.
const Faulty = struct {
    unused: u8 = 0,

    fn operate(op: phpz.Operator, lhs: *Zval, rhs: ?*Zval, result: *Zval) !void {
        _ = lhs;
        _ = rhs;
        switch (op) {
            // Succeeds without writing a result.
            .add => {},
            // Writes a refcounted result, then fails.
            .sub => {
                result.set(.string, "partial result");
                return error.Faulty;
            },
            else => return error.Unsupported,
        }
    }
};

pub const Class = phpz.Class("MyPHPExt\\Test\\FaultyOperand", Faulty, .{ .operate = Faulty.operate });
