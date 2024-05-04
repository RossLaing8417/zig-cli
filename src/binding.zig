const std = @import("std");

const Binding = @This();

const ParseError = error{ ParseIntError, ParseFloatError, ParseBoolError };

target: *anyopaque,
metadata: MetaData,

pub fn bindTo(target: anytype) Binding {
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

const MetaData = struct {
    size: usize,
    parse: ParseFn,

    const ParseFn = *const fn (target: *anyopaque, value: []const u8) ParseError!void;

    fn init(comptime T: type) MetaData {
        const Type = switch (@typeInfo(T)) {
            .Optional => |optional| optional.child,
            else => T,
        };
        return switch (@typeInfo(Type)) {
            .Int => |int| switch (int.signedness) {
                .signed => .{
                    .size = @sizeOf(Type),
                    .parse = struct {
                        fn parse(target: *anyopaque, value: []const u8) ParseError!void {
                            const ref: *Type = @alignCast(@ptrCast(target));
                            ref.* = std.fmt.parseInt(Type, value, 10) catch return ParseError.ParseIntError;
                        }
                    }.parse,
                },
                .unsigned => .{
                    .size = @sizeOf(Type),
                    .parse = struct {
                        fn parse(target: *anyopaque, value: []const u8) ParseError!void {
                            const ref: *Type = @alignCast(@ptrCast(target));
                            ref.* = std.fmt.parseUnsigned(Type, value, 10) catch return ParseError.ParseIntError;
                        }
                    }.parse,
                },
            },
            .Float => .{
                .size = @sizeOf(Type),
                .parse = struct {
                    fn parse(target: *anyopaque, value: []const u8) ParseError!void {
                        const ref: *Type = @alignCast(@ptrCast(target));
                        ref.* = std.fmt.parseFloat(Type, value, 10) catch return ParseError.ParseFloatError;
                    }
                }.parse,
            },
            .Bool => .{
                .size = @sizeOf(Type),
                .parse = struct {
                    fn parse(target: *anyopaque, value: []const u8) ParseError!void {
                        const ref: *Type = @alignCast(@ptrCast(target));
                        if (std.mem.eql(u8, value, "true")) {
                            ref.* = true;
                        } else if (std.mem.eql(u8, value, "false")) {
                            ref.* = false;
                        }
                        return ParseError.ParseBoolError;
                    }
                }.parse,
            },
            .Pointer => .{
                .size = @sizeOf(Type),
                .parse = struct {
                    fn parse(target: *anyopaque, value: []const u8) ParseError!void {
                        const ref: *Type = @alignCast(@ptrCast(target));
                        ref.* = value;
                    }
                }.parse,
            },
            else => @compileError("Unsupported type"),
        };
    }
};
