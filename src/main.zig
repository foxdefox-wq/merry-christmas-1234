const std = @import("std");
const ecs = @import("ecs.zig");
const rl = @import("raylib");

const Position = rl.Vector2;
const Hitbox = rl.Rectangle;
const Image = rl.Texture2D;
const Vector = rl.Vector2;
const MyComponents = struct {
    Velocity: Vector,
    Body: Hitbox,
    Sprite: Image,
};

const game = ecs.Gen(MyComponents);
const world = undefined;

pub fn main() !void {
    const gpa = std.heap.GeneralPurposeAllocator();
    defer _ = gpa.deinit();

    world = game.World.init(gpa);
    defer world.deinit();

    rl.initWindow(800, 600, "Christmas");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    const camera = rl.Camera2D{
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
        rl.endDrawing();
    }
}

pub fn update(dt: f32) void {
    game.World.addComp(self: *World, id: u32, comptime name: []const u8, val: anytype)
}

pub fn render() void {}
