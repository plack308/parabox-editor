const std = @import("std");
const rl = @import("raylib");

const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;

pub const LevelObject = struct {
    pub const ObjectType = enum {
        wall,
        box, // fillwithwalls block
        ref,
        floor,
    };

    selected: bool = false,
    type: ObjectType,

    x: i32,
    y: i32,

    // for refs
    room_id: i32 = 0,
    exitblock: bool = false,

    // color for box objects
    hue: f32 = 0,
    sat: f32 = 0,
    val: f32 = 0,

    is_player: bool = false,
    player_order: i32 = 0,

    possessable: bool = false,

    player_goal: bool = false, // makes floor objects PlayerButton instead of Button

    // for refs
    flip: bool = false,
    special_effect: i32 = 0,
};

pub const Room = struct {
    width: i32,
    height: i32,

    // color
    hue: f32,
    sat: f32,
    val: f32,

    zoom_factor: f32 = 1,

    special_effect: i32 = 0,

    objects: ArrayList(LevelObject),

    pub fn isPosInBounds(self: *const Room, x: i32, y: i32) bool {
        return x >= 0 and x < self.width and y >= 0 and y < self.height;
    }

    pub fn findObjectAtPos(self: *const Room, x: i32, y: i32) ?usize {
        for (0.., self.objects.items) |i, obj| {
            if (obj.x == x and obj.y == y) {
                return i;
            }
        }
        return null;
    }

    pub fn getSelectedObject(self: *const Room) ?*LevelObject {
        for (self.objects.items) |*obj| {
            if (obj.selected) {
                return obj;
            }
        }
        return null;
    }

    pub fn countSelected(self: *const Room) usize {
        var result: usize = 0;

        for (self.objects.items) |obj| {
            if (obj.selected) {
                result += 1;
            }
        }

        return result;
    }

    pub fn moveSelected(self: *Room, x: i32, y: i32) void {
        for (self.objects.items) |*obj| {
            if (obj.selected) {
                obj.x += x;
                obj.y += y;
            }
        }
    }

    pub fn deleteSelected(self: *Room) void {
        var i: usize = self.objects.items.len;
        while (i > 0) {
            i -= 1;
            if (self.objects.items[i].selected) {
                _ = self.objects.swapRemove(i);
            }
        }
    }

    pub fn deselectAll(self: *Room) void {
        for (self.objects.items) |*obj| {
            obj.selected = false;
        }
    }
};

pub const Level = struct {
    extrude: bool = false,
    inner_push: bool = false,
    palette: i32 = -1,
    music: i32 = -1,

    rooms: AutoHashMap(i32, Room),

    pub fn init(alloc: Allocator) Level {
        return .{ .rooms = AutoHashMap(i32, Room).init(alloc) };
    }

    pub fn deinit(self: *Level) void {
        var iter = self.rooms.valueIterator();
        while (iter.next()) |room| {
            room.objects.deinit();
        }
        self.rooms.deinit();
    }

    // add a new room
    // asserts that this id is free
    pub fn createRoom(self: *Level, alloc: Allocator, id: i32) !void {
        const new_room: Room = .{ .width = 9, .height = 9, .hue = 0, .sat = 0, .val = 0.8, .objects = ArrayList(LevelObject).init(alloc) };
        try self.rooms.putNoClobber(id, new_room);
    }

    // delete a room if it exists
    pub fn deleteRoom(self: *Level, id: i32) void {
        const maybe_room = self.rooms.getPtr(id);
        if (maybe_room) |room| {
            room.objects.deinit();
            _ = self.rooms.remove(id);
        }
    }

    pub fn nextFreeId(self: *const Level) i32 {
        var id: i32 = 0;
        while (self.rooms.contains(id)) {
            id += 1;
        }
        return id;
    }
};
