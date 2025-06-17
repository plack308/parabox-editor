const std = @import("std");
const rl = @import("raylib");
const gui = @import("raygui");

const lv = @import("level.zig");
const fileformat = @import("fileformat.zig");
const draw = @import("draw.zig");
const utils = @import("utils.zig");
const pal = @import("palettes.zig");

const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;

const MAX_PATH_LEN = 250;

const Scene = enum {
    main,
    level_options,
    controls,
};

const EditorMode = enum {
    build,
    select,
    box_select,
    delete,
};

const BuildObjectType = enum {
    wall,
    box,
    player, // places a box object with different defaults
    ref, // ref, exitblock on
    clone, // ref, exitblock off
    goal,
    player_goal,
};

var scene: Scene = .main;
var editor_mode: EditorMode = .build;
var build_object_type: BuildObjectType = .wall; // object type of placed objects
var focused_id: i32 = 0;
var select_origin: rl.Vector2 = .{ .x = 0, .y = 0 };
var file_path_buf: [MAX_PATH_LEN:0]u8 = .{0} ** MAX_PATH_LEN;

fn getSelectionRect() rl.Rectangle {
    const mouse = rl.getMousePosition();
    const left = @min(mouse.x, select_origin.x);
    const right = @max(mouse.x, select_origin.x);
    const top = @min(mouse.y, select_origin.y);
    const bottom = @max(mouse.y, select_origin.y);
    return .{ .x = left, .y = top, .width = right - left, .height = bottom - top };
}

fn update(level: *lv.Level) !void {
    switch (scene) {
        .main => {
            // esc - switch scene
            if (rl.isKeyPressed(.escape)) {
                scene = .level_options;
            }

            // arrow keys - move between rooms
            if (rl.isKeyPressed(.right) or rl.isKeyPressedRepeat(.right)) {
                focused_id += 1;
            }
            if (rl.isKeyPressed(.left) or rl.isKeyPressedRepeat(.left)) {
                focused_id -= 1;
            }

            // update room
            const maybe_room = level.rooms.getPtr(focused_id);
            if (maybe_room) |room| {
                try updateRoom(room);
            }
        },
        .level_options, .controls => {
            // esc - switch scene
            if (rl.isKeyPressed(.escape)) {
                scene = .main;
            }
        },
    }
}

