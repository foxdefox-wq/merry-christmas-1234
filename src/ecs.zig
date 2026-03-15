const std = @import("std");
const rl = @import("raylib-zig");

const EntityData = struct {
    Position: ?rl.Vector3,
    Velocity: ?rl.Vector3,
};

const World = struct {
    const Self = @This();
    var next_id: u32 = 1;

    allocator: std.mem.Allocator,
    entities: std.MultiArrayList(?EntityData),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator, .entities = .{} };
    }

    fn getNextID() u32 {
        const id = next_id;
        next_id += 1;
        return id;
    }

    pub fn spawn(self: *Self, entity: EntityData) !u32 {
        const id = getNextID();
        try self.entities.append(self.allocator, entity);
        return id;
    }

    pub fn kill(self: *Self, id: u32) !void {
        const components = try getComponents(self, id);
        for (components) |c| {
            if (c.deinit()) {
                c.deinit();
            }
        }

        try self.entities.set(id, null);
    }

    pub fn deinit(self: *Self) void {
        self.entities.deinit(self.allocator);
    }

    pub fn getComponents(self: *Self, id: u32) !*EntityData {
        return try self.entities.get(id);
    }

    pub fn setComponents(self: *Self, id: u32, data: EntityData) !void {
        try self.entities.set(id, data);
    }
};
