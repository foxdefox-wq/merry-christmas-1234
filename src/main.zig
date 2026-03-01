const std = @import("std");
const rl = @import("raylib");

pub fn main() !void {
    rl.initWindow(800, 600, "Christmas");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        update(rl.getFrameTime());

        rl.clearBackground(.white);
    }
}

pub fn update(dt: i32) void {
    physics(dt);
    render();
}

pub fn physics(dt: i32) void {}

pub fn render() void {}
