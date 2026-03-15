const std = @import("std");
const rl = @import("raylib-zig");

fn cleanupFn(comptime T: type) ?*const fn (T) void {
    return if (T == rl.Texture2D)
        &rl.unloadTexture
    else if (T == rl.RenderTexture2D)
        &rl.unloadRenderTexture
    else if (T == rl.Image)
        &rl.unloadImage
    else if (T == rl.Mesh)
        &rl.unloadMesh
    else
        null;
}

const EntityData = struct {
    Position: ?rl.Vector3 = null,
    Velocity: ?rl.Vector3 = null,
    Texture: ?rl.Texture2D = null,

    pub fn makeEntity(data: anytype) EntityData {
        var entity = EntityData{};
        inline for (std.meta.fields(@TypeOf(data))) |field| {
            if (!@hasField(EntityData, field.name)) {
                @compileError("Unknown field: " ++ field.name);
            }
            @field(entity, field.name) = @field(data, field.name);
        }
        return entity;
    }
};

pub const World = struct {
    const Self = @This();
    var next_id: u32 = 0;

    allocator: std.mem.Allocator,
    entities: std.MultiArrayList(EntityData),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .entities = .{},
        };
    }

    fn getNextID() u32 {
        const id = next_id;
        next_id += 1;
        return id;
    }

    pub fn spawn(self: *Self, entity: EntityData) !u32 {
        const id = getNextID();
        try self.entities.append(self.allocator, entity);
        return id;
    }

    pub fn kill(self: *Self, id: u32) void {
        if (id >= self.entities.len) return;
        cleanupEntity(&self.entities, id);
        self.entities.set(id, .{});
    }

    pub fn deinit(self: *Self) void {
        var i: usize = 0;
        while (i < self.entities.len) : (i += 1) {
            cleanupEntity(&self.entities, i);
        }
        self.entities.deinit(self.allocator);
    }

    fn cleanupEntity(entities: *std.MultiArrayList(EntityData), idx: usize) void {
        inline for (std.meta.fields(EntityData)) |field| {
            const info = @typeInfo(field.type);
            if (info != .Optional) continue;

            const Inner = info.Optional.child;
            if (comptime cleanupFn(Inner)) |deinit_fn| {
                const slice = entities.items(@enumFromInt(field.index));
                if (slice[idx]) |val| {
                    deinit_fn(val);
                    slice[idx] = null;
                }
            }
        }
    }

    pub fn getComponents(self: *Self, id: u32) ?EntityData {
        if (id >= self.entities.len) return null;
        return self.entities.get(id);
    }

    pub fn setComponents(self: *Self, id: u32, data: EntityData) void {
        if (id >= self.entities.len) return;
        self.entities.set(id, data);
    }
};
