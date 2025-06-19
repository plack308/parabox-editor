const std = @import("std");

const lv = @import("level.zig");
const pal = @import("palettes.zig");

const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;

const BlockProperties = struct {
    x: i32,
    y: i32,
    id: i32,
    width: i32,
    height: i32,
    hue: f32,
    sat: f32,
    val: f32,
    zoomfactor: f32,
    fillwithwalls: bool,
    player: bool,
    possessable: bool,
    playerorder: i32,
    fliph: bool,
    floatinspace: bool,
    specialeffect: i32,
};

const RefProperties = struct {
    x: i32,
    y: i32,
    id: i32,
    exitblock: bool,
    infexit: bool,
    infexitnum: i32,
    infenter: bool,
    infenternum: i32,
    infenterid: i32,
    player: bool,
    possessable: bool,
    playerorder: i32,
    fliph: bool,
    floatinspace: bool,
    specialeffect: i32,
};

const WallProperties = struct {
    x: i32,
    y: i32,
    player: bool,
    possessable: bool,
    playerorder: i32,
};

const FloorProperties = struct {
    const FloorType = enum {
        button,
        playerbutton,
    };

    x: i32,
    y: i32,
    ftype: FloorType,
};

const DrawStyle = enum {
    grid,
    tui,
    oldstyle,
};

fn nextInt(words: *std.mem.SplitIterator(u8, .scalar)) !i32 {
    return std.fmt.parseInt(i32, words.next() orelse return error.MissingField, 10);
}

fn nextFloat(words: *std.mem.SplitIterator(u8, .scalar)) !f32 {
    return std.fmt.parseFloat(f32, words.next() orelse return error.MissingField);
}

fn nextBool(words: *std.mem.SplitIterator(u8, .scalar)) !bool {
    const word = words.next() orelse return error.MissingField;
    // True/False actually works for bool properties!
    if (std.mem.eql(u8, word, "0") or std.mem.eql(u8, word, "False")) {
        return false;
    } else if (std.mem.eql(u8, word, "1") or std.mem.eql(u8, word, "True")) {
        return true;
    } else {
        return error.InvalidBool;
    }
}

