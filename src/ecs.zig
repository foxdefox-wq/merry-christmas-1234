const std = @import("std");

/// ComponentHolder, comptime
pub fn createComponentHolder(comptime Components: type, comptime DeInitFunction: *anyopaque) type {
    return struct { Components: Components, DeInitFunction: DeInitFunction };
}

pub fn createWorldStruct(comptime ComponentHolder: type) type {
    // Components = struct {
    // Position : Vector3
    // }
    // DeInitFunction : *const fn (*anyopaque) void
    // Will call DeInitFunction on all fields of an entities components upon removal
    const Components = ComponentHolder.Components;
    const DeInitFunc: *const fn (*anyopaque) void = &ComponentHolder.De_Init_Function;

    // World
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        entities: std.MultiArrayList(?Components),
        id: u32 = 0,
        pub fn init(alloc: std.mem.Allocator) !void {
            return Self{ .entities = std.MultiArrayList(), .allocator = alloc };
        }

        inline fn getAndIncrementID(self: *Self) u32 {
            const id = self.id;
            self.id += 1;
            return id;
        }

        pub fn spawn(self: *Self, components: Components) u32 {
            const id = getAndIncrementID(self);
            self.entities.insert(self.allocator, id, components);
            return id;
        }

        pub fn kill(self: *Self, id: u32) !void {
            const entity: *Components = &self.entities.get(id);
            inline for (std.meta.fields(entity)) |*c| {
                try DeInitFunc(c);
            }
            self.entities.set(id, null);
        }
    };
}

test "Test Components" {
    const Components = struct {
        Position : @Vector(3, f32)
    };
    fn DeInit(component_field : *anyopaque) void {
      switch (component_field) {}
    };
    const DeInitFunc =
}
