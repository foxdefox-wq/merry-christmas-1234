const std = @import("std");
const rl = @import("raylib");

var camera: rl.Camera2D = .{
    .target = rl.Vector2{ .x = 0, .y = 0 },
    .offset = rl.Vector2{ .x = 0, .y = 0 },
    .rotation = 0,
    .zoom = 0,
};

pub fn main() !void {
    //Init
    rl.initWindow(800, 600, "Christmas");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        //Update Loop
        rl.beginDrawing();
        defer rl.endDrawing();
        camera.begin();
        defer camera.end();
        update(rl.getFrameTime());
        rl.clearBackground(.white);
    }
}

pub fn update(dt: f32) void {
    physics(dt);
    render();
}

pub fn physics(dt: f32) void {
    inline for (std.meta.tags(rl.KeyboardKey)) |key| {
        if (rl.isKeyDown(key)) {
            switch (key) {
                .w => std.debug.print("w held\n", .{}),
                else => {},
            }
        }

        if (rl.isKeyPressed(key)) {
            switch (key) {
                .a => std.debug.print("a pressed\n", .{}),
                else => {},
            }
        }
    }

    _ = dt;
}

pub fn render() void {
    rl.drawCircle(0, 0, 10, .red);
}
