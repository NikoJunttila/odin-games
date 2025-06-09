package game

import "core:encoding/json"
import "core:math"
import "core:os"
import rl "vendor:raylib"
Platform :: struct {
	pos: rl.Vector2,
}
Level :: struct {
	platforms: [dynamic]Platform,
	p_size:    rl.Vector2,
}
Platform_Template :: struct {
	x:                    f32,
	y_offset_from_bottom: f32, // How far from bottom of screen
}

// Define your platform templates once
PLATFORM_TEMPLATES := []Platform_Template {
	{x = 150, y_offset_from_bottom = PLAYER_SIZE + 100},
	{x = 50, y_offset_from_bottom = PLAYER_SIZE},
	{x = 300, y_offset_from_bottom = PLAYER_SIZE + 100},
	{x = 200, y_offset_from_bottom = PLAYER_SIZE + 75},
	// Add more platforms here easily!
	// {x = 400, y_offset_from_bottom = PLAYER_SIZE + 150},
}

read_level_data :: proc(level: ^Level) {
	if level_data, ok := os.read_entire_file("level.json", context.temp_allocator); ok {
		if json.unmarshal(level_data, level) != nil {
			append(&level.platforms, Platform{pos = rl.Vector2{-20, 20}})
		} else {
			append(&level.platforms, Platform{pos = rl.Vector2{-20, 20}})
		}
	}
}

// Generate platforms from templates
generate_platforms :: proc(level: Level, allocator := context.allocator) -> [dynamic]Platform {
	platforms := make([dynamic]Platform, len(PLATFORM_TEMPLATES), allocator)

	for template, i in PLATFORM_TEMPLATES {
		platforms[i] = Platform {
			pos = {template.x, f32(window_height) - template.y_offset_from_bottom},
		}
	}

	return platforms
}
// Update all platforms in-place based on new window height
update_platform_positions :: proc(platforms: ^[dynamic]Platform, level: Level) {
	for &platform, i in platforms {
		if i < len(PLATFORM_TEMPLATES) {
			template := PLATFORM_TEMPLATES[i]
			platform.pos.y = f32(window_height) - template.y_offset_from_bottom
			// X position and size stay the same, only Y changes
		}
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
//Tiled texture drawing (repeats texture instead of stretching)
draw_platforms :: proc(platforms: []Platform, platform_texture: rl.Texture2D, level: Level) {
	for platform in platforms {
		// Draw colored rectangle as base
		// rl.DrawRectangleRec(platform.rect, platform.color)

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
		// Optional: Draw outline for better visibility
		// rl.DrawRectangleLinesEx(platform.rect, 1, rl.BLACK)
	}
}
