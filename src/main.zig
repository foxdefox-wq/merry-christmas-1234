const std = @import("std");
const b2 = @import("box2d.zig").c;
const rl = @import("raylib");
const ecs = @import("ecs.zig");

const ZERO = rl.Vector2{ .x = 0, .y = 0 };

const Velocity = union(enum) {
    Velocity: rl.Vector3,
    NPosition: rl.Vector3,
};

const Body = struct {
    id: b2.struct_b2BodyId,
    definition: b2.struct_b2BodyDef,
};

const Animator = union(enum) {
    Texture: rl.Texture2D,
    Animator: i32,
};

const Components = struct {
    PlayerCamera: ?rl.Camera2D = null,
    Body: ?Body = null,
    Animator: ?Animator = null,
};

const enum_components = std.meta.FieldEnum(Components);

const CameraPrefab = Components{
    .PlayerCamera = rl.Camera2D{
        .offset = ZERO,
        .rotation = 0,
        .target = ZERO,
        .zoom = 1,
    },
};

fn deinit_fn(ptr: *anyopaque, field: std.builtin.Type.StructField) void {
    if (field.type == ?Animator) {
        rl.unloadTexture(ptr);
    }
}

pub fn main() !void {
    rl.initWindow(800, 800, "Test");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const World = ecs.World(Components, deinit_fn);
    var world = World.init(gpa.allocator());
    defer world.deinit();

    const camera_id = try world.spawn(CameraPrefab);
    const camera_ptr = world.getComponent(camera_id, enum_components.PlayerCamera);

    while (!rl.windowShouldClose()) {
        update(rl.getFrameTime(), camera_ptr);
    }
}

fn update(delta: f32, camera_ptr: *?rl.Camera2D) void {
    _ = delta;
    rl.beginDrawing();
    defer rl.endDrawing();
    rl.clearBackground(.white);

    if (camera_ptr.*) |camera| {
        rl.beginMode2D(camera);
        defer rl.endMode2D();
    } else {
        @panic("Uhh, theres not a camera");
    }
}
