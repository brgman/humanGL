const std = @import("std");
const mem = std.mem;
const builtin = @import("builtin");

fn ensureValid(comptime T: type, comptime N: usize) void {
    switch (@typeInfo(T)) {
        .int, .float, .comptime_int, .comptime_float => {},
        else => @compileError("Vector only support familly type Float and Integer"),
    }
    if (N < 2) {
        @compileError("Vector only valid from N >= 2");
    }
}

pub fn Vector(comptime T: type, comptime N: usize) type {
    ensureValid(T, N);
    return struct {
        const Vec = @This();
        const VecType = @Vector(N, T);
        items: VecType,

        pub const zero: Vec = .fromScalar(0);
        pub const identity: Vec = .fromScalar(1);

        pub fn init(items: [N]T) Vec {
            var self: Vec = undefined;
            self.items = items;
            return self;
        }

        pub fn len(_: Vec) usize {
            return N;
        }

        pub fn add(a: Vec, b: Vec) Vec {
            return .{ .items = a.items + b.items };
        }

        pub fn substract(a: Vec, b: Vec) Vec {
            return .{ .items = a.items - b.items };
        }

        pub fn multiply(a: Vec, b: Vec) Vec {
            return .{ .items = a.items * b.items };
        }

        pub fn divide(a: Vec, b: Vec) Vec {
            return .{ .items = a.items / b.items };
        }

        pub fn modulo(a: Vec, b: Vec) Vec {
            return .{ .items = a.items % b.items };
        }

        pub fn fromScalar(item: T) Vec {
            return .{ .items = @splat(item) };
        }

        pub fn get(v: Vec, i: usize) T {
            return @as([N]T, v.items)[i];
        }

        pub fn set(v: *Vec, i: usize, x: T) void {
            var tmp = @as([N]T, v.items);
            tmp[i] = x;
            v.items = tmp;
        }

        pub fn negate(a: Vec) Vec {
            return a.multiply(.fromScalar(-1));
        }

        pub fn inverse(a: Vec) Vec {
            return a.divide(.fromScalar(1));
        }

        pub fn abs(a: Vec) Vec {
            return .init(@bitCast(@abs(a.items)));
        }

        pub fn scale(a: Vec, k: T) Vec {
            return a.multiply(.fromScalar(k));
        }

        pub fn sum(a: Vec) T {
            return @reduce(.Add, a.items);
        }

        pub fn squareRoot(a: Vec) Vec {
            return .{ .items = @sqrt(a.items) };
        }

        pub fn dotProduct(a: Vec, b: Vec) T {
            return sum(.multiply(a, b));
        }

        pub fn manhattanNorm(a: Vec) T {
            return sum(abs(a));
        }

        pub fn euclideanNorm(a: Vec) T {
            return @sqrt(sum(.multiply(a, a)));
        }

        pub fn maxNorm(a: Vec) T {
            return @reduce(.Max, abs(a).items);
        }

        pub fn equal(a: Vec, b: Vec) bool {
            return @reduce(.And, a.items == b.items);
        }

        pub fn cos(a: Vec, b: Vec) T {
            comptime {
                switch (@typeInfo(T)) {
                    .float, .comptime_float => {},
                    else => @compileError("cos requires a float vector type"),
                }
            }

            const dot = dotProduct(a, b);
            const norm_a = euclideanNorm(a);
            const norm_b = euclideanNorm(b);
            const denom = norm_a * norm_b;

            if (@abs(denom) < std.math.floatEps(T)) {
                return std.math.nan(T);
            }

            var result = dot / denom;

            if (result > 1) result = 1;
            if (result < -1) result = -1;

            return result;
        }

        pub fn shuffle(a: Vec, b: Vec, comptime mask: @Vector(N, i32)) Vec {
            return .{ .items = @shuffle(T, a.items, b.items, mask) };
        }

        pub fn crossProduct(a: Vec, b: Vec) Vec {
            comptime {
                if (N != 3) @compileError("Invalid length Vec.len() must be == 3");
            }
            const a_yzx = shuffle(a, a, .{ 1, 2, 0 });
            const a_zxy = shuffle(a, a, .{ 2, 0, 1 });
            const b_yzx = shuffle(b, b, .{ 1, 2, 0 });
            const b_zxy = shuffle(b, b, .{ 2, 0, 1 });
            return substract(multiply(a_yzx, b_zxy), multiply(a_zxy, b_yzx));
        }

        pub fn fusedMultiplyAdd(a: Vec, b: Vec, c: Vec) Vec {
            return .init(@mulAdd(VecType, a.items, b.items, c.items));
        }

        pub fn linearInterpolation(a: Vec, b: Vec, t: T) Vec {
            return .fusedMultiplyAdd(b.substract(a), .fromScalar(t), a);
        }

        pub fn linearCombination(vectors: []const Vec, scalars: []const T) Vec {
            std.debug.assert(vectors.len == scalars.len);
            std.debug.assert(vectors.len > 0);

            var result = Vec.zero;

            for (vectors, scalars) |v, a| {
                result = fusedMultiplyAdd(v, .fromScalar(a), result);
            }

            return result;
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            try writer.writeByte('[');
            inline for (0..N) |i| {
                if (i + 1 == N) {
                    try writer.print("{d}", .{self.items[i]});
                } else {
                    try writer.print("{d},", .{self.items[i]});
                }
            }
            try writer.writeByte(']');
        }
    };
}

