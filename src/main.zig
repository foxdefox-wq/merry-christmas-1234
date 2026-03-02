const std = @import("std");
const rl = @import("raylib");

const ID = u32;

//Define components here
pub const ComponentTypes = struct {
    velocity: rl.Vector2,
    sprite: rl.Texture2D,
    hitbox: rl.Rectangle,
};

//Metaprogramming helpers
fn MakeEntity(comptime Components: type) type {
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

//Makes hasmaps for all components
fn MakeStorage(comptime Components: type) type {
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

//Generates the World struct with methods
fn MakeWorld(comptime Components: type) type {
    return struct {
        const Self = @This();
        const Storage = MakeStorage(Components);

        allocator: std.mem.Allocator,
        next_id: ID = 0,

        // This struct holds all the AutoArrayHashMaps
        components: Storage,

        pub fn init(allocator: std.mem.Allocator) Self {
            var self: Self = undefined;
            self.allocator = allocator;
            self.next_id = 0;
            // Initialize every map in the storage struct
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

        // Auto-detects which map to use based on the type of 'val'
        pub fn addComponent(self: *Self, id: ID, val: anytype) !void {
            const T = @TypeOf(val);
            inline for (std.meta.fields(Components)) |field| {
                if (field.type == T) {
                    try @field(self.components, field.name).put(id, val);
                    return;
                }
            }
            @compileError("World has no storage for component type: " ++ @typeName(T));
        }

        pub fn get(self: *Self, id: ID) Entity {
            var e: Entity = undefined;
            // Link pointers from storage maps to the Entity struct
            inline for (std.meta.fields(Components)) |field| {
                @field(e, field.name) = @field(self.components, field.name).getPtr(id);
            }
            return e;
        }
    };
}

// ============================================================
// GAME TYPES
// ============================================================

pub const World = MakeWorld(ComponentTypes);
pub const Entity = MakeEntity(ComponentTypes);

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var world: World = undefined;
var camera: rl.Camera2D = undefined;

pub fn main() !void {
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    world = World.init(allocator);
    defer world.deinit();

    rl.initWindow(800, 600, "Christmas");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    camera = rl.Camera2D{
        .offset = .{ .x = 400, .y = 300 },
        .target = .{ .x = 400, .y = 300 },
        .rotation = 0,
        .zoom = 1.0,
    };

    // Example: Spawning an entity
    const id = world.spawn();
    try world.addComponent(id, rl.Rectangle{ .x = 400, .y = 300, .width = 32, .height = 32 }); // Hitbox
    try world.addComponent(id, rl.Vector2{ .x = 100, .y = 0 }); // Velocity
    // try world.addComponent(id, texture); // Sprite

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();
        update(dt);
        rl.beginDrawing();
        rl.clearBackground(.ray_white);
        rl.beginMode2D(camera);
        render();
        rl.endMode2D();
        rl.drawFPS(10, 10);
        rl.endDrawing();
    }
}

pub fn update(dt: f32) void {
    // We iterate over the 'hitbox' map because we are using hitbox x/y as position
    var iter = world.components.hitbox.iterator();
    while (iter.next()) |entry| {
        const id = entry.key_ptr.*;
        const e = world.get(id);

        if (e.velocity) |vel| {
            if (e.hitbox) |box| {
                box.x += vel.x * dt;

                // Bounce logic
                if (box.x > 800 or box.x < 0) vel.x *= -1;

                // Update Camera
                camera.target.x = std.math.lerp(camera.target.x, box.x, 5.0 * dt);
                camera.target.y = std.math.lerp(camera.target.y, box.y, 5.0 * dt);
            }
        }
    }
}

pub fn render() void {
    var iter = world.components.sprite.iterator();
    while (iter.next()) |entry| {
        const id = entry.key_ptr.*;
        const e = world.get(id);

        if (e.sprite) |spr| {
            // Use Hitbox for position
            if (e.hitbox) |box| {
                const source = rl.Rectangle{ .x = 0, .y = 0, .width = @floatFromInt(spr.width), .height = @floatFromInt(spr.height) };
                const dest = rl.Rectangle{ .x = box.x, .y = box.y, .width = @floatFromInt(spr.width), .height = @floatFromInt(spr.height) };
                const origin = rl.Vector2{ .x = 0, .y = 0 };

                rl.drawTexturePro(spr.*, source, dest, origin, 0.0, rl.Color.white);
            }
        }
    }
}
