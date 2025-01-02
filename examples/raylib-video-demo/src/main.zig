const std = @import("std");
const cl = @import("clay");
const rl = @import("raylib");
const renderer = @import("clay_renderer");

const FONT_ID_BODY_16 = 0;
const COLOR_WHITE = cl.Color.init(255, 255, 255, 255);

const Document = struct {
    title: []const u8,
    contents: []const u8,
};

var selected_document_index: usize = 0;

pub fn main() !void {
    rl.setConfigFlags(.{
        .window_resizable = true,
        .window_highdpi = true,
        .msaa_4x_hint = true,
        .vsync_hint = true,
    });
    rl.setTraceLogLevel(.log_warning);
    rl.initWindow(1024, 768, "Introducing Clay Demo");
    defer rl.closeWindow();

    const alloc = std.heap.page_allocator;
    const clay_memory = try alloc.alloc(u8, cl.minMemorySize());
    defer alloc.free(clay_memory);

    // An arena allocater that gets reset at the end of each frame. Allows cheap, frequent allocations.
    var frame_arena = std.heap.ArenaAllocator.init(alloc);
    defer frame_arena.deinit();

    const clay_arena = cl.Arena.init(clay_memory);
    cl.initialize(clay_arena, .{
        .w = @floatFromInt(rl.getScreenWidth()),
        .h = @floatFromInt(rl.getScreenHeight()),
    }, .{});
    cl.setMeasureTextFunction(renderer.measureText);

    renderer.fonts[FONT_ID_BODY_16] = rl.cdef.LoadFontEx("resources/Roboto-Regular.ttf", 48, 0, 400);
    rl.setTextureFilter(renderer.fonts[FONT_ID_BODY_16].?.texture, .texture_filter_bilinear);

    while (!rl.windowShouldClose()) {
        cl.setLayoutDimensions(.{
            .w = @floatFromInt(rl.getScreenWidth()),
            .h = @floatFromInt(rl.getScreenHeight()),
        });

        const mousePosition = rl.getMousePosition();
        const scrollDelta = rl.getMouseWheelMoveV();
        cl.setPointerState(mousePosition, rl.isMouseButtonDown(.mouse_button_left));
        cl.updateScrollContainers(true, scrollDelta, rl.getFrameTime());

        const content_background_config = cl.RectangleConfig{
            .color = cl.Color.init(90, 90, 90, 255),
            .corner_radius = cl.CornerRadius.all(8),
        };

        // Toggle the inspector with spacebar
        if (rl.isKeyPressed(.key_space)) cl.setDebugModeEnabled(!cl.isDebugModeEnabled());

        cl.beginLayout();
        if (cl.open(.{
            .id = cl.Id("OuterContainer"),
            .layout = .{
                .direction = .top_to_bottom,
                .sizing = cl.Sizing.grow,
                .padding = cl.Padding.all(16),
                .child_gap = 16,
            },
            .rectangle = .{ .color = cl.Color.init(43, 41, 51, 255) },
        })) {
            defer cl.close();
            if (cl.open(.{
                .id = cl.Id("HeaderBar"),
                .layout = .{
                    .sizing = .{ .w = cl.SizingAxis.grow, .h = cl.SizingAxis.fixed(60) },
                    .padding = .{ .x = 16 },
                    .child_gap = 16,
                    .alignment = .left_center,
                },
                .rectangle = content_background_config,
            })) {
                defer cl.close();
                if (cl.open(.{
                    .id = cl.Id("FileButton"),
                    .layout = .{ .padding = .{ .x = 16, .y = 8 } },
                    .rectangle = .{
                        .color = cl.Color.init(140, 140, 140, 255),
                        .corner_radius = cl.CornerRadius.all(5),
                    },
                })) {
                    defer cl.close();
                    cl.text("File", .{
                        .font_id = FONT_ID_BODY_16,
                        .font_size = 16,
                        .text_color = COLOR_WHITE,
                    });

                    const file_menu_visible =
                        cl.pointerOver(cl.Id("FileButton")) or
                        cl.pointerOver(cl.Id("FileMenu"));

                    // Below has been changed slightly to fix the small bug where the menu would
                    // dismiss when mousing over the top gap
                    if (file_menu_visible) {
                        if (cl.open(.{
                            .id = cl.Id("FileMenu"),
                            .floating = .{ .attachment = .{ .parent = .left_bottom } },
                            .layout = .{ .padding = .{ .x = 0, .y = 8 } },
                        })) {
                            defer cl.close();
                            if (cl.open(.{
                                .layout = .{ .direction = .top_to_bottom, .sizing = .{ .w = cl.SizingAxis.fixed(200) } },
                                .rectangle = .{ .color = cl.Color.init(40, 40, 40, 255), .corner_radius = cl.CornerRadius.all(8) },
                            })) {
                                defer cl.close();
                                renderDropdownMenuItem("New");
                                renderDropdownMenuItem("Open");
                                renderDropdownMenuItem("Close");
                            }
                        }
                    }
                }
                renderHeaderButton("Edit");
                cl.element(.{ .layout = .{ .sizing = cl.Sizing.grow } });
                renderHeaderButton("Upload");
                renderHeaderButton("Media");
                renderHeaderButton("Support");
            }

            if (cl.open(.{
                .id = cl.Id("LowerContent"),
                .layout = .{ .sizing = cl.Sizing.grow, .child_gap = 16 },
            })) {
                defer cl.close();
                if (cl.open(.{
                    .id = cl.Id("Sidebar"),
                    .rectangle = content_background_config,
                    .layout = .{
                        .direction = .top_to_bottom,
                        .padding = cl.Padding.all(16),
                        .child_gap = 8,
                        .sizing = .{ .w = cl.SizingAxis.fixed(250), .h = cl.SizingAxis.grow },
                    },
                })) {
                    defer cl.close();
                    for (documents, 0..) |document, i| {
                        const sidebar_button_layout = cl.LayoutConfig{
                            .sizing = .{ .w = cl.SizingAxis.grow },
                            .padding = cl.Padding.all(16),
                        };

                        // `cl.open()` and `cl.close()` are just functions, there is nothing special
                        // about their placement in the program as long as they have a coresponding
                        // pair. Here we are conditionally opening either one element or another
                        // and closing either of them in a single place.
                        if (i == selected_document_index) {
                            _ = cl.open(.{
                                .layout = sidebar_button_layout,
                                .rectangle = .{
                                    .color = cl.Color.init(120, 120, 120, 255),
                                    .corner_radius = cl.CornerRadius.all(8),
                                },
                            });
                        } else {
                            _ = cl.open(.{
                                .layout = sidebar_button_layout,
                                .rectangle = if (cl.hovered()) .{
                                    .color = cl.Color.init(120, 120, 120, 120),
                                    .corner_radius = cl.CornerRadius.all(8),
                                } else null,
                            });
                            cl.onHover(handleSidebarInteraction, i); // TODO: Improve this
                        }
                        defer cl.close();
                        cl.text(document.title, .{
                            .font_id = FONT_ID_BODY_16,
                            .font_size = 20,
                            .text_color = COLOR_WHITE,
                        });
                    }
                }

                if (cl.open(.{
                    .id = cl.Id("MainContent"),
                    .rectangle = content_background_config,
                    .scroll = .{ .vertical = true },
                    .layout = .{
                        .direction = .top_to_bottom,
                        .child_gap = 16,
                        .padding = cl.Padding.all(16),
                        .sizing = cl.Sizing.grow,
                    },
                })) {
                    defer cl.close();
                    const selected_document = documents[selected_document_index];
                    cl.text(selected_document.title, .{
                        .font_id = FONT_ID_BODY_16,
                        .font_size = 24,
                        .text_color = COLOR_WHITE,
                    });
                    cl.text(selected_document.contents, .{
                        .font_id = FONT_ID_BODY_16,
                        .font_size = 24,
                        .text_color = COLOR_WHITE,
                    });
                }
            }
        }
        const render_commands = cl.endLayout();

        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);
        renderer.render(render_commands, frame_arena.allocator());
        rl.endDrawing();

        _ = frame_arena.reset(.retain_capacity);
    }
}