pub fn Matrix(comptime T: type, comptime N: usize, comptime M: usize) type {
    return struct {
        const Mat = @This();
        pub const RowVec = Vector(T, N);
        pub const ColVec = Vector(T, M);

        items: [M]RowVec,

        pub const zero: Mat = blk: {
            var items: [M]RowVec = undefined;
            for (0..M) |i| {
                items[i] = RowVec.zero;
            }
            break :blk .init(items);
        };

        pub const identity: Mat = blk: {
            if (M != N) @compileError("Identity matrix only available for square matrices");

            var items: [M]RowVec = undefined;
            for (0..M) |i| {
                items[i] = RowVec.zero;
                items[i].items[i] = 1;
            }
            break :blk .init(items);
        };

        pub fn fromScalar(v: T) Mat {
            var items: [M]RowVec = undefined;
            for (0..M) |i| {
                items[i] = RowVec.fromScalar(v);
            }
            return .init(items);
        }

        pub fn init(items: [M]RowVec) Mat {
            return .{ .items = items };
        }

        pub fn rows(_: Mat) usize {
            return M;
        }

        pub fn cols(_: Mat) usize {
            return N;
        }

        pub fn isSquare() bool {
            return M == N;
        }

        pub fn get(m: Mat, i: usize, j: usize) T {
            std.debug.assert(i < M);
            std.debug.assert(j < N);
            return m.items[i].get(j);
        }

        pub fn set(m: *Mat, i: usize, j: usize, v: T) void {
            std.debug.assert(i < M);
            std.debug.assert(j < N);
            m.items[i].set(j, v);
        }

        pub fn setRow(m: *Mat, comptime index: usize, v: RowVec) void {
            std.debug.assert(index < M);
            m.items[index] = v;
        }

        pub fn setCol(m: *Mat, comptime index: usize, v: ColVec) void {
            std.debug.assert(index < N);
            inline for (0..M) |i| {
                m.items[i].items[index] = v.items[i];
            }
        }

        pub fn row(m: Mat, comptime index: usize) RowVec {
            std.debug.assert(index < M);
            return m.items[index];
        }

        pub fn col(m: Mat, comptime index: usize) ColVec {
            std.debug.assert(index < N);

            var result: ColVec = ColVec.zero;
            inline for (0..M) |i| {
                result.items[i] = m.items[i].items[index];
            }
            return result;
        }

        pub fn multiplyVector(m: Mat, v: RowVec) ColVec {
            std.debug.assert(v.len() == N);

            var result: ColVec = .zero;

            inline for (0..M) |i| {
                result.items[i] = RowVec.dotProduct(m.row(i), v);
            }

            return result;
        }

        pub fn multiply(
            comptime P: usize,
            a: Mat,
            b: Matrix(T, P, N),
        ) Matrix(T, P, M) {
            var result: Matrix(T, P, M) = .zero;

            inline for (0..M) |i| {
                inline for (0..P) |j| {
                    result.items[i].items[j] =
                        RowVec.dotProduct(a.row(i), b.col(j));
                }
            }

            return result;
        }

        pub fn transpose(m: Mat) Matrix(T, M, N) {
            var result: Matrix(T, M, N) = .zero;

            inline for (0..M) |i| {
                inline for (0..N) |j| {
                    result.items[j].items[i] = m.items[i].items[j];
                }
            }

            return result;
        }

        pub fn trace(m: Mat) T {
            if (M != N)
                @compileError("Trace only defined for square matrices");

            var result: T = 0;

            inline for (0..M) |i| {
                result += m.items[i].items[i];
            }

            return result;
        }

        pub fn rowEchelonForm(m: Mat) Mat {
            var result = m;

            var curr_row: usize = 0;

            for (0..N) |curr_col| {
                if (curr_row >= M) break;

                var pivot: ?usize = null;
                for (curr_row..M) |j| {
                    if (result.items[j].get(curr_col) != 0) {
                        pivot = j;
                        break;
                    }
                }

                if (pivot == null) continue;

                if (pivot.? != curr_row) {
                    const tmp = result.items[curr_row];
                    result.items[curr_row] = result.items[pivot.?];
                    result.items[pivot.?] = tmp;
                }

                for (curr_row + 1..M) |r| {
                    const factor =
                        result.items[r].get(curr_col) /
                        result.items[curr_row].get(curr_col);

                    for (curr_col..N) |c| {
                        const v = result.items[r].get(c);
                        result.items[r].set(c, v - factor * result.items[curr_row].get(c));
                    }
                }

                curr_row += 1;
            }

            return result;
        }

        pub fn determinant(m: Mat) T {
            if (M != N)
                @compileError("Determinant only defined for square matrices");

            var result = m;

            var det: T = 1;
            var sign: T = 1;

            var curr_row: usize = 0;

            for (0..N) |curr_col| {
                if (curr_row >= M) break;

                var pivot: ?usize = null;
                for (curr_row..M) |j| {
                    if (result.items[j].get(curr_col) != 0) {
                        pivot = j;
                        break;
                    }
                }

                if (pivot == null) return 0;

                if (pivot.? != curr_row) {
                    const tmp = result.items[curr_row];
                    result.items[curr_row] = result.items[pivot.?];
                    result.items[pivot.?] = tmp;

                    sign = -sign;
                }

                const pivot_val = result.items[curr_row].get(curr_col);

                det *= pivot_val;

                for (curr_row + 1..M) |r| {
                    const factor =
                        result.items[r].get(curr_col) / pivot_val;

                    for (curr_col..N) |c| {
                        const v = result.items[r].get(c);
                        result.items[r].set(
                            c,
                            v - factor * result.items[curr_row].get(c),
                        );
                    }
                }

                curr_row += 1;
            }

            return sign * det;
        }

        pub fn rank(m: Mat) usize {
            var result = m;

            var r: usize = 0;
            var curr_row: usize = 0;

            for (0..N) |column| {
                if (curr_row >= M) break;

                var pivot: ?usize = null;
                for (curr_row..M) |cr| {
                    if (result.items[cr].get(column) != 0) {
                        pivot = cr;
                        break;
                    }
                }

                if (pivot == null) continue;

                if (pivot.? != curr_row) {
                    const tmp = result.items[curr_row];
                    result.items[curr_row] = result.items[pivot.?];
                    result.items[pivot.?] = tmp;
                }

                const pivot_val = result.items[curr_row].get(column);

                for (curr_row + 1..M) |cr| {
                    const factor =
                        result.items[cr].get(column) / pivot_val;

                    for (column..N) |c| {
                        const v = result.items[cr].get(c);
                        result.items[cr].set(
                            c,
                            v - factor * result.items[curr_row].get(c),
                        );
                    }
                }

                r += 1;
                curr_row += 1;
            }

            return r;
        }

        pub fn inverse(m: Mat) !Mat {
            if (M != N)
                @compileError("Inverse only defined for square matrices");

            var left = m;
            var right = Mat.identity;

            for (0..N) |column| {
                var pivot: ?usize = null;
                for (column..M) |r| {
                    if (left.items[r].get(column) != 0) {
                        pivot = r;
                        break;
                    }
                }

                if (pivot == null)
                    return error.NotInvertible;

                if (pivot.? != column) {
                    const tmp_l = left.items[column];
                    const tmp_r = right.items[column];

                    left.items[column] = left.items[pivot.?];
                    right.items[column] = right.items[pivot.?];

                    left.items[pivot.?] = tmp_l;
                    right.items[pivot.?] = tmp_r;
                }

                const pivot_val = left.items[column].get(column);

                for (0..N) |j| {
                    left.items[column].set(j, left.items[column].get(j) / pivot_val);

                    right.items[column].set(j, right.items[column].get(j) / pivot_val);
                }

                for (0..M) |i| {
                    if (i == column) continue;

                    const factor = left.items[i].get(column);

                    for (0..N) |j| {
                        left.items[i].set(j, left.items[i].get(j) -
                            factor * left.items[column].get(j));

                        right.items[i].set(j, right.items[i].get(j) -
                            factor * right.items[column].get(j));
                    }
                }
            }

            return right;
        }

        pub fn format(
            self: Mat,
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            for (0..M) |i| {
                try writer.print("[{f}]", .{self.items[i]});
                if (i + 1 != M) try writer.writeByte('\n');
            }
        }

        fn isRowEchelon(m: anytype) bool {
            var last_pivot_col: isize = -1;

            for (0..M) |i| {
                var pivot_col: isize = -1;
                for (0..N) |j| {
                    if (m.items[i].get(j) != 0) {
                        pivot_col = @intCast(j);
                        break;
                    }
                }

                if (pivot_col == -1) continue;

                if (pivot_col <= last_pivot_col) return false;
                last_pivot_col = pivot_col;

                for (i + 1..M) |k| {
                    if (m.items[k].get(@intCast(pivot_col)) != 0)
                        return false;
                }
            }

            return true;
        }

        pub fn projection(fov: f32, ratio: f32, near: f32, far: f32) Matrix(f32, 4, 4) {
            std.debug.assert(fov > 0);
            std.debug.assert(ratio > 0);
            std.debug.assert(near > 0);
            std.debug.assert(far > near);

            const y_scale = 1.0 / @tan(fov * 0.5);
            const x_scale = y_scale / ratio;

            const z_scale = far / (far - near);
            const z_bias = -(near * far) / (far - near);

            return Matrix(f32, 4, 4).init(.{
                .{ .items = .{ x_scale, 0.0, 0.0, 0.0 } },
                .{ .items = .{ 0.0, y_scale, 0.0, 0.0 } },
                .{ .items = .{ 0.0, 0.0, z_scale, 1.0 } },
                .{ .items = .{ 0.0, 0.0, z_bias, 0.0 } },
            });
        }
    };
}

