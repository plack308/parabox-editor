const std = @import("std");
const rl = @import("raylib");

const lv = @import("level.zig");
const utils = @import("utils.zig");

const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;

const RECURSION_DEPTH = 10;

const CLOSED_BORDER_COLOR: rl.Color = .{ .r = 254, .g = 228, .b = 0, .a = 255 };
const FLOATINSPACE_COLOR: rl.Color = .{ .r = 217, .g = 121, .b = 255, .a = 255 };

const RoomBrightness = enum {
    normal,
    clone,
    infinity,
};

const Textures = struct {
    eyes: rl.Texture2D,
    possess_eyes: rl.Texture2D,
    infinity: rl.Texture2D,
    button: rl.Texture2D,
    player_button: rl.Texture2D,
    fast_travel: rl.Texture2D,
    info: rl.Texture2D,
    break_: rl.Texture2D,
    gallery: rl.Texture2D,
    smile: rl.Texture2D,
};

var textures: ?Textures = null;

pub fn loadTextures() !void {
    const eyes = try rl.loadTexture("graphics/eyes.png");
    const possess_eyes = try rl.loadTexture("graphics/possess_eyes.png");
    const infinity = try rl.loadTexture("graphics/infinity.png");
    const button = try rl.loadTexture("graphics/Button.png");
    const player_button = try rl.loadTexture("graphics/PlayerButton.png");
    const fast_travel = try rl.loadTexture("graphics/FastTravel.png");
    const info = try rl.loadTexture("graphics/Info.png");
    const break_ = try rl.loadTexture("graphics/Break.png");
    const gallery = try rl.loadTexture("graphics/Gallery.png");
    const smile = try rl.loadTexture("graphics/Smile.png");
    textures = .{ .eyes = eyes, .possess_eyes = possess_eyes, .infinity = infinity, .button = button, .player_button = player_button, .fast_travel = fast_travel, .info = info, .break_ = break_, .gallery = gallery, .smile = smile };
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

fn drawTextureToRect(tex: rl.Texture2D, rect: rl.Rectangle, color: rl.Color) void {
    const src_rect: rl.Rectangle = .{ .x = 0, .y = 0, .width = @floatFromInt(tex.width), .height = @floatFromInt(tex.height) };
    rl.drawTexturePro(tex, src_rect, rect, rl.math.vector2Zero(), 0, color);
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

fn drawRoom(level: *const lv.Level, id: i32, rect: rl.Rectangle, recursion_level: u8, selection_effect: bool, brightness: RoomBrightness, flip: bool) void {
    if (recursion_level == 0) return;

    if (rect.width < 7 or rect.height < 7) return;

    const maybe_room = level.rooms.getPtr(id);
    if (maybe_room) |room| {
        // this room exists, draw background and objects

        var room_color = utils.getColor(level.palette, room.hue, room.sat, room.val);
        var bg_color = rl.colorBrightness(room_color, -0.7);
        switch (brightness) {
            .normal => {},
            .clone => {
                room_color = rl.colorBrightness(room_color, 0.7);
                bg_color = rl.colorBrightness(bg_color, 0.3);
            },
            .infinity => {
                room_color = rl.colorBrightness(room_color, -0.4);
                bg_color = rl.colorBrightness(bg_color, -0.4);
            },
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
                    const bright: RoomBrightness = if (obj.is_infinity)
                        .infinity
                    else if (obj.exitblock)
                        .normal
                    else
                        .clone;

                    const flip_inside = flip != obj.flip; // effectively a XOR, two flips cancel out
                    // recursion!
                    drawRoom(level, obj.room_id, obj_rect, recursion_level - 1, false, bright, flip_inside);

                    // border
                    const border_color: rl.Color = if (obj.float_in_space)
                        FLOATINSPACE_COLOR
                    else if (obj.is_infinity)
                        CLOSED_BORDER_COLOR
                    else
                        .black;

                    rl.drawRectangleLinesEx(obj_rect, 2, rl.colorAlpha(border_color, 0.8));

                    // infinity symbol
                    if (obj.is_infinity) {
                        drawTextureToRect(textures.?.infinity, obj_rect, rl.colorAlpha(.white, 0.95));
                    }
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
                drawTextureToRect(textures.?.eyes, obj_rect, rl.colorAlpha(.black, 0.6));
            } else if (obj.possessable) { // possessable and not player
                drawTextureToRect(textures.?.possess_eyes, obj_rect, rl.colorAlpha(.black, 0.6));
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

            const texture: rl.Texture2D = switch (obj.floor_type) {
                .button => textures.?.button,
                .player_button => textures.?.player_button,
                .fast_travel => textures.?.fast_travel,
                .info, .demo_end => textures.?.info,
                .break_, .show => textures.?.break_,
                .gallery => textures.?.gallery,
                .smile => textures.?.smile,
            };

            const alpha: f32 = switch (obj.floor_type) {
                .button, .player_button => 0.6,
                .fast_travel, .info, .demo_end, .break_, .gallery => 0.3,
                .show, .smile => 0.5,
            };

            const color: rl.Color = if (obj.selected and selection_effect) rl.colorAlpha(.green, alpha) else rl.colorAlpha(.white, alpha);

            switch (obj.type) {
                .wall, .box, .ref => {},
                .floor => {
                    drawTextureToRect(texture, obj_rect, color);
                },
            }
        }
    } else {
        // this room doesn't exist, draw red rectangle
        rl.drawRectangleRec(rect, .red);
    }
}

fn drawOverlaps(room: *const lv.Room, room_rect: rl.Rectangle, alloc: Allocator) !void {
    var nonfloor_counts = AutoHashMap([2]i32, usize).init(alloc);
    defer nonfloor_counts.deinit();

    var floor_counts = AutoHashMap([2]i32, usize).init(alloc);
    defer floor_counts.deinit();

    const tw: f32 = room_rect.width / @as(f32, @floatFromInt(room.width));
    const th: f32 = room_rect.height / @as(f32, @floatFromInt(room.height));

    for (room.objects.items) |obj| {
        if (!room.isPosInBounds(obj.x, obj.y)) {
            continue;
        }

        const objx: f32 = @floatFromInt(obj.x);
        const objy: f32 = @floatFromInt(obj.y);
        const obj_rect: rl.Rectangle = .{
            .x = room_rect.x + objx * tw,
            .y = room_rect.y + room_rect.height - objy * th - th,
            .width = tw,
            .height = th,
        };

        switch (obj.type) {
            .wall, .box, .ref => {
                const count = nonfloor_counts.get(.{ obj.x, obj.y }) orelse 0;
                if (count == 1) {
                    rl.drawRectangleLinesEx(obj_rect, 5, .red);
                }
                // increment count for this position
                try nonfloor_counts.put(.{ obj.x, obj.y }, count + 1);
            },
            .floor => {
                const count = floor_counts.get(.{ obj.x, obj.y }) orelse 0;
                if (count == 1) {
                    rl.drawRectangleLinesEx(obj_rect, 5, .red);
                }
                try floor_counts.put(.{ obj.x, obj.y }, count + 1);
            },
        }
    }
}

pub fn drawMain(level: *const lv.Level, focused_id: i32, selection_box: ?rl.Rectangle, draw_overlaps: bool, alloc: Allocator) !void {
    drawRoom(level, focused_id, utils.getRoomRect(), RECURSION_DEPTH, true, .normal, false);

    if (draw_overlaps) {
        const maybe_room = level.rooms.getPtr(focused_id);
        if (maybe_room) |room| {
            try drawOverlaps(room, utils.getRoomRect(), alloc);
        }
    }

    if (selection_box) |rect| {
        rl.drawRectangleLinesEx(rect, 1, .green);
    }
}
