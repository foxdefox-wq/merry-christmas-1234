const std = @import("std");
const rl = @import("raylib");

pub const CFrame = struct {
    pos: rl.Vector2,
    rad: f32,
};

pub const DataTypes = enum {
    CFrame,
    Texture,
    Hitbox,
};

pub const Rectangle = struct {
    width: u8,
    height: u8,
};

pub const Circle = struct {
    radius: u8,
};

pub const Hitbox = union(enum) {
    Rectangle: Rectangle,
    Circle: Circle,
};

pub const Data = union(DataTypes) {
    Texture: *const rl.Texture,
    Hitbox: Hitbox,
    CFrame: CFrame,

    const Self = @This();
    pub const Tag = std.meta.Tag(Self);

    pub fn deinit(self: *Self) void {
        switch (self.*) {
            .Texture => {},
            .Hitbox => {},
            .CFrame => {},
        }
    }
};

pub const Instance = struct {
    const Self = @This();
    pub const DataMap = std.EnumMap(Data.Tag, ?Data);

    parent: ?*Self = null,
    children: std.ArrayList(*Self),
    components: DataMap,
    allocator: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, init_values: DataMap) !*Self {
        const self = try alloc.create(Self);
        self.* = .{
            .parent = null,
            .children = std.ArrayList(*Self).init(alloc),
            .components = init_values,
            .allocator = alloc,
        };
        return self;
    }

    pub fn setComponent(self: *Self, value: Data) void {
        const tag = std.meta.activeTag(value);

        if (self.components.getPtr(tag)) |slot| {
            if (slot.*) |*old| {
                old.deinit();
            }
            slot.* = value;
        }
    }

    pub fn getComponent(self: *Self, tag: Data.Tag) ?*Data {
        if (self.components.getPtr(tag)) |slot| {
            if (slot.*) |*value| {
                return value;
            }
        }
        return null;
    }

    pub fn destroy(self: *Self) void {
        while (self.children.popOrNull()) |child| {
            child.destroy();
        }

        var it = self.components.iterator();
        while (it.next()) |entry| {
            if (entry.value.*) |*component| {
                component.deinit();
                entry.value.* = null;
            }
        }

        self.children.deinit();
        self.allocator.destroy(self);
    }
};
