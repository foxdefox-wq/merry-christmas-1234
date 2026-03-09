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

    const Entity = struct {
        id: u32,
        self: *anyopaque,
        vtable: VTable,
    };

    const World = struct {
        allocator: std.mem.Allocator,
        next_id: u32 = 1,

        var entities = std.AutoArrayHashMap(u32, *anyopaque);

        pub fn init(alloc: std.mem.Allocator) World {
            return .{
                .allocator = alloc,
            };
        }
    };

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(rl.Color.ray_white);
        rl.beginMode2D(camera);

        rl.endMode2D();
        rl.endDrawing();
    }
}
