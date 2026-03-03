const std = @import("std");

pub const ID = u32;

pub fn Gen(comptime Components: type) type {
    const ComponentFields = std.meta.fields(Components);
    const ComponentCount = ComponentFields.len;

    const CompInfo = struct {
        pub fn getIndex(comptime name: []const u8) usize {
            inline for (ComponentFields, 0..) |field, i| {
                if (std.mem.eql(u8, field.name, name)) return i;
            }
            @compileError("Component '" ++ name ++ "' not found");
        }

        pub fn getMask(comptime names: anytype) u64 {
            var mask: u64 = 0;
            inline for (names) |name| {
                mask |= (1 << getIndex(name));
            }
            return mask;
        }

        pub const Metadata = struct {
            size: usize,
            alignment: u16,
            deinit_fn: ?*const fn (*anyopaque, std.mem.Allocator) void,
        };

        pub const meta: [ComponentCount]Metadata = blk: {
            var m: [ComponentCount]Metadata = undefined;
            for (ComponentFields, 0..) |field, i| {
                const T = field.type;
                m[i] = .{
                    .size = @sizeOf(T),
                    .alignment = @alignOf(T),
                    .deinit_fn = if (@hasDecl(T, "deinit")) &struct {
                        fn wrap(ptr: *anyopaque, _: std.mem.Allocator) void {
                            var casted = @as(*T, @ptrCast(@alignCast(ptr)));
                            casted.deinit();
                        }
                    }.wrap else null,
                };
            }
            break :blk m;
        };
    };

    const Archetype = undefined;
    Archetype = struct {
        allocator: std.mem.Allocator,
        mask: u64, // Bitmask of which components this archetype has
        ids: std.ArrayList(ID), // List of IDs in this archetype
        // Raw columns of data. Indexed by Component Index.
        // If the bit is NOT set in mask, the column is empty.
        columns: [ComponentCount]std.ArrayListAlignedUnmanaged(u8),

        pub fn init(allocator: std.mem.Allocator, mask: u64) Archetype {
            return .{
                .allocator = allocator,
                .mask = mask,
                .ids = std.ArrayList(ID).init(allocator),
                .columns = [_]std.ArrayListAlignedUnmanaged(u8){.{}} ** ComponentCount,
            };
        }

        pub fn deinit(self: *Archetype) void {
            // Run deinits on components if needed
            for (0..ComponentCount) |i| {
                if ((self.mask & (@as(u64, 1) << @intCast(i))) != 0) {
                    if (CompInfo.meta[i].deinit_fn) |deinit_fn| {
                        const stride = CompInfo.meta[i].size;
                        const ptr = self.columns[i].items;
                        var k: usize = 0;
                        while (k < ptr.len) : (k += stride) {
                            deinit_fn(@ptrCast(&ptr[k]), self.allocator);
                        }
                    }
                    self.columns[i].deinit(self.allocator);
                }
            }
            self.ids.deinit();
        }
    };

    const EntityRecord = struct {
        archetype_index: usize,
        row: usize, // Index within the archetype arrays
    };

    return struct {
        pub const World = struct {
            const Self = @This();

            allocator: std.mem.Allocator,
            next_id: ID = 0,
            entities: std.AutoHashMap(ID, EntityRecord),
            archetypes: std.ArrayList(Archetype),

            pub fn init(allocator: std.mem.Allocator) Self {
                var w = Self{
                    .allocator = allocator,
                    .next_id = 0,
                    .entities = std.AutoHashMap(ID, EntityRecord).init(allocator),
                    .archetypes = std.ArrayList(Archetype).init(allocator),
                };
                // Create the empty archetype (index 0)
                w.archetypes.append(Archetype.init(allocator, 0)) catch @panic("OOM");
                return w;
            }

            pub fn deinit(self: *Self) void {
                for (self.archetypes.items) |*arch| arch.deinit();
                self.archetypes.deinit();
                self.entities.deinit();
            }

            pub fn spawn(self: *Self) !ID {
                const id = self.next_id;
                self.next_id += 1;

                // Add to empty archetype (index 0)
                const arch_idx = 0;
                var arch = &self.archetypes.items[arch_idx];
                const row = arch.ids.items.len;
                try arch.ids.append(id);

                try self.entities.put(id, .{ .archetype_index = arch_idx, .row = row });
                return id;
            }

            pub fn delete(self: *Self, id: ID) void {
                const record = self.entities.get(id) orelse return;
                var arch = &self.archetypes.items[record.archetype_index];

                // Swap-remove logic to keep arrays packed
                const last_row = arch.ids.items.len - 1;
                const last_id = arch.ids.items[last_row];

                if (record.row != last_row) {
                    arch.ids.items[record.row] = last_id;
                    for (0..ComponentCount) |i| {
                        if ((arch.mask & (@as(u64, 1) << @intCast(i))) != 0) {
                            const size = CompInfo.meta[i].size;
                            const src = arch.columns[i].items[last_row * size ..][0..size];
                            const dst = arch.columns[i].items[record.row * size ..][0..size];
                            @memcpy(dst, src);
                        }
                    }
                    self.entities.getPtr(last_id).?.row = record.row;
                }

                _ = arch.ids.pop();
                for (0..ComponentCount) |i| {
                    if ((arch.mask & (@as(u64, 1) << @intCast(i))) != 0) {
                        const size = CompInfo.meta[i].size;
                        arch.columns[i].items.len -= size;
                    }
                }

                _ = self.entities.remove(id);
            }

            pub fn addComp(self: *Self, id: ID, comptime name: []const u8, val: anytype) !void {
                if (!@hasField(Components, name)) @compileError("Invalid component");
                const comp_idx = CompInfo.getIndex(name);
                const bit = @as(u64, 1) << @intCast(comp_idx);

                const T = @TypeOf(@field(@as(Components, undefined), name));
                if (@TypeOf(val) != T) @compileError("Type mismatch");

                const record = self.entities.get(id) orelse return error.EntityNotFound;
                const old_arch_idx = record.archetype_index;
                const old_arch = &self.archetypes.items[old_arch_idx];

                if ((old_arch.mask & bit) != 0) {
                    const size = CompInfo.meta[comp_idx].size;
                    const offset = record.row * size;
                    const ptr = @as(*T, @ptrCast(@alignCast(&old_arch.columns[comp_idx].items[offset])));
                    ptr.* = val;
                    return;
                }

                const new_mask = old_arch.mask | bit;
                const new_arch_idx = try self.getOrCreateArchetype(new_mask);

                var src_arch = &self.archetypes.items[old_arch_idx];
                var dst_arch = &self.archetypes.items[new_arch_idx];

                const old_row = record.row;
                const new_row = dst_arch.ids.items.len;

                try dst_arch.ids.append(id);

                for (0..ComponentCount) |i| {
                    if ((src_arch.mask & (@as(u64, 1) << @intCast(i))) != 0) {
                        const size = CompInfo.meta[i].size;
                        const align_ = CompInfo.meta[i].alignment;
                        const src_data = src_arch.columns[i].items[old_row * size ..][0..size];

                        try dst_arch.columns[i].appendSlice(self.allocator, src_data);
                        _ = align_;
                    }
                }

                const val_bytes = std.mem.asBytes(&val);
                try dst_arch.columns[comp_idx].appendSlice(self.allocator, val_bytes);

                self.entities.put(id, .{ .archetype_index = new_arch_idx, .row = new_row }) catch unreachable;

                const last_row = src_arch.ids.items.len - 1;
                const last_id = src_arch.ids.items[last_row];

                if (old_row != last_row) {
                    src_arch.ids.items[old_row] = last_id;
                    for (0..ComponentCount) |i| {
                        if ((src_arch.mask & (@as(u64, 1) << @intCast(i))) != 0) {
                            const size = CompInfo.meta[i].size;
                            const s = src_arch.columns[i].items[last_row * size ..][0..size];
                            const d = src_arch.columns[i].items[old_row * size ..][0..size];
                            @memcpy(d, s);
                        }
                    }
                    self.entities.getPtr(last_id).?.row = old_row;
                }

                _ = src_arch.ids.pop();
                for (0..ComponentCount) |i| {
                    if ((src_arch.mask & (@as(u64, 1) << @intCast(i))) != 0) {
                        src_arch.columns[i].items.len -= CompInfo.meta[i].size;
                    }
                }
            }

            fn getOrCreateArchetype(self: *Self, mask: u64) !usize {
                for (self.archetypes.items, 0..) |a, i| {
                    if (a.mask == mask) return i;
                }
                const new_arch = Archetype.init(self.allocator, mask);
                try self.archetypes.append(new_arch);
                return self.archetypes.items.len - 1;
            }

            pub fn query(self: *Self, comptime component_names: anytype, func: anytype) void {
                const req_mask = CompInfo.getMask(component_names);
                const Indices = blk: {
                    var idxs: [component_names.len]usize = undefined;
                    for (component_names, 0..) |name, i| idxs[i] = CompInfo.getIndex(name);
                    break :blk idxs;
                };

                for (self.archetypes.items) |arch| {
                    if ((arch.mask & req_mask) == req_mask) {
                        var column_ptrs: [component_names.len][]u8 = undefined;
                        inline for (Indices, 0..) |comp_idx, i| {
                            column_ptrs[i] = arch.columns[comp_idx].items;
                        }

                        const count = arch.ids.items.len;
                        var i: usize = 0;
                        while (i < count) : (i += 1) {
                            const id = arch.ids.items[i];

                            var args: std.meta.Tuple(&.{ID} ++ blk: {
                                var types: [component_names.len]type = undefined;
                                for (component_names, 0..) |name, k| {
                                    types[k] = *std.meta.FieldType(Components, name);
                                }
                                break :blk types;
                            }) = undefined;

                            args[0] = id;

                            inline for (Indices, 0..) |comp_idx, k| {
                                _ = comp_idx;
                                const T = std.meta.FieldType(Components, component_names[k]);
                                const size = @sizeOf(T);
                                const raw_ptr = &column_ptrs[k][i * size];
                                args[k + 1] = @as(*T, @ptrCast(@alignCast(raw_ptr)));
                            }

                            @call(.auto, func, args);
                        }
                    }
                }
            }
        };
    };
}
