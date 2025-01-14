const std = @import("std");
const print = std.debug.print;
const SQLBuilder = @import("SQLBuilder.zig");
const WhereQuery = @import("SQLBuilder.zig").WhereQuery;
const clibpq = @cImport({
    @cInclude("libpq-fe.h");
});

pub const Zorm = @This();
conn: *clibpq.PGconn = undefined,
conn_str: []const u8,
arena: *std.mem.Allocator,
sql_builder: SQLBuilder,

const Query = struct {
    fn Create(comptime Z: type, comptime T: type) type {
        return struct {
            const Self = @This();
            zorm: *Z,
            pub fn init(zorm: *Z) !Self {
                try zorm.sql_builder.createTable(T);
                return Self{ .zorm = zorm };
            }

            pub fn send(self: Self) !void {
                _ = try self.zorm.sql_builder.addTerminator();
                const data = self.zorm.sql_builder.ring_builder.data;
                const len = self.zorm.sql_builder.ring_builder.len();
                const req = data[0..len];
                try self.zorm.exec(req);
            }
        };
    }

    fn Insert(comptime Z: type, comptime T: type) type {
        return struct {
            const Self = @This();
            zorm: *Z,
            pub fn init(zorm: *Z, table_value: T) !Self {
                try zorm.sql_builder.insertTable(T, table_value);
                return Self{ .zorm = zorm };
            }

            pub fn where(self: Self, query: WhereQuery) !Self {
                try self.zorm.sql_builder.where(query);
                return self;
            }

            pub fn send(self: Self) !void {
                _ = try self.zorm.sql_builder.addTerminator();
                const data = self.zorm.sql_builder.ring_builder.data;
                const len = self.zorm.sql_builder.ring_builder.len();
                const req = data[0..len];
                try self.zorm.exec(req);
            }
        };
    }
    fn Select(comptime Z: type, comptime T: type) type {
        return struct {
            const Self = @This();
            zorm: *Z,
            pub fn init(zorm: *Z, query: []const u8) !Self {
                try zorm.sql_builder.select(T, query);
                return Self{ .zorm = zorm };
            }

            pub fn where(self: Self, query: WhereQuery) !Self {
                try self.zorm.sql_builder.where(query);
                return self;
            }

            pub fn send(self: Self) ![]T {
                _ = try self.zorm.sql_builder.addTerminator();
                const data = self.zorm.sql_builder.ring_builder.data;
                const len = self.zorm.sql_builder.ring_builder.len();
                const req = data[0..len];
                return self.zorm.queryTable(T, req);
            }
        };
    }
    fn SelectByCol(comptime Z: type, comptime T: type) type {
        return struct {
            const Self = @This();
            zorm: *Z,
            pub fn init(zorm: *Z, cols: [][]const u8) !Self {
                try zorm.sql_builder.selectByCol(T, cols);
                return Self{ .zorm = zorm };
            }

            pub fn where(self: Self, query: WhereQuery) !Self {
                try self.zorm.sql_builder.where(query);
                return self;
            }

            pub fn send(self: Self) ![]T {
                _ = try self.zorm.sql_builder.addTerminator();
                const data = self.zorm.sql_builder.ring_builder.data;
                const len = self.zorm.sql_builder.ring_builder.len();
                const req = data[0..len];
                return self.zorm.queryTable(T, req);
            }
        };
    }
    fn Update(comptime Z: type, comptime T: type) type {
        return struct {
            const Self = @This();
            zorm: *Z,
            pub fn init(zorm: *Z, value: T) !Self {
                try zorm.sql_builder.update(T, value);
                return Self{ .zorm = zorm };
            }

            pub fn where(self: Self, query: WhereQuery) !Self {
                try self.zorm.sql_builder.where(query);
                return self;
            }

            pub fn send(self: Self) !void {
                _ = try self.zorm.sql_builder.addTerminator();
                const data = self.zorm.sql_builder.ring_builder.data;
                const len = self.zorm.sql_builder.ring_builder.len();
                const req = data[0..len];
                try self.zorm.exec(req);
            }
        };
    }
};

pub const PGSQL_Config = struct { conn_str: []const u8 };

// When using *Zorm then it is a mutable var, else its *constZorm
// this is important for the ring builder
pub fn init(target: *Zorm, config: PGSQL_Config, allocator: *std.mem.Allocator) !void {
    var sql_builder: SQLBuilder = undefined;
    try sql_builder.init(allocator, 4096);

    target.* = .{
        .conn_str = config.conn_str,
        .arena = allocator,
        .sql_builder = sql_builder,
    };
}

pub fn simple(self: *Zorm) !void {
    try self.ring.writeSlice("Hello");
}

pub fn open(self: *Zorm) !void {
    const conn_info: [:0]const u8 = try std.mem.Allocator.dupeZ(
        std.heap.page_allocator,
        u8,
        self.conn_str,
    );
    const conn = clibpq.PQconnectdb(conn_info);
    if (clibpq.PQstatus(conn) != clibpq.CONNECTION_OK) {
        print("Connect failed, err: {s}\n", .{clibpq.PQerrorMessage(conn)});
        return error.connect;
    }
    self.conn = conn.?;
}

