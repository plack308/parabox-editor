pub const MAX_PALETTE = 10;

pub const palette_data: [11][6][3]f32 = .{
    // palette 0
    .{
        .{ 0, 0, 0.8 }, // root
        .{ 0.6, 0.8, 1 }, // blue
        .{ 0.4, 0.8, 1 }, // green
        .{ 0.1, 0.8, 1 }, // orange
        .{ 0.9, 1, 0.7 }, // player
        .{ 0.55, 0.8, 1 }, // teal
    },
    // palette 1
    .{
        .{ 0.05, 0.6, 1.1 }, // root
        .{ 0.63, 0.6, 1 }, // blue
        .{ 0.32, 0.55, 1 }, // green
        .{ 0.12, 0.6, 1 }, // orange
        .{ 0.85, 0.53, 0.8 }, // player
        .{ 0.55, 0.8, 1 }, // teal
    },
    // palette 2
    .{
        .{ 0.6, 0.3, 0.8 }, // root
        .{ 0.07, 0.7, 0.9 }, // blue
        .{ 0.42, 0.8, 0.85 }, // green
        .{ 0.55, 0.8, 0.85 }, // orange
        .{ 0.93, 0.7, 0.75 }, // player
        .{ 0.55, 0.8, 1 }, // teal
    },
    // palette 3
    .{
        .{ 0.68, 0.2, 0.6 }, // root
        .{ 0.25, 0.7, 0.6 }, // blue
        .{ 0.13, 0.7, 0.8 }, // green
        .{ 0.03, 0.7, 0.8 }, // orange
        .{ 0.73, 0.7, 0.82 }, // player
        .{ 0.55, 0.8, 1 }, // teal
    },
    // palette 4
    .{
        .{ 0, 0.08, 0.7 }, // root
        .{ 0.6, 0.55, 0.8 }, // blue
        .{ 0.08, 0.75, 0.95 }, // green
        .{ 0.21, 0.7, 0.8 }, // orange
        .{ 0.04, 0.8, 0.85 }, // player
        .{ 0.55, 0.8, 1 }, // teal
    },
    // palette 5
    .{
        .{ 0, 0, 0.5 }, // root
        .{ 0, 0, 0.25 }, // blue
        .{ 0, 0, 0.85 }, // green
        .{ 0, 0, 0.5 }, // orange
        .{ 0, 0, 0.5 }, // player
        .{ 0, 0, 0.5 }, // teal
    },
    // palette 6
    .{
        .{ 0.6, 0.6, 0.8 }, // root
        .{ 0.55, 0.75, 0.7 }, // blue
        .{ 0.45, 0.75, 0.75 }, // green
        .{ 0.13, 0.75, 0.85 }, // orange
        .{ 0, 0.7, 0.7 }, // player
        .{ 0.55, 0.8, 1 }, // teal
    },
    // palette 7
    .{
        .{ 0.6, 0.3, 0.75 }, // root
        .{ 0.25, 0.83, 0.82 }, // blue
        .{ 0.16, 1, 0.75 }, // green
        .{ 0.6, 0.7, 0.9 }, // orange
        .{ 0.96, 0.8, 0.7 }, // player
        .{ 0.46, 0.7, 0.8 }, // teal
    },
    // palette 8
    .{
        .{ 0.64, 0.6, 0.85 }, // root
        .{ 0.68, 0.55, 0.9 }, // blue
        .{ 0.95, 0.6, 0.7 }, // green
        .{ 0.45, 0.55, 0.8 }, // orange
        .{ 0.85, 0.6, 0.75 }, // player
        .{ 0.58, 0.7, 0.8 }, // teal
    },
    // palette 9
    .{
        .{ 0.13, 0.15, 0.7 }, // root
        .{ 0.92, 1, 0.7 }, // blue
        .{ 0.22, 0.9, 0.8 }, // green
        .{ 0.5, 0.7, 0.8 }, // orange
        .{ 0.8, 0.5, 0.85 }, // player
        .{ 0.09, 0.9, 0.9 }, // teal
    },
    // palette 10
    .{
        .{ 0.23, 0.6, 0.4 }, // root
        .{ 0.33, 0.6, 0.6 }, // blue
        .{ 0.15, 0.8, 0.8 }, // green
        .{ 0.1, 0.8, 0.8 }, // orange
        .{ 0.62, 0.7, 0.8 }, // player
        .{ 0.46, 0.7, 0.8 }, // teal
    },
};

pub fn paletteConversion(palette_idx: i32, hue: f32, sat: f32, val: f32) [3]f32 {
    if (palette_idx < 0) {
        return .{ hue, sat, val }; // no palette
    }

    const palette = palette_data[@intCast(palette_idx)];

    if (sat == 0) {
        return palette[0]; // color A (root)
    } else if (hue == 0.6) {
        return palette[1]; // color B (blue)
    } else if (hue == 0.4) {
        return palette[2]; // color C (green)
    } else if (hue == 0.1) {
        return palette[3]; // color D (orange)
    } else if (hue == 0.9) {
        return palette[4]; // color E (player)
    } else if (hue == 0.55) {
        return palette[5]; // color F (teal)
    } else {
        return .{ hue, sat, val }; // not a special color
    }
}
