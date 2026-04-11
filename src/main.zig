const std = @import("std");
const es = @import("es.zig");
const rl = @import("raylib");

pub const Constants = struct {
    pub const SCREEN_WIDTH = 800;
    pub const SCREEN_HEIGHT = 800;
    pub const TITLE = "Yo";
    pub const TARGET_FPS = 60;
    pub const CLEAR_BACKGROUND_COLOR = rl.Color.white;
    pub const GPA = std.heap.GeneralPurposeAllocator();
    pub const NODE_TYPE = union(enum) { part: struct {
        pos: rl.Vector3,
        size: rl.Vector3,
        color: rl.Color,
    } };
};

pub fn main() !void {
    init(Constants.GPA);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        // Logic here

        rl.clearBackground(Constants.CLEAR_BACKGROUND_COLOR);
        rl.endDrawing();
    }
    deinit();
}

pub fn init(constants: anytype, alloc: std.mem.Allocator) void {
    rl.initWindow(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT, Constants.TITLE);
    rl.setTargetFPS(Constants.TARGET_FPS);
    const root = es.DataModel(constants.Node_Type, alloc);
}

pub fn deinit() void {
    std.debug.print("Bye!!!", .{});
    rl.closeWindow();
}
