const std = @import("std");
const b2 = @import("box2d.zig").c;
const rl = @import("raylib");
const ecs = @import("ecs.zig");

// For some reason raylibs default .zero() doesn't work so
const ZERO = rl.Vector2{ .x = 0, .y = 0 };

// Components here
const Body = struct {
    // We use Box2D's getters and setters to adjust
    // It's like a mini ecs inside our ecs
    body_id: b2.b2BodyId,
    shape_id: b2.b2ShapeId,
};

// Either teleport to [Next Position] or apply velocity to the entities "Body" and consume it
const Velocity = union(enum) {
    Velocity: rl.Vector3,
    NPosition: rl.Vector3,
};

const AnimatedTexture = struct {
    Texture: rl.Texture2D,
    // [Next Texture] will be consumed and set to current texture
    // This is just a very simple way of doing animations for now
    // Later on we could make sprite sheets and some config settings for how to loop through or whatever
    NTexture: rl.Texture2D,
};

const Animator = union(enum) {
    StaticTexture: rl.Texture2D,
    AnimatedTexture: AnimatedTexture,
};

// We'll make all the components here
// It might get a little messy later on with a bunch of one off, "isThisorThat : bool"
// So try to avoid that
const Components = struct {
    PlayerCamera: ?rl.Camera2D = null,
    Animator: ?AnimatedTexture = null,

    // One thing cannot have both at once
    // Therefore we seperate into one union
    // What to call it?
    BodyID: Box2D_ID,
};

const Box2D_ID = union(enum) {
    World: b2.b2WorldId,
    Body: b2.b2BodyId,
};
// Prefabs
const CameraPrefab = Components{
    .PlayerCamera = rl.Camera2D{
        .offset = ZERO,
        .rotation = 0,
        .target = ZERO,
        .zoom = 1,
    },
};

// Seperate from entity component system world!!!
// Used for Box2D
// DON'T PUT RUNTIME STUFF IN HERE OR INIT() FUNCTIONS
// THERES PROBABLY A BETTER WAY TO DO IT
const PhysicsWorldPrefab = Components{
    .PhysicsWorldID = b2.b2WorldId,
};

const BodyPrefab = struct {
    // What only one thing???
    // Well it's because upon creation we store the rest of the data, velocity and whatnot into the Box2D ecs
    // Kinda weird how we're like juggling two id systems
    id: b2.b2BodyId,
};

// TODO : Add deinit for Box2D ID
fn deinit_fn(ptr: *anyopaque, field: std.builtin.Type.StructField) void {
    if (field.type == ?AnimatedTexture) {
        rl.unloadTexture(ptr);
    }
}

// For Box2D pixel per meter calculations
const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 800;

pub fn main() !void {
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Test");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Creating the world, wow
    const World = ecs.World(Components, deinit_fn);
    var world = World.init(gpa.allocator());
    defer world.deinit();

    // No real reason for camera to be part of the ECS but it's cool right?
    const camera_ptr: *rl.Camera = blk: {
        const id = try world.spawn(CameraPrefab);
        break :blk world.getComponent(id, .PlayerCamera);
    };

    const phys_world_ptr: *b2.b2WorldId = blk: {
        const id = try world.spawn(PhysicsWorldPrefab);
        break :blk world.getComponent(id, .PhysicsWorldID);
    };

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
