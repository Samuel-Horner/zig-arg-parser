# Zig Arg Parser

Simple, comptime focussed, argument parsing library for Zig.

Built targeting stable branch 0.15.1.

See [here](./example/src/main.zig) for example usage.

## Features
- Short and long form flags and optionals
- Chain-able flags
- Required and optional positionals

## Missing Features
- No type system, all argument values are returned as `[]u8`, with lifetimes equal to the result set.
- Chain-able optionals
- Deliminator based multi-value optionals
