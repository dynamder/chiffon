const std = @import("std");
const Io = std.Io;

const chiffon = @import("chiffon");

const Command = enum {
    init,
    list,
};

const ChiffonError = error{
    TemplateNotFound,
    TemplateFolderNotFound,
};

pub fn main(init: std.process.Init) !void {
    const chiffon_home_path = init.environ_map.get("CHIFFON_HOME") orelse {
        std.debug.print("`CHIFFON_HOME` not found in the current environment, set it first.", .{});
        std.process.exit(1);
    };

    const io = init.io;
    var buf_out: [128]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf_out);
    const out = &stdout.interface;

    const chiffon_home = std.Io.Dir.openDirAbsolute(io, chiffon_home_path, .{ .iterate = true }) catch |err| switch (err) {
        .FileNotFound => std.debug.print("Path in CHIFFON_HOME not found: {s}", .{chiffon_home_path}),
        .NotDir => std.debug.print("Path in CHIFFON_HOME is not a directory: {s}", .{chiffon_home_path}),
        else => std.debug.print("Unexpected Error in Accessing CHIFFON_HOME: {s}", .{chiffon_home_path}),
    };
    defer chiffon_home.close(io);

    const cwd = std.Io.Dir.cwd();
    defer cwd.close(io);

    const args = init.minimal.args.iterate();
    defer args.deinit();

    _ = args.next();
    const subcommand_arg = args.next() orelse {
        std.debug.print("Missing Subcommands, usage: list, init.\n");
        std.process.exit(2);
    };
    const cmd = std.meta.stringToEnum(Command, subcommand_arg) orelse {
        std.debug.print("Unknown sub command: {s}", .{subcommand_arg});
        std.process.exit(2);
    };

    switch (cmd) {
        .init => try initCmd(io, out, args.next(), chiffon_home, cwd),
        .list => {
            if (args.next() != null) {
                std.debug.print("list subcommand don't need a parameter.\n");
                std.process.exit(2);
            }
            try listCmd(io, out, chiffon_home);
        },
    }
}

fn initCmd(io: std.Io, writer: *std.Io.Writer, template: ?[:0]const u8, chiffon_home: std.io.Dir, cwd: std.io.Dir) !void {
    var it = chiffon_home.iterate();
    while (try it.next(io)) |entry| {
        if (std.mem.eql(u8, entry.name, template.?)) {
            try std.Io.Dir.copyFile(chiffon_home, entry.name, cwd, "AGENTS.md", io, .{ .replace = false });
            writer.writeAll("AGENTS.md template initialized.");
            return;
        }
    }
    return ChiffonError.TemplateNotFound;
}

fn listCmd(io: std.Io, writer: *std.Io.Writer, chiffon_home: std.Io.Dir) !void {
    var it = chiffon_home.iterate();
    while (try it.next(io)) |entry| {
        try writer.writeAll(entry.name);
        try writer.writeAll("\n");
    }
}
