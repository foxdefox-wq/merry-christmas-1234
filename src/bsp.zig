const rl = @import("raylib");
const std = @import("std");
const Line = struct {
    p1: rl.Vector2,
    p2: rl.Vector2,
};

fn pointSide(line: Line, point: rl.Vector2) f32 {
    return (line.p2.x - line.p1.x) * (point.y - line.p1.y) -
        (line.p2.y - line.p1.y) * (point.x - line.p1.x);
}

const Node = struct {
    splitter: Line,
    front: ?*Node = null,
    back: ?*Node = null,

    fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        if (self.front) |f| f.deinit(allocator);
        if (self.back) |b| b.deinit(allocator);
        allocator.destroy(self);
    }
};
