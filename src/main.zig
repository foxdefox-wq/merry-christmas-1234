const std = @import("std");
const rl = @import("raylib");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    rl.initWindow(800, 600, "Christmas ECS");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    const camera = rl.Camera2D{
        .offset = .{ .x = 0, .y = 0 },
        .target = .{ .x = 0, .y = 0 },
        .rotation = 0,
        .zoom = 1.0,
    };

    const VTable = struct {
        move: ?*const fn (*anyopaque, rl.Vector2) void = null,
        draw: ?*const fn (*anyopaque) void = null,
    };

    const EntityPrototype = struct {
        id: u32,
        self: *anyopaque,
        vtable: VTable,
    };

    const World = struct {
        entities: std.AutoArrayHashMap(u32, *anyopaque),
        alloc: std.mem.Allocator,
        var next_id: u32 = 1;
        var Self = @This();

        fn getID() u32 {
            const id = next_id;
            next_id += 1;
            return id;
        }

        pub fn spawnEntity(ptr: *anyopaque) u32 {
            const entity: *EntityPrototype = @ptrCast(@alignCast(ptr));
            entity.id = getID();
            entity.self = entity;
        }

        pub fn deleteEntity(id: u32) !void {
            Self.
        }

        pub fn update() void {
            std.log.debug("Updating", .{});
        }

        pub fn init(alloc: std.mem.Allocator) @This() {
            entities.init(alloc);
            return .{
                .allocator = alloc,
            };
        }
    };

    const world = World.init(gpa);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(rl.Color.ray_white);
        rl.beginMode2D(camera);
        world.update();

        rl.endMode2D();
        rl.endDrawing();
    }
}
