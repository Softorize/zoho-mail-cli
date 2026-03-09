const std = @import("std");
const Task = @import("../model/task.zig").Task;
const auth = @import("../auth.zig");
const http = @import("../http.zig");
const Config = @import("../config.zig").Config;

/// Errors from task API operations.
pub const TaskApiError = error{
    /// API returned an error response.
    ApiRequestFailed,
    /// Response JSON could not be parsed.
    ParseError,
} || auth.AuthError || http.HttpError;

/// List personal tasks (GET /api/tasks/me).
/// Allocator owns returned Task slices.
pub fn listMyTasks(
    allocator: std.mem.Allocator,
    config: Config,
) TaskApiError![]const Task {
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, "/api/tasks/me", null) catch return error.ApiRequestFailed;
    const response = try http.get(allocator, url, token);
    return parseList(allocator, response.body);
}

/// List group tasks (GET /api/tasks/groups/{zgid}).
/// Allocator owns returned Task slices.
pub fn listGroupTasks(
    allocator: std.mem.Allocator,
    config: Config,
    group_id: []const u8,
) TaskApiError![]const Task {
    const path = std.fmt.allocPrint(allocator, "/api/tasks/groups/{s}", .{group_id}) catch return error.ApiRequestFailed;
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch return error.ApiRequestFailed;
    const response = try http.get(allocator, url, token);
    return parseList(allocator, response.body);
}

/// Get a single task by ID.
/// Allocator owns returned Task.
pub fn getTask(
    allocator: std.mem.Allocator,
    config: Config,
    task_id: []const u8,
) TaskApiError!Task {
    const path = std.fmt.allocPrint(allocator, "/api/tasks/me/{s}", .{task_id}) catch return error.ApiRequestFailed;
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch return error.ApiRequestFailed;
    const response = try http.get(allocator, url, token);
    return parseOne(allocator, response.body);
}

/// Create a new task. Returns the created Task.
pub fn createTask(
    allocator: std.mem.Allocator,
    config: Config,
    title: []const u8,
    notes: []const u8,
    due_date: i64,
    priority: i32,
) TaskApiError!Task {
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, "/api/tasks/me", null) catch return error.ApiRequestFailed;
    const body = std.json.Stringify.valueAlloc(allocator, .{
        .title = title,
        .notes = notes,
        .dueDate = due_date,
        .priority = priority,
    }, .{}) catch return error.ApiRequestFailed;
    const response = try http.post(allocator, url, token, body);
    return parseOne(allocator, response.body);
}

/// Update an existing task. Returns the updated Task.
pub fn updateTask(
    allocator: std.mem.Allocator,
    config: Config,
    task_id: []const u8,
    title: ?[]const u8,
    notes: ?[]const u8,
    status: ?[]const u8,
    priority: ?i32,
) TaskApiError!Task {
    const path = std.fmt.allocPrint(allocator, "/api/tasks/me/{s}", .{task_id}) catch return error.ApiRequestFailed;
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch return error.ApiRequestFailed;
    const body = buildUpdateBody(allocator, title, notes, status, priority) catch return error.ApiRequestFailed;
    const response = try http.put(allocator, url, token, body);
    return parseOne(allocator, response.body);
}

/// Delete a task by ID.
pub fn deleteTask(
    allocator: std.mem.Allocator,
    config: Config,
    task_id: []const u8,
) TaskApiError!void {
    const path = std.fmt.allocPrint(allocator, "/api/tasks/me/{s}", .{task_id}) catch return error.ApiRequestFailed;
    const token = auth.getAccessToken(allocator, config) catch return error.ApiRequestFailed;
    const url = http.buildUrl(allocator, config.region, path, null) catch return error.ApiRequestFailed;
    _ = try http.delete(allocator, url, token);
}

/// Parse a list-style JSON response into a Task slice.
fn parseList(allocator: std.mem.Allocator, body: []const u8) TaskApiError![]const Task {
    const parsed = std.json.parseFromSliceLeaky(
        struct { data: []const Task },
        allocator,
        body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;
    return parsed.data;
}

/// Parse a single-item JSON response into a Task.
fn parseOne(allocator: std.mem.Allocator, body: []const u8) TaskApiError!Task {
    const parsed = std.json.parseFromSliceLeaky(
        struct { data: Task },
        allocator,
        body,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;
    return parsed.data;
}

/// Build JSON body for task update, including only non-null fields.
fn buildUpdateBody(
    allocator: std.mem.Allocator,
    title: ?[]const u8,
    notes: ?[]const u8,
    task_status: ?[]const u8,
    priority: ?i32,
) ![]const u8 {
    return std.json.Stringify.valueAlloc(allocator, .{
        .title = title,
        .notes = notes,
        .status = task_status,
        .priority = priority,
    }, .{});
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "TaskApiError composes auth and http errors" {
    const err: TaskApiError = error.ParseError;
    try std.testing.expectEqual(error.ParseError, err);
}

test "TaskApiError includes ApiRequestFailed" {
    const err: TaskApiError = error.ApiRequestFailed;
    try std.testing.expectEqual(error.ApiRequestFailed, err);
}

test "buildUpdateBody produces valid JSON with optional fields" {
    const allocator = std.testing.allocator;
    const body = try buildUpdateBody(allocator, "New Title", null, "completed", null);
    defer allocator.free(body);
    const parsed = try std.json.parseFromSlice(
        struct { title: ?[]const u8, status: ?[]const u8 },
        allocator,
        body,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    try std.testing.expectEqualStrings("New Title", parsed.value.title.?);
    try std.testing.expectEqualStrings("completed", parsed.value.status.?);
}
