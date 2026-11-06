// Tailles fixes
pub const torso_w: f32 = 0.7;
pub const torso_d: f32 = 0.35;
pub const head_size: f32 = 0.5;
pub const arm_w: f32 = 0.2;
pub const leg_w: f32 = 0.25;

// Couleurs
pub const color_torso = [3]f32{ 0.30, 0.70, 0.40 };
pub const color_head = [3]f32{ 0.95, 0.80, 0.65 };
pub const color_arm = [3]f32{ 0.95, 0.55, 0.15 };
pub const color_leg = [3]f32{ 0.20, 0.45, 0.85 };

// Camera
pub const camera_dist: f32 = 6.5;
pub const view_center_y: f32 = 2.0; // la camera orbite autour du milieu du corps
pub const auto_speed: f32 = 30.0; // degres par seconde