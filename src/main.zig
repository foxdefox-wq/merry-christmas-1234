const std = @import("std");
const rl = @import("raylib");
const ecs = @import("ecs.zig");

//Public variables
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var camera: rl.Camera2D = undefined;

pub fn main() !void {
    _ = gpa.allocator();
    defer gpa.deinit();
    rl.initWindow(800, 600, "Christmas");
    defer rl.closeWindow();
    rl.setTargetFPS(60);
    camera = rl.Camera2D{
        .offset = .{ .x = 400, .y = 300 },
        .target = .{ .x = 400, .y = 300 },
        .rotation = 0,
        .zoom = 1.0,
    };

    //Update loop
    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();
        update(dt);
        rl.beginDrawing();
        rl.clearBackground(.ray_white);
        rl.beginMode2D(camera);
        render();
        rl.endMode2D();
        rl.endDrawing();
    }
}

pub fn update(dt: f32) void {
    _ = dt;
}

pub fn render() void {}
