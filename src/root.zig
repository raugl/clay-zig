const std = @import("std");
const zeroes = std.mem.zeroes;

// Function Forward Declarations ---------------------------------
// for direct calls to the clay c library
pub const cdef = struct {
    // Public API functions ---------------------------------
    pub extern fn Clay_MinMemorySize() u32;
    pub extern fn Clay_CreateArenaWithCapacityAndMemory(capacity: u32, offset: [*c]u8) Arena;
    pub extern fn Clay_SetPointerState(position: Vector2, pointer_down: bool) void;
    pub extern fn Clay_Initialize(arena: Arena, layout_size: Dimensions, error_handler: ErrorHandler) void;
    pub extern fn Clay_UpdateScrollContainers(enable_drag_scrolling: bool, scroll_delta: Vector2, delta_time: f32) void;
    pub extern fn Clay_SetLayoutDimensions(size: Dimensions) void;
    pub extern fn Clay_BeginLayout() void;
    pub extern fn Clay_EndLayout() RenderCommandArray;
    pub extern fn Clay_GetElementId(id_string: String) ElementId;
    pub extern fn Clay_GetElementIdWithIndex(id_string: String, index: u32) ElementId;
    pub extern fn Clay_GetElementIdLocalWithIndex(id_string: String, index: i32) ElementId;
    pub extern fn Clay_Hovered() bool;
    pub extern fn Clay_OnHover(on_hover_function: *const fn (ElementId, PointerData, usize) callconv(.C) void, user_data: usize) void;
    pub extern fn Clay_PointerOver(element_id: ElementId) bool;
    pub extern fn Clay_GetScrollContainerData(id: ElementId) ScrollContainerData;
    pub extern fn Clay_SetMeasureTextFunction(measure_text_function: *const fn (*String, *TextConfig) callconv(.C) Dimensions) void;
    pub extern fn Clay_SetQueryScrollOffsetFunction(query_scroll_offset_function: *const fn (u32) callconv(.C) Vector2) void;
    pub extern fn Clay_RenderCommandArray_Get(array: *RenderCommandArray, index: i32) *RenderCommand;
    pub extern fn Clay_IsDebugModeEnabled() bool;
    pub extern fn Clay_SetDebugModeEnabled(enabled: bool) void;
    pub extern fn Clay_SetCullingEnabled(enabled: bool) void;
    pub extern fn Clay_SetMaxElementCount(max_element_count: u32) void;

    // Internal API functions required by macros
    pub extern fn Clay__SetMaxMeasureTextCacheWordCount(max_measure_text_cache_word_count: u32) void;
    pub extern fn Clay__OpenElement() void;
    pub extern fn Clay__CloseElement() void;
    pub extern fn Clay__StoreLayoutConfig(config: LayoutConfig) *LayoutConfig;
    pub extern fn Clay__ElementPostConfiguration() void;
    pub extern fn Clay__AttachId(id: ElementId) void;
    pub extern fn Clay__AttachLayoutConfig(config: *LayoutConfig) void;
    pub extern fn Clay__AttachElementConfig(config: *anyopaque, type: ElementConfigType) void;
    pub extern fn Clay__StoreRectangleElementConfig(config: RectangleConfig) *RectangleConfig;
    pub extern fn Clay__StoreTextElementConfig(config: TextConfig) *TextConfig;
    pub extern fn Clay__StoreImageElementConfig(config: ImageConfig) *ImageConfig;
    pub extern fn Clay__StoreFloatingElementConfig(config: FloatingConfig) *FloatingConfig;
    pub extern fn Clay__StoreCustomElementConfig(config: CustomConfig) *CustomConfig;
    pub extern fn Clay__StoreScrollElementConfig(config: ScrollConfig) *ScrollConfig;
    pub extern fn Clay__StoreBorderElementConfig(config: BorderConfig) *BorderConfig;
    pub extern fn Clay__HashString(key: String, offset: u32, seed: u32) ElementId;
    pub extern fn Clay__Noop() void;
    pub extern fn Clay__OpenTextElement(text: String, text_config: *TextConfig) void;
    pub extern fn Clay__GetOpenLayoutElementId() ElementId;
    pub extern fn Clay__NextHovered() bool;

    pub extern var CLAY_LAYOUT_DEFAULT: LayoutConfig;
    pub extern var Clay__debugViewHighlightColor: Color;
    pub extern var Clay__debugViewWidth: u32;
};

