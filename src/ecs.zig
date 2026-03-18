const std = @import("std");

pub const EntityId = struct {
    index: u32,
    generation: u32,
};

pub fn ECS(comptime EntityData: type, comptime Cleanup: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        entities: std.ArrayListUnmanaged(EntityData),
        generations: std.ArrayListUnmanaged(u32),
        alive: std.ArrayListUnmanaged(bool),
        free_list: std.ArrayListUnmanaged(u32),

        /// Creates an empty world.
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .entities = .{},
                .generations = .{},
                .alive = .{},
                .free_list = .{},
            };
        }

        /// Spawns an entity. Reuses dead slots when available.
        pub fn spawn(self: *Self, entity: EntityData) !EntityId {
            if (self.free_list.items.len > 0) {
                const index = self.free_list.items[self.free_list.items.len - 1];
                self.free_list.items.len -= 1;
                self.entities.items[index] = entity;
                self.alive.items[index] = true;
                return .{ .index = index, .generation = self.generations.items[index] };
            }

            const index: u32 = @intCast(self.entities.items.len);
            try self.entities.append(self.allocator, entity);
            try self.generations.append(self.allocator, 0);
            try self.alive.append(self.allocator, true);
            return .{ .index = index, .generation = 0 };
        }

        /// Returns true if this ID refers to a living entity.
        pub fn isAlive(self: *Self, id: EntityId) bool {
            if (id.index >= self.entities.items.len) return false;
            return self.alive.items[id.index] and
                self.generations.items[id.index] == id.generation;
        }

        /// Returns a copy of the entity data.
        pub fn get(self: *Self, id: EntityId) ?EntityData {
            if (!self.isAlive(id)) return null;
            return self.entities.items[id.index];
        }

        /// Returns a pointer for in-place mutation.
        pub fn getPtr(self: *Self, id: EntityId) ?*EntityData {
            if (!self.isAlive(id)) return null;
            return &self.entities.items[id.index];
        }

        /// Replaces the entity data.
        pub fn set(self: *Self, id: EntityId, data: EntityData) void {
            if (!self.isAlive(id)) return;
            self.entities.items[id.index] = data;
        }

        /// Kills the entity. Bumps generation so old IDs become invalid.
        pub fn kill(self: *Self, id: EntityId) !void {
            if (!self.isAlive(id)) return;
            cleanupEntity(&self.entities.items[id.index]);
            self.entities.items[id.index] = .{};
            self.alive.items[id.index] = false;
            self.generations.items[id.index] += 1;
            try self.free_list.append(self.allocator, id.index);
        }

        /// Number of living entities.
        pub fn count(self: *Self) u32 {
            var n: u32 = 0;
            for (self.alive.items) |a| {
                if (a) n += 1;
            }
            return n;
        }

        /// Total slots (alive + dead). Use for iteration.
        pub fn capacity(self: *Self) u32 {
            return @intCast(self.entities.items.len);
        }

        /// Get an EntityId for a raw index, if alive.
        /// Useful for iteration.
        pub fn entityAt(self: *Self, index: u32) ?EntityId {
            if (index >= self.entities.items.len) return null;
            if (!self.alive.items[index]) return null;
            return .{ .index = index, .generation = self.generations.items[index] };
        }

        /// Cleans up everything.
        pub fn deinit(self: *Self) void {
            for (self.entities.items, self.alive.items) |*entity, is_alive| {
                if (is_alive) cleanupEntity(entity);
            }
            self.entities.deinit(self.allocator);
            self.generations.deinit(self.allocator);
            self.alive.deinit(self.allocator);
            self.free_list.deinit(self.allocator);
        }

        fn cleanupEntity(entity: *EntityData) void {
            inline for (std.meta.fields(EntityData)) |field| {
                const info = @typeInfo(field.type);
                if (info != .optional) continue;

                const Inner = info.optional.child;
                const slot = &@field(entity, field.name);

                if (slot.*) |value| {
                    Cleanup.cleanup(Inner, value);
                    slot.* = null;
                }
            }
        }
    };
}
