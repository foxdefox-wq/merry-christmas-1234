const std = @import("std");
const rl = @import("raylib");

const ID = u32;
const ComponentTypes = struct {
    tag: []const u8,
    velocity: rl.Vector2,
    sprite: rl.Texture2D,
    hitbox: rl.Rectangle,
};

fn create(comptime Components: type) type {
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

fn createComponentHashmap(comptime Components: type) type {
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

fn makeWorld(comptime Components: type) type {
    return struct {
        const Self = @This();
        const Storage = createComponentHashmap(Components);

        allocator: std.mem.Allocator,
        next_id: ID = 0,
        components: Storage,

        pub fn init(allocator: std.mem.Allocator) Self {
            var self: Self = undefined;
            self.allocator = allocator;
            self.next_id = 0;
            inline for (std.meta.fields(Storage)) |field| {
                @field(self.components, field.name) = field.type.init(allocator);
            }
            return self;
        }

        pub fn deinit(self: *Self) void {
            inline for (std.meta.fields(Storage)) |field| {
                @field(self.components, field.name).deinit();
            }
        }

        pub fn spawn(self: *Self) ID {
            const id = self.next_id;
            self.next_id += 1;
            return id;
        }

        pub fn addComp(self: *Self, id: ID, comptime name: []const u8, val: anytype) !void {
            if (!@hasField(Components, name)) {
                @compileError("Component '" ++ name ++ "' does not exist in ComponentTypes.");
            }
            const ExpectedType = @TypeOf(@field(@as(Components, undefined), name));
            const ActualType = @TypeOf(val);
            if (ExpectedType != ActualType) {
                @compileError("Type mismatch for component '" ++ name ++ "'. Expected: " ++ @typeName(ExpectedType) ++ ", Got: " ++ @typeName(ActualType));
            }
            try @field(self.components, name).put(id, val);
        }

        pub fn getEntityStructFromID(self: *Self, id: ID) Entity {
            var e: Entity = undefined;
            inline for (std.meta.fields(Components)) |field| {
                @field(e, field.name) = @field(self.components, field.name).getPtr(id);
            }
            return e;
        }
    };
}
