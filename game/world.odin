package game

import "core:c"
import "core:math"
import rl "vendor:raylib"

// Draw a procedural background with parallax-like elements
draw_background :: proc(camera: rl.Camera2D, background_texture, tree_texture: rl.Texture2D) {
	// Draw ground
	rl.DrawRectangle(0, window_height - 50, c.int(WORLD_WIDTH), 50, rl.DARKGREEN)

	// Draw background with precise tiling
	bg_y := f32(background_texture.height - PLAYER_SIZE)
	tex_width := f32(background_texture.width)
	tiles_needed := int(math.ceil(f32(WORLD_WIDTH) / tex_width))

	for i in 0 ..< tiles_needed {
		x_pos := f32(i) * tex_width

		// Calculate how much of the texture to draw (for the last tile)
		draw_width := min(tex_width, f32(WORLD_WIDTH) - x_pos)

		if draw_width > 0 {
			source := rl.Rectangle{0, 0, draw_width, f32(background_texture.height)}
			dest := rl.Rectangle{x_pos, bg_y, draw_width, f32(background_texture.height)}
			rl.DrawTexturePro(background_texture, source, dest, {0, 0}, 0, rl.WHITE)
		}
	}

	// Draw background mountains/hills (far background - slower parallax)
	mountain_offset := camera.target.x * 0.2 // Move slower than camera
	mountain_spacing: f32 = 400

	for i in 0 ..< int(WORLD_WIDTH / mountain_spacing) + 2 {
		x := f32(i) * mountain_spacing - mountain_offset
		if x > camera.target.x - f32(window_width) && x < camera.target.x + f32(window_width) {
			// Draw simple mountain shape
			points := [3]rl.Vector2 {
				{x, f32(window_height - 50)},
				{x + 150, f32(window_height - 200)},
				{x + 300, f32(window_height - 50)},
			}
			rl.DrawTriangle(points[0], points[1], points[2], rl.DARKGRAY)
		}
	}

	// Draw middle-ground trees
	tree_offset := camera.target.x * 0.5 // Medium parallax speed
	tree_spacing: f32 = 200
	for i in 0 ..< int(WORLD_WIDTH / tree_spacing) + 2 {
		x := f32(i) * tree_spacing - tree_offset
		if x > camera.target.x - f32(window_width) && x < camera.target.x + f32(window_width) {
			// Use index as seed for consistent random placement
			seed := u64(i * 12345) // Simple hash for consistent randomness

			// Random Y offset (slight variation in tree positioning)
			y_variation := f32((seed % 20) - 10) // -10 to +10 pixel variation
			tree_y := f32(window_height - PLAYER_SIZE - tree_texture.height) + y_variation

			// Random scale (some trees bigger/smaller)
			scale_variation := 0.8 + f32((seed * 7) % 40) / 100.0 // 0.8 to 1.2 scale

			// Random horizontal offset within spacing
			x_variation := f32((seed * 3) % u64(tree_spacing / 2)) - tree_spacing / 4
			tree_x := x + x_variation

			// Draw tree with variations
			if scale_variation == 1.0 {
				// Normal size - use simple DrawTexture
				rl.DrawTexture(tree_texture, i32(tree_x), i32(tree_y), rl.WHITE)
			} else {
				// Scaled - use DrawTextureEx
				rl.DrawTextureEx(tree_texture, {tree_x, tree_y}, 0, scale_variation, rl.WHITE)
			}
		}
	} // Draw foreground grass patches (moves with world)
	grass_spacing: f32 = 100
	for i in 0 ..< int(WORLD_WIDTH / grass_spacing) {
		x := f32(i) * grass_spacing
		if x > camera.target.x - f32(window_width) && x < camera.target.x + f32(window_width) {
			// Draw grass patches
			for j in 0 ..< 5 {
				grass_x := x + f32(j * 20)
				rl.DrawRectangle(c.int(grass_x), window_height - 55, 3, 10, rl.LIME)
			}
		}
	}

	// Draw clouds (very slow parallax for far background)
	cloud_offset := camera.target.x * 0.1
	cloud_spacing: f32 = 500

	for i in 0 ..< int(WORLD_WIDTH / cloud_spacing) + 2 {
		x := f32(i) * cloud_spacing - cloud_offset
		if x > camera.target.x - f32(window_width) && x < camera.target.x + f32(window_width) {
			// Draw simple cloud
			y: f32 = 100 + f32(i % 3) * 30 // Vary cloud heights
			rl.DrawCircle(c.int(x), c.int(y), 25, rl.WHITE)
			rl.DrawCircle(c.int(x + 30), c.int(y), 35, rl.WHITE)
			rl.DrawCircle(c.int(x + 60), c.int(y), 25, rl.WHITE)
		}
	}
}
