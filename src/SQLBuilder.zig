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

// First, let's define some helper structs for the database field types
const FieldConfig = struct {
    primaryKey: bool = false,
    notNull: bool = false,
    // Add other common field configurations
};

const ForeignKeyConfig = struct {
    id: []const u8,
    table: []const u8,
    columnName: []const u8,
    cascade: bool = false,
};

// Define the model metadata structure
fn ModelConfig(comptime fields: type, comptime hasForeignKey: bool) type {
    if (hasForeignKey) {
        return struct {
            const TableName: []const u8 = undefined;
            const AllocatorType: type = undefined;
            const ForeignKey: ForeignKeyConfig = undefined;
            const Fields: fields = undefined;
        };
    } else {
        return struct {
            const TableName: []const u8 = undefined;
            const AllocatorType: type = undefined;
            const Fields: fields = undefined;
        };
    }
}

// -- Create a table with various data types including UUID
// CREATE TABLE users (
//     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
//     username VARCHAR(50) UNIQUE NOT NULL,
//     email VARCHAR(100) UNIQUE NOT NULL,
//     created_at TIMESTAMP DEFAULT NOW(),
//     updated_at TIMESTAMP DEFAULT NOW()
// );

pub fn createTable(self: *Self, comptime T: type) !void {
    assert(@typeInfo(T) == .Struct, "T must be a struct");
    assert(@hasDecl(T, "Table"), "T must have Table declaration");

    try self.ring_builder.writeSlice("CREATE TABLE ");

    const fields = @typeInfo(T).Struct.fields;
    const table_name = T.Table;
    try self.ring_builder.writeSlice(table_name);
    try self.ring_builder.writeSlice(" (\n");
    var count: usize = 0;
    inline for (fields) |f| {
        const field_type = f.type;
        try self.ring_builder.writeSlice(f.name);
        try self.ring_builder.writeSlice(" ");
        switch (field_type) {
            VARCHAR => {
                const dvalue_aligned: *align(f.alignment) const anyopaque = @alignCast(f.default_value.?);
                const value: VARCHAR = @as(*const f.type, @ptrCast(dvalue_aligned)).*;
                try self.ring_builder.writeSlice("VARCHAR(");
                try self.ring_builder.writeSlice(value.amount);
                try self.ring_builder.writeSlice(")");
                if (value.UNIQUE) {
                    try self.ring_builder.writeSlice(" UNIQUE");
                }
                if (value.NOT_NULL) {
                    try self.ring_builder.writeSlice(" NOT NULL");
                }
            },
            INTEGER => {
                const dvalue_aligned: *align(f.alignment) const anyopaque = @alignCast(f.default_value.?);
                const value: INTEGER = @as(*const f.type, @ptrCast(dvalue_aligned)).*;
                try self.ring_builder.writeSlice("INTEGER");
                if (value.UNIQUE) {
                    try self.ring_builder.writeSlice(" UNIQUE");
                }
                if (value.NOT_NULL) {
                    try self.ring_builder.writeSlice(" NOT NULL");
                }

                if (value.CHECK) |check| {
                    try self.ring_builder.writeSlice(" CHECK (");
                    try self.ring_builder.writeSlice(check);
                    try self.ring_builder.writeSlice(")");
                }
            },
            BOOLEAN => {
                const dvalue_aligned: *align(f.alignment) const anyopaque = @alignCast(f.default_value.?);
                const value: BOOLEAN = @as(*const f.type, @ptrCast(dvalue_aligned)).*;
                try self.ring_builder.writeSlice("BOOLEAN");
                if (value.UNIQUE) {
                    try self.ring_builder.writeSlice(" UNIQUE");
                }
                if (value.NOT_NULL) {
                    try self.ring_builder.writeSlice(" NOT NULL");
                }

                if (value.default) |default| {
                    try self.ring_builder.writeSlice(" DEFAULT ");
                    try self.ring_builder.writeSlice(default);
                }
            },
            UUID => {
                const dvalue_aligned: *align(f.alignment) const anyopaque = @alignCast(f.default_value.?);
                const value: UUID = @as(*const f.type, @ptrCast(dvalue_aligned)).*;
                try self.ring_builder.writeSlice("UUID ");
                if (value.primaryKey) {
                    try self.ring_builder.writeSlice("PRIMARY KEY ");
                }
                if (value.NOT_NULL) {
                    try self.ring_builder.writeSlice("NOT NULL ");
                }
                try self.ring_builder.writeSlice("DEFAULT ");
                try self.ring_builder.writeSlice(value.default);
            },
            SMALLINT => {
                const dvalue_aligned: *align(f.alignment) const anyopaque = @alignCast(f.default_value.?);
                const value: SMALLINT = @as(*const f.type, @ptrCast(dvalue_aligned)).*;
                try self.ring_builder.writeSlice("SMALLINT");
                if (value.UNIQUE) {
                    try self.ring_builder.writeSlice(" UNIQUE");
                }
                if (value.NOT_NULL) {
                    try self.ring_builder.writeSlice(" NOT NULL");
                }
                if (value.CHECK) |check| {
                    try self.ring_builder.writeSlice(" CHECK (");
                    try self.ring_builder.writeSlice(check);
                    try self.ring_builder.writeSlice(")");
                }
            },
            BIGINT => {
                const dvalue_aligned: *align(f.alignment) const anyopaque = @alignCast(f.default_value.?);
                const value: BIGINT = @as(*const f.type, @ptrCast(dvalue_aligned)).*;
                try self.ring_builder.writeSlice("BIGINT");
                if (value.UNIQUE) {
                    try self.ring_builder.writeSlice(" UNIQUE");
                }
                if (value.NOT_NULL) {
                    try self.ring_builder.writeSlice(" NOT NULL");
                }
                if (value.CHECK) |check| {
                    try self.ring_builder.writeSlice(" CHECK (");
                    try self.ring_builder.writeSlice(check);
                    try self.ring_builder.writeSlice(")");
                }
            },
            DECIMAL => {
                const dvalue_aligned: *align(f.alignment) const anyopaque = @alignCast(f.default_value.?);
                const value: DECIMAL = @as(*const f.type, @ptrCast(dvalue_aligned)).*;
                try self.ring_builder.writeSlice("DECIMAL(");
                try self.ring_builder.writeSlice(value.precision);
                try self.ring_builder.writeSlice(", ");
                try self.ring_builder.writeSlice(value.scale);
                try self.ring_builder.writeSlice(")");
                if (value.UNIQUE) {
                    try self.ring_builder.writeSlice(" UNIQUE");
                }
                if (value.NOT_NULL) {
                    try self.ring_builder.writeSlice(" NOT NULL");
                }
                if (value.CHECK) |check| {
                    try self.ring_builder.writeSlice(" CHECK (");
                    try self.ring_builder.writeSlice(check);
                    try self.ring_builder.writeSlice(")");
                }
            },
            TEXT => {
                const dvalue_aligned: *align(f.alignment) const anyopaque = @alignCast(f.default_value.?);
                const value: TEXT = @as(*const f.type, @ptrCast(dvalue_aligned)).*;
                try self.ring_builder.writeSlice("TEXT");
                if (value.UNIQUE) {
                    try self.ring_builder.writeSlice(" UNIQUE");
                }
                if (value.NOT_NULL) {
                    try self.ring_builder.writeSlice(" NOT NULL");
                }
            },
            TIMESTAMP => {
                const dvalue_aligned: *align(f.alignment) const anyopaque = @alignCast(f.default_value.?);
                const value: TIMESTAMP = @as(*const f.type, @ptrCast(dvalue_aligned)).*;
                try self.ring_builder.writeSlice("TIMESTAMP");
                if (value.withTimezone) {
                    try self.ring_builder.writeSlice(" WITH TIME ZONE");
                }
                if (value.UNIQUE) {
                    try self.ring_builder.writeSlice(" UNIQUE");
                }
                if (value.NOT_NULL) {
                    try self.ring_builder.writeSlice(" NOT NULL");
                }
                if (value.default) |default| {
                    try self.ring_builder.writeSlice(" DEFAULT ");
                    try self.ring_builder.writeSlice(default);
                }
            },

            JSON => {
                const dvalue_aligned: *align(f.alignment) const anyopaque = @alignCast(f.default_value.?);
                const value: JSON = @as(*const f.type, @ptrCast(dvalue_aligned)).*;
                try self.ring_builder.writeSlice("JSON");
                if (value.UNIQUE) {
                    try self.ring_builder.writeSlice(" UNIQUE");
                }
                if (value.NOT_NULL) {
                    try self.ring_builder.writeSlice(" NOT NULL");
                }
            },
            JSONB => {
                const dvalue_aligned: *align(f.alignment) const anyopaque = @alignCast(f.default_value.?);
                const value: JSONB = @as(*const f.type, @ptrCast(dvalue_aligned)).*;
                try self.ring_builder.writeSlice("JSONB");
                if (value.UNIQUE) {
                    try self.ring_builder.writeSlice(" UNIQUE");
                }
                if (value.NOT_NULL) {
                    try self.ring_builder.writeSlice(" NOT NULL");
                }
                if (value.CHECK) |check| {
                    try self.ring_builder.writeSlice(" CHECK (");
                    try self.ring_builder.writeSlice(check);
                    try self.ring_builder.writeSlice(")");
                }
            },
            ARRAY => {
                const dvalue_aligned: *align(f.alignment) const anyopaque = @alignCast(f.default_value.?);
                const value: ARRAY = @as(*const f.type, @ptrCast(dvalue_aligned)).*;

                if (value.type) |arr_type| {
                    switch (arr_type) {
                        ARRAY_TYPE.SMALLINT => {
                            try self.ring_builder.writeSlice("SMALLINT");
                        },
                        ARRAY_TYPE.INTEGER => {
                            try self.ring_builder.writeSlice("INTEGER");
                        },
                        ARRAY_TYPE.BIGINT => {
                            try self.ring_builder.writeSlice("BIGINT");
                        },
                        ARRAY_TYPE.REAL => {
                            try self.ring_builder.writeSlice("REAL");
                        },
                        ARRAY_TYPE.DECIMAL => {
                            try self.ring_builder.writeSlice("DECIMAL");
                        },
                        ARRAY_TYPE.TEXT => {
                            try self.ring_builder.writeSlice("TEXT");
                        },
                    }
                }
                try self.ring_builder.writeSlice("[]"); // Array syntax
                if (value.UNIQUE) {
                    try self.ring_builder.writeSlice(" UNIQUE");
                }
                if (value.NOT_NULL) {
                    try self.ring_builder.writeSlice(" NOT NULL");
                }
            },
            ENUM => {
                const dvalue_aligned: *align(f.alignment) const anyopaque = @alignCast(f.default_value.?);
                const value: ENUM = @as(*const f.type, @ptrCast(dvalue_aligned)).*;
                try self.ring_builder.writeSlice("ENUM(");
                for (value.values, 0..) |enum_value, i| {
                    if (i > 0) {
                        try self.ring_builder.writeSlice(", ");
                    }
                    try self.ring_builder.writeSlice("'");
                    try self.ring_builder.writeSlice(enum_value);
                    try self.ring_builder.writeSlice("'");
                }
                try self.ring_builder.writeSlice(")");
                if (value.UNIQUE) {
                    try self.ring_builder.writeSlice(" UNIQUE");
                }
                if (value.NOT_NULL) {
                    try self.ring_builder.writeSlice(" NOT NULL");
                }
                if (value.default) |default| {
                    try self.ring_builder.writeSlice(" DEFAULT '");
                    try self.ring_builder.writeSlice(default);
                    try self.ring_builder.writeSlice("'");
                }
            },
            BYTEA => {
                const dvalue_aligned: *align(f.alignment) const anyopaque = @alignCast(f.default_value.?);
                const value: BYTEA = @as(*const f.type, @ptrCast(dvalue_aligned)).*;
                try self.ring_builder.writeSlice("BYTEA");
                if (value.UNIQUE) {
                    try self.ring_builder.writeSlice(" UNIQUE");
                }
                if (value.NOT_NULL) {
                    try self.ring_builder.writeSlice(" NOT NULL");
                }
            },
            GEOMETRY => {
                const dvalue_aligned: *align(f.alignment) const anyopaque = @alignCast(f.default_value.?);
                const value: GEOMETRY = @as(*const f.type, @ptrCast(dvalue_aligned)).*;
                try self.ring_builder.writeSlice("GEOMETRY");
                if (value.type) |v_type| {
                    try self.ring_builder.writeSlice("(");
                    try self.ring_builder.writeSlice(v_type);
                    try self.ring_builder.writeSlice(")");
                }
                if (value.SRID) |srid| {
                    try self.ring_builder.writeSlice(" SRID=");
                    try self.ring_builder.writeSlice(srid);
                }
                if (value.NOT_NULL) {
                    try self.ring_builder.writeSlice(" NOT NULL");
                }
            },

            else => print("UNSUPPORTED TYPE\n", .{}),
        }

        if (fields.len - 1 > count) {
            try self.ring_builder.writeSlice(",\n");
        }
        count += 1;
    }
    if (@hasDecl(T, "Foreignkey")) {
        const foreignkey = T.Foreignkey;
        try self.ring_builder.writeSlice("FOREIGN KEY");
        if (foreignkey.ID) |id| {
            try self.ring_builder.writeSlice(" (");
            try self.ring_builder.writeSlice(id);
            try self.ring_builder.writeSlice(")");
        }
        if (foreignkey.TABLE) |table| {
            if (foreignkey.COLUMN_NAME) |name| {
                try self.ring_builder.writeSlice(" REFERENCES ");
                try self.ring_builder.writeSlice(table);
                try self.ring_builder.writeSlice("(");
                try self.ring_builder.writeSlice(name);
                try self.ring_builder.writeSlice(")");
            }
        }
        if (foreignkey.CASCADE) {
            try self.ring_builder.writeSlice(" ON DELETE CASCADE");
        }
    }
    try self.ring_builder.writeSlice("\n)");
}