const Line = union(enum) {
    // header lines
    version: []const u8,
    attempt_order: []const u8,
    shed: bool,
    inner_push: bool,
    draw_style: DrawStyle,
    custom_level_music: i32,
    custom_level_palette: i32,

    // the # line
    end_of_header: void,

    // object lines
    block: BlockProperties,
    ref: RefProperties,
    wall: WallProperties,
    floor: FloorProperties,

    garbage: void,

    fn parse(text: []const u8) !Line {
        // split into words
        var words = std.mem.splitScalar(u8, text, ' ');

        const first_word = words.first();

        if (std.mem.eql(u8, first_word, "version")) {
            const second_word = words.next() orelse return error.MissingField;
            return .{ .version = second_word };
        } else if (std.mem.eql(u8, first_word, "attempt_order")) {
            const second_word = words.next() orelse return error.MissingField;
            return .{ .attempt_order = second_word };
        } else if (std.mem.eql(u8, first_word, "shed")) {
            const enabled = try nextBool(&words);
            return .{ .shed = enabled };
        } else if (std.mem.eql(u8, first_word, "inner_push")) {
            const enabled = try nextBool(&words);
            return .{ .inner_push = enabled };
        } else if (std.mem.eql(u8, first_word, "draw_style")) {
            const second_word = words.next() orelse return error.MissingField;
            if (std.mem.eql(u8, second_word, "grid")) {
                return .{ .draw_style = .grid };
            } else if (std.mem.eql(u8, second_word, "tui")) {
                return .{ .draw_style = .tui };
            } else if (std.mem.eql(u8, second_word, "oldstyle")) {
                return .{ .draw_style = .oldstyle };
            } else {
                return .garbage; // the game ignores other draw_style values
            }
        } else if (std.mem.eql(u8, first_word, "custom_level_music")) {
            const music = try nextInt(&words);
            return .{ .custom_level_music = music };
        } else if (std.mem.eql(u8, first_word, "custom_level_palette")) {
            const palette = try nextInt(&words);
            return .{ .custom_level_palette = palette };
        } else if (std.mem.eql(u8, first_word, "#")) {
            return .end_of_header;
        } else if (std.mem.eql(u8, first_word, "Block")) {
            const x = try nextInt(&words);
            const y = try nextInt(&words);
            const id = try nextInt(&words);
            const width = try nextInt(&words);
            const height = try nextInt(&words);
            const hue = try nextFloat(&words);
            const sat = try nextFloat(&words);
            const val = try nextFloat(&words);
            const zoomfactor = try nextFloat(&words);
            const fillwithwalls = try nextBool(&words);
            const player = try nextBool(&words);
            const possessable = try nextBool(&words);
            const playerorder = try nextInt(&words);
            const fliph = try nextBool(&words);
            const floatinspace = try nextBool(&words);
            const specialeffect = try nextInt(&words);

            return .{ .block = .{
                .x = x,
                .y = y,
                .id = id,
                .width = width,
                .height = height,
                .hue = hue,
                .sat = sat,
                .val = val,
                .zoomfactor = zoomfactor,
                .fillwithwalls = fillwithwalls,
                .player = player,
                .possessable = possessable,
                .playerorder = playerorder,
                .fliph = fliph,
                .floatinspace = floatinspace,
                .specialeffect = specialeffect,
            } };
        } else if (std.mem.eql(u8, first_word, "Ref")) {
            const x = try nextInt(&words);
            const y = try nextInt(&words);
            const id = try nextInt(&words);
            const exitblock = try nextBool(&words);
            const infexit = try nextBool(&words);
            const infexitnum = try nextInt(&words);
            const infenter = try nextBool(&words);
            const infenternum = try nextInt(&words);
            const infenterid = try nextInt(&words);
            const player = try nextBool(&words);
            const possessable = try nextBool(&words);
            const playerorder = try nextInt(&words);
            const fliph = try nextBool(&words);
            const floatinspace = try nextBool(&words);
            const specialeffect = try nextInt(&words);

            return .{ .ref = .{
                .x = x,
                .y = y,
                .id = id,
                .exitblock = exitblock,
                .infexit = infexit,
                .infexitnum = infexitnum,
                .infenter = infenter,
                .infenternum = infenternum,
                .infenterid = infenterid,
                .player = player,
                .possessable = possessable,
                .playerorder = playerorder,
                .fliph = fliph,
                .floatinspace = floatinspace,
                .specialeffect = specialeffect,
            } };
        } else if (std.mem.eql(u8, first_word, "Wall")) {
            const x = try nextInt(&words);
            const y = try nextInt(&words);
            const player = try nextBool(&words);
            const possessable = try nextBool(&words);
            const playerorder = try nextInt(&words);

            return .{ .wall = .{
                .x = x,
                .y = y,
                .player = player,
                .possessable = possessable,
                .playerorder = playerorder,
            } };
        } else if (std.mem.eql(u8, first_word, "Floor")) {
            const x = try nextInt(&words);
            const y = try nextInt(&words);

            const type_word = words.next() orelse return error.MissingField;
            const ftype: FloorProperties.FloorType = if (std.mem.eql(u8, type_word, "Button"))
                .button
            else if (std.mem.eql(u8, type_word, "PlayerButton"))
                .playerbutton
            else {
                return error.InvalidFloorType;
            };

            return .{ .floor = .{
                .x = x,
                .y = y,
                .ftype = ftype,
            } };
        } else {
            return .garbage;
        }
    }
};

const IndentedLine = struct {
    line: Line,
    indent: usize,

    fn parse(text: []const u8) !IndentedLine {
        // count tabs (indentation level)
        var indent: usize = 0;
        while (indent < text.len and text[indent] == '\t') {
            indent += 1;
        }

        const text_no_indent = text[indent..];
        const line = try Line.parse(text_no_indent);
        return .{ .line = line, .indent = indent };
    }
};

// removes carriage return
fn readLineNoCR(reader: std.fs.File.Reader, buf: []u8) !?[]u8 {
    var line = try reader.readUntilDelimiterOrEof(buf, '\n') orelse return null;
    if (line.len > 0 and line[line.len - 1] == '\r') {
        line.len -= 1;
    }
    return line;
}

