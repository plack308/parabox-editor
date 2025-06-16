const std = @import("std");
const rl = @import("raylib");

const lv = @import("level.zig");
const utils = @import("utils.zig");

const RECURSION_DEPTH = 4;

const Textures = struct {
    eyes: rl.Texture2D,
    possess_eyes: rl.Texture2D,
};

var textures: ?Textures = null;

pub fn loadTextures() !void {
    const eyes = try rl.loadTexture("graphics/eyes.png");
    const possess_eyes = try rl.loadTexture("graphics/possess_eyes.png");
    textures = .{ .eyes = eyes, .possess_eyes = possess_eyes };
}

pub fn unloadTextures() void {
    if (textures) |tex| {
        // call unloadTexture on all fields
        inline for (std.meta.fields(Textures)) |field| {
            rl.unloadTexture(@field(tex, field.name));
        }
    }
    textures = null;
}

fn drawEyes(rect: rl.Rectangle, color: rl.Color) void {
    const tex = textures.?.eyes;
    const src_rect: rl.Rectangle = .{ .x = 0, .y = 0, .width = @floatFromInt(tex.width), .height = @floatFromInt(tex.height) };
    rl.drawTexturePro(tex, src_rect, rect, rl.math.vector2Zero(), 0, color);
}

fn drawPossessEyes(rect: rl.Rectangle, color: rl.Color) void {
    const tex = textures.?.possess_eyes;
    const src_rect: rl.Rectangle = .{ .x = 0, .y = 0, .width = @floatFromInt(tex.width), .height = @floatFromInt(tex.height) };
    rl.drawTexturePro(tex, src_rect, rect, rl.math.vector2Zero(), 0, color);
}

fn getGoalRect(rect: rl.Rectangle) rl.Rectangle {
    return .{
        .x = rect.x + 0.1 * rect.width,
        .y = rect.y + 0.1 * rect.height,
        .width = 0.8 * rect.width,
        .height = 0.8 * rect.height,
    };
}

fn drawFlipEffect(obj_rect: rl.Rectangle, right_to_left: bool) void {
    const SPEED = 0.75;

    const time: f32 = @floatCast(rl.getTime());

    var progress_front = rl.math.wrap(time * SPEED, -0.5, 1.5);
    var progress_back = progress_front - 0.2;

    progress_front = utils.cubicEasing(progress_front);
    progress_back = utils.cubicEasing(progress_back);

    if (right_to_left) {
        progress_front = 1 - progress_front;
        progress_back = 1 - progress_back;
    }

    const front_x = obj_rect.x + progress_front * obj_rect.width;
    const back_x = obj_rect.x + progress_back * obj_rect.width;

    const rect: rl.Rectangle = .{
        .x = @min(front_x, back_x),
        .y = obj_rect.y,
        .width = @abs(front_x - back_x),
        .height = obj_rect.height,
    };

    rl.drawRectangleRec(rect, rl.colorAlpha(.white, 0.5));
}

fn drawRoom(level: *const lv.Level, id: i32, rect: rl.Rectangle, recursion_level: u8, selection_effect: bool, clone: bool, flip: bool) void {
    if (recursion_level == 0) return;

    const maybe_room = level.rooms.getPtr(id);
    if (maybe_room) |room| {
        // this room exists, draw background and objects

        var room_color = utils.getColor(level.palette, room.hue, room.sat, room.val);
        var bg_color = rl.colorBrightness(room_color, -0.7);
        if (clone) {
            room_color = rl.colorBrightness(room_color, 0.7);
            bg_color = rl.colorBrightness(bg_color, 0.3);
        }

        rl.drawRectangleRec(rect, bg_color); // bg

        const tw: f32 = rect.width / @as(f32, @floatFromInt(room.width));
        const th: f32 = rect.height / @as(f32, @floatFromInt(room.height));

        // non-floor objects
        for (room.objects.items) |obj| {
            // ignore out of bounds objects
            if (!room.isPosInBounds(obj.x, obj.y)) {
                continue;
            }

            const draw_obj_x = if (flip) room.width - 1 - obj.x else obj.x;

            const objx: f32 = @floatFromInt(draw_obj_x);
            const objy: f32 = @floatFromInt(obj.y);
            const obj_rect: rl.Rectangle = .{
                .x = rect.x + objx * tw,
                .y = rect.y + rect.height - objy * th - th,
                .width = tw,
                .height = th,
            };

            // draw base
            switch (obj.type) {
                .wall => {
                    rl.drawRectangleRec(obj_rect, room_color);
                },
                .box => {
                    const obj_color = utils.getColor(level.palette, obj.hue, obj.sat, obj.val);
                    rl.drawRectangleRec(obj_rect, obj_color);
                    // black border
                    rl.drawRectangleLinesEx(obj_rect, 2, rl.colorAlpha(.black, 0.8));
                },
                .ref => {
                    const flip_inside = flip != obj.flip; // effectively a XOR, two flips cancel out
                    // recursion!
                    drawRoom(level, obj.room_id, obj_rect, recursion_level - 1, false, !obj.exitblock, flip_inside);
                    // black border
                    rl.drawRectangleLinesEx(obj_rect, 2, rl.colorAlpha(.black, 0.8));
                    // flip effect
                    if (obj.flip) {
                        drawFlipEffect(obj_rect, flip_inside);
                    }
                },
                .floor => {
                    continue; // skip eyes and selection effect
                },
            }

            // draw eyes
            if (obj.is_player) {
                drawEyes(obj_rect, rl.colorAlpha(.black, 0.6));
            } else if (obj.possessable) { // possessable and not player
                drawPossessEyes(obj_rect, rl.colorAlpha(.black, 0.6));
            }

            // draw selection effect
            if (obj.selected and selection_effect) {
                rl.drawRectangleLinesEx(obj_rect, 5, .green);
            }
        }

        // floor objects (draw above other objects)
        for (room.objects.items) |obj| {
            // ignore out of bounds objects
            if (!room.isPosInBounds(obj.x, obj.y)) {
                continue;
            }

            const draw_obj_x = if (flip) room.width - 1 - obj.x else obj.x;

            const objx: f32 = @floatFromInt(draw_obj_x);
            const objy: f32 = @floatFromInt(obj.y);
            const obj_rect: rl.Rectangle = .{
                .x = rect.x + objx * tw,
                .y = rect.y + rect.height - objy * th - th,
                .width = tw,
                .height = th,
            };
            const goal_rect = getGoalRect(obj_rect);

            const color: rl.Color = if (obj.selected and selection_effect) .green else .gray;

            switch (obj.type) {
                .wall, .box, .ref => {},
                .floor => {
                    rl.drawRectangleLinesEx(goal_rect, 2, color);
                    if (obj.player_goal) {
                        drawEyes(goal_rect, color);
                    }
                },
            }
        }
    } else {
        // this room doesn't exist, draw red rectangle
        rl.drawRectangleRec(rect, .red);
    }
}

pub fn drawMain(level: *const lv.Level, focused_id: i32, draw_sel_box: bool, sel_rect: rl.Rectangle) void {
    drawRoom(level, focused_id, utils.getRoomRect(), RECURSION_DEPTH, true, false, false);

    // selection box
    if (draw_sel_box) {
        rl.drawRectangleLinesEx(sel_rect, 1, .green);
    }
}
