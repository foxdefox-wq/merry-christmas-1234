const std = @import("std");
const rl = @import("raylib");

var camera: rl.Camera2D = .{
    .target = rl.Vector2{ .x = 0, .y = 0 },
    // Offset determines where "target" sits on the screen (Center of screen)
    .offset = rl.Vector2{ .x = 400, .y = 300 },
    .rotation = 0,
    .zoom = 1.0,
};

var pos = rl.Vector2{ .x = 0, .y = 0 };

const Keybind = struct {
    keys: []const rl.KeyboardKey,
    action: *const fn (rl.Vector2, f32) void,
    dir: rl.Vector2,
};

// Generic move function
pub fn move(dir: rl.Vector2, dt: f32) void {
    const speed = 300.0;
    pos.x += dir.x * speed * dt;
    pos.y += dir.y * speed * dt;
}

const movement_binds = [_]Keybind{
    .{ .keys = &.{ .w, .up }, .action = move, .dir = .{ .x = 0, .y = -1 } },
    .{ .keys = &.{ .s, .down }, .action = move, .dir = .{ .x = 0, .y = 1 } },
    .{ .keys = &.{ .a, .left }, .action = move, .dir = .{ .x = -1, .y = 0 } },
    .{ .keys = &.{ .d, .right }, .action = move, .dir = .{ .x = 1, .y = 0 } },
};

const allKeybinds = movement_binds;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    rl.initWindow(800, 600, "Camera Follow");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        // 1. Update Physics
        update(dt);

        // 2. Update Camera (Smooth Follow)
        // We move the camera target 10% of the way to the player position every frame
        const smooth_speed = 4.0 * dt;

        // Use std.math.lerp for smoothing
        camera.target.x = std.math.lerp(camera.target.x, pos.x, smooth_speed);
        camera.target.y = std.math.lerp(camera.target.y, pos.y, smooth_speed);

        // 3. Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        camera.begin();
        defer camera.end();

        render();
    }
}

pub fn update(dt: f32) void {
    for (allKeybinds) |bind| {
        for (bind.keys) |k| {
            if (rl.isKeyDown(k)) {
                bind.action(bind.dir, dt);
                break; // Don't apply same bind twice (e.g. W and Up pressed)
            }
        }
    }
}

pub fn render() void {
    // Draw grid to visualize movement
    rl.drawGrid(100, 50.0);
    // Draw the ball
    rl.drawCircleV(pos, 20, rl.Color.red);
}