// Utility Structs ---------------------------------
/// Clay_String is not guaranteed to be null terminated. It may be if created from a
/// literal C string, but it is also used to represent slices.
pub const String = extern struct {
    len: usize,
    chars: [*c]const u8,

    pub fn init(string: []const u8) String {
        return String{ .chars = string.ptr, .len = string.len };
    }

    pub fn slice(self: String) []const u8 {
        return self.chars[0..self.len];
    }
};

pub const StringArray = extern struct {
    capacity: u32,
    len: u32,
    items: [*c]String,
};

pub const Arena = extern struct {
    next_allocation: usize,
    capacity: usize,
    memory: [*c]u8,

    pub fn init(memory: []u8) Arena {
        return cdef.Clay_CreateArenaWithCapacityAndMemory(@intCast(memory.len), @ptrCast(memory));
    }
};

pub const Dimensions = extern struct {
    w: f32 = 0,
    h: f32 = 0,

    pub fn all(size: f32) Dimensions {
        return Dimensions{ .w = size, .h = size };
    }
};

// HACK: Add build option for this
const rl = @import("raylib");
pub const Color = rl.Color;
pub const Vector2 = rl.Vector2;
pub const BoundingBox = rl.Rectangle;

// // TODO: Replace with raylib type
// pub const Vector2 = extern struct {
//     x: f32 = 0,
//     y: f32 = 0,
// };
//
// // TODO: Replace with raylib type
// pub const Color = extern struct {
//     r: f32 = 0,
//     g: f32 = 0,
//     b: f32 = 0,
//     a: f32 = 0,
// };
//
// // TODO: Replace with raylib type
// pub const BoundingBox = extern struct {
//     x: f32 = 0,
//     y: f32 = 0,
//     width: f32 = 0,
//     height: f32 = 0,
// };

// base_id + offset = id
pub const ElementId = extern struct {
    id: u32,
    offset: u32,
    base_id: u32,
    string_id: String,
};

pub const CornerRadius = extern struct {
    top_left: f32 = 0,
    top_right: f32 = 0,
    bottom_left: f32 = 0,
    bottom_right: f32 = 0,

    // TODO: Add factories for more combinations
    pub fn all(radius: f32) CornerRadius {
        return CornerRadius{
            .top_left = radius,
            .top_right = radius,
            .bottom_left = radius,
            .bottom_right = radius,
        };
    }
};

pub const ElementConfigType = enum(u8) {
    rectangle = 1,
    border = 2,
    floating = 4,
    scroll = 8,
    image = 16,
    text = 32,
    custom = 64,
};

// Element Configs ---------------------------------
// Layout
pub const LayoutDirection = enum(u8) {
    left_to_right,
    top_to_bottom,
};

pub const SizingType = enum(u8) {
    fit,
    grow,
    percent,
    fixed,
};

// NOTE: I have merged the per-axis loyout alignments into a single enum as to have
// the same API as `FloatingAttachPointType`
pub const ChildAlignment = enum(u16) {
    left_top = 0x0000,
    left_bottom = 0x0100,
    left_center = 0x0200,
    right_top = 0x0001,
    right_bottom = 0x0101,
    right_center = 0x0201,
    center_top = 0x0002,
    center_bottom = 0x0102,
    center_center = 0x0202,
};

// pub const LayoutAlignmentX = enum(u8) {
//     left,
//     right,
//     center,
// };
//
// pub const LayoutAlignmentY = enum(u8) {
//     top,
//     bottom,
//     center,
// };
//
// pub const ChildAlignment = extern struct {
//     x: LayoutAlignmentX = .left,
//     y: LayoutAlignmentY = .top,
// };

pub const SizingMinMax = extern struct {
    min: f32 = 0,
    max: f32 = 0,
};

pub const SizingConstraint = extern union {
    min_max: SizingMinMax,
    percent: f32,
};

pub const SizingAxis = extern struct {
    size: SizingConstraint = SizingConstraint{ .min_max = .{} },
    type: SizingType = .fit,

    pub const grow = SizingAxis{ .type = .grow, .size = SizingConstraint{ .min_max = .{} } };
    pub const fit = SizingAxis{ .type = .fit, .size = SizingConstraint{ .min_max = .{} } };

    pub fn growMinMax(min_max: SizingMinMax) SizingAxis {
        return SizingAxis{ .type = .grow, .size = SizingConstraint{ .min_max = min_max } };
    }

    pub fn fitMinMax(min_max: SizingMinMax) SizingAxis {
        return SizingAxis{ .type = .fit, .size = SizingConstraint{ .min_max = min_max } };
    }

    pub fn fixed(size: f32) SizingAxis {
        return SizingAxis{
            .type = .fixed,
            .size = SizingConstraint{ .min_max = SizingMinMax{ .max = size, .min = size } },
        };
    }

    /// The range is from 0 to 1, not to 100
    pub fn percent(size: f32) SizingAxis {
        return SizingAxis{ .type = .percent, .size = SizingConstraint{ .percent = size } };
    }
};

