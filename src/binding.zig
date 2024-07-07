const std = @import("std");

const Binding = @This();

target: *anyopaque,
count: usize = 0,
metadata: MetaData,

pub fn bind(target: anytype) Binding {
    const T = @typeInfo(@TypeOf(target)).Pointer.child;

    switch (@typeInfo(T)) {
        .Pointer => |pointer| {
            switch (pointer.size) {
                .Slice => {
                    if (pointer.child == u8) {
                        return .{
                            .target = @ptrCast(target),
                            .metadata = MetaData.init(T),
                        };
                    } else {
                        @compileError("Only u8 slices are supported currently");
                    }
                },
                else => @compileError("Only u8 slices are supported currently"),
            }
        },
        else => return .{
            .target = target,
            .metadata = MetaData.init(T),
        },
    }
}

const ParseError = error{
    ParseIntError,
    ParseFloatError,
    ParseBoolError,
    ParseStringError,
    ParseEnumError,
};

pub fn parse(self: *Binding, value: ?[]const u8) ParseError!void {
    self.count += 1;
    try self.metadata.parse(self.target, value);
}

const MetaData = struct {
    size: usize,
    bool: bool = false,
    parse: ParseFn,

    const ParseFn = *const fn (target: *anyopaque, value: ?[]const u8) ParseError!void;

    fn init(comptime T: type) MetaData {
        const Type = switch (@typeInfo(T)) {
            .Optional => |optional| optional.child,
            else => T,
        };
        return switch (@typeInfo(Type)) {
            .Int => .{
                .size = @sizeOf(Type),
                .parse = struct {
                    fn parse(target: *anyopaque, value: ?[]const u8) !void {
                        try parseInt(Type, target, value);
                    }
                }.parse,
            },
            .Float => .{
                .size = @sizeOf(Type),
                .parse = struct {
                    fn parse(target: *anyopaque, value: ?[]const u8) !void {
                        try parseFloat(Type, target, value);
                    }
                }.parse,
            },
            .Bool => .{
                .size = @sizeOf(Type),
                .bool = true,
                .parse = struct {
                    fn parse(target: *anyopaque, value: ?[]const u8) !void {
                        try parseBool(Type, target, value);
                    }
                }.parse,
            },
            .Pointer => .{
                .size = @sizeOf(Type),
                .parse = struct {
                    fn parse(target: *anyopaque, value: ?[]const u8) !void {
                        try parseString(Type, target, value);
                    }
                }.parse,
            },
            .Enum => .{
                .size = @sizeOf(Type),
                .parse = struct {
                    fn parse(target: *anyopaque, value: ?[]const u8) !void {
                        try parseEnum(Type, target, value);
                    }
                }.parse,
            },
            else => @compileError("Unsupported type"),
        };
    }
};

fn parseInt(comptime T: type, target: *anyopaque, value: ?[]const u8) ParseError!void {
    const int = @typeInfo(T).Int;
    const ref: *T = @alignCast(@ptrCast(target));
    if (value) |val| {
        switch (int.signedness) {
            .signed => ref.* = std.fmt.parseInt(T, val, 10) catch return ParseError.ParseIntError,

            .unsigned => ref.* = std.fmt.parseUnsigned(T, val, 10) catch return ParseError.ParseIntError,
        }
    } else {
        return ParseError.ParseIntError;
    }
}

fn parseFloat(comptime T: type, target: *anyopaque, value: ?[]const u8) ParseError!void {
    const ref: *T = @alignCast(@ptrCast(target));
    if (value) |val| {
        ref.* = std.fmt.parseFloat(T, val) catch return ParseError.ParseFloatError;
    } else {
        return ParseError.ParseFloatError;
    }
}

fn parseBool(comptime T: type, target: *anyopaque, value: ?[]const u8) ParseError!void {
    const ref: *T = @alignCast(@ptrCast(target));
    if (value) |val| {
        if (std.mem.eql(u8, val, "true")) {
            ref.* = true;
        } else if (std.mem.eql(u8, val, "false")) {
            ref.* = false;
        } else {
            return ParseError.ParseBoolError;
        }
    } else {
        ref.* = true;
    }
}

fn parseString(comptime T: type, target: *anyopaque, value: ?[]const u8) ParseError!void {
    const ref: *T = @alignCast(@ptrCast(target));
    if (value) |val| {
        ref.* = val;
    } else {
        return ParseError.ParseStringError;
    }
}

fn parseEnum(comptime T: type, target: *anyopaque, value: ?[]const u8) ParseError!void {
    if (value) |val| {
        const ref: *T = @alignCast(@ptrCast(target));
        const enum_info = @typeInfo(T).Enum;
        inline for (enum_info.fields) |field| {
            if (std.mem.eql(u8, field.name, val)) {
                ref.* = @field(T, field.name);
                return;
            }
        }
    }
    return ParseError.ParseEnumError;
}