const testing = std.testing;

test "add" {
    const Vec = Vector(u32, 3);
    const v0: Vec = .init(.{ 1, 2, 3 });
    const v1: Vec = .init(.{ 1, 2, 3 });
    const expected: Vec = .init(.{ 2, 4, 6 });

    try testing.expect(v0.add(v1).equal(expected));
}

test "sub" {
    const Vec = Vector(u32, 3);
    const v0: Vec = .init(.{ 1, 2, 3 });
    const v1: Vec = .init(.{ 1, 2, 3 });
    const expected: Vec = .init(.{ 0, 0, 0 });

    try testing.expect(v0.substract(v1).equal(expected));
}

test "division" {
    const Vec = Vector(f32, 3.0);
    const v0: Vec = .init(.{ 2.0, 4.0, 8.0 });
    const v1: Vec = .fromScalar(2.0);
    const expected: Vec = .init(.{ 1.0, 2.0, 4.0 });

    try testing.expect(v0.divide(v1).equal(expected));
}

test "multiply" {
    const Vec = Vector(f32, 3.0);
    const v0: Vec = .init(.{ 2.0, 4.0, 8.0 });
    const v1: Vec = .fromScalar(2.0);
    const expected: Vec = .init(.{ 4.0, 8.0, 16.0 });

    try testing.expect(v0.multiply(v1).equal(expected));
}