pub const Sizing = extern struct {
    w: SizingAxis = .{},
    h: SizingAxis = .{},

    pub const grow = Sizing{ .h = SizingAxis.grow, .w = SizingAxis.grow };
    pub const fit = Sizing{ .h = SizingAxis.fit, .w = SizingAxis.fit };

    pub fn fixed(w: f32, h: f32) Sizing {
        return Sizing{ .w = SizingAxis.fixed(w), .h = SizingAxis.fixed(h) };
    }
};

pub const Padding = extern struct {
    x: u16 = 0,
    y: u16 = 0,

    pub fn all(size: u16) Padding {
        return Padding{ .x = size, .y = size };
    }
};

pub const LayoutConfig = extern struct {
    /// sizing of the element
    sizing: Sizing = .{},
    /// padding arround children
    padding: Padding = .{},
    /// gap between the children
    child_gap: u16 = 0,
    /// alignement of the children
    alignment: ChildAlignment = .left_top,
    /// direction of the children's layout
    direction: LayoutDirection = .left_to_right,
};

pub const default_layout = cdef.CLAY_LAYOUT_DEFAULT;

// Rectangle
pub const RectangleConfig = extern struct {
    color: Color,
    corner_radius: CornerRadius = .{},
};

// Text
pub const TextWrapMode = enum(c_uint) {
    words,
    newlines,
    none,
};

pub const TextConfig = extern struct {
    text_color: Color,
    font_id: u16 = 0,
    font_size: u16 = 20,
    letter_spacing: u16 = 0,
    line_height: u16 = 0,
    wrap_mode: TextWrapMode = .words,
};

// Image
pub const ImageConfig = extern struct {
    image_data: *anyopaque, // TODO: Replace with raylib type
    source_size: Dimensions,
};

// Floating
pub const FloatingAttachPointType = enum(u8) {
    left_top,
    left_center,
    left_bottom,
    center_top,
    center_center,
    center_bottom,
    right_top,
    right_center,
    right_bottom,
};

pub const FloatingAttachPoints = extern struct {
    element: FloatingAttachPointType = .left_top,
    parent: FloatingAttachPointType = .left_top,
};

pub const PointerCaptureMode = enum(c_uint) {
    capture,
    // parent, // TODO: pass pointer through to attached parent
    passthrough,
};

pub const FloatingConfig = extern struct {
    offset: Vector2 = zeroes(Vector2),
    expand: Dimensions = .{},
    z_index: u16 = 0,
    parent_id: u32 = 0,
    attachment: FloatingAttachPoints = .{},
    pointer_capture_mode: PointerCaptureMode = .capture,
};

// Custom
pub const CustomConfig = extern struct {
    custom_data: *anyopaque,
};

// Scroll
pub const ScrollConfig = extern struct {
    horizontal: bool = false,
    vertical: bool = false,

    pub fn all(enabled: bool) ScrollConfig {
        return ScrollConfig{ .horizontal = enabled, .vertical = enabled };
    }
};

// Border
pub const Border = extern struct {
    width: u32 = 0,
    color: Color = zeroes(Color),
};

pub const BorderConfig = extern struct {
    left: Border = .{},
    right: Border = .{},
    top: Border = .{},
    bottom: Border = .{},
    between_children: Border = .{},
    corner_radius: CornerRadius = .{},

    pub fn outside(color: Color, width: u32, radius: f32) BorderConfig {
        const data = Border{ .color = color, .width = width };
        return BorderConfig{
            .left = data,
            .right = data,
            .top = data,
            .bottom = data,
            .between_children = .{},
            .corner_radius = .all(radius),
        };
    }

    pub fn all(color: Color, width: u32, radius: f32) BorderConfig {
        const data = Border{ .color = color, .width = width };
        return BorderConfig{
            .left = data,
            .right = data,
            .top = data,
            .bottom = data,
            .between_children = data,
            .corner_radius = .all(radius),
        };
    }

    pub fn betweenChildren(color: Color, width: u32) BorderConfig {
        const data = Border{ .color = color, .width = width };
        return BorderConfig{ .between_children = data };
    }
};

pub const ElementConfigUnion = extern union {
    rectangle: *RectangleConfig,
    text: *TextConfig,
    image: *ImageConfig,
    flaoting: *FloatingConfig,
    custom: *CustomConfig,
    scroll: *ScrollConfig,
    border: *BorderConfig,
};

