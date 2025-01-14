const std = @import("std");
const TYPES = @import("Types.zig");
const UUID = TYPES.UUID;
const VARCHAR = TYPES.VARCHAR;
const INTEGER = TYPES.INTEGER;
const BOOLEAN = TYPES.BOOLEAN;
const SMALLINT = TYPES.SMALLINT;
const BIGINT = TYPES.BIGINT;
const TIMESTAMP = TYPES.TIMESTAMP;
const DECIMAL = TYPES.DECIMAL;
const TEXT = TYPES.TEXT;
const JSON = TYPES.JSON;
const JSONB = TYPES.JSONB;
const ARRAY = TYPES.ARRAY;
const GEOMETRY = TYPES.GEOMETRY;
const ENUM = TYPES.ENUM;
const BYTEA = TYPES.BYTEA;
const FOREIGNKEY = TYPES.FOREIGNKEY;
const ARRAY_TYPE = TYPES.ARRAY_TYPE;
const Value = TYPES.Value;

const PG = @import("Zorm.zig");
const SQLBuilder = @import("SQLBuilder.zig");
const WhereQuery = SQLBuilder.WhereQuery;
const SqlValue = SQLBuilder.SqlValue;

const UserModel = struct {
    pub const Table = "users";
    user_uuid: UUID = UUID{ .primaryKey = true },
    name: VARCHAR = VARCHAR{ .NOT_NULL = true },
    age: INTEGER = INTEGER{},
    is_active: BOOLEAN = BOOLEAN{},
    favorite_music: ARRAY = ARRAY{ .type = ARRAY_TYPE.TEXT },
};

const UserType = struct {
    pub const Table = UserModel.Table;
    user_uuid: ?[]const u8 = null,
    name: []const u8,
    age: i32,
    is_active: bool,
    favorite_music: [][]const u8,
};

pub fn createTable(db: *PG) !void {
    var query = try db.create(UserModel);
    try query.send();
}

pub fn insertTable(db: *PG) !void {
    var arr = [3][]const u8{
        "Led Zeppelin",
        "Metallica",
        "The Black Keys",
    };

    const user = UserType{
        .name = "Vic",
        .age = 24,
        .is_active = true,
        .favorite_music = &arr,
    };

    try (try db.insert(UserType, user)).send();
}

pub fn updateTable(db: *PG, allocator: std.mem.Allocator) !void {
    var arr = [3][]const u8{
        "Led Zeppelin",
        "Metallica",
        "The Black Keys",
    };

    var user = UserType{
        .name = "Vic",
        .age = 24,
        .is_active = true,
        .favorite_music = &arr,
    };
    user.test_num = 36;
    user.test_value = "Vic-August Rokx-Nellemann";

    var map = std.StringHashMap(SqlValue).init(allocator);
    defer map.deinit();
    try map.put("user_uuid", SqlValue{ .string = "d92c5e5b-d0e3-484e-bfc6-a98be594468b" });

    var query = try db.update(UserType, user);
    query = try query.where(WhereQuery{ .map = map });
    try query.send();
}

pub fn selectUserTable(db: *PG, allocator: std.mem.Allocator) !void {
    var map = std.StringHashMap(SqlValue).init(allocator);
    defer map.deinit();
    try map.put("user_uuid", SqlValue{ .string = "d92c5e5b-d0e3-484e-bfc6-a98be594468b" });

    var query = try db.select(UserType, "*");
    // query = try query.where(WhereQuery{ .map = map });
    const users: []UserType = try query.send();

    for (users) |u| {
        std.debug.print("\n{s}", .{u.user_uuid.?});
    }
    for (users) |u| {
        allocator.free(u.favorite_music);
    }
}

pub fn selectUserSpecificTable(db: *PG, allocator: std.mem.Allocator) !void {
    var map = std.StringHashMap(SqlValue).init(allocator);
    defer map.deinit();
    try map.put("user_uuid", SqlValue{ .string = "d92c5e5b-d0e3-484e-bfc6-a98be594468b" });

    var cols = [2][]const u8{ "name", "age" };
    var query = try db.selectByColumns(UserType, &cols);
    // query = try query.where(WhereQuery{ .map = map });
    const users: []UserType = try query.send();

    for (users) |u| {
        std.debug.print("\n{d}", .{u.age});
    }
    // for (users) |u| {
    //     allocator.free(u.favorite_music);
    // }
}

pub fn main() !void {
    const conn_info = "host=localhost user=postgres password=postgres dbname=mydatabase port=5433 sslmode=disable";

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("Memmory leak...");
    var allocator = gpa.allocator();

    var db: PG = undefined;
    try db.init(PG.PGSQL_Config{ .conn_str = conn_info }, &allocator);
    defer db.deinit();
    try db.open();

    try selectUserSpecificTable(&db, allocator);
}