test "fma" {
    const Vec = Vector(f32, 3);
    const a: Vec = .init(.{ 2.0, 3.0, 4.0 });
    const b: Vec = .init(.{ 5.0, 6.0, 7.0 });
    const c: Vec = .init(.{ 1.0, 1.0, 1.0 });

    const result = Vec.fusedMultiplyAdd(a, b, c);
    const expected: Vec = .init(.{ 11.0, 19.0, 29.0 });

    try std.testing.expect(result.equal(expected));
}

test "lerp" {
    const Vec = Vector(f32, 3);
    const a: Vec = .init(.{ 0.0, 0.0, 0.0 });
    const b: Vec = .init(.{ 10.0, 20.0, 30.0 });

    const result = a.linearInterpolation(b, 0.5);
    const expected: Vec = .init(.{ 5.0, 10.0, 15.0 });

    try std.testing.expect(result.equal(expected));
}

test "matrix.zero" {
    const Mat = Matrix(f64, 3, 2);

    const m = Mat.zero;

    inline for (0..2) |i| {
        inline for (0..3) |j| {
            try std.testing.expectEqual(@as(f64, 0), m.get(i, j));
        }
    }
}

test "matrix.identity" {
    const Mat = Matrix(f64, 3, 3);

    const m = Mat.identity;

    inline for (0..3) |i| {
        inline for (0..3) |j| {
            if (i == j) {
                try std.testing.expectEqual(@as(f64, 1), m.get(i, j));
            } else {
                try std.testing.expectEqual(@as(f64, 0), m.get(i, j));
            }
        }
    }
}

