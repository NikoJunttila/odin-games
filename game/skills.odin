package game

import "core:math"
import rl "vendor:raylib"

skill_flash :: proc(player : ^Player, camera : rl.Camera2D) {
	mouse_screen_pos := rl.GetMousePosition()
	// Get mouse position in world coordinates
	mouse_world_pos := rl.GetScreenToWorld2D(mouse_screen_pos, camera)

	// Calculate player center position
	player_center := rl.Vector2{player.pos.x + PLAYER_SIZE / 2, player.pos.y + PLAYER_SIZE / 2}

	// Calculate direction vector from player to mouse
	direction := rl.Vector2 {
		mouse_world_pos.x - player_center.x,
		mouse_world_pos.y - player_center.y,
	}

	// Normalize the direction vector
	length := math.sqrt(direction.x * direction.x + direction.y * direction.y)
	if length > 0 {
		// Normalize and apply flash distance
		normalized_direction := rl.Vector2{direction.x / length, direction.y / length}

		// Move player in the direction of mouse
		new_pos := rl.Vector2 {
			player.pos.x + normalized_direction.x * FLASH_DISTANCE,
			player.pos.y + normalized_direction.y * FLASH_DISTANCE,
		}

		// Apply bounds checking to prevent going out of world
		player.pos.x = clamp(new_pos.x, 0, WORLD_WIDTH - PLAYER_SIZE)
		player.pos.y = clamp(new_pos.y, 0, f32(window_height) - PLAYER_SIZE)

		// Optional: Reset grounded state if moving vertically
		if math.abs(normalized_direction.y) > 0.1 {
			player.grounded = false
		}
	}
}
