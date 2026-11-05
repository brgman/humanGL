const std = @import("std");

/// Degrés -> radians : rad = deg * pi / 180
pub fn radians(deg: f32) f32 {
    return deg * std.math.pi / 180.0;
}

/// Matrice 4x4 sockée en "colomn-major" (comme OpenGL):
///     l'élément (ligne r, colonne c) se trouve à l'indice m[c * 4 + r]
///     ´extern struct´ garantit la même disposition mémoire qu'en C :
///     on peut donc passer '&mat.m' directement à glUniformMatrix4fv
pub const Mat4 = extern struct {
    m: [16]f32,

    pub fn identity() Mat4 {
        return .{ .m = .{
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        } };
    }

    /// Translation: (tx, ty, tz) vont dans la 4e colonne (indices 12, 13, 14)
    pub fn translate(x: f32, y: f32, z: f32) Mat4 {
        var r = identity();
        r.m[12] = x;
        r.m[13] = y;
        r.m[14] = z;
        return r;
    }

    /// Mise à l'échelle: (sx, sy, sz) sur la diagonale
    pub fn scale(x: f32, y: f32, z: f32) Mat4 {
        var r = identity();
        r.m[0] = x;
        r.m[5] = y;
        r.m[10] = z;
        return r;
    }

    /// Rotation autour de X (angle en radians)
    /// y' = cos*y - sin*z
    /// z' = sin*y + cos*z
    pub fn rotateX(a: f32) Mat4 {
        const c = @cos(a);
        const s = @sin(a);
        var r = identity();
        r.m[5] = c;
        r.m[6] = s;
        r.m[9] = -s;
        r.m[10] = c;
        return r;
    }

    /// Rotation autour de Y
    ///     x' = cos*x + sin*z
    ///     z' = -sin*x + cos*z
    pub fn rotateY(a: f32) Mat4 {
        const c = @cos(a);
        const s = @sin(a);
        var r = identity();
        r.m[0] = c;
        r.m[2] = -s;
        r.m[8] = s;
        r.m[10] = c;
        return r;
    }

    /// Rotation autour de Z
    /// x' = cos*x = sin*y
    /// y' = sin*x + cos*y
    pub fn rotateZ(a: f32) Mat4 {
        const c = @cos(a);
        const s = @sin(a);
        var r = identity();
        r.m[0] = c;
        r.m[1] = s;
        r.m[4] = -s;
        r.m[5] = c;
        return r;
    }

    /// Projection en perspective (convention OpenGL : la caméra regarde vers -Z, profondeur normalisée de -1 à +1)
    /// fovy en fadians. Aprés cette matrice, w' = -z : le GPU divise x, y, z par w'
    pub fn perspective(fovy: f32, aspect:f32, near: f32, far: f32) Mat4 {
        const f = 1.0 / @tan(fovy / 2.0);
        var r = std.mem.zeroes(Mat4);
        r.m[0] = f / aspect;
        r.m[5] = f;
        r.m[10] = (far + near) / (near - far);
        r.m[11] = -1.0;
        r.m[14] = (2.0 * far * near) / (near - far);
        return r;
    }

    /// Produit matriciel a * b
    /// Appliqué à un vecteur v : (a * b) * v = a * (b * v),
    /// donc b est appliquée EN PREMIER.
    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var r: Mat4 = undefined;
        for (0..4) |col| {
            for (0..4) |row| {
                var sum: f32 = 0;
                for (0..4) |k| {
                    sum += a.m[k * 4 + row] * b.m[col * 4 + k];
                }
                r.m[col * 4 + row] = sum;
            }
        }
        return r;
    }

    /// Matrice * vecteur colonne (x, y, z, w).
    pub fn mulVec4(a: Mat4, v: [4]f32) [4]f32 {
        var r = [4]f32{ 0, 0, 0, 0 };
        for (0..4) |row| {
            for (0..4) |col| {
                r[row] += a.m[col * 4 + row] * v[col];
            }
        }
        return r;
    }
};

/// Pile de matrices (remplace glPushMatrix / glPopMatrix, interdits ici).
/// `push` duplique le sommet, `pop` le retire, `mul` multiplie le sommet.
pub const MatrixStack = struct {
    items: [32]Mat4 = undefined,
    len: usize = 1,

    pub fn init() MatrixStack {
        var s = MatrixStack{};
        s.items[0] = Mat4.identity();
        return s;
    }

    pub fn top(self: *const MatrixStack) Mat4 {
        return self.items[self.len - 1];
    }

    pub fn push(self: *MatrixStack) void {
        std.debug.assert(self.len < self.items.len);
        self.items[self.len] = self.items[self.len - 1];
        self.len += 1;
    }

    pub fn pop(self: *MatrixStack) void {
        std.debug.assert(self.len > 1);
        self.len -= 1;
    }

    /// top = top * m  (m s'applique dans le repère local courant)
    pub fn mul(self: *MatrixStack, m: Mat4) void {
        const t = &self.items[self.len - 1];
        t.* = t.mul(m);
    }
};
