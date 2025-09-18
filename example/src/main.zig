const std = @import("std");
const args = @import("zig_arg_parser");

const args_definition = args.Definition.init(
    &.{ // Flags (aka boolean 'is present' checks)
        .{ .name = "test_long" },
        .{ .name = "a_test_short", .short = 'a', .desc = "Test Short." },
        .{ .name = "b_test_short", .short = 'b' },
    },
    &.{ // Optionals (aka arguments which require a value)
        .{ .name = "test_optional", .default_value = null },
        .{ .name = "test_short_optional", .short = 'o', .default_value = "def" },
    },
    &.{ // Positionals
        .{ .name = "test_positional" },
        .{ .name = "test_positional_optional", .default_value = "123" },
    },
    .{
        .add_help = true,
        .help_description = "Hello World",
    },
);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() == .leak) {
        std.log.err("GPA detected memory leaks when deinit-ing.", .{});
    };

    try args.init(gpa.allocator());
    defer args.deinit();

    const result_set: args_definition.ResultSet = args.parse(&args_definition) catch {
        try args_definition.printHelp(std.io.getStdOut().writer());
        return; // Dont double print error message
    } orelse {
        return; // If argparse returns null, the program should not continue (a.k.a help argument encountered)
    };

    result_set.log();

    if (result_set.getFlag(.test_long)) std.log.debug("Test long detected!", .{});
}
