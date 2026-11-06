const math = @import("maths.zig");
const constants = @import("constants.zig");
const Renderer = @import("main.zig").Renderer;

const Mat4 = math.Mat4;

/// Longueurs modifiables : tout le reste se replace automatiquement
/// parce que chaque articulation est placee a "longueur du parent".
pub const Dims = struct {
    thigh: f32 = 1.0,
    shin: f32 = 1.0,
    upper_arm: f32 = 0.8,
    forearm: f32 = 0.7,
    torso_h: f32 = 1.5,
};

/// Angles en degres. Les tableaux sont [gauche, droite].
/// Rotation autour de X, membre qui pend vers -Y, avant du corps vers +Z :
///   angle negatif -> le membre part vers l'avant, angle positif -> vers l'arriere.
pub const Pose = struct {
    root_y: f32 = 0, // hauteur du bassin (saut)
    torso_tilt: f32 = 0,
    head_yaw: f32 = 0,
    shoulder: [2]f32 = .{ 0, 0 },
    elbow: [2]f32 = .{ 0, 0 },
    hip: [2]f32 = .{ 0, 0 },
    knee: [2]f32 = .{ 0, 0 },
};

/// UNE partie du corps = UN appel de dessin d'un cube 1x1x1.
/// 'offset' decale la boite dans le repere courant, 'size' l'etire.
/// Le push/pop garde le decalage et l'echelle pour cette boite seulement.
fn part(r: Renderer, stack: *math.MatrixStack, offset: [3]f32, size: [3]f32, color: [3]f32) void {
    stack.push();
    stack.mul(Mat4.translate(offset[0], offset[1], offset[2]));
    stack.mul(Mat4.scale(size[0], size[1], size[2]));
    r.drawUnitCube(stack.top(), color);
    stack.pop();
}

/// Hierarchie
///   bassin (position + inclinaison du torse)
///   |- torse
///   |- tete
///   |- bras G/D : epaule -> bras -> coude -> avant-bras
///   |- jambe G/D : hanche -> cuisse -> genou -> tibia
/// Chaque niveau : push, ses transformations locales, dessin, enfants, pop.
pub fn drawBody(r: Renderer, stack: *math.MatrixStack, d: Dims, p: Pose) void {
    stack.push();
    stack.mul(Mat4.translate(0, p.root_y, 0));
    stack.mul(Mat4.rotateX(math.radians(p.torso_tilt)));

    // torse : l'origine est au bassin, la boite monte vers le haut
    part(r, stack, .{ 0, d.torso_h / 2, 0 }, .{ constants.torso_w, d.torso_h, constants.torso_d }, constants.color_torso);

    // tete : au sommet du torse
    stack.push();
    stack.mul(Mat4.translate(0, d.torso_h, 0));
    stack.mul(Mat4.rotateY(math.radians(p.head_yaw)));
    part(r, stack, .{ 0, constants.head_size / 2, 0 }, .{ constants.head_size, constants.head_size, constants.head_size }, constants.color_head);
    stack.pop();

    for (0..2) |i| {
        const side: f32 = if (i == 0) -1.0 else 1.0;

        // bras : epaule sur le cote du torse, en haut
        stack.push();
        stack.mul(Mat4.translate(side * (constants.torso_w / 2 + constants.arm_w / 2), d.torso_h - constants.arm_w / 2, 0));
        stack.mul(Mat4.rotateX(math.radians(p.shoulder[i])));
        part(r, stack, .{ 0, -d.upper_arm / 2, 0 }, .{ constants.arm_w, d.upper_arm, constants.arm_w }, constants.color_arm);

        // avant-bras : coude au bout du bras
        stack.push();
        stack.mul(Mat4.translate(0, -d.upper_arm, 0));
        stack.mul(Mat4.rotateX(math.radians(p.elbow[i])));
        part(r, stack, .{ 0, -d.forearm / 2, 0 }, .{ constants.arm_w, d.forearm, constants.arm_w }, constants.color_arm);
        stack.pop(); // fin coude
        stack.pop(); // fin epaule

        // jambe : hanche en bas du torse
        stack.push();
        stack.mul(Mat4.translate(side * (constants.torso_w - constants.leg_w) / 2, 0, 0));
        stack.mul(Mat4.rotateX(math.radians(p.hip[i])));
        part(r, stack, .{ 0, -d.thigh / 2, 0 }, .{ constants.leg_w, d.thigh, constants.leg_w }, constants.color_leg);

        // tibia : genou au bout de la cuisse
        stack.push();
        stack.mul(Mat4.translate(0, -d.thigh, 0));
        stack.mul(Mat4.rotateX(math.radians(p.knee[i])));
        part(r, stack, .{ 0, -d.shin / 2, 0 }, .{ constants.leg_w, d.shin, constants.leg_w }, constants.color_leg);
        stack.pop(); // fin genou
        stack.pop(); // fin hanche
    }

    stack.pop(); // fin bassin
}