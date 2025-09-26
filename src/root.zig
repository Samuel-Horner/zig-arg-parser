//! Zig Arg Parser library
//!
//! Example usage:
//! ``` Zig
//! const args = @import("zig_arg_parser");
//!
//! const args_def = args.Definition.init(
//!     &.{ .{ .name = "foo" } }, // Flags
//!     &.{ .{ .name = "foo" .default_value = null } }, // Optionals
//!     &.{ .{ .name = "foo" } }, // Positionals
//!     .{} // Optional Arguments
//! );
//!
//! pub fn main() !void {
//!     var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
//!     defer if (gpa.deinit() == .leak) {
//!         std.log.err("GPA detected memory leaks when deinit-ing.", .{});
//!     };
//!
//!     try args.init(gpa.allocator());
//!     defer args.deinit();
//!
//!     const result_set = args.parse(&args_definition) catch {
//!         try args_definition.printHelp();
//!         return; // Dont double print error message
//!     } orelse {
//!         return; // If argparse returns null, the program should not continue (a.k.a help argument encountered)
//!     };
//!
//!     result_set.log();
//! }
//! ```

const std = @import("std");

/// Struct containing `flag` definition.
/// Used with `Definition.init(...)`.
pub const Flag = struct {
    /// Used for long form arguments and its corresponding EnumMember name.
    name: [:0]const u8,
    /// Short form flag name, single character.
    short: ?u8 = null,
    /// Help description.
    desc: ?[]const u8 = null,
};

/// Struct containing `optional` definition.
/// Used with `Definition.init(...)`.
pub const Optional = struct {
    /// Used for long form arguments and its corresponding EnumMember name.
    name: [:0]const u8,
    /// Short form optional name, single character.
    /// Note that optionals cannot be chained, even with short form names.
    short: ?u8 = null,
    /// Default optional value, must be specified but can be null.
    default_value: ?[:0]const u8,
    /// Help description.
    desc: ?[]const u8 = null,
};

/// Struct containing `positional` definition.
/// Used with `Definition.init(...)`.
pub const Positional = struct {
    /// Used for its corresponding EnumMember name.
    name: [:0]const u8,
    /// Marks the positional as an 'optional positional', with this default value.
    /// Optional positionals *must* be declared after non-optional positionals to prevent undefined behaviour.
    default_value: ?[:0]const u8 = null,
    /// Help Description.
    desc: ?[]const u8 = null,
};

/// Result Set Type Function.
/// Used by `Definition.init(...)`.
pub fn ResultSet(comptime flags_len: comptime_int, comptime optionals: []const Optional, comptime positionals_len: comptime_int, comptime definition: Definition) type {
    return struct {
        /// Flag values, use `getFlag` to retrieve.
        flags: [flags_len]bool = @splat(false),

        /// Optionl values, use `getOptional` to retrieve.
        optionals: [optionals.len]?[]const u8 = blk: {
            var default_optional_values: [optionals.len]?[]const u8 = undefined;
            for (optionals, 0..) |optional, i| {
                default_optional_values[i] = optional.default_value;
            }
            break :blk default_optional_values;
        },

        /// Positional values, use `getPositional` to retrieve.
        positionals: [positionals_len][]const u8 = undefined,

        const Self = @This();

        /// Returns the value of a flag given its enum.
        /// Example: `_ = result_set.getFlag(.foo);`.
        pub fn getFlag(result_set: *const Self, flag_enum: definition.FlagEnum) bool {
            return result_set.flags[definition.getFlagIndex(flag_enum)];
        }

        /// Returns the value of an optional given its enum.
        /// Return value lifetime bounded by `args.init` and `args.deinit` functions.
        /// Example: `_ = result_set.getOptional(.foo);`.
        pub fn getOptional(result_set: *const Self, optional_enum: definition.OptionalEnum) ?[]const u8 {
            return result_set.optionals[definition.getOptionalIndex(optional_enum)];
        }

        /// Returns the value of an optional given its enum.
        /// Return value lifetime bounded by `args.init` and `args.deinit` functions.
        /// Example: `_ = result_set.getPositional(.foo);`.
        pub fn getPositional(result_set: *const Self, positional_enum: definition.PositionalEnum) []const u8 {
            return result_set.positionals[definition.getPositionalIndex(positional_enum)];
        }

        /// Prints values of all arguments using `std.log.debug`
        pub fn log(result_set: *const Self) void {
            std.log.debug("Argument result set:", .{});

            std.log.debug("Flags:", .{});

            for (result_set.flags, 0..) |value, i| {
                std.log.debug("  - {s}: {any}", .{
                    definition.flags[i].name,
                    value,
                });
            }

            std.log.debug("Optionals:", .{});

            for (result_set.optionals, 0..) |value, i| {
                std.log.debug("  - {s}: {?s}", .{
                    definition.optionals[i].name,
                    value,
                });
            }

            std.log.debug("Positionals:", .{});

            for (result_set.positionals, 0..) |value, i| {
                std.log.debug("  - {s}: {s}", .{
                    definition.positionals[i].name,
                    value,
                });
            }
        }
    };
}

