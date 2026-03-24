const std = @import("std");
const rl = @import("raylib");

const Key = rl.KeyboardKey;
pub const Keys = []const Key;

pub fn Keybinding(comptime callback: fn (Keys) void) type {
    return struct {
        keys: Keys,

        pub fn call(self: @This()) void {
            callback(self.keys);
        }

        pub fn pressed(self: @This()) bool {
            for (self.keys) |key| {
                if (!rl.isKeyDown(key)) return false;
            }
            return true;
        }

        pub fn justPressed(self: @This()) bool {
            if (self.keys.len == 0) return false;

            for (self.keys[0 .. self.keys.len - 1]) |key| {
                if (!rl.isKeyDown(key)) return false;
            }

            return rl.isKeyPressed(self.keys[self.keys.len - 1]);
        }
    };
}

pub fn createKeybind(comptime callback: fn (Keys) void, keys: Keys) Keybinding(callback) {
    return .{ .keys = keys };
}

pub fn processBindings(bindings: anytype) void {
    inline for (bindings) |bind| {
        if (bind.justPressed()) {
            bind.call();
        }
    }
}
