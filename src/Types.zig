const std = @import("std");

pub const SMALLINT = struct {
    value: ?i8 = null,
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
    CHECK: ?[]const u8 = null, // Optional check constraint, e.g., "value > 0"
};

pub const INTEGER = struct {
    value: ?i32 = null,
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
    CHECK: ?[]const u8 = null, // Optional check constraint, e.g., "value BETWEEN 1 AND 100"
};

pub const BIGINT = struct {
    value: ?i64 = null,
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
    CHECK: ?[]const u8 = null, // Optional check constraint
};

pub const DECIMAL = struct {
    value: ?i32 = null,
    precision: []const u8 = "10", // Total number of digits
    scale: []const u8 = "2", // Digits after the decimal point
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
    CHECK: ?[]const u8 = null, // Optional check constraint
};

pub const FLOAT = struct {
    value: ?f32 = null,
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
    CHECK: ?[]const u8 = null, // Optional check constraint, e.g., "value >= 0.0"
};

pub const DOUBLE_PRECISION = struct {
    value: ?i32 = null,
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
    CHECK: ?[]const u8 = null, // Optional check constraint
};

pub const TEXT = struct {
    value: ?[]const u8 = null,
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
};

pub const DATE = struct {
    value: ?[]const u8 = null,
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
    default: ?[]const u8 = null, // Optionally specify a default date
};

pub const TIMESTAMP = struct {
    value: ?[]const u8 = null,
    withTimezone: bool = false, // Set to true if using TIMESTAMPTZ
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
    default: ?[]const u8 = "CURRENT_TIMESTAMP", // Common default for timestamps
};

pub const BOOLEAN = struct {
    value: ?bool = null,
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
    default: ?bool = null, // Default value for boolean
};

pub const JSON = struct {
    value: ?[]const u8 = null,
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
};

pub const JSONB = struct {
    value: ?[]const u8 = null,
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
    CHECK: ?[]const u8 = null, // Optional check constraint
};

pub const ARRAY = struct {
    value: ?[]const u8 = null,
    type: []const u8 = "TEXT", // Type of array elements (e.g., TEXT, INTEGER)
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
};

pub const ENUM = struct {
    value: ?[]const u8 = null,
    values: []const []const u8, // List of possible values for the enum
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
    default: ?[]const u8 = null, // Optionally specify a default value
};

pub const BYTEA = struct {
    value: ?[]const u8 = null,
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
};

pub const GEOMETRY = struct {
    value: ?[]const u8 = null,
    type: ?[]const u8 = null, // Specific geometry type (e.g., POINT, POLYGON)
    SRID: ?[]const u8 = null, // Spatial Reference System Identifier
    NOT_NULL: bool = false,
};

pub const UUID = struct {
    value: ?[]const u8 = null,
    type: []const u8 = "UUID",
    primaryKey: bool = undefined,
    default: []const u8 = "uuid_generate_v4()",
    NOT_NULL: bool = false,
};

pub const VARCHAR = struct {
    value: ?[]const u8 = null,
    amount: []const u8 = "255", // Maximum character length
    UNIQUE: bool = false,
    NOT_NULL: bool = false,
};

pub const FOREIGNKEY = struct {
    value: ?[]const u8 = null,
    ID: ?[]const u8 = null,
    TABLE: ?[]const u8 = null,
    COLUMN_NAME: ?[]const u8 = null,
    CASCADE: bool = false,
};
