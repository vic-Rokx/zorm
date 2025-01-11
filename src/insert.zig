const std = @import("std");
const print = std.debug.print;
const UUID = @import("Types.zig").UUID;
const VARCHAR = @import("Types.zig").VARCHAR;
const INTEGER = @import("Types.zig").INTEGER;
const BOOLEAN = @import("Types.zig").BOOLEAN;
const SMALLINT = @import("Types.zig").SMALLINT;
const BIGINT = @import("Types.zig").BIGINT;
const TIMESTAMP = @import("Types.zig").TIMESTAMP;
const DECIMAL = @import("Types.zig").DECIMAL;
const TEXT = @import("Types.zig").TEXT;
const JSON = @import("Types.zig").JSON;
const JSONB = @import("Types.zig").JSONB;
const ARRAY = @import("Types.zig").ARRAY;
const GEOMETRY = @import("Types.zig").GEOMETRY;
const ENUM = @import("Types.zig").ENUM;
const BYTEA = @import("Types.zig").BYTEA;
const FOREIGNKEY = @import("Types.zig").FOREIGNKEY;

const Self = @This();
ring_builder: std.RingBuffer,
arena: *std.mem.Allocator,

fn assert(ok: bool, comptime error_msg: []const u8) void {
    if (!ok) {
        const boldRed = "\x1b[1;31m"; // ANSI escape code for bold + red
        const reset = "\x1b[0m"; // Reset ANSI code to clear formatting
        std.debug.print("\n{s}Error{s}: ", .{ boldRed, reset });
        std.debug.print("{s}\n", .{error_msg});
        unreachable; // assertion failure
    }
}

pub fn init(target: *Self, arena: *std.mem.Allocator, capacity: u16) !void {
    target.* = .{
        .ring_builder = try std.RingBuffer.init(arena.*, capacity),
        .arena = arena,
    };
}

pub fn deinit(self: *Self) void {
    self.ring_builder.deinit();
}

pub fn printRingBuff(self: *Self) void {
    print("{s}\n", .{self.ring_builder.data[0..self.ring_builder.len()]});
}

// INSERT INTO users (username, email, created_at)
// VALUES
//     ('Alice', 'alice@example.com', NOW()),
//     ('Bob', 'bob@example.com', NOW()),
//     ('Charlie', 'charlie@example.com', NOW());

pub fn insertTable(self: *Self, comptime T: type, table_value: T) !void {
    assert(@typeInfo(T) == .Struct, "T must be a struct");
    assert(@hasDecl(T, "Table"), "T must have Table declaration");

    try self.ring_builder.writeSlice("INSERT INTO ");

    const fields = @typeInfo(T).Struct.fields;
    const table_name = T.Table;
    try self.ring_builder.writeSlice(table_name);
    try self.ring_builder.writeSlice(" (");

    var count: usize = 1;
    inline for (fields) |f| {
        const field_value = @field(table_value, f.name);
        if (field_value.value) |_| {
            try self.ring_builder.writeSlice(f.name);
            if (fields.len > count) {
                try self.ring_builder.writeSlice(", ");
            }
        }
        count += 1;
    }

    try self.ring_builder.writeSlice(")\n");

    try self.ring_builder.writeSlice("VALUES\n");
    try self.ring_builder.writeSlice("(");
    count = 1;
    inline for (fields) |f| {
        const field_value = @field(table_value, f.name);
        if (field_value.value) |v| {
            switch (f.type) {
                INTEGER, BIGINT, SMALLINT, DECIMAL => {
                    const buf = try std.fmt.allocPrint(self.arena.*, "{any}", .{v});
                    try self.ring_builder.writeSlice(buf);
                },
                BOOLEAN => {
                    const buf = try std.fmt.allocPrint(self.arena.*, "{any}", .{v});
                    try self.ring_builder.writeSlice(buf);
                },
                else => {
                    try self.ring_builder.writeSlice(v);
                },
            }
            if (fields.len > count) {
                try self.ring_builder.writeSlice(", ");
            }
        }
        count += 1;
    }
    try self.ring_builder.writeSlice(")\n");
    try self.ring_builder.writeSlice(");");
    self.printRingBuff();
}

test "insert table" {
    var arena = std.heap.c_allocator;
    const User = struct {
        pub const Table = "test_table";
        pub const Allocator = std.testing.allocator;
        pub const Foreignkey = FOREIGNKEY{
            .ID = "test_uuid",
            .TABLE = "orders",
            .COLUMN_NAME = "order_id",
            .CASCADE = true,
        };

        test_uuid: UUID = UUID{ .primaryKey = true },
        test_value: VARCHAR = VARCHAR{ .NOT_NULL = true },
        test_num: INTEGER = INTEGER{},
        test_bool: BOOLEAN = BOOLEAN{},
    };

    const user = User{
        .test_value = VARCHAR{ .value = "Vic" },
        .test_num = INTEGER{ .value = 24 },
        .test_bool = BOOLEAN{ .value = true },
    };

    var zorm: Self = undefined;
    try zorm.init(&arena, 1024);

    try zorm.insertTable(User, user);
    print("\n", .{});
}
