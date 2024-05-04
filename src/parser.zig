const std = @import("std");

pub const Arg = union(enum) {
    short: struct {
        name: []const u8,
        value: ?[]const u8,
    },
    long: struct {
        name: []const u8,
        value: ?[]const u8,
    },
    positional: []const u8,
};

const Error = error{ OutOfMemory, BadArgument, MissingName, MissingValue };

pub fn parse(allocator: std.mem.Allocator, args: []const []const u8) !struct { []const Arg, []const []const u8 } {
    var parsed_args = try std.ArrayList(Arg).initCapacity(allocator, args.len);
    defer parsed_args.deinit();

    if (args.len == 0) {
        return .{
            try parsed_args.toOwnedSlice(),
            args[0..0],
        };
    }

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (arg.len == 0) {
            return Error.BadArgument;
        }

        if (arg[0] == '-') {
            if (arg.len == 1) {
                try parsed_args.append(.{
                    .positional = arg,
                });
                continue;
            }

            const index = std.mem.indexOfScalar(u8, arg, '=');

            if (arg[1] == '-') {
                if (arg.len == 2) {
                    // Double dash '--'
                    i += 1;
                    break;
                }

                // Long flags

                if (index) |idx| {
                    if (idx == 3) {
                        return Error.MissingName;
                    }
                    if (idx == arg.len - 1) {
                        return Error.MissingValue;
                    }

                    try parsed_args.append(.{ .long = .{
                        .name = arg[2..idx],
                        .value = arg[idx + 1 ..],
                    } });
                } else {
                    try parsed_args.append(.{ .long = .{
                        .name = arg[2..],
                        .value = null,
                    } });
                }

                continue;
            }

            // Short flags

            if (index) |idx| {
                if (index.? > 2) {
                    return Error.BadArgument;
                }
                if (idx == arg.len - 1) {
                    return Error.MissingValue;
                }

                try parsed_args.append(.{ .short = .{
                    .name = arg[1..idx],
                    .value = arg[idx + 1 ..],
                } });
                continue;
            }

            try parsed_args.append(.{ .short = .{
                .name = arg[1..],
                .value = null,
            } });
            continue;
        }

        // Positional and sub commands
        try parsed_args.append(.{ .positional = arg });
    }

    return .{
        try parsed_args.toOwnedSlice(),
        if (i < args.len) args[i..] else args[args.len - 1 .. args.len - 1],
    };
}

test "single short flag" {
    const args, const passthrough = try parse(std.testing.allocator, &.{"-a"});
    defer std.testing.allocator.free(args);

    try std.testing.expectEqual(@as(usize, 1), args.len);
    try std.testing.expectEqual(@as(usize, 0), passthrough.len);

    const arg = args[0];
    try std.testing.expectEqualStrings("short", @tagName(arg));

    const short = arg.short;
    try std.testing.expectEqualStrings("a", short.name);
    try std.testing.expectEqual(@as(?[]const u8, null), short.value);
}

test "multiple short flag" {
    const args, const passthrough = try parse(std.testing.allocator, &.{ "-b", "-c" });
    defer std.testing.allocator.free(args);

    try std.testing.expectEqual(@as(usize, 2), args.len);
    try std.testing.expectEqual(@as(usize, 0), passthrough.len);

    const expected = &[_][]const u8{ "b", "c" };

    for (args, expected) |arg, name| {
        try std.testing.expectEqualStrings("short", @tagName(arg));

        const short = arg.short;
        try std.testing.expectEqualStrings(name, short.name);
        try std.testing.expectEqual(@as(?[]const u8, null), short.value);
    }
}

test "single long flag" {
    const args, const passthrough = try parse(std.testing.allocator, &.{"--foo"});
    defer std.testing.allocator.free(args);

    try std.testing.expectEqual(@as(usize, 1), args.len);
    try std.testing.expectEqual(@as(usize, 0), passthrough.len);

    const arg = args[0];
    try std.testing.expectEqualStrings("long", @tagName(arg));

    const long = arg.long;
    try std.testing.expectEqualStrings("foo", long.name);
    try std.testing.expectEqual(@as(?[]const u8, null), long.value);
}

test "multiple long flag" {
    const args, const passthrough = try parse(std.testing.allocator, &.{ "--bar", "--baz" });
    defer std.testing.allocator.free(args);

    try std.testing.expectEqual(@as(usize, 2), args.len);
    try std.testing.expectEqual(@as(usize, 0), passthrough.len);

    const expected = &[_][]const u8{ "bar", "baz" };

    for (args, expected) |arg, name| {
        try std.testing.expectEqualStrings("long", @tagName(arg));

        const long = arg.long;
        try std.testing.expectEqualStrings(name, long.name);
        try std.testing.expectEqual(@as(?[]const u8, null), long.value);
    }
}

test "positional arguments" {
    const args, const passthrough = try parse(std.testing.allocator, &.{ "foo", "bar" });
    defer std.testing.allocator.free(args);

    try std.testing.expectEqual(@as(usize, 2), args.len);
    try std.testing.expectEqual(@as(usize, 0), passthrough.len);

    const expected = &[_][]const u8{ "foo", "bar" };

    for (args, expected) |arg, value| {
        try std.testing.expectEqualStrings("positional", @tagName(arg));
        try std.testing.expectEqualStrings(value, arg.positional);
    }
}

test "double dash" {
    const args, const passthrough = try parse(std.testing.allocator, &.{ "foo", "--", "bar", "baz" });
    defer std.testing.allocator.free(args);

    try std.testing.expectEqual(@as(usize, 1), args.len);
    try std.testing.expectEqual(@as(usize, 2), passthrough.len);

    try std.testing.expectEqualStrings("positional", @tagName(args[0]));
    try std.testing.expectEqualStrings("foo", args[0].positional);

    const expected = &[_][]const u8{ "bar", "baz" };

    for (passthrough, expected) |arg, value| {
        try std.testing.expectEqualStrings(value, arg);
    }
}
