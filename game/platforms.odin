package game

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

Platform :: struct {
	pos: rl.Vector2,
}

Level :: struct {
	platforms: [dynamic]Platform,
	p_size:    rl.Vector2,
}

// Serializable version for JSON
Level_Data :: struct {
	platforms: []Platform,
	p_size:    rl.Vector2,
}

LEVEL_FILE :: "level.json"

// Load level from file
load_level :: proc(level: ^Level, allocator := context.allocator) -> bool {
	level_data, read_ok := os.read_entire_file(LEVEL_FILE, context.temp_allocator)
	if !read_ok {
		fmt.println("Could not read level file, creating new level")
		return false
	}

	data: Level_Data
	if json.unmarshal(level_data, &data, allocator = context.temp_allocator) != nil {
		fmt.println("Failed to parse level file, creating new level")
		return false
	}

	// Clear existing platforms
	clear(&level.platforms)

	// Load platforms from file
	for platform in data.platforms {
		append(&level.platforms, platform)
	}

	// Set platform size
	level.p_size = data.p_size

	fmt.printf("Loaded %d platforms from %s\n", len(level.platforms), LEVEL_FILE)
	return true
}

// Save level to file
save_level :: proc(level: ^Level) -> bool {
	// Convert dynamic array to slice for JSON serialization
	data := Level_Data {
		platforms = level.platforms[:],
		p_size    = level.p_size,
	}

	json_data, marshal_err := json.marshal(data, {pretty = true})
	if marshal_err != nil {
		fmt.printf("Failed to marshal level data: %v\n", marshal_err)
		return false
	}
	defer delete(json_data)

	write_ok := os.write_entire_file(LEVEL_FILE, json_data)
	if !write_ok {
		fmt.printf("Failed to write level file: %s\n", LEVEL_FILE)
		return false
	}

	fmt.printf("Saved %d platforms to %s\n", len(level.platforms), LEVEL_FILE)
	return true
}

// Add a new platform at position
add_platform :: proc(level: ^Level, pos: rl.Vector2) {
	new_platform := Platform {
		pos = pos,
	}
	append(&level.platforms, new_platform)
	fmt.printf("Added platform at (%.1f, %.1f)\n", pos.x, pos.y)
}

// Remove platform at index
remove_platform :: proc(level: ^Level, index: int) -> bool {
	if index < 0 || index >= len(level.platforms) {
		return false
	}

	ordered_remove(&level.platforms, index)
	fmt.printf("Removed platform at index %d\n", index)
	return true
}

// Find platform at position (for deletion)
find_platform_at_pos :: proc(level: ^Level, pos: rl.Vector2, tolerance: f32 = 32.0) -> int {
	for platform, i in level.platforms {
		rect := platform_to_rect(platform, level.p_size)
		if rl.CheckCollisionPointRec(pos, rect) {
			return i
		}
	}
	return -1
}

// Initialize level (call this at program start)
init_level :: proc(level: ^Level, allocator := context.allocator) {
	level.platforms = make([dynamic]Platform, allocator)
	level.p_size = {200, 20} // Default platform size

	// Try to load from file, if that fails create a default level
	if !load_level(level, allocator) {
		// Create a default platform if no file exists
		add_platform(level, {100, 300})
		fmt.println("Created new level with default platform")
	}
}

platform_to_rect :: proc(plat: Platform, size: rl.Vector2) -> rl.Rectangle {
	rect: rl.Rectangle
	rect.x = plat.pos.x
	rect.y = plat.pos.y
	rect.width = size.x
	rect.height = size.y
	return rect
}

// Tiled texture drawing (repeats texture instead of stretching)
draw_platforms :: proc(platforms: []Platform, platform_texture: rl.Texture2D, level: Level) {
	for platform in platforms {
		// Calculate how many times the texture fits
		tex_width := f32(platform_texture.width)
		tex_height := f32(platform_texture.height)
		tiles_x := int(math.ceil(level.p_size.x / tex_width))
		tiles_y := int(math.ceil(level.p_size.y / tex_height))

		// Draw tiled texture
		for x in 0 ..< tiles_x {
			for y in 0 ..< tiles_y {
				pos_x := platform.pos.x + f32(x) * tex_width
				pos_y := platform.pos.y + f32(y) * tex_height

				// Calculate how much of the texture to draw (for edge tiles)
				draw_width := min(tex_width, platform.pos.x + level.p_size.x - pos_x)
				draw_height := min(tex_height, platform.pos.y + level.p_size.y - pos_y)

				if draw_width > 0 && draw_height > 0 {
					source_rect := rl.Rectangle{0, 0, draw_width, draw_height}
					dest_rect := rl.Rectangle{pos_x, pos_y, draw_width, draw_height}
					origin := rl.Vector2{0, 0}
					rl.DrawTexturePro(
						platform_texture,
						source_rect,
						dest_rect,
						origin,
						0,
						rl.WHITE,
					)
				}
			}
		}
	}
}

// Level editor input handling
handle_editor_input :: proc(level: ^Level, mouse_world_pos: rl.Vector2) {
	// Left click to add platform
	if rl.IsMouseButtonPressed(.LEFT) {
		add_platform(level, mouse_world_pos)
	}

	// Right click to remove platform
	if rl.IsMouseButtonPressed(.RIGHT) {
		index := find_platform_at_pos(level, mouse_world_pos)
		if index >= 0 {
			remove_platform(level, index)
		}
	}

	// Save level
	if rl.IsKeyPressed(.S) && rl.IsKeyDown(.LEFT_CONTROL) {
		save_level(level)
	}

	// Load level
	if rl.IsKeyPressed(.L) && rl.IsKeyDown(.LEFT_CONTROL) {
		load_level(level)
	}

	// Clear all platforms
	if rl.IsKeyPressed(.C) && rl.IsKeyDown(.LEFT_CONTROL) {
		clear(&level.platforms)
		fmt.println("Cleared all platforms")
	}
}

// Draw editor UI
draw_editor_ui :: proc(level: ^Level, editing: bool) {
	if !editing do return

	ui_text := fmt.tprintf(
		"LEVEL EDITOR\n" +
		"Left Click: Add Platform\n" +
		"Right Click: Remove Platform\n" +
		"Ctrl+S: Save Level\n" +
		"Ctrl+L: Load Level\n" +
		"Ctrl+C: Clear All\n" +
		"Platforms: %d",
		len(level.platforms),
	)

	rl.DrawText(strings.clone_to_cstring(ui_text, context.temp_allocator), 10, 10, 20, rl.WHITE)
}