fn updateRoom(room: *lv.Room) !void {
    const mouse = rl.getMousePosition();
    const mouse_tile_x = try utils.posToTileX(mouse.x, room.width);
    const mouse_tile_y = try utils.posToTileY(mouse.y, room.height);

    // wasd - move selected
    if (rl.isKeyPressed(.a) or rl.isKeyPressedRepeat(.a)) {
        room.moveSelected(-1, 0);
    }
    if (rl.isKeyPressed(.d) or rl.isKeyPressedRepeat(.d)) {
        room.moveSelected(1, 0);
    }
    if (rl.isKeyPressed(.w) or rl.isKeyPressedRepeat(.w)) {
        room.moveSelected(0, 1);
    }
    if (rl.isKeyPressed(.s) or rl.isKeyPressedRepeat(.s)) {
        room.moveSelected(0, -1);
    }

    // delete - delete selected
    if (rl.isKeyPressed(.delete)) {
        room.deleteSelected();
    }

    if (rl.isKeyPressed(.one)) {
        editor_mode = .build;
    }
    if (rl.isKeyPressed(.two)) {
        editor_mode = .select;
    }
    if (rl.isKeyPressed(.three)) {
        editor_mode = .box_select;
    }
    if (rl.isKeyPressed(.four)) {
        editor_mode = .delete;
    }

    switch (editor_mode) {
        .build => {
            if (rl.isMouseButtonDown(.left)) {
                const tile_is_free = room.findObjectAtPos(mouse_tile_x, mouse_tile_y) == null;

                if (room.isPosInBounds(mouse_tile_x, mouse_tile_y) and tile_is_free) {
                    room.deselectAll();
                    // place object
                    switch (build_object_type) {
                        .wall => {
                            try room.objects.append(.{ .selected = true, .type = .wall, .x = mouse_tile_x, .y = mouse_tile_y });
                        },
                        .box => {
                            try room.objects.append(.{ .selected = true, .type = .box, .x = mouse_tile_x, .y = mouse_tile_y, .hue = 0.1, .sat = 0.8, .val = 1 });
                        },
                        .player => {
                            try room.objects.append(.{ .selected = true, .type = .box, .x = mouse_tile_x, .y = mouse_tile_y, .hue = 0.9, .sat = 1, .val = 0.7, .is_player = true, .possessable = true });
                        },
                        .goal => {
                            try room.objects.append(.{ .selected = true, .type = .floor, .x = mouse_tile_x, .y = mouse_tile_y, .player_goal = false });
                        },
                        .player_goal => {
                            try room.objects.append(.{ .selected = true, .type = .floor, .x = mouse_tile_x, .y = mouse_tile_y, .player_goal = true });
                        },
                        .ref => {
                            try room.objects.append(.{ .selected = true, .type = .ref, .x = mouse_tile_x, .y = mouse_tile_y, .exitblock = true });
                        },
                        .clone => {
                            try room.objects.append(.{ .selected = true, .type = .ref, .x = mouse_tile_x, .y = mouse_tile_y, .exitblock = false });
                        },
                    }
                }
            }
        },
        .select => {
            const mouse_in_room = rl.checkCollisionPointRec(rl.getMousePosition(), utils.getRoomRect());
            if (rl.isMouseButtonPressed(.left) and mouse_in_room) {
                const object_idx = room.findObjectAtPos(mouse_tile_x, mouse_tile_y);

                // hold shift - toggle selection of the clicked object
                if (rl.isKeyDown(.left_shift)) {
                    if (object_idx) |idx| {
                        // toggle selection
                        room.objects.items[idx].selected = !room.objects.items[idx].selected;
                    }
                } else {
                    room.deselectAll();

                    if (object_idx) |idx| {
                        // select object
                        room.objects.items[idx].selected = true;
                    }
                }
            }
        },
        .box_select => {
            if (rl.isMouseButtonPressed(.left)) {
                select_origin = rl.getMousePosition();
            }
            if (rl.isMouseButtonReleased(.left)) {
                const rect = getSelectionRect();
                const left_x = try utils.posToTileX(rect.x, room.width);
                const right_x = try utils.posToTileX(rect.x + rect.width, room.width);
                const top_y = try utils.posToTileY(rect.y, room.height);
                const bottom_y = try utils.posToTileY(rect.y + rect.height, room.height);

                // hold shift - add to selection
                if (!rl.isKeyDown(.left_shift)) {
                    room.deselectAll();
                }
                // select objects
                for (room.objects.items) |*obj| {
                    if (obj.x >= left_x and obj.x <= right_x and
                        obj.y >= bottom_y and obj.y <= top_y)
                    {
                        obj.selected = true;
                    }
                }
            }
        },
        .delete => {
            if (rl.isMouseButtonDown(.left)) {
                const object_idx = room.findObjectAtPos(mouse_tile_x, mouse_tile_y);

                if (object_idx) |idx| {
                    // delete object
                    _ = room.objects.swapRemove(idx);
                }
            }
        },
    }
}

fn roomPropertiesPanel(room: *lv.Room, palette_idx: i32) void {
    var rect: rl.Rectangle = .{ .x = utils.guiSecondColumnX(), .y = 10, .width = 150, .height = 30 };
    _ = gui.label(rect, "room");

    // width/height
    rect.y += 40;
    _ = gui.spinner(rect, "width", &room.width, 1, std.math.maxInt(i32), false);

    rect.y += 30;
    _ = gui.spinner(rect, "height", &room.height, 1, std.math.maxInt(i32), false);

    // room color
    rect.y += 40;
    _ = gui.slider(rect, "hue", "", &room.hue, 0, 1);
    rect.y += 30;
    _ = gui.slider(rect, "sat", "", &room.sat, 0, 1);
    rect.y += 30;
    _ = gui.slider(rect, "val", "", &room.val, 0, 1);

    // palette color buttons
    rect.y += 30;
    rect.width = 30;
    for (0..6) |i| {
        const hsv = pal.palette_data[0][i]; // color from default palette
        const color = utils.getColor(palette_idx, hsv[0], hsv[1], hsv[2]);

        if (utils.colorButton(rect, color)) {
            room.hue = hsv[0];
            room.sat = hsv[1];
            room.val = hsv[2];
        }

        rect.x += 30;
    }

    // zoom factor
    rect.x = utils.guiSecondColumnX();
    rect.y += 40;
    rect.width = 200;
    _ = gui.label(rect, rl.textFormat("zoom factor: %.2f", .{room.zoom_factor}));

    // special effect
    rect.x += 75;
    rect.y += 40;
    rect.width = 85;
    _ = gui.spinner(rect, "special effect", &room.special_effect, 0, std.math.maxInt(i32), false);
}