test "matrix.fromScalar" {
    const Mat = Matrix(f64, 2, 2);

    const m = Mat.fromScalar(5);

    inline for (0..2) |i| {
        inline for (0..2) |j| {
            try std.testing.expectEqual(@as(f64, 5), m.get(i, j));
        }
    }
}

test "matrix.get_set" {
    const Mat = Matrix(f64, 2, 2);

    var m = Mat.zero;
    m.set(1, 0, 42);

    try std.testing.expectEqual(@as(f64, 42), m.get(1, 0));
}

test "matrix.row" {
    const Mat = Matrix(f64, 3, 2);

    const m = Mat.init(.{
        .{ .items = .{ 1, 2, 3 } },
        .{ .items = .{ 4, 5, 6 } },
    });

    const r = m.row(1);

    try std.testing.expectEqual(@as(f64, 4), r.items[0]);
    try std.testing.expectEqual(@as(f64, 5), r.items[1]);
    try std.testing.expectEqual(@as(f64, 6), r.items[2]);
}

test "matrix.col" {
    const Mat = Matrix(f64, 3, 2);

    const m = Mat.init(.{
        .{ .items = .{ 1, 2, 3 } },
        .{ .items = .{ 4, 5, 6 } },
    });

    const c = m.col(1);

    try std.testing.expectEqual(@as(f64, 2), c.items[0]);
    try std.testing.expectEqual(@as(f64, 5), c.items[1]);
}

