const std = @import("std");
const rl = @import("raylib-zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    rl.initWindow(800, 600, "Test ECS");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    const camera = rl.Camera2D{
        .offset = .{ .x = 0, .y = 0 },
        .target = .{ .x = 0, .y = 0 },
        .rotation = 0,
        .zoom = 1.0,
    };

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(rl.Color.ray_white);
        rl.beginMode2D(camera);
        rl.endMode2D();
        rl.endDrawing();
    }
}
