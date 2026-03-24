const std = @import("std");
const b2 = @import("box2d.zig").c;
const rl = @import("raylib");
const ecs = @import("ecs.zig");
const kb = @import("keybind.zig");

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

const PlayerController = struct {
    speed: f32,
};

const Bullet = struct {
    lifetime: f32,
    speed: f32,
};

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
    bullet: ?Bullet = null,
};

fn deinitFn(ptr: *anyopaque, field: std.builtin.Type.StructField) void {
    _ = ptr;
    _ = field;
}

const WorldType = ecs.World(Components, deinitFn);

// Spawn helpers
fn spawnCamera(world: *WorldType) !u32 {
    return try world.spawn(.{
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
}

fn spawnPlayer(world: *WorldType, phys_world: b2.b2WorldId, pos: rl.Vector2) !u32 {
    const texture = try rl.loadTexture("assets/haha.png");

    const half_w: f32 = 30.0 / PIXELS_PER_METER;
    const half_h: f32 = 30.0 / PIXELS_PER_METER;

    var body_def = b2.b2DefaultBodyDef();
    body_def.type = b2.b2_dynamicBody;
    body_def.position = .{ .x = pos.x, .y = pos.y };

    const body_id = b2.b2CreateBody(phys_world, &body_def);

    var box = b2.b2MakeBox(half_w, half_h);
    var shape_def = b2.b2DefaultShapeDef();
    const shape_id = b2.b2CreatePolygonShape(body_id, &shape_def, &box);

    return try world.spawn(.{
        .physics = .{
            .body = .{
                .body_id = body_id,
                .shape_id = shape_id,
                .render_type = .rectangle,
            },
        },
        .animator = .{ .static = texture },
        .player_controller = .{ .speed = 100.0 },
    });
}

fn spawnBullet(
    world: *WorldType,
    phys_world: b2.b2WorldId,
    bullet_texture: rl.Texture2D,
    pos: b2.b2Vec2,
    dir: b2.b2Vec2,
) !u32 {
    const half_w: f32 = 10.0 / PIXELS_PER_METER;
    const half_h: f32 = 10.0 / PIXELS_PER_METER;

    var body_def = b2.b2DefaultBodyDef();
    body_def.type = b2.b2_dynamicBody;
    body_def.position = pos;
    body_def.isBullet = true;

    const body_id = b2.b2CreateBody(phys_world, &body_def);

    var box = b2.b2MakeBox(half_w, half_h);
    var shape_def = b2.b2DefaultShapeDef();
    const shape_id = b2.b2CreatePolygonShape(body_id, &shape_def, &box);

    const bullet_speed: f32 = 15.0;
    b2.b2Body_SetLinearVelocity(body_id, .{
        .x = dir.x * bullet_speed,
        .y = dir.y * bullet_speed,
    });

    return try world.spawn(.{
        .physics = .{
            .body = .{
                .body_id = body_id,
                .shape_id = shape_id,
                .render_type = .rectangle,
            },
        },
        .animator = .{ .static = bullet_texture },
        .bullet = .{
            .lifetime = 30.0,
            .speed = bullet_speed,
        },
    });
}

// Main
pub fn main() !void {
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Test");
    defer rl.closeWindow();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    rl.setTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var world = WorldType.init(gpa.allocator());
    defer world.deinit();

    const ball_sound = try rl.loadSound("assets/ball.wav");
    defer rl.unloadSound(ball_sound);

    const bullet_texture = try rl.loadTexture("assets/360.png");
    defer rl.unloadTexture(bullet_texture);

    // Physics world
    var world_def = b2.b2DefaultWorldDef();
    world_def.gravity = b2.b2Vec2{ .x = 0, .y = 0 };
    const phys_world = b2.b2CreateWorld(&world_def);
    defer b2.b2DestroyWorld(phys_world);

    _ = try world.spawn(.{
        .physics = .{ .world = phys_world },
    });

    const camera_id = try spawnCamera(&world);
    _ = try spawnPlayer(&world, phys_world, .{ .x = 0, .y = 0 });

    while (!rl.windowShouldClose()) {
        update(rl.getFrameTime(), &world, camera_id, ball_sound, bullet_texture);
    }
}

fn updateCamera(world: *WorldType, cam: *rl.Camera2D) void {
    const player_pos: b2.b2Vec2 = blk: {
        const players = world.components.items(.player_controller);
        const bodies = world.components.items(.physics);

        for (players, bodies) |maybe_player, maybe_body| {
            if (maybe_player == null or maybe_body == null) continue;

            const phys = maybe_body.?;
            switch (phys) {
                .body => |body| break :blk b2.b2Body_GetPosition(body.body_id),
                .world => continue,
            }
        }

        break :blk .{ .x = 0, .y = 0 };
    };

    const target_x = player_pos.x * PIXELS_PER_METER;
    const target_y = player_pos.y * PIXELS_PER_METER;

    const lerp_factor: f32 = 0.3;

    cam.target = rl.Vector2{
        .x = std.math.lerp(cam.target.x, target_x, lerp_factor),
        .y = std.math.lerp(cam.target.y, target_y, lerp_factor),
    };
}

// Update loop
fn update(
    delta: f32,
    world: *WorldType,
    camera_id: u32,
    ball_sound: rl.Sound,
    bullet_texture: rl.Texture2D,
) void {
    processAnimators(world);

    const phys_world = findPhysicsWorld(world) orelse return;

    // Get camera pointer for player aiming before possible spawn
    {
        const camera_ptr = world.getComponent(camera_id, .camera);
        const cam: *rl.Camera2D = &camera_ptr.*.?;
        movePlayer(world, cam, phys_world, ball_sound, bullet_texture) catch {};
    }

    stepPhysics(world, delta);
    updateBullets(world, delta);

    // Reacquire camera pointer after any world.spawn/world mutation
    const camera_ptr = world.getComponent(camera_id, .camera);
    const cam: *rl.Camera2D = &camera_ptr.*.?;

    updateCamera(world, cam);

    rl.beginDrawing();
    defer rl.endDrawing();
    rl.clearBackground(.white);

    if (camera_ptr.*) |*camera| {
        rl.beginMode2D(camera.*);
        camera.zoom += rl.getMouseWheelMove();
        rl.drawCircle(0, 0, 5, .red);
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
    const phys_world = findPhysicsWorld(world) orelse return;
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

fn updateBullets(world: *WorldType, delta: f32) void {
    const bullets = world.components.items(.bullet);
    const physics_list = world.components.items(.physics);
    const animator_list = world.components.items(.animator);

    for (bullets, physics_list, animator_list) |*maybe_bullet, *maybe_phys, *maybe_anim| {
        if (maybe_bullet.* == null or maybe_phys.* == null) continue;

        var bullet = maybe_bullet.*.?;
        bullet.lifetime -= delta;

        if (bullet.lifetime <= 0) {
            const phys = maybe_phys.*.?;
            switch (phys) {
                .body => |body| b2.b2DestroyBody(body.body_id),
                .world => {},
            }

            maybe_bullet.* = null;
            maybe_phys.* = null;
            maybe_anim.* = null;
        } else {
            maybe_bullet.* = bullet;
        }
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

fn movePlayer(
    world: *WorldType,
    camera: *rl.Camera2D,
    phys_world: b2.b2WorldId,
    ball_sound: rl.Sound,
    bullet_texture: rl.Texture2D,
) !void {
    const player_controllers = world.components.items(.player_controller);
    const physics_list = world.components.items(.physics);

    var shoot_pos: ?b2.b2Vec2 = null;
    var shoot_dir: ?b2.b2Vec2 = null;

    for (player_controllers, physics_list) |maybe_pc, maybe_phys| {
        if (maybe_pc == null or maybe_phys == null) continue;

        const pc = maybe_pc.?;
        const phys = maybe_phys.?;

        const body = switch (phys) {
            .body => |body| body,
            .world => continue,
        };

        const body_pos = b2.b2Body_GetPosition(body.body_id);
        const center = b2.b2Body_GetWorldCenterOfMass(body.body_id);

        const mouse_world_rl = rl.getScreenToWorld2D(rl.getMousePosition(), camera.*);
        const mouse_x = mouse_world_rl.x / PIXELS_PER_METER;
        const mouse_y = mouse_world_rl.y / PIXELS_PER_METER;

        const dx = mouse_x - body_pos.x;
        const dy = mouse_y - body_pos.y;
        const angle = std.math.atan2(dy, dx);

        const rot = b2.b2Rot{
            .c = @cos(angle),
            .s = @sin(angle),
        };
        b2.b2Body_SetTransform(body.body_id, body_pos, rot);

        if (rl.isKeyDown(.w)) {
            b2.b2Body_ApplyForce(body.body_id, .{ .x = 0, .y = -pc.speed }, center, true);
        }
        if (rl.isKeyDown(.s)) {
            b2.b2Body_ApplyForce(body.body_id, .{ .x = 0, .y = pc.speed }, center, true);
        }
        if (rl.isKeyDown(.a)) {
            b2.b2Body_ApplyForce(body.body_id, .{ .x = -pc.speed, .y = 0 }, center, true);
        }
        if (rl.isKeyDown(.d)) {
            b2.b2Body_ApplyForce(body.body_id, .{ .x = pc.speed, .y = 0 }, center, true);
        }

        if (rl.isMouseButtonPressed(.left)) {
            const len = @sqrt(dx * dx + dy * dy);
            if (len > 0.0001) {
                shoot_pos = body_pos;
                shoot_dir = .{
                    .x = dx / len,
                    .y = dy / len,
                };
            }
        }
    }

    if (shoot_pos) |pos| {
        const dir = shoot_dir.?;
        rl.playSound(ball_sound);
        _ = try spawnBullet(world, phys_world, bullet_texture, pos, dir);
    }
}
