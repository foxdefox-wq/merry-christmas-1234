const std = @import("std");
const rl = @import("raylib");

const ID = u32;
const Position = rl.Vector2;
const Velocity = rl.Vector2;

pub const Sprite = struct {
    image: rl.Texture2D,
    destination: rl.Rectangle,
};

pub const World = struct {
    allocator: std.mem.Allocator,
    next_id: ID = 0,

    players: std.AutoArrayHashMap(ID, ID),
    positions: std.AutoHashMap(ID, Position),
    velocities: std.AutoHashMap(ID, Velocity),
    sprites: std.AutoArrayHashMap(ID, Sprite),

    pub fn init(allocator: std.mem.Allocator) World {
        var self: World = undefined;
        self.allocator = allocator;
        self.next_id = 0;

        inline for (std.meta.fields(World)) |field| {
            if (comptime (std.mem.eql(u8, field.name, "next_id") or
                std.mem.eql(u8, field.name, "allocator"))) continue;

            @field(self, field.name) = field.type.init(allocator);
        }
        return self;
    }

    pub fn deinit(self: *World) void {
        inline for (std.meta.fields(World)) |field| {
            const T = field.type;
            switch (@typeInfo(T)) {
                .@"struct", .@"union", .@"enum" => {
                    if (comptime @hasDecl(T, "deinit")) {
                        @field(self, field.name).deinit();
                    }
                },
                else => {},
            }
        }
    }

    pub fn spawn(self: *World) ID {
        const id = self.next_id;
        self.next_id += 1;
        return id;
    }
};

var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
var world: World = undefined;
var camera: rl.Camera2D = undefined;

pub fn main() !void {
    const allocator = gpa_state.allocator();
    defer _ = gpa_state.deinit();

    world = World.init(allocator);
    defer world.deinit();

    const player = world.spawn();
    try world.positions.put(player, .{ .x = 0, .y = 0 });
    const playSprite: Sprite = .{ .image = rl.loadTexture("assets/haha.png"), .destination = rl.Rectangle{
        .x = 0,
        .y = 0,
        .width = 10,
        .height = 10,
    } };
    try world.sprites.put(player, playSprite);
    try world.velocities.put(player, .{ .x = 0, .y = 0 });

    rl.initWindow(800, 600, "Christmas");
    defer rl.closeWindow();
    rl.setTargetFPS(144);

    camera = rl.Camera2D{
        .offset = .{ .x = 400, .y = 300 },
        .target = .{ .x = 0, .y = 0 },
        .rotation = 0,
        .zoom = 1.0,
    };

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();
        update(dt);

        rl.beginDrawing();
        rl.clearBackground(.white);

        rl.beginMode2D(camera);
        render();
        rl.endMode2D();
        rl.endDrawing();
    }
}

pub fn update(dt: f32) void {
    var posIter = world.positions.iterator();
    for (posIter.next(), 0..) |entry, index| {
        const pos = entry.value_ptr;
        if (index == 0) {
            const t = 5.0 * dt;
            camera.target.x = std.math.lerp(camera.target.x, pos.x, t);
            camera.target.y = std.math.lerp(camera.target.y, pos.y, t);
        }
    }
}

pub fn render() void {
    var iter = world.sprites.iterator();
    while (iter.next()) |entry| {
        const sprite = entry.value_ptr;
        const destination = sprite.destination;
        const image = sprite.image;
        const source = rl.Rectangle{ .x = 0, .y = 0, .width = @floatFromInt(image.width), .height = @floatFromInt(image.height) };
        const origin = rl.Vector2{ .x = 0, .y = 0 };
        rl.drawTexturePro(image, source, destination, origin, 0.0, rl.Color.white);
    }
}