pub fn exec(self: Zorm, query: []const u8) !void {
    const sql_query: [:0]const u8 = try std.mem.Allocator.dupeZ(
        std.heap.page_allocator,
        u8,
        query,
    );
    const result = clibpq.PQexec(self.conn, sql_query);
    defer clibpq.PQclear(result);

    if (clibpq.PQresultStatus(result) != clibpq.PGRES_COMMAND_OK) {
        print("exec query failed, query:{s}\n, err: {s}\n", .{ sql_query, clibpq.PQerrorMessage(self.conn) });
        return error.Exec;
    }
}

fn stripBraces(str: []const u8) ![]const u8 {
    if (str.len < 2 or str[0] != '{' or str[str.len - 1] != '}') {
        return error.InvalidFormat;
    }
    return str[1 .. str.len - 1];
}

fn countCommas(str: []const u8) usize {
    var cc: usize = 0;
    for (str) |c| {
        if (c == ',') {
            cc += 1;
        }
    }
    return cc;
}

pub fn select(self: *Zorm, comptime T: type, query: []const u8) !Query.Select(Zorm, T) {
    return Query.Select(Zorm, T).init(self, query);
}

pub fn selectByColumns(self: *Zorm, comptime T: type, cols: [][]const u8) !Query.SelectByCol(Zorm, T) {
    return Query.SelectByCol(Zorm, T).init(self, cols);
}

pub fn insert(self: *Zorm, comptime T: type, value: T) !Query.Insert(Zorm, T) {
    return Query.Insert(Zorm, T).init(self, value);
}

pub fn create(self: *Zorm, comptime T: type) !Query.Create(Zorm, T) {
    return Query.Create(Zorm, T).init(self);
}

pub fn update(
    self: *Zorm,
    comptime T: type,
    value: T,
) !Query.Update(Zorm, T) {
    return Query.Update(Zorm, T).init(self, value);
}

pub fn queryTable(self: Zorm, comptime T: type, query: []const u8) ![]T {
    const sql_query: [:0]const u8 = try std.mem.Allocator.dupeZ(
        std.heap.page_allocator,
        u8,
        query,
    );

    const result = clibpq.PQexec(self.conn, sql_query);
    defer clibpq.PQclear(result);

    if (clibpq.PQresultStatus(result) != clibpq.PGRES_TUPLES_OK) {
        print("exec query failed, query:{s}, err: {s}\n", .{ query, clibpq.PQerrorMessage(self.conn) });
        return error.queryTable;
    }

    const num_rows = clibpq.PQntuples(result);
    const num_cols = clibpq.PQnfields(result);
    var rows: []T = try std.heap.page_allocator.alloc(T, @intCast(num_rows));
    const fields = @typeInfo(T).Struct.fields;

    for (0..@intCast(num_rows)) |row| {
        var item: T = undefined;

        var y: usize = 0;
        while (y < num_cols) : (y += 1) {
            const col_name: []const u8 = std.mem.span(clibpq.PQfname(result, @intCast(y)));
            const value = std.mem.span(clibpq.PQgetvalue(result, @intCast(row), @intCast(y)));
            inline for (fields) |f| {
                if (std.mem.eql(u8, f.name, col_name)) {
                    const field_type = @TypeOf(@field(item, f.name));
                    switch (field_type) {
                        i32 => {
                            const new_value = try std.fmt.parseInt(field_type, value, 10);
                            @field(item, f.name) = new_value;
                        },
                        []const u8, ?[]const u8 => {
                            @field(item, f.name) = value;
                            // const v = @field(item, f.f.name);
                        },
                        bool => {
                            if (std.mem.eql(u8, value, "true")) {
                                @field(item, f.name) = true;
                            } else {
                                @field(item, f.name) = false;
                            }
                        },
                        [][]const u8 => {
                            const buf = try stripBraces(value);
                            const cc = countCommas(buf);

                            var itr = std.mem.tokenizeScalar(u8, buf, ',');
                            const element_type = @TypeOf(itr.peek().?);
                            var arr = try self.arena.alloc(element_type, cc + 1);
                            var i: usize = 0;
                            while (itr.next()) |v| {
                                switch (element_type) {
                                    i32 => {
                                        const v_int = try std.fmt.parseInt(field_type, v, 10);
                                        arr[i] = v_int;
                                    },
                                    []const u8 => {
                                        arr[i] = v;
                                    },
                                    else => {
                                        arr[i] = "";
                                    },
                                }
                                i += 1;
                            }
                            @field(item, f.name) = arr;
                        },
                        else => {
                            @field(item, f.name) = null;
                        },
                    }
                }
            }
        }
        rows[row] = item;
    }

    return rows;
}

pub fn uuidExtension(self: Zorm) !void {
    try self.exec("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"");
}

pub fn deinit(self: *Zorm) void {
    self.sql_builder.ring_builder.deinit(self.arena.*);
    clibpq.PQfinish(self.conn);
}
