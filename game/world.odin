package game

import rl "vendor:raylib"
import "core:c"

// Draw a procedural background with parallax-like elements
draw_background :: proc(camera: rl.Camera2D) {
	// Draw ground
	rl.DrawRectangle(0, window_height - 50, c.int(WORLD_WIDTH), 50, rl.DARKGREEN)

	// Draw background mountains/hills (far background - slower parallax)
	mountain_offset := camera.target.x * 0.2  // Move slower than camera
	mountain_spacing: f32 = 400

	for i in 0..<int(WORLD_WIDTH / mountain_spacing) + 2 {
		x := f32(i) * mountain_spacing - mountain_offset
		if x > camera.target.x - f32(window_width) && x < camera.target.x + f32(window_width) {
			// Draw simple mountain shape
			points := [3]rl.Vector2{
				{x, f32(window_height - 50)},
				{x + 150, f32(window_height - 200)},
				{x + 300, f32(window_height - 50)},
			}
			rl.DrawTriangle(points[0], points[1], points[2], rl.DARKGRAY)
		}
	}

	// Draw middle-ground trees
	tree_offset := camera.target.x * 0.5  // Medium parallax speed
	tree_spacing: f32 = 200

	for i in 0..<int(WORLD_WIDTH / tree_spacing) + 2 {
		x := f32(i) * tree_spacing - tree_offset
		if x > camera.target.x - f32(window_width) && x < camera.target.x + f32(window_width) {
			// Draw simple tree
			rl.DrawRectangle(c.int(x + 15), window_height - 100, 20, 50, rl.BROWN)  // Trunk
			rl.DrawCircle(c.int(x + 25), window_height - 120, 30, rl.GREEN)         // Leaves
		}
	}

	// Draw foreground grass patches (moves with world)
	grass_spacing: f32 = 100
	for i in 0..<int(WORLD_WIDTH / grass_spacing) {
		x := f32(i) * grass_spacing
		if x > camera.target.x - f32(window_width) && x < camera.target.x + f32(window_width) {
			// Draw grass patches
			for j in 0..<5 {
				grass_x := x + f32(j * 20)
				rl.DrawRectangle(c.int(grass_x), window_height - 55, 3, 10, rl.LIME)
			}
		}
	}

	// Draw clouds (very slow parallax for far background)
	cloud_offset := camera.target.x * 0.1
	cloud_spacing: f32 = 500

	for i in 0..<int(WORLD_WIDTH / cloud_spacing) + 2 {
		x := f32(i) * cloud_spacing - cloud_offset
		if x > camera.target.x - f32(window_width) && x < camera.target.x + f32(window_width) {
			// Draw simple cloud
			y: f32 = 100 + f32(i % 3) * 30  // Vary cloud heights
			rl.DrawCircle(c.int(x), c.int(y), 25, rl.WHITE)
			rl.DrawCircle(c.int(x + 30), c.int(y), 35, rl.WHITE)
			rl.DrawCircle(c.int(x + 60), c.int(y), 25, rl.WHITE)
		}
	}
}
