const std = @import("std");
const NOTFOUND = "Not Found";
const PAYLOAD_TOO_LARGE = "Payload Too Large";
const BAD_REQUEST = "Bad Request";
const TEXT = "text/html; charset=utf8";
const defaulttemplate =
    \\HTTP/1.1 {d} {s}
    \\Connection: close
    \\Content-Type: {s}
    \\Content-Length: {d}
    \\{s}
;
const img_template =
    \\HTTP/1.1 200 OK
    \\Connection: close
    \\Content-Type: image/png
    \\Content-Length: {d}
    \\
    \\
;
const http404 = std.fmt.comptimePrint(defaulttemplate, .{ 404, NOTFOUND, TEXT, NOTFOUND.len, NOTFOUND });
const http413 = std.fmt.comptimePrint(defaulttemplate, .{ 413, PAYLOAD_TOO_LARGE, TEXT, PAYLOAD_TOO_LARGE.len, PAYLOAD_TOO_LARGE });
const http400 = std.fmt.comptimePrint(defaulttemplate, .{ 400, BAD_REQUEST, TEXT, BAD_REQUEST.len, BAD_REQUEST });

fn parse_path(request_line: []const u8) ![]const u8 {
    var line_iterator = std.mem.tokenizeScalar(u8, request_line, ' ');
    const request_type = line_iterator.next() orelse return error.HeaderMalformed;
    if (!std.mem.eql(u8, request_type, "GET")) {
        return error.ExpectedGET;
    }
    const path = line_iterator.next() orelse return error.HeaderMalformed;
    return path;
}
const Date = struct { year: u16, month: u16, day: u16 };
fn parse_date(date_line: []const u8) !Date {
    var date_iterator = std.mem.tokenizeScalar(u8, date_line, '/');
    _ = date_iterator.next();
    const year = try std.fmt.parseInt(u16, date_iterator.next() orelse return error.YearNotPresent, 10);
    const month = try std.fmt.parseInt(u16, date_iterator.next() orelse return error.MonthNotPresent, 10);
    const day = try std.fmt.parseInt(u16, date_iterator.next() orelse return error.DayNotPresent, 10);
    return Date{ .day = day, .month = month, .year = year };
}

pub fn openLocalFile(path: []const u8) ![]u8 {
    const localPath = path;
    const file = std.fs.cwd().openFile(localPath, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("File not found: {s}\n", .{localPath});
            return error.FileNotFound;
        },
        else => return err,
    };
    defer file.close();
    std.debug.print("file: {}\n", .{file});
    const memory = std.heap.page_allocator;
    const maxSize = std.math.maxInt(usize);
    return try file.readToEndAlloc(memory, maxSize);
}

pub fn main() !void {
    const address = try std.net.Address.resolveIp("::", 8086);
    var server = try address.listen(.{ .reuse_address = true });
    std.debug.print("{}\n", .{address});
    while (server.accept()) |connection| {
        defer connection.stream.close();
        var buffer: [4 * 1024]u8 = undefined;
        const bytes_read = connection.stream.read(&buffer) catch |err| {
            std.debug.print("{s}\n", .{@errorName(err)});
            continue;
        };
        // If the request data is more than 4KB, return can't handle.
        if (bytes_read >= 4 * 1024) {
            try connection.stream.writeAll(http413);
            continue;
        }
        const content = buffer[0..bytes_read];
        std.debug.print("{s}\n", .{content});
        var request_iterator = std.mem.tokenizeSequence(u8, content, "\r\n");
        // Parse content
        const path = parse_path(request_iterator.next() orelse {
            try connection.stream.writeAll(http400);
            continue;
        }) catch |err| {
            std.debug.print("{s}", .{@errorName(err)});
            continue;
        };

        if (std.mem.startsWith(u8, path, "/date")) {
            const date = parse_date(path) catch |err| {
                std.debug.print("{s}", .{@errorName(err)});
                continue;
            };
            const total: u16 = (date.day + date.month + date.year) % 12;
            const file_path = std.fmt.allocPrint(std.heap.page_allocator, "resources/tarots/{}.png", .{total}) catch |err| {
                std.debug.print("{s}", .{@errorName(err)});
                continue;
            };
            defer std.heap.page_allocator.free(file_path);
            const buf = openLocalFile(file_path) catch |err| {
                std.debug.print("{s}", .{@errorName(err)});
                continue;
            };
            defer std.heap.page_allocator.free(buf);
            _ = try connection.stream.writer().print(img_template, .{buf.len});
            _ = try connection.stream.writeAll(buf);
        }
        try connection.stream.writeAll(http404);
    } else |err| {
        return err;
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
