
// LEGS

pub const thigh_len: f32 = 1.0;
pub const shin_len: f32 = 1.0;
pub const thigh_w: f32 = 0.2;
pub const shin_w: f32 = 0.2;
pub const joint_size: f32 = 0.201;

// CORP

pub const torso_w: f32 = 0.7;
pub const torso_h: f32 = thigh_len * 1.5;
pub const torso_d: f32 = thigh_w;
pub const pelvis_y: f32 = 0.19;

pub const joint_names = [7][]const u8{
    "hanche G", "genou G", "cheville G",
    "hanche D", "genou D", "cheville D",
    "bassin"
 };

pub const camera_dist: f32 = 6.5;
pub const auto_speed: f32 = 30.0; // degrees per second