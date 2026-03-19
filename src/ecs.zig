const std = @import("std");

pub fn World(comptime components: type, comptime deinit_fns: anytype) type {
    if (@typeInfo(components) != .Struct) {
        @compileError("Components must be a struct");
    }

    const comp_fields = std.meta.fields(components);

    if (comp_fields.len != deinit_fns.len) {
        @compileError("deinit_funcs must match Components field count");
    }

    const Storages = MakeStoragesStruct(components, deinit_fns);

    return struct {
        const Self = @This();

        pub const Entity = struct {
            index: u32,
            generation: u32,
        };

        const EntitySlot = struct {
            alive: bool,
            generation: u32,
        };

        allocator: std.mem.Allocator,
        entity_slots: std.ArrayList(EntitySlot),
        free_list: std.ArrayList(u32),
        storages: Storages,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .entity_slots = std.ArrayList(EntitySlot).init(allocator),
                .free_list = std.ArrayList(u32).init(allocator),
                .storages = Storages.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            var i: usize = 0;
            while (i < self.entity_slots.items.len) : (i += 1) {
                const e = Entity{
                    .index = @intCast(i),
                    .generation = self.entity_slots.items[i].generation,
                };
                if (self.isAlive(e)) {
                    self.kill(e);
                }
            }

            self.storages.deinit();
            self.entity_slots.deinit();
            self.free_list.deinit();
        }

        pub fn spawn(self: *Self) !Entity {
            if (self.free_list.items.len > 0) {
                const index = self.free_list.pop().?;
                self.entity_slots.items[index].alive = true;
                return .{
                    .index = index,
                    .generation = self.entity_slots.items[index].generation,
                };
            }

            const index: u32 = @intCast(self.entity_slots.items.len);
            try self.entity_slots.append(.{
                .alive = true,
                .generation = 0,
            });

            return .{
                .index = index,
                .generation = 0,
            };
        }

        pub fn isAlive(self: *Self, entity: Entity) bool {
            if (entity.index >= self.entity_slots.items.len) return false;
            const slot = self.entity_slots.items[entity.index];
            return slot.alive and slot.generation == entity.generation;
        }

        pub fn kill(self: *Self, entity: Entity) void {
            if (!self.isAlive(entity)) return;

            inline for (comp_fields) |f| {
                @field(self.storages, f.name).remove(entity, self.allocator);
            }

            self.entity_slots.items[entity.index].alive = false;
            self.entity_slots.items[entity.index].generation += 1;
            self.free_list.append(entity.index) catch unreachable;
        }

        pub fn add(self: *Self, entity: Entity, comptime T: type, value: T) !void {
            if (!self.isAlive(entity)) return error.InvalidEntity;
            return self.storage(T).put(entity, value);
        }

        pub fn get(self: *Self, entity: Entity, comptime T: type) ?*T {
            if (!self.isAlive(entity)) return null;
            return self.storage(T).get(entity);
        }

        pub fn has(self: *Self, entity: Entity, comptime T: type) bool {
            if (!self.isAlive(entity)) return false;
            return self.storage(T).has(entity);
        }

        pub fn remove(self: *Self, entity: Entity, comptime T: type) void {
            if (!self.isAlive(entity)) return;
            self.storage(T).remove(entity, self.allocator);
        }

        fn storage(self: *Self, comptime T: type) *FindStorageType(components, deinit_fns, T) {
            inline for (comp_fields) |f| {
                if (f.type == T) {
                    return &@field(self.storages, f.name);
                }
            }
            @compileError("Component type not found: " ++ @typeName(T));
        }
    };
}

fn ComponentStorage(comptime T: type, comptime maybe_deinit: anytype) type {
    return struct {
        const Self = @This();

        items: std.ArrayList(T),
        owners: std.ArrayList(u32),
        indices: std.AutoHashMap(u32, usize),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .items = std.ArrayList(T).init(allocator),
                .owners = std.ArrayList(u32).init(allocator),
                .indices = std.AutoHashMap(u32, usize).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit();
            self.owners.deinit();
            self.indices.deinit();
        }

        pub fn has(self: *Self, entity: anytype) bool {
            return self.indices.contains(entity.index);
        }

        pub fn get(self: *Self, entity: anytype) ?*T {
            const index = self.indices.get(entity.index) orelse return null;
            return &self.items.items[index];
        }

        pub fn put(self: *Self, entity: anytype, value: T) !void {
            if (self.indices.get(entity.index)) |index| {
                self.items.items[index] = value;
                return;
            }

            const new_index = self.items.items.len;
            try self.items.append(value);
            try self.owners.append(entity.index);
            try self.indices.put(entity.index, new_index);
        }

        pub fn remove(self: *Self, entity: anytype, allocator: std.mem.Allocator) void {
            const index = self.indices.get(entity.index) orelse return;

            if (maybe_deinit) |deinit_func| {
                deinit_func(&self.items.items[index], allocator);
            }

            const last_index = self.items.items.len - 1;
            const moved_owner = self.owners.items[last_index];

            _ = self.items.swapRemove(index);
            _ = self.owners.swapRemove(index);
            _ = self.indices.remove(entity.index);

            if (index != last_index) {
                self.indices.put(moved_owner, index) catch unreachable;
            }
        }
    };
}

fn MakeStoragesStruct(comptime Components: type, comptime deinit_funcs: anytype) type {
    const comp_fields = std.meta.fields(Components);

    const storage_fields = blk: {
        var fields: [comp_fields.len]std.builtin.Type.StructField = undefined;

        inline for (comp_fields, deinit_funcs, 0..) |f, df, i| {
            const StorageT = ComponentStorage(f.type, df);
            fields[i] = .{
                .name = f.name,
                .type = StorageT,
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(StorageT),
            };
        }

        break :blk fields;
    };

    return @Type(.{
        .Struct = .{
            .layout = .auto,
            .fields = &storage_fields,
            .decls = &.{
                .{
                    .name = "init",
                    .value = initFn(Components, deinit_funcs),
                },
                .{
                    .name = "deinit",
                    .value = deinitFn(Components),
                },
            },
            .is_tuple = false,
        },
    });
}

fn initFn(comptime Components: type, comptime deinit_funcs: anytype) fn (std.mem.Allocator) MakeStoragesStruct(Components, deinit_funcs) {
    const Storages = MakeStoragesStruct(Components, deinit_funcs);
    const comp_fields = std.meta.fields(Components);

    return struct {
        fn f(allocator: std.mem.Allocator) Storages {
            var storages: Storages = undefined;
            inline for (comp_fields, deinit_funcs) |finfo, df| {
                @field(storages, finfo.name) = ComponentStorage(finfo.type, df).init(allocator);
            }
            return storages;
        }
    }.f;
}

fn deinitFn(comptime Components: type) fn (anytype) void {
    const comp_fields = std.meta.fields(Components);

    return struct {
        fn f(self: anytype) void {
            inline for (comp_fields) |finfo| {
                @field(self, finfo.name).deinit();
            }
        }
    }.f;
}

fn FindStorageType(comptime Components: type, comptime deinit_funcs: anytype, comptime T: type) type {
    inline for (std.meta.fields(Components), deinit_funcs) |f, df| {
        if (f.type == T) return ComponentStorage(T, df);
    }
    @compileError("Component type not found: " ++ @typeName(T));
}