/// Comptime-initialised struct containing argument definitions.
pub const Definition = struct {
    /// Flag definitions
    flags: []const Flag,
    /// Optional definitions
    optionals: []const Optional,
    /// Positional definitions
    positionals: []const Positional,

    FlagEnum: type,
    OptionalEnum: type,
    PositionalEnum: type,

    /// Whether or not to add and handle a help argument
    add_help: bool,
    /// A description of the program displayed in its help message
    help_description: ?[]const u8,

    /// Specified ResultSet
    ResultSet: type,

    fn getFlagEnum(definition: *const Definition, name: union(enum) { long: []const u8, short: u8 }) ?definition.FlagEnum {
        switch (name) {
            .long => |long| {
                return std.meta.stringToEnum(definition.FlagEnum, long);
            },
            .short => |short| {
                for (definition.flags) |flag| {
                    if (flag.short == short) {
                        return definition.getFlagEnum(.{ .long = flag.name });
                    }
                }

                return null;
            },
        }
    }

    fn getFlagIndex(definition: *const Definition, flag_enum: definition.FlagEnum) usize {
        return @intFromEnum(flag_enum);
    }

    fn getOptionalEnum(definition: *const Definition, name: union(enum) { long: []const u8, short: u8 }) ?definition.OptionalEnum {
        switch (name) {
            .long => |long| {
                return std.meta.stringToEnum(definition.OptionalEnum, long);
            },
            .short => |short| {
                for (definition.optionals) |optional| {
                    if (optional.short == short) {
                        return definition.getOptionalEnum(.{ .long = optional.name });
                    }
                }

                return null;
            },
        }
    }

    fn getOptionalIndex(definition: *const Definition, optional_enum: definition.OptionalEnum) usize {
        return @intFromEnum(optional_enum);
    }

    fn getPositionalEnum(definition: *const Definition, name: []const u8) ?definition.OptionalEnum {
        return std.meta.stringToEnum(definition.PositionalEnum, name);
    }

    fn getPositionalIndex(definition: *const Definition, optional_enum: definition.OptionalEnum) usize {
        return @intFromEnum(optional_enum);
    }

    /// Prints the programs help message, generated from defined arguments, to stdout.
    pub fn printHelp(definition: *const Definition) !void {
        var out_buffer: [1024]u8 = undefined;
        var out_writer = std.fs.File.stdout().writer(&out_buffer);
        const out = &out_writer.interface;

        try out.print("Usage: {s}", .{args[0]});

        // Print flags into usage string
        for (definition.flags) |flag| {
            if (flag.short != null) {
                try out.print(" [-{c}]", .{flag.short.?});
            } else {
                try out.print(" [--{s}]", .{flag.name});
            }
        }

        // Print optionals into usage string
        for (definition.optionals) |optional| {
            const value_name = try allocator.alloc(u8, optional.name.len);
            defer allocator.free(value_name);
            _ = std.ascii.upperString(value_name, optional.name);

            if (optional.short != null) {
                try out.print(" [-{c} {s}]", .{ optional.short.?, value_name });
            } else {
                try out.print(" [--{s} {s}]", .{ optional.name, value_name });
            }
        }

        // Print positionals into usage string
        for (definition.positionals) |positional| {
            if (positional.default_value != null) {
                try out.print(" [{s}]", .{positional.name});
            } else {
                try out.print(" {s}", .{positional.name});
            }
        }

        try out.print("\n", .{});

        // Print description
        if (definition.help_description != null) {
            try out.print("\n{s}\n", .{definition.help_description.?});
        }

        // Print Positionals
        if (definition.positionals.len > 0) {
            try out.print("\nPositional arguments:\n", .{});

            for (definition.positionals) |positional| {
                try out.print(" {s}", .{positional.name});

                if (positional.desc != null) {
                    try out.print("    {s}", .{positional.desc.?});
                }

                try out.print("\n", .{});
            }
        }

        if (definition.flags.len > 0 or definition.optionals.len > 0) try out.print("\nOptions:\n", .{});

        // Print Flags
        if (definition.flags.len > 0) {
            for (definition.flags) |flag| {
                if (flag.short != null) {
                    try out.print(" -{c},", .{flag.short.?});
                }

                try out.print(" --{s}", .{flag.name});

                if (flag.desc != null) {
                    try out.print("    {s}", .{flag.desc.?});
                }

                try out.print("\n", .{});
            }
        }

        // Print Options
        if (definition.optionals.len > 0) {
            for (definition.optionals) |optional| {
                if (optional.short != null) {
                    try out.print(" -{c},", .{optional.short.?});
                }

                try out.print(" --{s}", .{optional.name});

                const value_name = try allocator.alloc(u8, optional.name.len);
                defer allocator.free(value_name);
                _ = std.ascii.upperString(value_name, optional.name);

                try out.print(" {s}", .{value_name});

                if (optional.desc != null) {
                    try out.print("    {s}", .{optional.desc.?});
                }

                try out.print("\n", .{});
            }
        }

        try out.flush();
    }

    /// Initialises the argument definitions, creates argument enums, and creates a specified ResultSet type.
    pub fn init(
        /// Flag definitions
        comptime in_flags: []const Flag,
        /// Optional definitions
        comptime optionals: []const Optional,
        /// Positional defintions
        comptime positionals: []const Positional,
        comptime definition_args: struct {
            /// Whether or not to add and handle a help argument, defaults to `true`
            add_help: bool = true,
            /// Description of the program to be printed in the help message, defaults to `null`
            help_description: ?[]const u8 = null,
        },
    ) Definition {
        // Flags
        var flags = in_flags;

        if (definition_args.add_help) {
            flags = [1]Flag{.{ .name = "help", .short = 'h', .desc = "Prints this message." }} ++ flags;
        }

        var flag_enum_fields: [flags.len]std.builtin.Type.EnumField = undefined;

        for (flags, 0..) |flag, i| {
            flag_enum_fields[i] = std.builtin.Type.EnumField{ .name = flag.name, .value = i };
        }

        const FlagEnum = @Type(.{
            .@"enum" = .{
                .decls = &.{},
                .tag_type = std.math.IntFittingRange(0, if (flag_enum_fields.len > 0) flag_enum_fields.len - 1 else 0),
                .fields = &flag_enum_fields,
                .is_exhaustive = true,
            },
        });

        // Optionals
        var optional_enum_fields: [optionals.len]std.builtin.Type.EnumField = undefined;

        for (optionals, 0..) |optional, i| {
            optional_enum_fields[i] = std.builtin.Type.EnumField{ .name = optional.name, .value = i };
        }

        const OptionalEnum = @Type(.{
            .@"enum" = .{
                .decls = &.{},
                .tag_type = std.math.IntFittingRange(0, if (optional_enum_fields.len > 0) optional_enum_fields.len - 1 else 0),
                .fields = &optional_enum_fields,
                .is_exhaustive = true,
            },
        });

        // Positionals
        var positional_enum_fields: [positionals.len]std.builtin.Type.EnumField = undefined;

        for (positionals, 0..) |positional, i| {
            positional_enum_fields[i] = std.builtin.Type.EnumField{ .name = positional.name, .value = i };
        }

        const PositionalEnum = @Type(.{
            .@"enum" = .{
                .decls = &.{},
                .tag_type = std.math.IntFittingRange(0, if (positional_enum_fields.len > 0) positional_enum_fields.len - 1 else 0),
                .fields = &positional_enum_fields,
                .is_exhaustive = true,
            },
        });

        var definition = Definition{
            .flags = flags,
            .optionals = optionals,
            .positionals = positionals,

            .FlagEnum = FlagEnum,
            .OptionalEnum = OptionalEnum,
            .PositionalEnum = PositionalEnum,

            .add_help = definition_args.add_help,
            .help_description = definition_args.help_description,

            .ResultSet = undefined,
        };

        definition.ResultSet = ResultSet(flags.len, optionals, positionals.len, definition);

        return definition;
    }
};

