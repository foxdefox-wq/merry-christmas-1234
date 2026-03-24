const std = @import("std");
const b2 = @import("box2d.zig").c;
const rl = @import("raylib");
const ecs = @import("ecs.zig");

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 800;
const PIXELS_PER_METER: f32 = 32.0;

// Components
const Velocity = union(enum) {
    velocity: rl.Vector2,
    teleport: rl.Vector2,
};

const AnimatedTexture = struct {
    current: rl.Texture2D,
    next: rl.Texture2D,
};

const PlayerController = struct {};

const Animator = union(enum) {
    static: rl.Texture2D,
    animated: AnimatedTexture,
};

const RenderType = enum {
    rectangle,
};

const PhysicsBody = struct {
    body_id: b2.b2BodyId,
    shape_id: b2.b2ShapeId,
    render_type: RenderType,
    PlayerController: ?PlayerController,
};

const Physics = union(enum) {
    world: b2.b2WorldId,
    body: PhysicsBody,
};

const Components = struct {
    camera: ?rl.Camera2D = null,
    animator: ?Animator = null,
    physics: ?Physics = null,
    velocity: ?Velocity = null,
    player_controller: ?PlayerController = null,
};

fn deinitFn(ptr: *anyopaque, field: std.builtin.Type.StructField) void {
    _ = ptr;
    _ = field;
}

const WorldType = ecs.World(Components, deinitFn);

// Spawn helpers
fn spawnCamera(world: *WorldType) !*?rl.Camera2D {
    const id = try world.spawn(.{
        .camera = rl.Camera2D{
            .offset = .{
                .x = @as(f32, SCREEN_WIDTH) / 2.0,
                .y = @as(f32, SCREEN_HEIGHT) / 2.0,
            },
            .rotation = 0,
            .target = .{ .x = 0, .y = 0 },
            .zoom = 1,
        },
    });
    return world.getComponent(id, .camera);
}

fn spawnBox(
    world: *WorldType,
    phys_world: b2.b2WorldId,
    body_type: c_uint,
    x: f32,
    y: f32,
    half_w: f32,
    half_h: f32,
    density: f32,
    texture: rl.Texture2D,
) !void {
    var body_def = b2.b2DefaultBodyDef();
    body_def.type = body_type;
    body_def.position = .{ .x = x, .y = y };

    const body_id = b2.b2CreateBody(phys_world, &body_def);

    var box = b2.b2MakeBox(half_w, half_h);

    var shape_def = b2.b2DefaultShapeDef();
    shape_def.density = density;

    const shape_id = b2.b2CreatePolygonShape(body_id, &shape_def, &box);

    _ = try world.spawn(.{
        .physics = .{
            .body = .{
                .body_id = body_id,
                .shape_id = shape_id,
                .render_type = .rectangle,
            },
        },
        .animator = .{ .static = texture },
    });
}

// Main
pub fn main() !void {
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Test");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var world = WorldType.init(gpa.allocator());
    defer world.deinit();

    // Physics world
    const phys_world = try b2.b2DefaultWorldDef();
    defer b2.b2DestroyWorld(phys_world);

    // Spawn camera
    const camera_id = try world.spawn(.{
        .camera = rl.Camera2D{
            .offset = .{
                .x = @as(f32, SCREEN_WIDTH) / 2.0,
                .y = @as(f32, SCREEN_HEIGHT) / 2.0,
            },
            .rotation = 0,
            .target = .{ .x = 0, .y = 0 },
            .zoom = 1,
        },
    });

    // Game loop
    while (!rl.windowShouldClose()) {
        // Pointer changes every game loop
        const camera_ptr = world.getComponent(camera_id, .camera);
        update(rl.getFrameTime(), &world, camera_ptr);
    }
}

// Update loop
fn update(delta: f32, world: *WorldType, camera_ptr: *?rl.Camera2D) void {
    processAnimators(world);
    stepPhysics(world, delta);

    rl.beginDrawing();
    defer rl.endDrawing();
    rl.clearBackground(.white);

    if (camera_ptr.*) |camera| {
        rl.beginMode2D(camera);
        defer rl.endMode2D();
        drawBodies(world);
    } else {
        @panic("No camera found");
    }
}

// Physics
fn findPhysicsWorld(world: *WorldType) ?b2.b2WorldId {
    for (world.components.items(.physics)) |maybe| {
        if (maybe) |p| {
            switch (p) {
                .world => |wid| return wid,
                .body => {},
            }
        }
    }
    return null;
}

fn stepPhysics(world: *WorldType, delta: f32) void {
    const phys_world = findPhysicsWorld(world) orelse @compileError("No physics world");
    b2.b2World_Step(phys_world, delta, 4);

    const physics_list = world.components.items(.physics);
    const velocity_list = world.components.items(.velocity);

    for (physics_list, velocity_list) |maybe_phys, maybe_vel| {
        if (maybe_phys == null or maybe_vel == null) continue;

        const phys = maybe_phys.?;
        const vel = maybe_vel.?;

        switch (phys) {
            .body => |body| applyVelocity(body.body_id, vel),
            .world => {},
        }
    }
}

fn applyVelocity(body_id: b2.b2BodyId, vel: Velocity) void {
    switch (vel) {
        .velocity => |v| {
            b2.b2Body_SetLinearVelocity(body_id, .{ .x = v.x, .y = v.y });
        },
        .teleport => |p| {
            b2.b2Body_SetTransform(
                body_id,
                .{ .x = p.x, .y = p.y },
                b2.b2Body_GetRotation(body_id),
            );
        },
    }
}

// Animators
fn processAnimators(world: *WorldType) void {
    for (world.components.items(.animator)) |*maybe_animator| {
        if (maybe_animator.*) |anim| {
            switch (anim) {
                .animated => |at| {
                    maybe_animator.* = .{ .static = at.next };
                },
                .static => {},
            }
        }
    }
}

// Drawing
fn drawBodies(world: *WorldType) void {
    const physics_list = world.components.items(.physics);
    const animator_list = world.components.items(.animator);

    for (physics_list, animator_list) |maybe_phys, maybe_anim| {
        if (maybe_phys == null or maybe_anim == null) continue;

        const phys = maybe_phys.?;
        const anim = maybe_anim.?;

        switch (phys) {
            .body => |body| {
                switch (body.render_type) {
                    .rectangle => drawRectangleBody(body, anim),
                }
            },
            .world => {},
        }
    }
}

fn drawRectangleBody(body: PhysicsBody, anim: Animator) void {
    const body_id = body.body_id;
    var shape_id = body.shape_id;

    const pos = b2.b2Body_GetPosition(body_id);
    const rot = b2.b2Body_GetRotation(body_id);
    const angle_deg = std.math.atan2(rot.s, rot.c) * (180.0 / std.math.pi);

    const texture = switch (anim) {
        .static => |t| t,
        .animated => |at| at.current,
    };

    _ = b2.b2Body_GetShapes(body_id, &shape_id, 1);
    const poly = b2.b2Shape_GetPolygon(shape_id);

    const width = (poly.vertices[1].x - poly.vertices[0].x) * PIXELS_PER_METER;
    const height = (poly.vertices[2].y - poly.vertices[1].y) * PIXELS_PER_METER;

    rl.drawTexturePro(
        texture,
        .{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(texture.width),
            .height = @floatFromInt(texture.height),
        },
        .{
            .x = pos.x * PIXELS_PER_METER,
            .y = pos.y * PIXELS_PER_METER,
            .width = width,
            .height = height,
        },
        .{ .x = width / 2.0, .y = height / 2.0 },
        angle_deg,
        .white,
    );
}