pub fn saveLevel(level: *const lv.Level, filename: []const u8) !void {
    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();

    const writer = file.writer();

    var rooms_iter = level.rooms.iterator();

    const box_id = level.nextFreeId(); // use this id for boxes to avoid conflicts

    // HEADER
    try writer.print("version 4\n", .{});

    const priority_slice = level.priority_buf[0..std.mem.len(@as([*:0]const u8, &level.priority_buf))];
    if (!std.mem.eql(u8, priority_slice, lv.DEFAULT_PRIORITY)) {
        try writer.print("attempt_order {s}\n", .{priority_slice});
    }

    if (level.extrude) {
        try writer.print("shed 1\n", .{});
    }

    if (level.inner_push) {
        try writer.print("inner_push 1\n", .{});
    }

    switch (level.draw_style) {
        .normal => {},
        .grid => try writer.print("draw_style grid\n", .{}),
        .text => try writer.print("draw_style tui\n", .{}),
        .gallery => try writer.print("draw_style oldstyle\n", .{}),
    }

    if (level.palette > -1) {
        try writer.print("custom_level_palette {d}\n", .{level.palette});
    }

    if (level.music > -1) {
        try writer.print("custom_level_music {d}\n", .{level.music});
    }

    try writer.print("#\n", .{});

    // OBJECTS
    while (rooms_iter.next()) |entry| {
        const id = entry.key_ptr.*;
        const room = entry.value_ptr;
        // room
        try writer.print("Block -1 -1 {d} {d} {d} {d} {d} {d} {d} 0 0 0 0 0 0 {d}\n", .{ id, room.width, room.height, room.hue, room.sat, room.val, room.zoom_factor, room.special_effect });
        // objects
        for (room.objects.items) |obj| {
            // ignore out of bounds objects
            if (!room.isPosInBounds(obj.x, obj.y)) {
                continue;
            }

            switch (obj.type) {
                .wall => {
                    try writer.print("\tWall {d} {d} {d} {d} {d}\n", .{ obj.x, obj.y, @intFromBool(obj.is_player), @intFromBool(obj.possessable), obj.player_order });
                },
                .box => {
                    try writer.print("\tBlock {d} {d} {d} 1 1 {d} {d} {d} 1 1 {d} {d} {d} 0 0 0\n", .{ obj.x, obj.y, box_id, obj.hue, obj.sat, obj.val, @intFromBool(obj.is_player), @intFromBool(obj.possessable), obj.player_order });
                },
                .ref => {
                    try writer.print("\tRef {d} {d} {d} {d} {d} {d} 0 0 0 {d} {d} {d} {d} 0 {d}\n", .{ obj.x, obj.y, obj.room_id, @intFromBool(obj.exitblock), @intFromBool(obj.is_infinity), obj.infinity_num - 1, @intFromBool(obj.is_player), @intFromBool(obj.possessable), obj.player_order, @intFromBool(obj.flip), obj.special_effect });
                },
                .floor => {
                    const type_text = if (obj.player_goal) "PlayerButton" else "Button";
                    try writer.print("\tFloor {d} {d} {s}\n", .{ obj.x, obj.y, type_text });
                },
            }
        }
    }

    std.log.info("Saved {s}", .{filename});
}

const BlockRefListEntry = struct {
    ref_id: i32,
    parent_id: i32,
    obj_index: usize,
};

