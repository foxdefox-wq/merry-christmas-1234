const std = @import("std");
const b2 = @import("box2d.zig").c;
const rl = @import("raylib");
const ecs = @import("ecs.zig");

// For some reason raylibs default .zero() doesn't work so
const ZERO = rl.Vector2{ .x = 0, .y = 0 };

// Components here

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
    Animator: ?Animator = null,

    // One thing cannot have both at once
    // Therefore we seperate into one union
    // What to call it?
    Box2D_ID: Box2D_ID,
};

const Body = struct {
    // We use Box2D's getters and setters to adjust
    // It's like a mini ecs inside our ecs
    body_id: b2.b2BodyId,
    shape_id: b2.b2ShapeId,
};

const Box2D_ID = union(enum) {
    World: b2.b2WorldId,
    Body: Body,
};

// Seperate from entity component system world!!!
// Used for Box2D
// DON'T PUT RUNTIME STUFF IN HERE OR INIT() FUNCTIONS
// THERES PROBABLY A BETTER WAY TO DO IT
const PhysicsWorldPrefab = Components{
    .PhysicsWorldID = b2.b2WorldId,
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

fn deinit_fn(ptr: *anyopaque, field: std.builtin.Type.StructField) void {
    if (field.type == ?AnimatedTexture) {
        rl.unloadTexture(ptr);
    }
}

// For Box2D pixel per meter calculations
const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 800;
const WorldType = ecs.World(Components, deinit_fn);
// Let it be used everywhere
var world: WorldType = undefined;

pub fn main() !void {
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Test");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Creating the world, wow
    world = WorldType.init(gpa.allocator());
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
    _ = phys_world_ptr;

    while (!rl.windowShouldClose()) {
        update(rl.getFrameTime(), world, camera_ptr);
    }
}

fn update(delta: f32, w: WorldType, camera_ptr: *?rl.Camera2D) void {
    _ = delta;
    rl.beginDrawing();
    defer rl.endDrawing();
    rl.clearBackground(.white);
    draw(w);

    if (camera_ptr.*) |camera| {
        rl.beginMode2D(camera);
        defer rl.endMode2D();
    } else {
        @panic("Uhh, theres not a camera");
    }
}

fn draw(w: *WorldType) void {
    const box2d_ids = w.components.items(.Box2D_ID);
    const animators = w.components.items(.Animator);
    const scale: f32 = 32.0;

    lbl: for (box2d_ids, animators) |box2d_id, animator| {
        const bid = switch (box2d_id) {
            .World => continue :lbl, // Skip the global world object
            .Body => |id| id, // Unwrap and keep the actual ID
            // .none => continue :lbl, // If you have an empty state
            else => {
                @compileError("Flippin forgot to add the switch statement to the drawing thingie");
            }, // This reminds me to add it here
        };

        const b_id = bid.body_id;
        const texture = animator.StaticTexture;
        const pos = b2.b2Body_GetPosition(b_id);
        const angle = b2.b2Body_GetAngle(b_id); // In radians
        var s_id: b2.b2ShapeId = undefined;
        _ = b2.b2Body_GetShapes(b_id, &s_id, 1);
        const poly = b2.b2Shape_GetPolygon(s_id);

        // Box2D 'half-extents' means width is twice the vertex distance
        const width = (poly.vertices[1].x - poly.vertices[0].x) * scale;
        const height = (poly.vertices[2].y - poly.vertices[1].y) * scale;

        const dest_rect = rl.Rectangle{
            .x = pos.x * scale,
            .y = pos.y * scale,
            .width = width,
            .height = height,
        };

        const origin = rl.Vector2{ .x = width / 2, .y = height / 2 };
        rl.drawTexturePro(texture, rl.Rectangle{ .x = 0, .y = 0, .width = @floatFromInt(texture.width), .height = @floatFromInt(texture.height) }, dest_rect, origin, angle * (180.0 / std.math.pi), // Convert to degrees for Raylib
            rl.WHITE);
    }
}

// Helper func for drawing, prob gonna add more, like if we add liquids or constraints eventually
// Or we could just tag the shape with its "shape" but thats kinda idk man, might break, seems safer
// to just verify here even if its less performant
const shape_type = std.AutoHashMap(b2.b2BodyId, comptime V: type)
fn isSimpleRectangle(body_id: b2.b2BodyId) bool {
    // 1. Must have exactly one shape
    if (b2.b2Body_GetShapeCount(body_id) != 1) return false;

    var s_id: b2.b2ShapeId = undefined;
    const count = b2.b2Body_GetShapes(body_id, &s_id, 1);

    // 2. Must be a polygon
    if (count == 1 and b2.b2Shape_GetType(s_id) == .b2_polygonShape) {
        const poly = b2.b2Shape_GetPolygon(s_id);
        // 3. A "box" created via b2MakeBox always has 4 vertices
        return poly.count == 4;
    }

    return false;
}
