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
const ARRAY_TYPE = @import("Types.zig").ARRAY_TYPE;
const Value = @import("Types.zig").Value;

const Self = @This();
ring_builder: std.RingBuffer,
arena: *std.mem.Allocator,

const SqlValue = union(enum) {
    string: []const u8,
    integer: i64,
    float: f64,
    boolean: bool,

    pub fn toSql(self: SqlValue, builder: *std.RingBuffer) !void {
        switch (self) {
            .string => |str| {
                try builder.writeSlice("'");
                try builder.writeSlice(str);
                try builder.writeSlice("'");
            },
            .integer => |int| {
                // Convert integer to string and write
                var buf: [32]u8 = undefined;
                const value = try std.fmt.bufPrint(&buf, "{d}", .{int});
                try builder.writeSlice(value);
            },
            .float => |float| {
                var buf: [32]u8 = undefined;
                const value = try std.fmt.bufPrint(&buf, "{d}", .{float});
                try builder.writeSlice(value);
            },
            .boolean => |bool_val| {
                try builder.writeSlice(if (bool_val) "TRUE" else "FALSE");
            },
        }
    }
};

const WhereQuery = union(enum) {
    map: std.StringHashMap(SqlValue),
    arr: []SqlValue,

    pub fn toQuery(self: WhereQuery, builder: *std.RingBuffer) !void {
        switch (self) {
            .map => |map_value| {
                var itr = map_value.iterator();
                var count: usize = 0;
                while (itr.next()) |elem| {
                    count += 1;
                    try builder.writeSlice(elem.key_ptr.*);
                    try builder.writeSlice(" = ");
                    try elem.value_ptr.*.toSql(builder);
                    if (count < map_value.count()) {
                        try builder.writeSlice(" AND ");
                    }
                }
            },
            .arr => |arr_value| {
                for (arr_value, 0..) |sql_value, i| {
                    try sql_value.toSql(builder);
                    if (i < arr_value.len - 1) {
                        try builder.writeSlice(", ");
                    }
                }
            },
        }
    }
};

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
                ARRAY => {
                    try self.ring_builder.writeSlice("[");
                    switch (v[0]) {
                        .int => {
                            for (v, 0..) |e, i| {
                                const buf = try std.fmt.allocPrint(self.arena.*, "{any}", .{e.int});
                                try self.ring_builder.writeSlice(buf);
                                if (i < v.len - 1) {
                                    try self.ring_builder.writeSlice(", ");
                                }
                            }
                        },
                        .float => {
                            for (v, 0..) |e, i| {
                                const buf = try std.fmt.allocPrint(self.arena.*, "{any}", .{e.float});
                                try self.ring_builder.writeSlice(buf);
                                if (i < v.len - 1) {
                                    try self.ring_builder.writeSlice(", ");
                                }
                            }
                        },
                        .string => {
                            for (v, 0..) |e, i| {
                                try self.ring_builder.writeSlice("'");
                                try self.ring_builder.writeSlice(e.string);
                                try self.ring_builder.writeSlice("'");
                                if (i < v.len - 1) {
                                    try self.ring_builder.writeSlice(", ");
                                }
                            }
                        },
                        .unknown => {},
                    }
                    try self.ring_builder.writeSlice("]");
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
        test_arr: ARRAY = ARRAY{ .type = ARRAY_TYPE.TEXT },
    };

    var arr = [3]Value{
        Value{ .string = "Hello" },
        Value{ .string = "Im" },
        Value{ .string = "Vic" },
    };
    const user = User{
        .test_value = VARCHAR{ .value = "Vic" },
        .test_num = INTEGER{ .value = 24 },
        .test_bool = BOOLEAN{ .value = true },
        .test_arr = ARRAY{ .value = &arr },
    };

    var zorm: Self = undefined;
    try zorm.init(&arena, 1024);

    try zorm.insertTable(User, user);
    print("\n", .{});
}

// SELECT * FROM comments WHERE post_id = 1;
pub fn where(self: *Self, query: WhereQuery) !void {
    try self.ring_builder.writeSlice("\n");
    try self.ring_builder.writeSlice("WHERE ");

    try query.toQuery(&self.ring_builder);
}

// UPDATE users SET email = 'new_email@example.com' WHERE id = 1;
pub fn update(
    self: *Self,
    comptime T: type,
    set_key: []const u8,
    set_value: SqlValue,
) !void {
    assert(@typeInfo(T) == .Struct, "T must be a struct");
    assert(@hasDecl(T, "Table"), "T must have Table declaration");

    const table_name = T.Table;
    try self.ring_builder.writeSlice("UPDATE ");
    try self.ring_builder.writeSlice(table_name);
    try self.ring_builder.writeSlice(" SET ");
    try self.ring_builder.writeSlice(set_key);
    try self.ring_builder.writeSlice(" = ");
    try set_value.toSql(&self.ring_builder);
}