fn renderHeaderButton(text: []const u8) void {
    if (cl.open(.{
        .layout = .{ .padding = .{ .x = 16, .y = 8 } },
        .rectangle = .{
            .color = cl.Color.init(140, 140, 140, 255),
            .corner_radius = cl.CornerRadius.all(5),
        },
    })) {
        defer cl.close();
        cl.text(text, .{
            .font_id = FONT_ID_BODY_16,
            .font_size = 16,
            .text_color = COLOR_WHITE,
        });
    }
}

fn renderDropdownMenuItem(text: []const u8) void {
    if (cl.open(.{ .layout = .{ .padding = cl.Padding.all(16) } })) {
        defer cl.close();
        cl.text(text, .{
            .font_id = FONT_ID_BODY_16,
            .font_size = 16,
            .text_color = COLOR_WHITE,
        });
    }
}

fn handleSidebarInteraction(
    element_id: cl.ElementId,
    pointer_data: cl.PointerData,
    user_data: usize,
) callconv(.C) void {
    _ = element_id;

    // If this button was clicked
    if (pointer_data.state == .pressed_this_frame) {
        const index = user_data;
        std.debug.assert(index < documents.len);
        selected_document_index = index;

        // FIXME: Program receives signal 5 (SIGTRAP) if I don't print `user_data`. All the memory
        // layouts look fine.
        // std.debug.print("{d}\n", .{index});
    }
}

