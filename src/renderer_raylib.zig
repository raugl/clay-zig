const std = @import("std");
const rl = @import("raylib");
const cl = @import("clay");

pub var fonts: [10]?rl.Font = .{null} ** 10;
var fonts_len: u8 = 0;

pub fn loadFont(file_name: [*:0]const u8, font_size: i32, font_chars: ?[]i32) u16 {
    fonts[fonts_len] = rl.loadFontEx(file_name, font_size, font_chars);
    rl.setTextureFilter(fonts[0].?.texture, .texture_filter_bilinear);
    defer fonts_len += 1;
    return fonts_len;
}

/// Render the list of render commands you got from `cl.endLayout()` using raylib.
/// `alloc` should be a per-frame arena allocator. Other allocation strategies will
/// still produce correct results, but will be a lot slower.
pub fn render(render_commands: cl.RenderCommandArray, alloc: std.mem.Allocator) void {
    for (render_commands.slice()) |*render_command| {
        const vec2 = rl.Vector2.init;
        const bounding_box = render_command.bounding_box;
        const position = vec2(bounding_box.x, bounding_box.y);
        const bounding_size = vec2(bounding_box.width, bounding_box.height);

        switch (render_command.type) {
            .text => {
                // Raylib uses standard C strings so isn't compatible with cheap
                // slices, we need to clone the string to append null terminator
                const config = render_command.config.text;
                const text = alloc.dupeZ(u8, render_command.text.slice()) catch @panic("Out of memory");
                defer alloc.free(text);

                rl.setTextLineSpacing(config.line_height);
                rl.drawTextEx(
                    fonts[config.font_id].?,
                    text,
                    position,
                    @floatFromInt(config.font_size),
                    @floatFromInt(config.letter_spacing),
                    config.text_color,
                );
            },
            .image => {
                const config = render_command.config.image;
                const texture: *const rl.Texture = @alignCast(@ptrCast(config.image_data));
                const scale = bounding_box.width / @as(f32, @floatFromInt(texture.width));
                rl.drawTextureEx(texture.*, position, 0, scale, rl.Color.white);
            },
            .scissor_start => rl.beginScissorMode(
                @intFromFloat(@round(bounding_box.x)),
                @intFromFloat(@round(bounding_box.y)),
                @intFromFloat(@round(bounding_box.width)),
                @intFromFloat(@round(bounding_box.height)),
            ),
            .scissor_end => rl.endScissorMode(),
            .rectangle => {
                const config = render_command.config.rectangle;

                // TODO: Allow for individual corners to be rounded
                if (config.corner_radius.top_left > 0) {
                    const min_side: f32 = @min(bounding_box.width, bounding_box.height);
                    const radius = config.corner_radius.top_left * 2 / min_side;
                    rl.drawRectangleRounded(bounding_box, radius, 8, config.color);
                } else {
                    rl.drawRectangleRec(bounding_box, config.color);
                }
            },
            .border => {
                const config = render_command.config.border;
                const radius = config.corner_radius;
                const left_width: f32 = @floatFromInt(config.left.width);
                const right_width: f32 = @floatFromInt(config.right.width);
                const top_width: f32 = @floatFromInt(config.top.width);
                const bottom_width: f32 = @floatFromInt(config.bottom.width);

                // Left border
                if (left_width > 0) {
                    const rect = rl.Rectangle{
                        .x = bounding_box.x,
                        .y = bounding_box.y + radius.top_left,
                        .width = left_width,
                        .height = bounding_box.height - radius.top_left - radius.bottom_left,
                    };
                    rl.drawRectangleRec(rect, config.left.color);
                }
                // Right border
                if (right_width > 0) {
                    const rect = rl.Rectangle{
                        .x = bounding_box.x + bounding_box.width - right_width,
                        .y = bounding_box.y + radius.top_right,
                        .width = right_width,
                        .height = bounding_box.height - radius.top_right - radius.bottom_right,
                    };
                    rl.drawRectangleRec(rect, config.right.color);
                }
                // Top border
                if (top_width > 0) {
                    const rect = rl.Rectangle{
                        .x = bounding_box.x + radius.top_left,
                        .y = bounding_box.y,
                        .width = bounding_box.width - radius.top_left - radius.top_right,
                        .height = top_width,
                    };
                    rl.drawRectangleRec(rect, config.top.color);
                }
                // Bottom border
                if (bottom_width > 0) {
                    const rect = rl.Rectangle{
                        .x = bounding_box.x + radius.top_left,
                        .y = bounding_box.y + bounding_box.height - bottom_width,
                        .width = bounding_box.width - radius.bottom_left - radius.bottom_right,
                        .height = bottom_width,
                    };
                    rl.drawRectangleRec(rect, config.bottom.color);
                }
                // Top left corner border
                if (radius.top_left > 0) {
                    const center = position.addValue(radius.top_left);
                    const outer_radius = radius.top_left;
                    const inner_radius = outer_radius - top_width;
                    rl.drawRing(center, inner_radius, outer_radius, 180, 270, 10, config.top.color);
                }
                // Top right corner border
                if (radius.top_right > 0) {
                    const center = vec2(
                        position.x + bounding_box.width - radius.top_right,
                        position.y + radius.top_right,
                    );
                    const outer_radius = radius.top_right;
                    const inner_radius = outer_radius - top_width;
                    rl.drawRing(center, inner_radius, outer_radius, 270, 360, 10, config.top.color);
                }
                // Bottom left corner border
                if (radius.bottom_left > 0) {
                    const center = vec2(
                        position.x + radius.bottom_left,
                        position.y + bounding_box.height - radius.bottom_left,
                    );
                    const outer_radius = radius.bottom_left;
                    const inner_radius = outer_radius - bottom_width;
                    rl.drawRing(center, inner_radius, outer_radius, 90, 180, 10, config.bottom.color);
                }
                // Bottom right corner border
                if (radius.bottom_right > 0) {
                    const center = position.add(bounding_size).subtractValue(radius.bottom_right);
                    const outer_radius = radius.bottom_right;
                    const inner_radius = outer_radius - bottom_width;
                    rl.drawRing(center, inner_radius, outer_radius, 0.01, 90, 10, config.bottom.color);
                }
            },
            .custom => {
                // Implement custom element rendering here
            },
            else => @panic("Error: unhandled render command."),
        }
    }
}