fn objectPropertiesPanel(obj: *lv.LevelObject, palette_idx: i32) void {
    // object info
    var rect: rl.Rectangle = .{ .x = utils.guiSecondColumnX(), .y = 10, .width = 150, .height = 30 };
    _ = gui.label(rect, @tagName(obj.type));

    if (obj.type == .ref) {
        // room id
        rect.y += 40;
        _ = gui.spinner(rect, "room id", &obj.room_id, std.math.minInt(i32), std.math.maxInt(i32), false);

        // edit room button
        rect.y += 30;
        if (gui.button(rect, "edit room")) {
            focused_id = obj.room_id;
        }

        // exitblock
        rect.y += 40;
        rect.width = 30;
        _ = gui.checkBox(rect, "exitblock", &obj.exitblock);
    }

    rect.width = 150;

    if (obj.type == .box) {
        // color
        rect.y += 40;
        _ = gui.slider(rect, "hue", "", &obj.hue, 0, 1);
        rect.y += 30;
        _ = gui.slider(rect, "sat", "", &obj.sat, 0, 1);
        rect.y += 30;
        _ = gui.slider(rect, "val", "", &obj.val, 0, 1);

        // palette color buttons
        rect.y += 30;
        rect.width = 30;
        for (0..6) |i| {
            const hsv = pal.palette_data[0][i]; // color from default palette
            const color = utils.getColor(palette_idx, hsv[0], hsv[1], hsv[2]);

            if (utils.colorButton(rect, color)) {
                obj.hue = hsv[0];
                obj.sat = hsv[1];
                obj.val = hsv[2];
            }

            rect.x += 30;
        }
    }

    rect.x = utils.guiSecondColumnX();

    if (obj.type == .wall or obj.type == .box or obj.type == .ref) {
        // is player
        rect.y += 40;
        rect.width = 30;
        _ = gui.checkBox(rect, "is player", &obj.is_player);

        // player order
        if (obj.is_player) {
            rect.y += 30;
            rect.width = 150;
            _ = gui.spinner(rect, "player order", &obj.player_order, 0, std.math.maxInt(i32), false);
        }

        // possessable
        rect.y += 40;
        rect.width = 30;
        _ = gui.checkBox(rect, "possessable", &obj.possessable);
    }

    if (obj.type == .floor) {
        // player goal
        rect.y += 40;
        rect.width = 30;
        _ = gui.checkBox(rect, "player goal", &obj.player_goal);
    }

    if (obj.type == .ref) {
        // flip
        rect.y += 40;
        rect.width = 30;
        _ = gui.checkBox(rect, "flip", &obj.flip);

        // special effect
        rect.x += 75;
        rect.y += 40;
        rect.width = 85;
        _ = gui.spinner(rect, "special effect", &obj.special_effect, 0, std.math.maxInt(i32), false);
    }
}

fn multipleObjectsPanel(count: usize) void {
    // object info
    const rect: rl.Rectangle = .{ .x = utils.guiSecondColumnX(), .y = 10, .width = 150, .height = 30 };
    _ = gui.label(rect, rl.textFormat("%d objects", .{count}));
}

