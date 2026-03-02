const std = @import("std");
const ecs = @import("ecs.zig");
const rl = @import("raylib");

const Position = rl.Vector2;
const MyComponents = struct {
    pos: Position,
};

const game = ecs.Gen(MyComponents);
var camera: rl.Camera2D = undefined;

pub fn main() !void {
    const gpa = std.heap.GeneralPurposeAllocator();
    _ = gpa.allocator();
    defer _ = gpa.deinit();
    rl.initWindow(800, 600, "Christmas");
    defer rl.closeWindow();
    rl.setTargetFPS(60);
    camera = rl.Camera2D{
        .offset = .{ .x = 400, .y = 300 },
        .target = .{ .x = 400, .y = 300 },
        .rotation = 0,
        .zoom = 1.0,
    };

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
    _ = dt;
}

pub fn render() void {}