test "matrix.multiplyVector" {
    const Mat = Matrix(f64, 3, 2);

    const m = Mat.init(.{
        .{ .items = .{ 1, 2, 3 } },
        .{ .items = .{ 4, 5, 6 } },
    });

    const v = Mat.RowVec.init(.{ 1, 1, 1 });

    const result = m.multiplyVector(v);

    try std.testing.expectEqual(@as(f64, 6), result.items[0]);
    try std.testing.expectEqual(@as(f64, 15), result.items[1]);
}

test "matrix.multiply" {
    const A = Matrix(f64, 3, 2);
    const B = Matrix(f64, 2, 3);

    const a = A.init(.{
        .{ .items = .{ 1, 2, 3 } },
        .{ .items = .{ 4, 5, 6 } },
    });

    const b = B.init(.{
        .{ .items = .{ 7, 8 } },
        .{ .items = .{ 9, 10 } },
        .{ .items = .{ 11, 12 } },
    });

    const c = A.multiply(2, a, b);

    try std.testing.expectEqual(@as(f64, 58), c.items[0].items[0]);
    try std.testing.expectEqual(@as(f64, 64), c.items[0].items[1]);

    try std.testing.expectEqual(@as(f64, 139), c.items[1].items[0]);
    try std.testing.expectEqual(@as(f64, 154), c.items[1].items[1]);
}

test "matrix.setRow_setCol" {
    const Mat = Matrix(f64, 2, 2);

    var m = Mat.zero;

    m.setRow(0, .{ .items = .{ 1, 2 } });
    m.setCol(1, .{ .items = .{ 3, 4 } });

    try std.testing.expectEqual(@as(f64, 1), m.get(0, 0));
    try std.testing.expectEqual(@as(f64, 3), m.get(0, 1));
    try std.testing.expectEqual(@as(f64, 0), m.get(1, 0));
    try std.testing.expectEqual(@as(f64, 4), m.get(1, 1));
}

test "matrix.transpose" {
    const Mat = Matrix(f64, 3, 2);

    const m = Mat.init(.{
        .{ .items = .{ 1, 2, 3 } },
        .{ .items = .{ 4, 5, 6 } },
    });

    const t = Mat.transpose(m);

    try std.testing.expectEqual(@as(f64, 1), t.items[0].items[0]);
    try std.testing.expectEqual(@as(f64, 4), t.items[0].items[1]);

    try std.testing.expectEqual(@as(f64, 2), t.items[1].items[0]);
    try std.testing.expectEqual(@as(f64, 5), t.items[1].items[1]);

    try std.testing.expectEqual(@as(f64, 3), t.items[2].items[0]);
    try std.testing.expectEqual(@as(f64, 6), t.items[2].items[1]);
}

test "matrix.trace basic" {
    const Mat = Matrix(f64, 3, 3);

    const m = Mat.init(.{
        .{ .items = .{ 1, 2, 3 } },
        .{ .items = .{ 4, 5, 6 } },
        .{ .items = .{ 7, 8, 9 } },
    });

    const t = Mat.trace(m);

    // trace = 1 + 5 + 9 = 15
    try std.testing.expectEqual(@as(f64, 15), t);
}

test "matrix.rowEchelon basic" {
    const Mat = Matrix(f64, 3, 3);

    const m = Mat.init(.{
        .{ .items = .{ 1, 2, 3 } },
        .{ .items = .{ 4, 5, 6 } },
        .{ .items = .{ 7, 8, 9 } },
    });

    const r = Mat.rowEchelonForm(m);

    try std.testing.expect(Mat.isRowEchelon(r));
}

test "matrix.rowEchelon already echelon" {
    const Mat = Matrix(f64, 3, 3);

    const m = Mat.init(.{
        .{ .items = .{ 1, 2, 3 } },
        .{ .items = .{ 0, 5, 6 } },
        .{ .items = .{ 0, 0, 9 } },
    });

    const r = Mat.rowEchelonForm(m);

    try std.testing.expect(Mat.isRowEchelon(r));
}

test "matrix.determinant basic" {
    const Mat = Matrix(f64, 3, 3);

    const m = Mat.init(.{
        .{ .items = .{ 1, 2, 3 } },
        .{ .items = .{ 4, 5, 6 } },
        .{ .items = .{ 7, 8, 9 } },
    });

    const d = Mat.determinant(m);

    try std.testing.expectEqual(@as(f64, 0), d);
}