test "update table" {
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
        test_arr: ARRAY = ARRAY{ .type = ARRAY_TYPE.TEXT },
    };

    var zorm: Self = undefined;
    try zorm.init(&arena, 1024);
    try zorm.update(User, "name", SqlValue{ .string = "John" });

    var map = std.StringHashMap(SqlValue).init(arena);
    try map.put("id", SqlValue{ .integer = 10 });
    try map.put("title", SqlValue{ .string = "Rational Optimist" });
    try zorm.where(WhereQuery{ .map = map });

    zorm.printRingBuff();
    print("\n", .{});
}

// DELETE FROM comments WHERE id = 1;
pub fn delete(
    self: *Self,
    comptime T: type,
) !void {
    assert(@typeInfo(T) == .Struct, "T must be a struct");
    assert(@hasDecl(T, "Table"), "T must have Table declaration");

    const table_name = T.Table;
    try self.ring_builder.writeSlice("DELETE FROM ");
    try self.ring_builder.writeSlice(table_name);
}

test "delete table" {
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
        test_arr: ARRAY = ARRAY{ .type = ARRAY_TYPE.TEXT },
    };

    var zorm: Self = undefined;
    try zorm.init(&arena, 1024);
    try zorm.delete(User);

    var map = std.StringHashMap(SqlValue).init(arena);
    try map.put("id", SqlValue{ .integer = 23 });
    try zorm.where(WhereQuery{ .map = map });

    zorm.printRingBuff();
    print("\n", .{});
}

// SELECT posts.id AS post_id, posts.title, COUNT(comments.id) AS comment_count
// FROM posts
// LEFT JOIN comments ON posts.id = comments.post_id
// GROUP BY posts.id, posts.title;
pub fn select(
    self: *Self,
    comptime T: type,
    key: []const u8,
) !void {
    assert(@typeInfo(T) == .Struct, "T must be a struct");
    assert(@hasDecl(T, "Table"), "T must have Table declaration");

    try self.ring_builder.writeSlice("SELECT ");
    try self.ring_builder.writeSlice(key);
    try self.ring_builder.writeSlice(" FROM ");
    const table_name = T.Table;
    try self.ring_builder.writeSlice(table_name);
}

pub fn find(self: *Self) ![]const u8 {
    self.printRingBuff();
    return "";
}

pub fn exec(self: *Self) ![]const u8 {
    try self.ring_builder.writeSlice(";");
    self.printRingBuff();
    return "";
}

// LEFT JOIN comments ON posts.id = comments.post_id
pub fn join(
    self: *Self,
    comptime T: type,
    join_side: []const u8,
    key: []const u8,
    value: []const u8,
) !void {
    assert(@typeInfo(T) == .Struct, "T must be a struct");
    assert(@hasDecl(T, "Table"), "T must have Table declaration");

    const table_name = T.Table;
    try self.ring_builder.writeSlice("\n");
    try self.ring_builder.writeSlice(join_side);
    try self.ring_builder.writeSlice(" JOIN ");
    try self.ring_builder.writeSlice(table_name);
    try self.ring_builder.writeSlice(" ON ");
    try self.ring_builder.writeSlice(key);
    try self.ring_builder.writeSlice(" = ");
    try self.ring_builder.writeSlice(value);
}

// GROUP BY posts.id, posts.title;
pub fn group(
    self: *Self,
    values: []const []const u8,
) !void {
    try self.ring_builder.writeSlice("\n");
    try self.ring_builder.writeSlice("GROUP ");
    try self.ring_builder.writeSlice("BY ");

    for (values, 0..) |value, i| {
        try self.ring_builder.writeSlice(value);

        if (i < values.len - 1) try self.ring_builder.writeSlice(", ");
    }
}

test "select join table" {
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
        test_arr: ARRAY = ARRAY{ .type = ARRAY_TYPE.TEXT },
    };

    var zorm: Self = undefined;
    try zorm.init(&arena, 1024);

    // Creating sql statement
    try zorm.select(User, "post.id");
    try zorm.join(User, "LEFT", "posts.id", "comments.id");
    const values = [_][]const u8{ "posts.id", "posts.title" };
    try zorm.group(&values);
    var map = std.StringHashMap(SqlValue).init(arena);
    try map.put("posts.id", SqlValue{ .integer = 10 });
    try map.put("posts.title", SqlValue{ .string = "Rational Optimist" });
    try zorm.where(WhereQuery{ .map = map });
    _ = try zorm.exec();
    print("\n", .{});
}
