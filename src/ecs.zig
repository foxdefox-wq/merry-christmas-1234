const std = @import("std");

pub const ID = u32;

pub fn Gen(comptime Components: type) type {
    const EntityType = MakeEntityStruct(Components);
    const StorageType = MakeStorageStruct(Components);

    return struct {
        pub const Entity = EntityType;

        pub const World = struct {
            const Self = @This();

            allocator: std.mem.Allocator,
            next_id: ID = 0,
            components: StorageType,

            pub fn init(allocator: std.mem.Allocator) Self {
                var self: Self = undefined;
                self.allocator = allocator;
                self.next_id = 0;
                inline for (std.meta.fields(StorageType)) |field| {
                    @field(self.components, field.name) = field.type.init(allocator);
                }
                return self;
            }

            pub fn deinit(self: *Self) void {
                inline for (std.meta.fields(Components)) |field| {
                    if (@hasDecl(field.type, "deinit")) {
                        var iter = @field(self.components, field.name).iterator();
                        while (iter.next()) |entry| {
                            entry.value_ptr.deinit();
                        }
                    }
                }

                inline for (std.meta.fields(StorageType)) |field| {
                    @field(self.components, field.name).deinit();
                }
            }

            pub fn spawn(self: *Self) ID {
                const id = self.next_id;
                self.next_id += 1;
                return id;
            }

            /// If a component has a `deinit()` method, it will be called.
            pub fn delete(self: *Self, id: ID) void {
                inline for (std.meta.fields(Components)) |field| {
                    var map = &@field(self.components, field.name);

                    if (map.fetchSwapRemove(id)) |kv| {
                        if (@hasDecl(field.type, "deinit")) {
                            var component = kv.value;
                            component.deinit();
                        }
                    }
                }
            }

            pub fn addComp(self: *Self, id: ID, comptime name: []const u8, val: anytype) !void {
                if (!@hasField(Components, name)) {
                    @compileError("Component '" ++ name ++ "' does not exist in the Component struct.");
                }
                const ExpectedType = @TypeOf(@field(@as(Components, undefined), name));
                const ActualType = @TypeOf(val);
                if (ExpectedType != ActualType) {
                    @compileError("Type mismatch for component '" ++ name ++ "'. Expected: " ++ @typeName(ExpectedType) ++ ", Got: " ++ @typeName(ActualType));
                }
                try @field(self.components, name).put(id, val);
            }

            pub fn get(self: *Self, id: ID) EntityType {
                var e: EntityType = undefined;
                inline for (std.meta.fields(Components)) |field| {
                    @field(e, field.name) = @field(self.components, field.name).getPtr(id);
                }
                return e;
            }
        };
    };
}

//Internal helpers
fn MakeEntityStruct(comptime Components: type) type {
    const fields = std.meta.fields(Components);
    var entity_fields: []const std.builtin.Type.StructField = &.{};

    for (fields) |field| {
        const PtrType = ?*field.type;
        entity_fields = entity_fields ++ .{std.builtin.Type.StructField{
            .name = field.name,
            .type = PtrType,
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(PtrType),
        }};
    }
    return @Type(.{ .Struct = .{ .layout = .auto, .fields = entity_fields, .decls = &.{}, .is_tuple = false } });
}

fn MakeStorageStruct(comptime Components: type) type {
    const fields = std.meta.fields(Components);
    var storage_fields: []const std.builtin.Type.StructField = &.{};

    for (fields) |field| {
        const MapType = std.AutoArrayHashMap(ID, field.type);
        storage_fields = storage_fields ++ .{std.builtin.Type.StructField{
            .name = field.name,
            .type = MapType,
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(MapType),
        }};
    }
    return @Type(.{ .Struct = .{ .layout = .auto, .fields = storage_fields, .decls = &.{}, .is_tuple = false } });
}
