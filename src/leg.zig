const math = @import("maths.zig");

const constants = @import("constants.zig");
const thigh_len = constants.thigh_len;
const thigh_w = constants.thigh_w;
const shin_w = constants.shin_w;
const joint_size = constants.joint_size;
const shin_len = constants.shin_len;

const main = @import("main.zig");
const Renderer = main.Renderer;
const Mat4 = math.Mat4;


fn jointColor(i: usize, selected: ?usize) [3]f32 {
    const is_selected = if (selected) |s| s == i else false;
    return if (is_selected) .{ 1.0, 0.9, 0.2 } else .{ 0.85, 0.85, 0.9 };
}

/// Hiérarchie : hanche -> cuisse -> genou -> tibia -> cheville -> Pied ^_^
/// Chaque niveau fait push (copie du parent), applique SA tranformation locale,
/// dessine, descend vers l'enfant, puis pop.
pub fn drawLeg(r: Renderer, stack: *math.MatrixStack, hip_pos: [3]f32, angles: [3]f32, selected: ?usize) void {
    // --- hanche : origine = sommet de la cuisse
    stack.push();
    stack.mul(Mat4.translate(hip_pos[0], hip_pos[1], hip_pos[2]));
    stack.mul(Mat4.rotateX(math.radians(angles[0])));
    r.drawBox(stack.top(), .{ 0, -thigh_len / 2, 0 }, .{ thigh_w, thigh_len, thigh_w }, .{ 0.95, 0.55, 0.15 });
    r.drawBox(stack.top(), .{ 0, 0, 0 }, .{ joint_size, joint_size, joint_size }, jointColor(0, selected));

    // == genou: au bout de la cuisse, dans le repère de la hanche
    stack.push();
    stack.mul(Mat4.translate(0, -thigh_len, 0));
    stack.mul(Mat4.rotateX(math.radians(angles[1])));
    r.drawBox(stack.top(), .{ 0, -shin_len / 2, 0 }, .{ shin_w, shin_len, shin_w }, .{ 0.2, 0.45, 0.85 });
    r.drawBox(stack.top(), .{ 0, 0, 0 }, .{ joint_size, joint_size, joint_size }, jointColor(1, selected));

    // == cheville : au bout du tibia, dans le repère du genou
    stack.push();
    stack.mul(Mat4.translate(0, -shin_len, 0));
    stack.mul(Mat4.rotateX(math.radians(angles[2])));
    r.drawBox(stack.top(), .{ 0, -0.06, 0.12 }, .{ thigh_w, 0.12, 0.55 }, .{ 0.5, 0.52, 0.58 });
    r.drawBox(stack.top(), .{ 0, 0, 0 }, .{ joint_size, joint_size, joint_size }, jointColor(2, selected));
    stack.pop(); // fin cheville

    stack.pop(); // fin genou
    stack.pop(); // fin hanche
}