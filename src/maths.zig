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

    /// Translation: (tx, ty, tz) vont la 4e colonne (indices 12, 13, 14)
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
}