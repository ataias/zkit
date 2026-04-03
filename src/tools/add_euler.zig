const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const process = std.process;

pub fn main(init: process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var args = init.minimal.args.iterate();
    _ = args.skip();

    const problem_num_str = args.next() orelse {
        std.debug.print("Usage: add-euler <problem-number>\nExample: add-euler 9\n", .{});
        process.exit(1);
    };

    const problem_num = std.fmt.parseInt(u32, problem_num_str, 10) catch {
        std.debug.print("Error: '{s}' is not a valid problem number\n", .{problem_num_str});
        process.exit(1);
    };

    const padded = try std.fmt.allocPrint(gpa, "{d:0>4}", .{problem_num});
    defer gpa.free(padded);

    var variant: u32 = 1;
    while (true) {
        const path = try std.fmt.allocPrint(gpa, "src/euler/p{s}_{d}.zig", .{ padded, variant });
        defer gpa.free(path);
        Dir.cwd().access(io, path, .{}) catch break;
        variant += 1;
    }

    const name = try std.fmt.allocPrint(gpa, "p{s}_{d}", .{ padded, variant });
    defer gpa.free(name);
    const filepath = try std.fmt.allocPrint(gpa, "src/euler/{s}.zig", .{name});
    defer gpa.free(filepath);

    const url = try std.fmt.allocPrint(gpa, "https://projecteuler.net/minimal={d}", .{problem_num});
    defer gpa.free(url);

    std.debug.print("Fetching {s} ...\n", .{url});
    const result = try process.run(gpa, io, .{ .argv = &.{ "curl", "-sL", url } });
    defer gpa.free(result.stdout);
    defer gpa.free(result.stderr);

    if (result.term != .exited or result.term.exited != 0) {
        std.debug.print("Error: curl failed\n", .{});
        process.exit(1);
    }

    if (result.stdout.len == 0) {
        std.debug.print("Error: empty response from server\n", .{});
        process.exit(1);
    }

    try createSourceFile(io, filepath, problem_num, result.stdout);
    try updateBuildZig(gpa, io, name);

    const fmt_result = process.run(gpa, io, .{ .argv = &.{ "zig", "fmt", filepath, "build.zig" } }) catch null;
    if (fmt_result) |r| {
        gpa.free(r.stdout);
        gpa.free(r.stderr);
    }

    std.debug.print("\nCreated {s}\nUpdated build.zig\n\nNext steps:\n  zig build run-{s}\n  zig build test\n", .{ filepath, name });
}

fn createSourceFile(io: Io, filepath: []const u8, problem_num: u32, html: []const u8) !void {
    var buf: [4096]u8 = undefined;
    const file = try Dir.cwd().createFile(io, filepath, .{});
    defer file.close(io);
    var writer = file.writer(io, &buf);
    const w = &writer.interface;

    try w.print("//! Project Euler Problem: https://projecteuler.net/problem={d}\n//!\n", .{problem_num});

    var lines = std.mem.splitScalar(u8, html, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len > 0) {
            try w.print("//! {s}\n", .{trimmed});
        }
    }

    try w.writeAll(
        \\
        \\const std = @import("std");
        \\
        \\pub fn main() void {
        \\    // TODO: implement
        \\}
        \\
        \\// TODO: implement solution
        \\
        \\test "solution" {
        \\    // TODO: add tests
        \\}
        \\
    );
    try writer.flush();
}

fn updateBuildZig(gpa: Allocator, io: Io, new_name: []const u8) !void {
    const source = try Dir.cwd().readFileAllocOptions(io, "build.zig", gpa, .unlimited, .@"1", 0);
    defer gpa.free(source);

    var ast = try std.zig.Ast.parse(gpa, source, .zig);
    defer ast.deinit(gpa);

    const token_count: u32 = @intCast(ast.tokens.len);
    var euler_tok: ?u32 = null;
    for (0..token_count) |i| {
        const idx: u32 = @intCast(i);
        if (ast.tokenTag(idx) == .identifier) {
            if (std.mem.eql(u8, ast.tokenSlice(idx), "euler_problems")) {
                euler_tok = idx;
                break;
            }
        }
    }
    const et = euler_tok orelse return error.EulerProblemsNotFound;

    var tuple_dot: u32 = et;
    while (tuple_dot < token_count - 1) : (tuple_dot += 1) {
        if (ast.tokenTag(tuple_dot) == .period and ast.tokenTag(tuple_dot + 1) == .l_brace) break;
    }
    const tuple_lbrace = tuple_dot + 1;

    var depth: u32 = 0;
    var tuple_rbrace: u32 = tuple_lbrace + 1;
    while (tuple_rbrace < token_count) : (tuple_rbrace += 1) {
        if (ast.tokenTag(tuple_rbrace) == .l_brace) {
            depth += 1;
        } else if (ast.tokenTag(tuple_rbrace) == .r_brace) {
            if (depth == 0) break;
            depth -= 1;
        }
    }

    var entries: std.ArrayListUnmanaged([]const u8) = .empty;
    defer entries.deinit(gpa);

    for (tuple_lbrace..tuple_rbrace) |tok_i| {
        const idx: u32 = @intCast(tok_i);
        if (ast.tokenTag(idx) == .string_literal) {
            const lit = ast.tokenSlice(idx);
            try entries.append(gpa, lit[1 .. lit.len - 1]);
        }
    }

    for (entries.items) |entry| {
        if (std.mem.eql(u8, entry, new_name)) {
            std.debug.print("Entry \"{s}\" already exists in build.zig\n", .{new_name});
            return;
        }
    }

    const owned_name = try gpa.dupe(u8, new_name);
    defer gpa.free(owned_name);
    try entries.append(gpa, owned_name);

    std.mem.sort([]const u8, entries.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lessThan);

    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(gpa);
    try buf.appendSlice(gpa, ".{ ");
    for (entries.items, 0..) |entry, idx| {
        try buf.appendSlice(gpa, "\"");
        try buf.appendSlice(gpa, entry);
        try buf.appendSlice(gpa, "\"");
        if (idx + 1 < entries.items.len) {
            try buf.appendSlice(gpa, ", ");
        }
    }
    try buf.appendSlice(gpa, " }");

    const replace_start = ast.tokenStart(tuple_dot);
    const rbrace_start = ast.tokenStart(tuple_rbrace);
    const replace_end = rbrace_start + 1;

    var output: std.ArrayListUnmanaged(u8) = .empty;
    defer output.deinit(gpa);
    try output.appendSlice(gpa, source[0..replace_start]);
    try output.appendSlice(gpa, buf.items);
    try output.appendSlice(gpa, source[replace_end..source.len]);

    try Dir.cwd().writeFile(io, .{ .sub_path = "build.zig", .data = output.items });
}