pub fn measureText(text: []const u8, config: *cl.TextConfig) cl.Dimensions {
    const font = fonts[config.font_id].?;
    const font_size: f32 = @floatFromInt(config.font_size);

    var byte_counter: usize = 0;
    var max_byte_counter: usize = 0;
    var text_width: f32 = 0.0;
    var max_text_width: f32 = 0.0;
    var text_height: f32 = font_size;
    var utf8 = std.unicode.Utf8View.initUnchecked(text).iterator();

    while (utf8.nextCodepoint()) |codepoint| {
        byte_counter += std.unicode.utf8CodepointSequenceLength(codepoint) catch 1;
        const idx: usize = @intCast(rl.getGlyphIndex(font, @intCast(codepoint)));

        if (codepoint != '\n') {
            if (font.glyphs[idx].advanceX != 0) {
                text_width += @floatFromInt(font.glyphs[idx].advanceX);
            } else {
                text_width += font.recs[idx].width + @as(f32, @floatFromInt(font.glyphs[idx].offsetX));
            }
        } else {
            max_text_width = @max(max_text_width, text_width);
            byte_counter = 0;
            text_width = 0;
            text_height += font_size + @as(f32, @floatFromInt(config.line_height));
        }
        max_byte_counter = @max(max_byte_counter, byte_counter);
    }
    max_text_width = @max(max_text_width, text_width);

    const letter_spacing: f32 = @floatFromInt(config.letter_spacing);
    const scale_factor = font_size / @as(f32, @floatFromInt(font.baseSize));
    const spacing_width = letter_spacing * (@as(f32, @floatFromInt(max_byte_counter)) - 1);

    return cl.Dimensions{
        .h = text_height,
        .w = max_text_width * scale_factor + spacing_width,
    };
}