fn editorControlsPanel() void {
    // editor mode buttons
    var rect: rl.Rectangle = .{ .x = utils.guiFirstColumnX(), .y = 10, .width = 150, .height = 30 };
    var build_active: bool = editor_mode == .build;
    _ = gui.toggle(rect, "build (1)", &build_active);
    if (build_active) {
        editor_mode = .build;
    }

    rect.y += 30;
    var select_active: bool = editor_mode == .select;
    _ = gui.toggle(rect, "select (2)", &select_active);
    if (select_active) {
        editor_mode = .select;
    }

    rect.y += 30;
    var box_select_active: bool = editor_mode == .box_select;
    _ = gui.toggle(rect, "box select (3)", &box_select_active);
    if (box_select_active) {
        editor_mode = .box_select;
    }

    rect.y += 30;
    var delete_active: bool = editor_mode == .delete;
    _ = gui.toggle(rect, "delete (4)", &delete_active);
    if (delete_active) {
        editor_mode = .delete;
    }

    // object type buttons
    rect.y += 40;
    var wall_active: bool = build_object_type == .wall;
    _ = gui.toggle(rect, "wall", &wall_active);
    if (wall_active) {
        build_object_type = .wall;
    }

    rect.y += 30;
    var player_active: bool = build_object_type == .player;
    _ = gui.toggle(rect, "player", &player_active);
    if (player_active) {
        build_object_type = .player;
    }

    rect.y += 30;
    var box_active: bool = build_object_type == .box;
    _ = gui.toggle(rect, "box", &box_active);
    if (box_active) {
        build_object_type = .box;
    }

    rect.y += 30;
    var goal_active: bool = build_object_type == .goal;
    _ = gui.toggle(rect, "goal", &goal_active);
    if (goal_active) {
        build_object_type = .goal;
    }

    rect.y += 30;
    var player_goal_active: bool = build_object_type == .player_goal;
    _ = gui.toggle(rect, "player goal", &player_goal_active);
    if (player_goal_active) {
        build_object_type = .player_goal;
    }

    rect.y += 30;
    var ref_active: bool = build_object_type == .ref;
    _ = gui.toggle(rect, "ref", &ref_active);
    if (ref_active) {
        build_object_type = .ref;
    }

    rect.y += 30;
    var clone_active: bool = build_object_type == .clone;
    _ = gui.toggle(rect, "clone", &clone_active);
    if (clone_active) {
        build_object_type = .clone;
    }

    // focused id
    rect.y += 40;
    _ = gui.spinner(rect, "focused id", &focused_id, std.math.minInt(i32), std.math.maxInt(i32), false);
}

fn drawAndUpdateGui(level: *lv.Level, alloc: Allocator) !void {
    const ws = utils.getWindowSize();

    editorControlsPanel();

    // properties panel
    const maybe_room = level.rooms.getPtr(focused_id);
    if (maybe_room) |room| {
        // decide what should be displayed based on selected object count
        const sel_count = room.countSelected();

        switch (sel_count) {
            0 => {
                roomPropertiesPanel(room, level.palette);
            },
            1 => {
                const obj = room.getSelectedObject().?;
                objectPropertiesPanel(obj, level.palette);
            },
            else => {
                multipleObjectsPanel(sel_count);
            },
        }
    }

    if (level.rooms.contains(focused_id)) {
        // delete room button
        const rect: rl.Rectangle = .{ .x = utils.guiSecondColumnX(), .y = ws.y - 40, .width = 150, .height = 30 };
        if (gui.button(rect, "delete room")) {
            level.deleteRoom(focused_id);
        }
    } else {
        // create room button
        const rect: rl.Rectangle = .{ .x = utils.guiSecondColumnX(), .y = 50, .width = 150, .height = 30 };
        if (gui.button(rect, "create room")) {
            try level.createRoom(alloc, focused_id);
        }
    }

    // level options button
    var rect: rl.Rectangle = .{ .x = ws.x - 35, .y = 5, .width = 30, .height = 30 };
    if (gui.button(rect, gui.iconText(@intFromEnum(gui.IconName.burger_menu), ""))) {
        scene = .level_options;
    }

    // controls menu button
    rect.x -= 35;
    if (gui.button(rect, gui.iconText(@intFromEnum(gui.IconName.help), ""))) {
        scene = .controls;
    }
}

