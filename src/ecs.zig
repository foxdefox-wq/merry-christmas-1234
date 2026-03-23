const std = @import("std");

pub fn World(comptime Components: type, comptime deinit_fn: anytype) type {
    const View = struct {
        const fields = std.meta.fields(Components);

        pub const Type = @Type(.{
            .@"struct" = .{
                .layout = .auto,
                .fields = blk: {
                    var f: [fields.len]std.builtin.Type.StructField = undefined;
                    for (fields, 0..) |field, i| {
                        f[i] = field;
                        f[i].type = *field.type;
                        f[i].default_value_ptr = null;
                    }
                    break :blk &f;
                },
                .decls = &.{},
                .is_tuple = false,
            },
        });
    }.Type;

    return struct {
        pub const Self = @This();
        pub const Field = std.meta.FieldEnum(Components);

        components: std.MultiArrayList(Components) = .empty,
        alloc: std.mem.Allocator,
        id: u32 = 0,

        pub fn init(alloc: std.mem.Allocator) Self {
            return .{
                .alloc = alloc,
            };
        }

        pub fn deinit(self: *Self) void {
            self.components.deinit(self.alloc);
        }

        pub fn spawn(self: *Self, components: Components) !u32 {
            const current_id = self.id;
            try self.components.append(self.alloc, components);
            self.id += 1;
            return current_id;
        }

        pub fn kill(self: *Self, id: u32) void {
            const slices = self.components.slice();
            inline for (std.meta.fields(Components)) |field| {
                const field_enum = @field(Field, field.name);
                const component_ptr = &slices.items(field_enum)[id];
                deinit_fn(component_ptr, field);
            }
        }

        pub fn getView(self: *Self, id: u32) View {
            const slices = self.components.slice();
            var view: View = undefined;

            inline for (std.meta.fields(Components)) |field| {
                const field_enum = @field(Field, field.name);
                @field(view, field.name) = &slices.items(field_enum)[id];
            }

            return view;
        }

        pub fn getComponent(
            self: *Self,
            id: u32,
            comptime field: Field,
        ) *std.meta.fieldInfo(Components, field).type {
            const slices = self.components.slice();
            return &slices.items(field)[id];
        }
    };
}