test "create table" {
    var arena = std.heap.c_allocator;
    const UserModel = struct {
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
        test_array: ARRAY = ARRAY{ .type = ARRAY_TYPE.TEXT },
    };

    var zorm: Self = undefined;
    try zorm.init(&arena, 1024);

    try zorm.createTable(UserModel);
    print("\n", .{});
}

pub const SqlValue = union(enum) {
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

pub const WhereQuery = union(enum) {
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

// \\INSERT INTO test_table (test_value, test_num, test_bool, test_array)
// \\VALUES ('Vic', 24, true, ARRAY['Hello', 'Im', 'Vic']);
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
        const is_optional = @typeInfo(f.type) == .Optional;

        if (!is_optional or (is_optional and field_value != null)) {
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
        const is_optional = @typeInfo(f.type) == .Optional;
        const field_value = @field(table_value, f.name);
        if (!is_optional or (is_optional and field_value != null)) {
            switch (f.type) {
                i32, f32 => {
                    const max_len = 20;
                    var buf: [max_len]u8 = undefined;
                    const numAsString = try std.fmt.bufPrint(&buf, "{}", .{field_value});
                    try self.ring_builder.writeSlice(numAsString);
                },
                bool => {
                    const max_len = 20;
                    var buf: [max_len]u8 = undefined;
                    const numAsString = try std.fmt.bufPrint(&buf, "{}", .{field_value});
                    try self.ring_builder.writeSlice(numAsString);
                },
                [][]const u8 => {
                    try self.ring_builder.writeSlice("ARRAY[");
                    for (field_value, 0..) |e, i| {
                        try self.ring_builder.writeSlice("'");
                        try self.ring_builder.writeSlice(e);
                        try self.ring_builder.writeSlice("'");
                        if (i < field_value.len - 1) {
                            try self.ring_builder.writeSlice(", ");
                        }
                    }
                    try self.ring_builder.writeSlice("]");
                },
                []i32 => {
                    try self.ring_builder.writeSlice("ARRAY[");
                    for (field_value, 0..) |e, i| {
                        const max_len = 20;
                        var buf: [max_len]u8 = undefined;
                        const numAsString = try std.fmt.bufPrint(&buf, "{}", .{e.int});
                        try self.ring_builder.writeSlice(numAsString);
                        if (i < field_value.len - 1) {
                            try self.ring_builder.writeSlice(", ");
                        }
                    }
                    try self.ring_builder.writeSlice("]");
                },
                []f32 => {
                    try self.ring_builder.writeSlice("ARRAY[");
                    for (field_value, 0..) |e, i| {
                        const max_len = 20;
                        var buf: [max_len]u8 = undefined;
                        const numAsString = try std.fmt.bufPrint(&buf, "{}", .{e.float});
                        try self.ring_builder.writeSlice(numAsString);
                        try self.ring_builder.writeSlice(buf);
                        if (i < field_value.len - 1) {
                            try self.ring_builder.writeSlice(", ");
                        }
                    }
                    try self.ring_builder.writeSlice("]");
                },
                []const u8 => {
                    try self.ring_builder.writeSlice("'");
                    try self.ring_builder.writeSlice(field_value);
                    try self.ring_builder.writeSlice("'");
                },
                else => {},
            }
            if (fields.len > count) {
                try self.ring_builder.writeSlice(", ");
            }
        }
        count += 1;
    }
    // try self.ring_builder.writeSlice(")\n");
    try self.ring_builder.writeSlice(");");
    // self.printRingBuff();
}

test "insert table" {
    var arena = std.heap.c_allocator;
    const UserModel = struct {
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
    const user = UserModel{
        .test_value = VARCHAR{ .value = "Vic" },
        .test_num = INTEGER{ .value = 24 },
        .test_bool = BOOLEAN{ .value = true },
        .test_arr = ARRAY{ .value = &arr },
    };

    var zorm: Self = undefined;
    try zorm.init(&arena, 1024);

    try zorm.insertTable(UserModel, user);
    print("\n", .{});
}

// SELECT * FROM comments WHERE post_id = 1;
pub fn where(self: *Self, query: WhereQuery) !void {
    try self.ring_builder.writeSlice("\n");
    try self.ring_builder.writeSlice("WHERE ");

    try query.toQuery(&self.ring_builder);
}

// UPDATE users SET email = 'new_email@example.com';
pub fn update(
    self: *Self,
    comptime T: type,
    table_value: T,
) !void {
    assert(@typeInfo(T) == .Struct, "T must be a struct");
    assert(@hasDecl(T, "Table"), "T must have Table declaration");

    const table_name = T.Table;
    try self.ring_builder.writeSlice("UPDATE ");
    try self.ring_builder.writeSlice(table_name);
    const fields = @typeInfo(T).Struct.fields;
    try self.ring_builder.writeSlice(" SET ");

    var count: usize = 1;
    inline for (fields) |f| {
        const is_optional = @typeInfo(f.type) == .Optional;
        const field_value = @field(table_value, f.name);
        if (!is_optional or (is_optional and field_value != null)) {
            try self.ring_builder.writeSlice(f.name);
            try self.ring_builder.writeSlice("=");
            switch (f.type) {
                i32, f32 => {
                    const buf = try std.fmt.allocPrint(self.arena.*, "{any}", .{field_value});
                    try self.ring_builder.writeSlice(buf);
                },
                bool => {
                    const buf = try std.fmt.allocPrint(self.arena.*, "{any}", .{field_value});
                    try self.ring_builder.writeSlice(buf);
                },
                [][]const u8 => {
                    try self.ring_builder.writeSlice("ARRAY[");
                    for (field_value, 0..) |e, i| {
                        try self.ring_builder.writeSlice("'");
                        try self.ring_builder.writeSlice(e);
                        try self.ring_builder.writeSlice("'");
                        if (i < field_value.len - 1) {
                            try self.ring_builder.writeSlice(", ");
                        }
                    }
                    try self.ring_builder.writeSlice("]");
                },
                []i32 => {
                    try self.ring_builder.writeSlice("ARRAY[");
                    for (field_value, 0..) |e, i| {
                        const buf = try std.fmt.allocPrint(self.arena.*, "{any}", .{e.int});
                        try self.ring_builder.writeSlice(buf);
                        if (i < field_value.len - 1) {
                            try self.ring_builder.writeSlice(", ");
                        }
                    }
                    try self.ring_builder.writeSlice("]");
                },
                []f32 => {
                    try self.ring_builder.writeSlice("ARRAY[");
                    for (field_value, 0..) |e, i| {
                        const buf = try std.fmt.allocPrint(self.arena.*, "{any}", .{e.float});
                        try self.ring_builder.writeSlice(buf);
                        if (i < field_value.len - 1) {
                            try self.ring_builder.writeSlice(", ");
                        }
                    }
                    try self.ring_builder.writeSlice("]");
                },
                []const u8 => {
                    try self.ring_builder.writeSlice("'");
                    try self.ring_builder.writeSlice(field_value);
                    try self.ring_builder.writeSlice("'");
                },
                else => {},
            }
            if (fields.len > count) {
                try self.ring_builder.writeSlice(", ");
            }
        }
        count += 1;
    }
}

test "update table" {
    var arena = std.heap.c_allocator;
    const UserModel = struct {
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
    try zorm.update(UserModel, "name", SqlValue{ .string = "John" });

    var map = std.StringHashMap(SqlValue).init(arena);
    try map.put("id", SqlValue{ .integer = 10 });
    try map.put("title", SqlValue{ .string = "Rational Optimist" });
    try zorm.where(WhereQuery{ .map = map });

    // zorm.printRingBuff();
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
    const UserModel = struct {
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
    try zorm.delete(UserModel);

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

pub fn selectByCol(
    self: *Self,
    comptime T: type,
    cols: [][]const u8,
) !void {
    assert(@typeInfo(T) == .Struct, "T must be a struct");
    assert(@hasDecl(T, "Table"), "T must have Table declaration");

    try self.ring_builder.writeSlice("SELECT ");
    for (cols, 0..) |c, i| {
        try self.ring_builder.writeSlice(c);
        if (i < cols.len - 1) {
            try self.ring_builder.writeSlice(", ");
        }
    }
    try self.ring_builder.writeSlice(" FROM ");
    const table_name = T.Table;
    try self.ring_builder.writeSlice(table_name);
    self.printRingBuff();
}

pub fn find(self: *Self) ![]const u8 {
    self.printRingBuff();
    return "";
}

pub fn addTerminator(self: *Self) ![]const u8 {
    try self.ring_builder.writeSlice(";");
    // self.printRingBuff();
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
    const UserModel = struct {
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
    try zorm.select(UserModel, "post.id");
    try zorm.join(UserModel, "LEFT", "posts.id", "comments.id");
    const values = [_][]const u8{ "posts.id", "posts.title" };
    try zorm.group(&values);
    var map = std.StringHashMap(SqlValue).init(arena);
    try map.put("posts.id", SqlValue{ .integer = 10 });
    try map.put("posts.title", SqlValue{ .string = "Rational Optimist" });
    try zorm.where(WhereQuery{ .map = map });
    _ = try zorm.exec();
    print("\n", .{});
}