fn guiLevelOptions(level: *lv.Level, alloc: Allocator) void {
    // back button
    var rect: rl.Rectangle = .{ .x = 10, .y = 10, .width = 30, .height = 30 };
    if (gui.button(rect, gui.iconText(@intFromEnum(gui.IconName.arrow_left_fill), ""))) {
        scene = .main;
    }

    // file path label
    rect = .{ .x = 10, .y = 50, .width = 500, .height = 30 };
    _ = gui.label(rect, "file path:");

    // file path input
    rect.y += 30;
    _ = gui.textBox(rect, &file_path_buf, MAX_PATH_LEN, true);

    const file_path_slice = file_path_buf[0..std.mem.len(@as([*:0]u8, &file_path_buf))];

    // save button
    rect.y += 30;
    rect.width = 70;
    if (gui.button(rect, "save")) {
        fileformat.saveLevel(level, file_path_slice) catch |err| {
            std.log.err("Saving failed: {any}", .{err});
        };
    }

    // load button
    rect.x += 80;
    if (gui.button(rect, "load")) {
        if (fileformat.loadLevel(file_path_slice, alloc)) |new_level| {
            // loading succeeded, replace the existing level
            level.deinit();
            level.* = new_level;
        } else |err| {
            std.log.err("Loading failed: {any}", .{err});
        }
    }

    // level options label
    rect.x = 10;
    rect.y += 50;
    rect.width = 150;
    _ = gui.label(rect, "Level options");

    // extrude
    rect.y += 30;
    rect.width = 30;
    _ = gui.checkBox(rect, "extrude", &level.extrude);

    // inner push
    rect.y += 40;
    _ = gui.checkBox(rect, "inner push", &level.inner_push);

    // palette
    rect.x += 100;
    rect.y += 40;
    rect.width = 100;
    _ = gui.spinner(rect, "palette", &level.palette, -1, pal.MAX_PALETTE, false);

    // palette preview
    rect.x += 110;
    rect.width = 30;
    for (0..6) |i| {
        const hsv = pal.palette_data[0][i]; // color from default palette
        const color = utils.getColor(level.palette, hsv[0], hsv[1], hsv[2]);
        rl.drawRectangleRec(rect, color);
        rect.x += 30;
    }

    // music
    rect.x = 110;
    rect.y += 40;
    rect.width = 100;
    _ = gui.spinner(rect, "music", &level.music, -1, utils.MAX_MUSIC, false);

    // music text
    rect.x += 110;
    rect.width = 300;
    _ = gui.label(rect, utils.getMusicText(level.music));

    // draw style
    rect.x = 10;
    rect.y += 40;
    rect.width = 100;
    _ = gui.label(rect, "draw style");

    rect.x += 100;
    var normal_active: bool = level.draw_style == .normal;
    _ = gui.toggle(rect, "normal", &normal_active);
    if (normal_active) {
        level.draw_style = .normal;
    }

    rect.x += 100;
    var grid_active: bool = level.draw_style == .grid;
    _ = gui.toggle(rect, "grid", &grid_active);
    if (grid_active) {
        level.draw_style = .grid;
    }

    rect.x += 100;
    var text_active: bool = level.draw_style == .text;
    _ = gui.toggle(rect, "text", &text_active);
    if (text_active) {
        level.draw_style = .text;
    }

    rect.x += 100;
    var gallery_active: bool = level.draw_style == .gallery;
    _ = gui.toggle(rect, "gallery", &gallery_active);
    if (gallery_active) {
        level.draw_style = .gallery;
    }
}

fn guiControls() void {
    // back button
    var rect: rl.Rectangle = .{ .x = 10, .y = 10, .width = 30, .height = 30 };
    if (gui.button(rect, gui.iconText(@intFromEnum(gui.IconName.arrow_left_fill), ""))) {
        scene = .main;
    }

    // labels
    rect = .{ .x = 10, .y = 50, .width = 700, .height = 30 };
    _ = gui.label(rect, "WASD - move objects");

    rect.y += 30;
    _ = gui.label(rect, "DEL - delete objects");

    rect.y += 30;
    _ = gui.label(rect, "left/right - change room");

    rect.y += 30;
    _ = gui.label(rect, "1-4 - change mode");

    rect.y += 30;
    _ = gui.label(rect, "SHIFT in SELECT mode - select/deselect specific objects");

    rect.y += 30;
    _ = gui.label(rect, "SHIFT in BOX SELECT mode - add to selection");

    rect.y += 30;
    _ = gui.label(rect, "ESC - level options / back");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    rl.initWindow(1000, 600, "parabox editor");
    defer rl.closeWindow();

    try draw.loadTextures();
    defer draw.unloadTextures();

    rl.setWindowState(.{ .window_resizable = true });
    rl.setWindowMinSize(100, 100);
    rl.setTargetFPS(75);
    rl.setExitKey(.null);

    // gui: set text size
    gui.setStyle(.default, .{ .default = .text_size }, 20);

    var level = lv.Level.init(allocator);
    defer level.deinit();

    while (!rl.windowShouldClose()) {
        try update(&level);

        rl.beginDrawing();

        rl.clearBackground(.black);

        switch (scene) {
            .main => {
                const draw_sel_box = editor_mode == .box_select and rl.isMouseButtonDown(.left);
                draw.drawMain(&level, focused_id, draw_sel_box, getSelectionRect());

                try drawAndUpdateGui(&level, allocator);
            },
            .level_options => {
                guiLevelOptions(&level, allocator);
            },
            .controls => {
                guiControls();
            },
        }

        rl.endDrawing();
    }
}
