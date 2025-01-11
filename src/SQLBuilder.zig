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
                try self.ring_builder.writeSlice(value.type);
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

        if (fields.len > count) {
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
    try self.ring_builder.writeSlice("\n");
    try self.ring_builder.writeSlice(");");
    self.printRingBuff();
}

test "create table" {
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
        test_array: ARRAY = ARRAY{},
    };
    var zorm: Self = undefined;
    try zorm.init(&arena, 1024);

    try zorm.createTable(User);
    print("\n", .{});
}