test "matrix.rank full" {
    const Mat = Matrix(f64, 3, 3);

    const m = Mat.identity;

    try std.testing.expectEqual(@as(usize, 3), Mat.rank(m));
}

test "matrix.rank deficient" {
    const Mat = Matrix(f64, 3, 3);

    const m = Mat.init(.{
        .{ .items = .{ 1, 2, 3 } },
        .{ .items = .{ 2, 4, 6 } },
        .{ .items = .{ 7, 8, 9 } },
    });

    try std.testing.expectEqual(@as(usize, 2), Mat.rank(m));
}

test "matrix.rank zero" {
    const Mat = Matrix(f64, 4, 3);

    const m = Mat.zero;

    try std.testing.expectEqual(@as(usize, 0), Mat.rank(m));
}

test "matrix.inverse correctness" {
    const Mat = Matrix(f64, 3, 3);

    const m = Mat.init(.{
        .{ .items = .{ 1, 2, 3 } },
        .{ .items = .{ 0, 1, 4 } },
        .{ .items = .{ 5, 6, 0 } },
    });

    const inv = try Mat.inverse(m);
    const prod = Mat.multiply(3, m, inv);

    for (0..3) |i| {
        for (0..3) |j| {
            if (i == j) {
                try std.testing.expectApproxEqAbs(@as(f64, 1), prod.get(i, j), 1e-6);
            } else {
                try std.testing.expectApproxEqAbs(@as(f64, 0), prod.get(i, j), 1e-6);
            }
        }
    }
}

test "matrix.inverse 2x2" {
    const Mat = Matrix(f64, 2, 2);

    const m = Mat.init(.{
        .{ .items = .{ 2, 1 } },
        .{ .items = .{ 1, 1 } },
    });

    const inv = try Mat.inverse(m);

    try std.testing.expectApproxEqAbs(@as(f64, 1), inv.get(0, 0), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, -1), inv.get(0, 1), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, -1), inv.get(1, 0), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 2), inv.get(1, 1), 1e-6);
}

test "linear combination" {
    const Vec = Vector(f32, 3);

    const v0: Vec = .init(.{ 1, 0, 0 });
    const v1: Vec = .init(.{ 0, 1, 0 });
    const v2: Vec = .init(.{ 0, 0, 1 });

    const vectors = [_]Vec{ v0, v1, v2 };
    const scalars = [_]f32{ 2, 3, 4 };

    const result = Vec.linearCombination(&vectors, &scalars);
    const expected: Vec = .init(.{ 2, 3, 4 });

    try std.testing.expect(result.equal(expected));
}

test "dot - integers basic" {
    const Vec = Vector(i32, 3);

    const a: Vec = .init(.{ 1, 2, 3 });
    const b: Vec = .init(.{ 4, 5, 6 });

    try std.testing.expect(Vec.dotProduct(a, b) == 32);
}

test "manhattan norm - basic" {
    const Vec = Vector(i32, 3);

    const v: Vec = .init(.{ 1, -2, 3 });

    try std.testing.expect(Vec.manhattanNorm(v) == 6);
}

test "manhattan norm - zero" {
    const Vec = Vector(i32, 4);

    const v: Vec = Vec.zero;

    try std.testing.expect(Vec.manhattanNorm(v) == 0);
}

test "euclidean norm - basic" {
    const Vec = Vector(f32, 3);

    const v: Vec = .init(.{ 3.0, 4.0, 0.0 });

    try std.testing.expectApproxEqAbs(Vec.euclideanNorm(v), 5.0, 1e-6);
}

test "euclidean norm - unit vector" {
    const Vec = Vector(f32, 3);

    const v: Vec = .init(.{ 1.0, 0.0, 0.0 });

    try std.testing.expectApproxEqAbs(Vec.euclideanNorm(v), 1.0, 1e-6);
}