pub const ElementConfig = struct {
    id: ?ElementId = null,
    layout: ?LayoutConfig = null,
    rectangle: ?RectangleConfig = null,
    image: ?ImageConfig = null,
    floating: ?FloatingConfig = null,
    custom: ?CustomConfig = null,
    scroll: ?ScrollConfig = null,
    border: ?BorderConfig = null,
};

// Miscellaneous Structs & Enums ---------------------------------
pub const ScrollContainerData = extern struct {
    /// This is a pointer to the real internal scroll position, mutating it may cause a
    /// change in final layout. Intended for use with external functionality that modifies
    /// scroll position, such as scroll bars or auto scrolling.
    scroll_position: *Vector2,
    container_size: Dimensions,
    content_size: Dimensions,
    config: ScrollConfig,
    /// Indicates whether an actual scroll container matched the provided ID or if the
    /// default struct was returned.
    found: bool,
};

pub const RenderCommandType = enum(c_uint) {
    none,
    rectangle,
    border,
    text,
    image,
    scissor_start,
    scissor_end,
    custom,
};

pub const RenderCommand = extern struct {
    bounding_box: BoundingBox,
    config: ElementConfigUnion,
    text: String,
    id: u32,
    type: RenderCommandType,
};

pub const RenderCommandArray = extern struct {
    capacity: u32,
    len: u32,
    items: [*c]RenderCommand,

    pub fn slice(self: RenderCommandArray) []RenderCommand {
        return self.items[0..self.len];
    }

    pub fn get(self: *RenderCommandArray, index: i32) *RenderCommand {
        return cdef.Clay_RenderCommandArray_Get(self, index);
    }
};

pub const PointerInteractionState = enum(c_uint) {
    pressed_this_frame,
    pressed,
    released_this_frame,
    released,
};

pub const PointerData = extern struct {
    position: Vector2 = zeroes(Vector2),
    state: PointerInteractionState = .pressed_this_frame,
};

pub const ErrorType = enum(c_uint) {
    /// User attempted to use `text()` and forgot to call `setMeasureTextFunction()`.
    text_measurement_function_not_provided,
    /// Clay was initialized with an arena that was too small for the configured max element count.
    /// Try using `minMemorySize()` to get the exact number of bytes needed.
    arena_capacity_exceeded,
    /// The declared UI hierarchy has too many elements fo the configured max element count.
    /// Use `setMaxElementCount()` to increase the max, then call `minMemorySize()` again.
    elements_capacity_exceeded,
    /// The declared UI hierarchy has too much text for the configured text measure cache size.
    /// Use `setMaxMeasureTextCacheWordCount()` to increase the max, then call `minMemorySize()` again.
    text_measurement_capacity_exceeded,
    /// Two elements have been declared with the same ID.
    /// Set a breakpoint in your error handler for a stack back trace to where this occurred.
    duplicate_id,
    /// A floating element was declared with a `parent_id` property, but no element with that ID was found.
    /// Set a breakpoint in your error handler for a stack back trace to where this occurred.
    floating_container_parent_not_found,
    /// Clay has encountered an internal logic or memory error. Report this.
    internal_error,
};

pub const ErrorData = extern struct {
    error_type: ErrorType,
    error_text: String,
    user_data: ?*anyopaque = null,
};

pub const ErrorHandler = extern struct {
    function: *const fn (ErrorData) callconv(.C) void = &defaultHandler,
    user_data: ?*anyopaque = null,

    fn defaultHandler(data: ErrorData) callconv(.C) void {
        std.debug.print("[ERROR]: '{s}', '{s}'\n", .{ @tagName(data.error_type), data.error_text.slice() });
    }
};

// Public API functions ---------------------------------
pub const debug_view_highlight_color = cdef.Clay__debugViewHighlightColor;
pub const debug_view_width = cdef.Clay__debugViewWidth;

pub const minMemorySize = cdef.Clay_MinMemorySize;
pub const setPointerState = cdef.Clay_SetPointerState;
pub const initialize = cdef.Clay_Initialize;
pub const updateScrollContainers = cdef.Clay_UpdateScrollContainers;
pub const setLayoutDimensions = cdef.Clay_SetLayoutDimensions;
pub const beginLayout = cdef.Clay_BeginLayout;
pub const endLayout = cdef.Clay_EndLayout;
pub const onHover = cdef.Clay_OnHover; // FIXME: which id?
pub const pointerOver = cdef.Clay_PointerOver;
pub const getScrollContainerData = cdef.Clay_GetScrollContainerData;
pub const getOpenElementId = cdef.Clay__GetOpenLayoutElementId;
pub const setQueryScrollOffsetFunction = cdef.Clay_SetQueryScrollOffsetFunction;
pub const isDebugModeEnabled = cdef.Clay_IsDebugModeEnabled;
pub const setDebugModeEnabled = cdef.Clay_SetDebugModeEnabled;
pub const setCullingEnabled = cdef.Clay_SetCullingEnabled;
pub const setMaxElementCount = cdef.Clay_SetMaxElementCount;