var allocator: std.mem.Allocator = undefined;
var args: [][:0]u8 = undefined;

/// Intialises the argument parser, loading arguments into memory.
/// Call at runtime, with `Definition.init(...)` called at comptime.
pub fn init(args_allocator: std.mem.Allocator) !void {
    allocator = args_allocator;

    args = try std.process.argsAlloc(allocator);
}

/// Frees resources.
/// After calling this, all slice-based argument values (a.k.a. optional and positional values) will no longer be valid.
pub fn deinit() void {
    std.process.argsFree(allocator, args);
}

/// Parses arguments according to the given definition.
/// Returns one of:
///   - `error.InvalidArgument`
///   - `error.MissingArgument`
///   - `null`
///   - specified `ResultSet` instance
///
/// If this function returns null, it indicates that it encountered a 'help' argument (and that the definition had `add_help = true`) and therefore the program should halt.
pub fn parse(definition: *const Definition) !?definition.ResultSet {
    var result_set: definition.ResultSet = .{};

    var positional_index: usize = 0;

    var i: usize = 0; // Skip first element, since we increment i before reading arg
    while (i < args.len - 1) {
        i += 1; // Next argument

        const arg = args[i];
        if (arg.len == 0) {
            continue;
        }

        if (arg[0] == '-') {
            if (arg.len < 2) {
                std.log.err("Invalid argument '{s}'.", .{arg});
                return error.InvalidArgument;
            }

            // Possibly a flag or optional
            if (arg[1] == '-') {
                // Optional / Long flag
                if (arg.len < 3) {
                    std.log.err("Invalid argument '{s}'.", .{arg});
                    return error.InvalidArgument;
                }

                // Handle Flag
                if (definition.flags.len > 0) {
                    const flag_enum = definition.getFlagEnum(.{ .long = arg[2..] });

                    if (flag_enum != null) {
                        if (definition.add_help) {
                            if (flag_enum == definition.FlagEnum.help) {
                                try definition.printHelp();
                                return null;
                            }
                        }

                        const index = definition.getFlagIndex(flag_enum.?);
                        result_set.flags[index] = true;

                        continue;
                    }
                }

                // Handle Optional
                if (definition.optionals.len > 0) {
                    const optional_enum = definition.getOptionalEnum(.{ .long = arg[2..] });
                    if (optional_enum != null) {
                        const index = definition.getOptionalIndex(optional_enum.?);
                        result_set.optionals[index] = args[i + 1];
                        i += 1;

                        continue;
                    }
                }

                std.log.err("Invalid argument '{s}'.", .{arg});
                return error.InvalidArgument;
            } else {
                if (arg[1..].len == 1) {
                    if (definition.optionals.len > 0) {
                        // Possibly a short form optional
                        const optional_enum = definition.getOptionalEnum(.{ .short = arg[1] });
                        if (optional_enum != null) {
                            const index = definition.getOptionalIndex(optional_enum.?);
                            result_set.optionals[index] = args[i + 1];
                            i += 1;

                            continue;
                        } // Else treat as a flag and continue to flag processing
                    }
                }

                // Short flag(s)
                if (definition.flags.len > 0) {
                    for (arg[1..]) |short_flag| {
                        const flag_enum = definition.getFlagEnum(.{ .short = short_flag });

                        if (flag_enum != null) {
                            if (definition.add_help) {
                                if (flag_enum == definition.FlagEnum.help) {
                                    try definition.printHelp();
                                    return null;
                                }
                            }

                            const index = definition.getFlagIndex(flag_enum.?);
                            result_set.flags[index] = true;

                            continue;
                        }

                        std.log.err("Invalid argument '{c}'.", .{short_flag});
                        return error.InvalidArgument;
                    }
                } else {
                    std.log.err("Invalid argument '{s}'.", .{arg});
                    return error.InvalidArgument;
                }
            }
        } else {
            // Positional
            if (definition.positionals.len > 0) {
                if (positional_index >= definition.positionals.len) {
                    std.log.err("Unexpected positional argument '{s}'.", .{arg});
                    return error.InvalidArgument;
                }

                result_set.positionals[positional_index] = arg;
                positional_index += 1;
            }
        }
    }

    // Check for missing possitionals and fill with default values.
    if (definition.positionals.len > 0) {
        for (definition.positionals[positional_index..], positional_index..) |positional, j| {
            if (positional.default_value == null) {
                std.log.err("Missing positional argument '{s}'.", .{positional.name});
                return error.MissingArgument;
            }

            result_set.positionals[j] = positional.default_value.?;
        }
    }

    return result_set;
}
