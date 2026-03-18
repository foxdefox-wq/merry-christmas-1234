const raylib = @import("raylib");
const b2 = @import("box2d.zig").c;

pub fn main() !void {
    var world_def = b2.b2DefaultWorldDef();
    world_def.gravity = .{ .x = 0.0, .y = 9.8 };
    const world = b2.b2CreateWorld(&world_def);
    defer b2.b2DestroyWorld(world);

    // Ground
    var ground_def = b2.b2DefaultBodyDef();
    ground_def.position = .{ .x = 0.0, .y = 8.0 };
    const ground = b2.b2CreateBody(world, &ground_def);

    const ground_box = b2.b2MakeBox(10.0, 0.5);
    var ground_shape_def = b2.b2DefaultShapeDef();
    _ = b2.b2CreatePolygonShape(ground, &ground_shape_def, &ground_box);

    // Falling box
    var body_def = b2.b2DefaultBodyDef();
    body_def.type = b2.b2_dynamicBody;
    body_def.position = .{ .x = 0.0, .y = 2.0 };
    const body = b2.b2CreateBody(world, &body_def);

    const dynamic_box = b2.b2MakeBox(0.5, 0.5);
    var shape_def = b2.b2DefaultShapeDef();
    shape_def.density = 1.0;
    _ = b2.b2CreatePolygonShape(body, &shape_def, &dynamic_box);

    raylib.initWindow(800, 450, "box2d falling box");
    defer raylib.closeWindow();
    raylib.setTargetFPS(60);

    const ppm: f32 = 50.0;

    while (!raylib.windowShouldClose()) {
        b2.b2World_Step(world, 1.0 / 60.0, 4);

        const pos = b2.b2Body_GetPosition(body);

        raylib.beginDrawing();
        defer raylib.endDrawing();

        raylib.clearBackground(.white);

        // ground
        raylib.drawRectangle(0, 400, 800, 25, .dark_gray);

        // box
        raylib.drawRectangle(
            @intFromFloat(pos.x * ppm + 400.0 - 25.0),
            @intFromFloat(pos.y * ppm - 25.0),
            50,
            50,
            .red,
        );

        raylib.drawText("If the red box falls, box2d works", 20, 20, 20, .black);
    }
}