/// Closes the UI element that was most recently opened with `clay.open()`.
pub const close = cdef.Clay__CloseElement;

/// Checks if the element you are about to open is hovered. Can be called before
/// calls to `clay.open()` or `clay.element()`, and also inline in their argument lists.
///
/// Asserts that you have have not used a custom id, in that case you should use
/// `clay.pointerOver(your_custom_id)`.
pub const hovered = cdef.Clay__NextHovered;

/// Hash a string into an id.
pub fn Id(id_string: []const u8) ElementId {
    return cdef.Clay__HashString(String.init(id_string), 0, 0);
}

/// Hash a string and a number into an id.
pub fn IdWithIndex(id_string: []const u8, index: usize) ElementId {
    return cdef.Clay__HashString(String.init(id_string), @intCast(index), 0);
}

/// Hash a string into an id, using the current parent element's id as a seed.
pub fn IdLocal(id_string: []const u8) ElementId {
    return cdef.Clay_GetElementIdLocalWithIndex(String.init(id_string), 0);
}

/// Hash a string and a number into an id, using the current parent element's id as a seed.
pub fn IdLocalWithIndex(id_string: []const u8, index: usize) ElementId {
    return cdef.Clay_GetElementIdLocalWithIndex(String.init(id_string), @intCast(index));
}

/// Set the function used to compute the size of text in pixels.
pub fn setMeasureTextFunction(comptime measureTextFn: fn ([]const u8, *TextConfig) Dimensions) void {
    const Fn = struct {
        pub fn measureText(text_: *String, config: *TextConfig) callconv(.C) Dimensions {
            return measureTextFn(text_.slice(), config);
        }
    };
    cdef.Clay_SetMeasureTextFunction(Fn.measureText);
}

/// Inserts a single text element into the UI with no children.
pub fn text(text_: []const u8, config: TextConfig) void {
    const ptr = cdef.Clay__StoreTextElementConfig(config);
    cdef.Clay__OpenTextElement(String.init(text_), ptr);
}

/// Inserts a single element into the UI with no children.
pub fn element(config: ElementConfig) void {
    _ = open(config);
    close();
}

/// Open a new UI element. Can have any number of children. Must be closed with `clay.close()`.
pub fn open(config: ElementConfig) bool {
    var num_elems: u8 = 0;
    if (config.image != null) num_elems += 1;
    if (config.rectangle != null) num_elems += 1;
    if (config.custom != null) num_elems += 1;
    std.debug.assert(num_elems <= 1);

    cdef.Clay__OpenElement();
    defer cdef.Clay__ElementPostConfiguration();

    if (config.id) |id_| {
        cdef.Clay__AttachId(id_);
    }
    if (config.layout) |conf| {
        const ptr = cdef.Clay__StoreLayoutConfig(conf);
        cdef.Clay__AttachLayoutConfig(ptr);
    }
    if (config.border) |conf| {
        const ptr = cdef.Clay__StoreBorderElementConfig(conf);
        cdef.Clay__AttachElementConfig(@ptrCast(ptr), .border);
    }
    if (config.scroll) |conf| {
        const ptr = cdef.Clay__StoreScrollElementConfig(conf);
        cdef.Clay__AttachElementConfig(@ptrCast(ptr), .scroll);
    }
    if (config.floating) |conf| {
        const ptr = cdef.Clay__StoreFloatingElementConfig(conf);
        cdef.Clay__AttachElementConfig(@ptrCast(ptr), .floating);
    }
    if (config.image) |conf| {
        const ptr = cdef.Clay__StoreImageElementConfig(conf);
        cdef.Clay__AttachElementConfig(@ptrCast(ptr), .image);
    }
    if (config.rectangle) |conf| {
        const ptr = cdef.Clay__StoreRectangleElementConfig(conf);
        cdef.Clay__AttachElementConfig(@ptrCast(ptr), .rectangle);
    }
    if (config.custom) |conf| {
        const ptr = cdef.Clay__StoreCustomElementConfig(conf);
        cdef.Clay__AttachElementConfig(@ptrCast(ptr), .custom);
    }
    return true;
}

test "decls" {
    std.testing.refAllDeclsRecursive(@This());
}
