const math = @import("maths.zig");

const constants = @import("constants.zig");
const torso_h = constants.torso_h;
const torso_w = constants.torso_w;
const torso_d = constants.torso_d;
const joint_size = constants.joint_size;

const main = @import("main.zig");
const Renderer = main.Renderer;
const Mat4 = math.Mat4;

pub fn drawTorso(r: Renderer, stack: *math.MatrixStack, pos: [3]f32, angle: f32, selected: bool) void {
    stack.push();
    stack.mul(Mat4.translate(pos[0], pos[1], pos[2]));
    stack.mul(Mat4.rotateX(math.radians(angle)));

    r.drawBox(stack.top(), .{ 0, torso_h / 2, 0 }, .{ torso_w, torso_h, torso_d }, .{ 0.3, 0.7, 0.4 });

    const col: [3]f32 = if (selected) .{ 1.0, 0.9, 0.2 } else .{ 0.85, 0.85, 0.9 };
    r.drawBox(stack.top(), .{ 0, 0, 0 }, .{ torso_w, joint_size, joint_size }, col);
    stack.pop();
}
