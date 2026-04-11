const std = @import("std");
const rl = @import("raylib");

pub fn DataModel(comptime Node_Type: type, alloc: *std.mem.Allocator) !type {
    if (@typeInfo(Node_Type) != .Union) {
        @compileError("Node type must be an tagged union!");
    }
    if (!@hasDecl(Node_Type, "deinit")) {
        @compileError("Node type must have a deinit function!");
    }
    // Create node type
    const Node = struct {
        const Self = @This();
        alloc: *std.mem.Allocator = alloc,
        parent: ?*Self = null,
        children: std.ArrayList(*Self),
        data: Node_Type,

        pub fn spawn(self: *Self, @"type": Node_Type) Self {
            return .{
                .parent = self,
                .children = std.ArrayList(Self).initCapacity(self.alloc, 0),
                .data = @"type",
            };
        }
        pub fn kill(self: *Self) !void {
            const children = self.children;
            for (children) |child| {
                kill(child);
            }
            // Now we are child.
            self.children.deinit(self.alloc.*);
            self.data.deinit();
        }

        pub fn findFirstChild(self: *Self, data: Node_Type) ?*Self {
            // data could be a name, position, whatever
            for (self.children) |child| {
                if (child.data == data) {
                    return child;
                }

                if (findFirstChild(child, data)) |found| {
                    return found;
                }
            }
            return null;
        }

b fn findFirstType(self: *Self, target_tag: @typeInfo(NodeData).Union.tag_type.?) ?*Self {
    for (self.children.items) |child| {
        // Use @activeTag to get the enum member currently active in the union
        if (@activeTag(child.data) == target_tag) {
            return child;
        }

        // Recurse
        if (child.findFirstType(target_tag)) |found| {
            return found;
        }
    }
    return null;
}
    };
    // The Root!
    return try alloc.create(Node);
}
