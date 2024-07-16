const std = @import("std");

const Binding = @This();

target: *anyopaque,
count: usize = 0,
metadata: MetaData,
allocator: ?std.mem.Allocator = null,

pub fn bind(target: anytype) Binding {
    const Type = @typeInfo(@TypeOf(target)).Pointer.child;

    const T = switch (@typeInfo(Type)) {
        .Optional => |optional| optional.child,
        else => Type,
    };

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

pub fn bindSlice(target: anytype, allocator: std.mem.Allocator) Binding {
    const Type = @typeInfo(@TypeOf(target)).Pointer.child;

    const T = switch (@typeInfo(Type)) {
        .Optional => |optional| optional.child,
        else => Type,
    };

    switch (@typeInfo(T)) {
        .Pointer => |pointer| {
            switch (pointer.size) {
                .Slice => {
                    const Child = @typeInfo(pointer.child);
                    if (Child == .Pointer and Child.Pointer.child != u8) {
                        @compileError("Slice of pointers are currently not supported");
                    }
                    return .{
                        .target = @ptrCast(target),
                        .metadata = MetaData.initSlice(pointer.child, allocator),
                        .allocator = allocator,
                    };
                },
                else => @compileError("bindSlice requires a slice"),
            }
        },
        else => @compileError("bindSlice requires a slice"),
    }
}

const ParseError = error{
    ParseIntError,
    ParseFloatError,
    ParseBoolError,
    ParseStringError,
    ParseEnumError,
} || std.mem.Allocator.Error;

pub fn parse(self: *Binding, value: ?[]const u8) ParseError!void {
    self.count += 1;
    try self.metadata.parse(self.target, self.allocator, value);
}

const MetaData = struct {
    size: usize,
    bool: bool = false,
    parse: ParseFn,

    const ParseFn = *const fn (target: *anyopaque, allocator: ?std.mem.Allocator, value: ?[]const u8) ParseError!void;

    fn init(comptime T: type) MetaData {
        return .{
            .size = @sizeOf(T),
            .parse = getParseFn(T),
        };
    }

    fn initSlice(T: type, allocator: std.mem.Allocator) MetaData {
        _ = allocator;
        return .{
            .size = @sizeOf(T),
            .parse = getParseSliceFn(T),
        };
    }
};

fn getParseFn(comptime T: type) MetaData.ParseFn {
    return switch (@typeInfo(T)) {
        .Int => struct {
            fn parse(target: *anyopaque, _: ?std.mem.Allocator, value: ?[]const u8) !void {
                try parseInt(T, target, value);
            }
        }.parse,
        .Float => struct {
            fn parse(target: *anyopaque, _: ?std.mem.Allocator, value: ?[]const u8) !void {
                try parseFloat(T, target, value);
            }
        }.parse,
        .Bool => struct {
            fn parse(target: *anyopaque, _: ?std.mem.Allocator, value: ?[]const u8) !void {
                try parseBool(T, target, value);
            }
        }.parse,
        .Pointer => struct {
            fn parse(target: *anyopaque, _: ?std.mem.Allocator, value: ?[]const u8) !void {
                try parseString(T, target, value);
            }
        }.parse,
        .Enum => struct {
            fn parse(target: *anyopaque, _: ?std.mem.Allocator, value: ?[]const u8) !void {
                try parseEnum(T, target, value);
            }
        }.parse,
        else => @compileError("Unsupported type"),
    };
}

fn getParseSliceFn(comptime T: type) MetaData.ParseFn {
    return struct {
        fn parse(target: *anyopaque, allocator: ?std.mem.Allocator, value: ?[]const u8) !void {
            std.debug.assert(allocator != null);
            const slice_ptr: *[]T = @alignCast(@ptrCast(target));
            if (!allocator.?.resize(slice_ptr.*, slice_ptr.len + 1)) {
                slice_ptr.* = try allocator.?.realloc(slice_ptr.*, slice_ptr.len + 1);
            }
            const value_parse = getParseFn(T);
            const element_ptr: *T = &slice_ptr.*[slice_ptr.len - 1];
            try value_parse(@ptrCast(element_ptr), null, value);
        }
    }.parse;
}

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