const documents = [_]Document{
    .{ .title = "Squirrels", .contents = "The Secret Life of Squirrels: Nature's Clever Acrobats\nSquirrels are often overlooked creatures, dismissed as mere park inhabitants or backyard nuisances. Yet, beneath their fluffy tails and twitching noses lies an intricate world of cunning, agility, and survival tactics that are nothing short of fascinating. As one of the most common mammals in North America, squirrels have adapted to a wide range of environments from bustling urban centers to tranquil forests and have developed a variety of unique behaviors that continue to intrigue scientists and nature enthusiasts alike.\n\nMaster Tree Climbers\nAt the heart of a squirrel's skill set is its impressive ability to navigate trees with ease. Whether they're darting from branch to branch or leaping across wide gaps, squirrels possess an innate talent for acrobatics. Their powerful hind legs, which are longer than their front legs, give them remarkable jumping power. With a tail that acts as a counterbalance, squirrels can leap distances of up to ten times the length of their body, making them some of the best aerial acrobats in the animal kingdom.\nBut it's not just their agility that makes them exceptional climbers. Squirrels' sharp, curved claws allow them to grip tree bark with precision, while the soft pads on their feet provide traction on slippery surfaces. Their ability to run at high speeds and scale vertical trunks with ease is a testament to the evolutionary adaptations that have made them so successful in their arboreal habitats.\n\nFood Hoarders Extraordinaire\nSquirrels are often seen frantically gathering nuts, seeds, and even fungi in preparation for winter. While this behavior may seem like instinctual hoarding, it is actually a survival strategy that has been honed over millions of years. Known as \"scatter hoarding,\" squirrels store their food in a variety of hidden locations, often burying it deep in the soil or stashing it in hollowed-out tree trunks.\nInterestingly, squirrels have an incredible memory for the locations of their caches. Research has shown that they can remember thousands of hiding spots, often returning to them months later when food is scarce. However, they don't always recover every stash some forgotten caches eventually sprout into new trees, contributing to forest regeneration. This unintentional role as forest gardeners highlights the ecological importance of squirrels in their ecosystems.\n\nThe Great Squirrel Debate: Urban vs. Wild\nWhile squirrels are most commonly associated with rural or wooded areas, their adaptability has allowed them to thrive in urban environments as well. In cities, squirrels have become adept at finding food sources in places like parks, streets, and even garbage cans. However, their urban counterparts face unique challenges, including traffic, predators, and the lack of natural shelters. Despite these obstacles, squirrels in urban areas are often observed using human infrastructure such as buildings, bridges, and power lines as highways for their acrobatic escapades.\nThere is, however, a growing concern regarding the impact of urban life on squirrel populations. Pollution, deforestation, and the loss of natural habitats are making it more difficult for squirrels to find adequate food and shelter. As a result, conservationists are focusing on creating squirrel-friendly spaces within cities, with the goal of ensuring these resourceful creatures continue to thrive in both rural and urban landscapes.\n\nA Symbol of Resilience\nIn many cultures, squirrels are symbols of resourcefulness, adaptability, and preparation. Their ability to thrive in a variety of environments while navigating challenges with agility and grace serves as a reminder of the resilience inherent in nature. Whether you encounter them in a quiet forest, a city park, or your own backyard, squirrels are creatures that never fail to amaze with their endless energy and ingenuity.\nIn the end, squirrels may be small, but they are mighty in their ability to survive and thrive in a world that is constantly changing. So next time you spot one hopping across a branch or darting across your lawn, take a moment to appreciate the remarkable acrobat at work a true marvel of the natural world.\n" },
    .{ .title = "Lorem Ipsum", .contents = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum." },
    .{ .title = "Vacuum Instructions", .contents = "Chapter 3: Getting Started - Unpacking and Setup\n\nCongratulations on your new SuperClean Pro 5000 vacuum cleaner! In this section, we will guide you through the simple steps to get your vacuum up and running. Before you begin, please ensure that you have all the components listed in the \"Package Contents\" section on page 2.\n\n1. Unboxing Your Vacuum\nCarefully remove the vacuum cleaner from the box. Avoid using sharp objects that could damage the product. Once removed, place the unit on a flat, stable surface to proceed with the setup. Inside the box, you should find:\n\n    The main vacuum unit\n    A telescoping extension wand\n    A set of specialized cleaning tools (crevice tool, upholstery brush, etc.)\n    A reusable dust bag (if applicable)\n    A power cord with a 3-prong plug\n    A set of quick-start instructions\n\n2. Assembling Your Vacuum\nBegin by attaching the extension wand to the main body of the vacuum cleaner. Line up the connectors and twist the wand into place until you hear a click. Next, select the desired cleaning tool and firmly attach it to the wand's end, ensuring it is securely locked in.\n\nFor models that require a dust bag, slide the bag into the compartment at the back of the vacuum, making sure it is properly aligned with the internal mechanism. If your vacuum uses a bagless system, ensure the dust container is correctly seated and locked in place before use.\n\n3. Powering On\nTo start the vacuum, plug the power cord into a grounded electrical outlet. Once plugged in, locate the power switch, usually positioned on the side of the handle or body of the unit, depending on your model. Press the switch to the \"On\" position, and you should hear the motor begin to hum. If the vacuum does not power on, check that the power cord is securely plugged in, and ensure there are no blockages in the power switch.\n\nNote: Before first use, ensure that the vacuum filter (if your model has one) is properly installed. If unsure, refer to \"Section 5: Maintenance\" for filter installation instructions." },
    .{ .title = "Article 4", .contents = "Article 4" },
    .{ .title = "Article 5", .contents = "Article 5" },
};
