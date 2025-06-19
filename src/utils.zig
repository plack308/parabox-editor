const std = @import("std");
const rl = @import("raylib");

const pal = @import("palettes.zig");

const GUI_WIDTH = 410;

pub const MAX_MUSIC = 21;

pub fn getMusicText(music_idx: i32) [:0]const u8 {
    return switch (music_idx) {
        -1 => "No music",
        0 => "Intro",
        1 => "Enter",
        2 => "Empty",
        3 => "Eat",
        4 => "Reference",
        5 => "Center",
        6 => "Clone",
        7 => "Transfer",
        8 => "Open",
        9 => "Flip",
        10 => "Cycle",
        11 => "Swap",
        12 => "Player",
        13 => "Possess",
        14 => "Wall",
        15 => "Infinite Exit",
        16 => "Infinite Enter",
        17 => "Multi Infinite",
        18 => "Reception",
        19 => "Appendix",
        20 => "Pause",
        21 => "Credits",
        else => "",
    };
}

pub fn getWindowSize() rl.Vector2 {
    return .{ .x = @floatFromInt(rl.getScreenWidth()), .y = @floatFromInt(rl.getScreenHeight()) };
}

pub fn guiFirstColumnX() f32 {
    return getWindowSize().x - GUI_WIDTH + 10;
}

pub fn guiSecondColumnX() f32 {
    return getWindowSize().x - GUI_WIDTH + 220;
}

pub fn getRoomRect() rl.Rectangle {
    var sz: f32 = @floatFromInt(@min(rl.getScreenWidth() - GUI_WIDTH, rl.getScreenHeight()));
    sz = @max(sz, 100);
    return .{
        .x = 0,
        .y = 0,
        .width = sz,
        .height = sz,
    };
}

pub fn getTileWidth(room_width: i32) f32 {
    return getRoomRect().width / @as(f32, @floatFromInt(room_width));
}

pub fn getTileHeight(room_height: i32) f32 {
    return getRoomRect().height / @as(f32, @floatFromInt(room_height));
}

// convert screen position to room tile coordinates
pub fn posToTileX(x: f32, room_width: i32) !i32 {
    return @intFromFloat(try std.math.divFloor(f32, x - getRoomRect().x, getTileWidth(room_width)));
}

pub fn posToTileY(y: f32, room_height: i32) !i32 {
    // flipped
    const room_rect = getRoomRect();
    return @intFromFloat(try std.math.divFloor(f32, room_rect.y + room_rect.height - y, getTileHeight(room_height)));
}

// convert game HSV values to raylib Color (applies palette)
pub fn getColor(palette_idx: i32, hue: f32, sat: f32, val: f32) rl.Color {
    const hsv = pal.paletteConversion(palette_idx, hue, sat, val);
    return rl.colorFromHSV(hsv[0] * 360, hsv[1], hsv[2]);
}

pub fn isRectClicked(rect: rl.Rectangle) bool {
    return rl.isMouseButtonPressed(.left) and rl.checkCollisionPointRec(rl.getMousePosition(), rect);
}

// custom gui element
pub fn colorButton(rect: rl.Rectangle, color: rl.Color) bool {
    rl.drawRectangleRec(rect, color);

    return isRectClicked(rect);
}

pub fn cubicEasing(x: f32) f32 {
    const c = rl.math.clamp(x, 0, 1);
    return c * c * (3 - 2 * c);
}