pub fn loadLevel(filename: []const u8, alloc: Allocator) !lv.Level {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const reader = file.reader();

    var buf: [100]u8 = undefined;

    var level = lv.Level.init(alloc);
    errdefer level.deinit();

    // HEADER
    // read lines
    while (try readLineNoCR(reader, &buf)) |line_text| {
        const line = try Line.parse(line_text);

        switch (line) {
            .version => |word| {
                // expect version 4
                if (!std.mem.eql(u8, word, "4")) return error.UnsupportedVersion;
            },
            .attempt_order => |word| {
                if (word.len > level.priority_buf.len) {
                    return error.PriorityTooLong;
                }
                level.priority_buf = .{0} ** level.priority_buf.len;
                std.mem.copyForwards(u8, &level.priority_buf, word);
            },
            .shed => |enabled| {
                level.extrude = enabled;
            },
            .inner_push => |enabled| {
                level.inner_push = enabled;
            },
            .draw_style => |style| {
                switch (style) {
                    .grid => level.draw_style = .grid,
                    .tui => level.draw_style = .text,
                    .oldstyle => level.draw_style = .gallery,
                }
            },
            .custom_level_palette => |palette| {
                if (palette > pal.MAX_PALETTE) {
                    return error.InvalidPalette;
                }
                level.palette = palette;
            },
            .custom_level_music => |music| {
                level.music = music;
            },
            .end_of_header => {
                break; // found the # line
            },
            .block, .ref, .wall, .floor, .garbage => {
                // ignore
            },
        }
    }

    // OBJECTS
    var parent_stack = ArrayList(i32).init(alloc); // holds the IDs of blocks we're currently inside of
    defer parent_stack.deinit();

    var block_ref_list = ArrayList(BlockRefListEntry).init(alloc);
    defer block_ref_list.deinit();

    var exitblock_ids = AutoHashMap(i32, void).init(alloc);
    defer exitblock_ids.deinit();

    // read lines
    while (try readLineNoCR(reader, &buf)) |line_text| {
        const i_line = try IndentedLine.parse(line_text);

        // check indent level
        if (i_line.indent == parent_stack.items.len) {
            // this object is inside the last block in parent_stack
        } else if (i_line.indent < parent_stack.items.len) {
            // indent level is smaller
            // remove exited blocks from the stack
            parent_stack.shrinkRetainingCapacity(i_line.indent);
        } else {
            // indent level is bigger than expected
            return error.WrongIndentLevel;
        }

        switch (i_line.line) {
            .block => |prop| {
                if (prop.fliph) return error.FlipNotImplemented;
                if (prop.floatinspace) return error.FloatInSpaceNotImplemented;

                if (prop.fillwithwalls) {
                    // if there is a parent block
                    if (parent_stack.getLastOrNull()) |parent_id| {
                        // add a box
                        const room = level.rooms.getPtr(parent_id).?;
                        try room.objects.append(.{
                            .type = .box,
                            .x = prop.x,
                            .y = prop.y,
                            .hue = prop.hue,
                            .sat = prop.sat,
                            .val = prop.val,
                            .is_player = prop.player,
                            .player_order = prop.playerorder,
                            .possessable = prop.possessable,
                        });
                    }
                    // ignore root fillwithwalls blocks?

                } else { // no fillwithwalls
                    // if there is a parent block
                    if (parent_stack.getLastOrNull()) |parent_id| {
                        // add a reference to this block inside the parent block
                        const room = level.rooms.getPtr(parent_id).?;
                        try room.objects.append(.{
                            .type = .ref,
                            .x = prop.x,
                            .y = prop.y,
                            .room_id = prop.id,
                            .is_player = prop.player,
                            .player_order = prop.playerorder,
                            .possessable = prop.possessable,
                            .flip = prop.fliph,
                            .special_effect = prop.specialeffect,
                        });
                        // we don't know if this is an exitblock until we reach the end of the file
                        // add it to the list so it can be accessed later
                        try block_ref_list.append(.{
                            .ref_id = prop.id,
                            .parent_id = parent_id,
                            .obj_index = room.objects.items.len - 1,
                        });
                    }

                    if (prop.width < 1 or prop.height < 1) return error.InvalidDimensions;

                    // check if this id is free
                    if (level.rooms.contains(prop.id)) return error.IdAlreadyExists;
                    // create room
                    try level.createRoom(alloc, prop.id);
                    const new_room = level.rooms.getPtr(prop.id).?; // :(
                    // set room properties
                    new_room.width = prop.width;
                    new_room.height = prop.height;
                    new_room.hue = prop.hue;
                    new_room.sat = prop.sat;
                    new_room.val = prop.val;
                    new_room.zoom_factor = prop.zoomfactor;
                    new_room.special_effect = prop.specialeffect;

                    // push to stack
                    try parent_stack.append(prop.id);
                }
            },
            .ref => |prop| {
                if (prop.infenter) return error.EpsilonNotImplemented;
                if (prop.floatinspace) return error.FloatInSpaceNotImplemented;

                const parent_id = parent_stack.getLastOrNull() orelse return error.NoParentBlock;
                const room = level.rooms.getPtr(parent_id).?;
                try room.objects.append(.{
                    .type = .ref,
                    .x = prop.x,
                    .y = prop.y,
                    .room_id = prop.id,
                    .exitblock = prop.exitblock,
                    .is_infinity = prop.infexit,
                    .infinity_num = prop.infexitnum + 1, // in the file, single inf is 0, double is 1, etc
                    .is_player = prop.player,
                    .player_order = prop.playerorder,
                    .possessable = prop.possessable,
                    .flip = prop.fliph,
                    .special_effect = prop.specialeffect,
                });

                if (prop.exitblock) {
                    try exitblock_ids.put(prop.id, void{});
                }
            },
            .wall => |prop| {
                const parent_id = parent_stack.getLastOrNull() orelse return error.NoParentBlock;
                const room = level.rooms.getPtr(parent_id).?;
                try room.objects.append(.{
                    .type = .wall,
                    .x = prop.x,
                    .y = prop.y,
                    .is_player = prop.player,
                    .player_order = prop.playerorder,
                    .possessable = prop.possessable,
                });
            },
            .floor => |prop| {
                const parent_id = parent_stack.getLastOrNull() orelse return error.NoParentBlock;
                const room = level.rooms.getPtr(parent_id).?;
                const player_goal = switch (prop.ftype) {
                    .button => false,
                    .playerbutton => true,
                };
                try room.objects.append(.{
                    .type = .floor,
                    .x = prop.x,
                    .y = prop.y,
                    .player_goal = player_goal,
                });
            },
            else => {
                // ignore
            },
        }
    }

    // go back and set the correct values of exitblock
    for (block_ref_list.items) |entry| {
        // check if an exitblock for this id exists
        const exitblock_exists = exitblock_ids.contains(entry.ref_id);

        // get object pointer
        const room = level.rooms.getPtr(entry.parent_id).?;
        const object = &room.objects.items[entry.obj_index];

        // set exitblock property
        object.exitblock = !exitblock_exists;
    }

    std.log.info("Loaded {s}", .{filename});
    return level;
}
