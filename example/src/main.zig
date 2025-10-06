const std = @import("std");
const args = @import("zig_arg_parser");

const args_def = args.Definition.init(
    &.{ .{ .name = "foo" } }, // Flags
    &.{ .{ .name = "bar", .default_value = null } }, // Optionals
    &.{ .{ .name = "car" } }, // Positionals
    .{} // Optional Arguments
);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() == .leak) {
        std.log.err("GPA detected memory leaks when deinit-ing.", .{});
    };

    try args.init(gpa.allocator());
    defer args.deinit();

    const result_set: args.ResultSet(args_def) = args.parse(&args_def) catch {
        try args_def.printHelp();
        return; // Dont double print error message
    } orelse {
        return; // If argparse returns null, the program should not continue (a.k.a help argument encountered)
    };

    if (result_set.getFlag(.foo)) std.log.debug("Foo flag encountered!", .{});

    result_set.log();
}
