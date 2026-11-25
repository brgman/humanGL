const body = @import("body.zig");

pub const Mode = enum { stay, walk, jump };

/// Pose du corps au temps t (secondes) pour le mode choisi.
pub fn pose(mode: Mode, t: f32, d: body.Dims) body.Pose {
    var p = body.Pose{};
    var lift: f32 = 0; // decalage vertical du bassin

    switch (mode) {
        .stay => {},
        .walk => {
            const ph = t * 5.0;
            const swing_l = 20.0 * @sin(ph); // > 0 : jambe gauche vers l'arriere
            const swing_r = -swing_l;
            p.hip = .{ swing_l, swing_r };
            // le genou plie quand la jambe revient vers l'avant
            p.knee = .{ 45.0 * @max(0.0, -@cos(ph)), 45.0 * @max(0.0, @cos(ph)) };
            // les bras balancent a l'oppose de la jambe du meme cote
            p.shoulder = .{ swing_r * 0.9, swing_l * 0.9 };
            p.elbow = .{ -25, -25 };
            p.torso_tilt = -4;
            lift = 0.05 * @abs(@sin(ph)); // leger balancement du bassin
        },
        .jump => {
            const ph = t * 4.0;
            const h = @abs(@sin(ph)); // 0 au sol, 1 au sommet
            const crouch = 1.0 - h;
            p.hip = .{ -40.0 * crouch, -40.0 * crouch };
            p.knee = .{ 80.0 * crouch, 80.0 * crouch };
            p.shoulder = .{ -110.0 * h, -110.0 * h };
            p.elbow = .{ -15, -15 };
            p.torso_tilt = -8.0 * crouch;
            // accroupi : le bassin descend, en l'air : il monte
            lift = 0.9 * h - 0.47 * crouch;
        },
    }

    p.root_y = d.thigh + d.shin + lift;
    return p;
}