test "euclidean norm - zero" {
    const Vec = Vector(f32, 3);

    const v: Vec = Vec.zero;

    try std.testing.expectApproxEqAbs(Vec.euclideanNorm(v), 0.0, 1e-6);
}

test "max norm - basic" {
    const Vec = Vector(i32, 4);

    const v: Vec = .init(.{ 1, -7, 3, 2 });

    try std.testing.expect(Vec.maxNorm(v) == 7);
}

test "max norm - zero" {
    const Vec = Vector(i32, 3);

    const v: Vec = Vec.zero;

    try std.testing.expect(Vec.maxNorm(v) == 0);
}

test "cos - identical vectors" {
    const Vec = Vector(f32, 3);

    const a: Vec = .init(.{ 1.0, 2.0, 3.0 });

    const result = Vec.cos(a, a);

    // cos(0) = 1
    try std.testing.expectApproxEqAbs(result, 1.0, 1e-6);
}

test "cos - orthogonal vectors" {
    const Vec = Vector(f32, 3);

    const x: Vec = .init(.{ 1.0, 0.0, 0.0 });
    const y: Vec = .init(.{ 0.0, 1.0, 0.0 });

    const result = Vec.cos(x, y);

    // cos(90°) = 0
    try std.testing.expectApproxEqAbs(result, 0.0, 1e-6);
}

test "cos - opposite vectors" {
    const Vec = Vector(f32, 3);

    const a: Vec = .init(.{ 1.0, 2.0, 3.0 });
    const b: Vec = .init(.{ -1.0, -2.0, -3.0 });

    const result = Vec.cos(a, b);

    // cos(180°) = -1
    try std.testing.expectApproxEqAbs(result, -1.0, 1e-6);
}

test "cross - i x j = k" {
    const Vec = Vector(i32, 3);

    const i: Vec = .init(.{ 1, 0, 0 });
    const j: Vec = .init(.{ 0, 1, 0 });
    const k: Vec = .init(.{ 0, 0, 1 });

    try std.testing.expect(Vec.crossProduct(i, j).equal(k));
}

test "cross - j x k = i" {
    const Vec = Vector(i32, 3);

    const i: Vec = .init(.{ 1, 0, 0 });
    const j: Vec = .init(.{ 0, 1, 0 });
    const k: Vec = .init(.{ 0, 0, 1 });

    try std.testing.expect(Vec.crossProduct(j, k).equal(i));
}

test "cross - k x i = j" {
    const Vec = Vector(i32, 3);

    const i: Vec = .init(.{ 1, 0, 0 });
    const j: Vec = .init(.{ 0, 1, 0 });
    const k: Vec = .init(.{ 0, 0, 1 });

    try std.testing.expect(Vec.crossProduct(k, i).equal(j));
}

test "cross - anti commutative" {
    const Vec = Vector(i32, 3);

    const a: Vec = .init(.{ 1, 2, 3 });
    const b: Vec = .init(.{ 4, 5, 6 });

    const ab = Vec.crossProduct(a, b);
    const ba = Vec.crossProduct(b, a);

    try std.testing.expect(ab.equal(ba.negate()));
}

test "cross - known values" {
    const Vec = Vector(i32, 3);

    const a: Vec = .init(.{ 1, 2, 3 });
    const b: Vec = .init(.{ 4, 5, 6 });

    const expected: Vec = .init(.{ -3, 6, -3 });

    try std.testing.expect(Vec.crossProduct(a, b).equal(expected));
}

test "cross - orthogonal to inputs" {
    const Vec = Vector(f32, 3);

    const a: Vec = .init(.{ 1.0, 2.0, 3.0 });
    const b: Vec = .init(.{ 4.0, 5.0, 6.0 });

    const c = Vec.crossProduct(a, b);

    try std.testing.expectApproxEqAbs(Vec.dotProduct(c, a), 0.0, 1e-6);
    try std.testing.expectApproxEqAbs(Vec.dotProduct(c, b), 0.0, 1e-6);
}
