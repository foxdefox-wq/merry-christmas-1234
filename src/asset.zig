const std = @import("std");
const rl = @import("raylib");

pub const AssetManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    textures: std.StringHashMap(rl.Texture2D),
    sounds: std.StringHashMap(rl.Sound),
    music: std.StringHashMap(rl.Music),
    fonts: std.StringHashMap(rl.Font),
    shaders: std.StringHashMap(rl.Shader),
    images: std.StringHashMap(rl.Image),

    pub fn init(alloc: std.mem.Allocator) Self {
        return .{
            .allocator = alloc,
            .textures = std.StringHashMap(rl.Texture2D).init(alloc),
            .sounds = std.StringHashMap(rl.Sound).init(alloc),
            .music = std.StringHashMap(rl.Music).init(alloc),
            .fonts = std.StringHashMap(rl.Font).init(alloc),
            .shaders = std.StringHashMap(rl.Shader).init(alloc),
            .images = std.StringHashMap(rl.Image).init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        {
            var it = self.textures.iterator();
            while (it.next()) |entry| {
                rl.unloadTexture(entry.value_ptr.*);
                self.allocator.free(entry.key_ptr.*);
            }
            self.textures.deinit();
        }

        {
            var it = self.sounds.iterator();
            while (it.next()) |entry| {
                rl.unloadSound(entry.value_ptr.*);
                self.allocator.free(entry.key_ptr.*);
            }
            self.sounds.deinit();
        }

        {
            var it = self.music.iterator();
            while (it.next()) |entry| {
                rl.unloadMusicStream(entry.value_ptr.*);
                self.allocator.free(entry.key_ptr.*);
            }
            self.music.deinit();
        }

        {
            var it = self.fonts.iterator();
            while (it.next()) |entry| {
                rl.unloadFont(entry.value_ptr.*);
                self.allocator.free(entry.key_ptr.*);
            }
            self.fonts.deinit();
        }

        {
            var it = self.shaders.iterator();
            while (it.next()) |entry| {
                rl.unloadShader(entry.value_ptr.*);
                self.allocator.free(entry.key_ptr.*);
            }
            self.shaders.deinit();
        }

        {
            var it = self.images.iterator();
            while (it.next()) |entry| {
                rl.unloadImage(entry.value_ptr.*);
                self.allocator.free(entry.key_ptr.*);
            }
            self.images.deinit();
        }
    }

    fn dupeKey(self: *Self, name: []const u8) ![]const u8 {
        return try self.allocator.dupe(u8, name);
    }

    pub fn loadTexture(self: *Self, name: []const u8, path: [:0]const u8) !void {
        if (self.textures.contains(name)) return error.AssetAlreadyLoaded;

        const key = try self.dupeKey(name);
        errdefer self.allocator.free(key);

        const asset = try rl.loadTexture(path);
        errdefer rl.unloadTexture(asset);

        try self.textures.put(key, asset);
    }

    pub fn getTexture(self: *Self, name: []const u8) ?*const rl.Texture2D {
        return self.textures.getPtr(name);
    }

    pub fn unloadTexture(self: *Self, name: []const u8) bool {
        if (self.textures.fetchRemove(name)) |kv| {
            rl.unloadTexture(kv.value);
            self.allocator.free(kv.key);
            return true;
        }
        return false;
    }

    pub fn loadSound(self: *Self, name: []const u8, path: [:0]const u8) !void {
        if (self.sounds.contains(name)) return error.AssetAlreadyLoaded;

        const key = try self.dupeKey(name);
        errdefer self.allocator.free(key);

        const asset = try rl.loadSound(path);
        errdefer rl.unloadSound(asset);

        try self.sounds.put(key, asset);
    }

    pub fn getSound(self: *Self, name: []const u8) ?*const rl.Sound {
        return self.sounds.getPtr(name);
    }

    pub fn unloadSound(self: *Self, name: []const u8) bool {
        if (self.sounds.fetchRemove(name)) |kv| {
            rl.unloadSound(kv.value);
            self.allocator.free(kv.key);
            return true;
        }
        return false;
    }

    pub fn loadMusic(self: *Self, name: []const u8, path: [:0]const u8) !void {
        if (self.music.contains(name)) return error.AssetAlreadyLoaded;

        const key = try self.dupeKey(name);
        errdefer self.allocator.free(key);

        const asset = try rl.loadMusicStream(path);
        errdefer rl.unloadMusicStream(asset);

        try self.music.put(key, asset);
    }

    pub fn getMusic(self: *Self, name: []const u8) ?*const rl.Music {
        return self.music.getPtr(name);
    }

    pub fn getMusicMut(self: *Self, name: []const u8) ?*rl.Music {
        return self.music.getPtr(name);
    }

    pub fn unloadMusic(self: *Self, name: []const u8) bool {
        if (self.music.fetchRemove(name)) |kv| {
            rl.unloadMusicStream(kv.value);
            self.allocator.free(kv.key);
            return true;
        }
        return false;
    }

    pub fn updateMusic(self: *Self) void {
        var it = self.music.iterator();
        while (it.next()) |entry| {
            rl.updateMusicStream(entry.value_ptr.*);
        }
    }

    pub fn loadFont(self: *Self, name: []const u8, path: [:0]const u8) !void {
        if (self.fonts.contains(name)) return error.AssetAlreadyLoaded;

        const key = try self.dupeKey(name);
        errdefer self.allocator.free(key);

        const asset = try rl.loadFont(path);
        errdefer rl.unloadFont(asset);

        try self.fonts.put(key, asset);
    }

    pub fn getFont(self: *Self, name: []const u8) ?*const rl.Font {
        return self.fonts.getPtr(name);
    }

    pub fn unloadFont(self: *Self, name: []const u8) bool {
        if (self.fonts.fetchRemove(name)) |kv| {
            rl.unloadFont(kv.value);
            self.allocator.free(kv.key);
            return true;
        }
        return false;
    }

    pub fn loadShader(self: *Self, name: []const u8, vs_path: ?[:0]const u8, fs_path: ?[:0]const u8) !void {
        if (self.shaders.contains(name)) return error.AssetAlreadyLoaded;

        const key = try self.dupeKey(name);
        errdefer self.allocator.free(key);

        const asset = rl.loadShader(vs_path, fs_path);
        errdefer rl.unloadShader(asset);

        try self.shaders.put(key, asset);
    }

    pub fn getShader(self: *Self, name: []const u8) ?*const rl.Shader {
        return self.shaders.getPtr(name);
    }

    pub fn getShaderMut(self: *Self, name: []const u8) ?*rl.Shader {
        return self.shaders.getPtr(name);
    }

    pub fn unloadShader(self: *Self, name: []const u8) bool {
        if (self.shaders.fetchRemove(name)) |kv| {
            rl.unloadShader(kv.value);
            self.allocator.free(kv.key);
            return true;
        }
        return false;
    }

    pub fn loadImage(self: *Self, name: []const u8, path: [:0]const u8) !void {
        if (self.images.contains(name)) return error.AssetAlreadyLoaded;

        const key = try self.dupeKey(name);
        errdefer self.allocator.free(key);

        const asset = try rl.loadImage(path);
        errdefer rl.unloadImage(asset);

        try self.images.put(key, asset);
    }

    pub fn getImage(self: *Self, name: []const u8) ?*const rl.Image {
        return self.images.getPtr(name);
    }

    pub fn getImageMut(self: *Self, name: []const u8) ?*rl.Image {
        return self.images.getPtr(name);
    }

    pub fn unloadImage(self: *Self, name: []const u8) bool {
        if (self.images.fetchRemove(name)) |kv| {
            rl.unloadImage(kv.value);
            self.allocator.free(kv.key);
            return true;
        }
        return false;
    }
};
