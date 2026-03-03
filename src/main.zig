const std = @import("std");
const rl = @import("raylib");

const ecs = @import("ecs.zig");

const MyComponents = struct {
    velocity: rl.Vector2,
    body: rl.Rectangle,
    color: rl.Color,
};

const Game = ecs.Gen(MyComponents);

fn physicsSystem(id: ecs.ID, vel: *rl.Vector2, body: *rl.Rectangle) void {
    _ = id;
    const dt = rl.getFrameTime();

    body.x += vel.x * dt;
    body.y += vel.y * dt;

    if (body.x < 0 or body.x > 800) vel.x *= -1;
    if (body.y < 0 or body.y > 600) vel.y *= -1;
}

fn renderSystem(id: ecs.ID, body: *rl.Rectangle, color: *rl.Color) void {
    _ = id;
    rl.drawRectangleRec(body.*, color.*);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var world = Game.World.init(allocator);
    defer world.deinit();

    const e1 = try world.spawn();
    try world.addComp(e1, "body", rl.Rectangle{ .x = 400, .y = 300, .width = 50, .height = 50 });
    try world.addComp(e1, "velocity", rl.Vector2{ .x = 200, .y = 200 });
    try world.addComp(e1, "color", rl.Color.red);

    const e2 = try world.spawn();
    try world.addComp(e2, "body", rl.Rectangle{ .x = 100, .y = 100, .width = 80, .height = 80 });
    try world.addComp(e2, "color", rl.Color.blue);

    rl.initWindow(800, 600, "Christmas ECS");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    const camera = rl.Camera2D{
        .offset = .{ .x = 0, .y = 0 },
        .target = .{ .x = 0, .y = 0 },
        .rotation = 0,
        .zoom = 1.0,
    };

    while (!rl.windowShouldClose()) {
        world.query(.{ "velocity", "body" }, physicsSystem);

        rl.beginDrawing();
        rl.clearBackground(rl.Color.ray_white);
        rl.beginMode2D(camera);

        world.query(.{ "body", "color" }, renderSystem);

        rl.endMode2D();
        rl.endDrawing();
    }
}
