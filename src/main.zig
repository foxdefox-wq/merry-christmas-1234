const rl = @import("raylib");
const ecs = @import("ecs.zig");
const b2 = @import("box2d.zig").c;

// Component structs
const Velocity = union(enum) {
    NPosition: rl.Vector3,
    Velocity: rl.Vector3,
};

// Same indices
const Components = struct {
    Position: rl.Vector3,
    Velocity: Velocity,
    Texture: rl.Texture2D,
};

const DeInitFns = .{
    null,
    null,
    deInitTexture,
};

// Deinit functions
fn deInitTexture(item: *anyopaque) void {
    const texture: *rl.Texture2D = @ptrCast(@alignCast(item));
    texture.unload();
}

pub fn main() !void {
    const world = ecs.World(Components, DeInitFns);
    const player = try world.spawn();
    rl.initWindow(800, 450, "Test");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        update();
    }
}

fn update() void {}
