const std = @import("std");
const rl = @import("raylib");
const stc = @import("stecs.zig");
const ast = @import("asset.zig");

pub const Constants = struct {
    pub const SCREEN_WIDTH = 800;
    pub const SCREEN_HEIGHT = 800;
    pub const TITLE = "Yo";
    pub const TARGET_FPS = 60;
    pub const CLEAR_BACKGROUND_COLOR = rl.Color.white;
};

pub fn main() !void {
    init();
    update();
    deinit();
}

pub fn init() void {
    rl.initWindow(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT, Constants.TITLE);
    rl.setTargetFPS(Constants.TARGET_FPS);
}

pub fn update() void {
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        // Logic here

        rl.clearBackground(Constants.CLEAR_BACKGROUND_COLOR);
        rl.endDrawing();
    }
}

pub fn draw(root: *stc.Instance) void {
    for (root.children.items) |child| {
        draw(child);
    }
}

pub fn deinit() void {
    std.debug.print("Bye!!!", .{});
    rl.closeWindow();
}
