package game

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

player_exp_update :: proc(player: ^Player, exp_amount: int) {
	player.current_exp += exp_amount
	if player.current_exp >= player.exp_to_next_level {
		player.level += 1
		player.current_exp -= player.exp_to_next_level
		player.exp_to_next_level += 100
    rl.PlaySound(sounds.level_up)
	} else {
    play_sound_varied(sounds.score)
  }
}

init_player :: proc() -> Player {
	player := Player {
		pos               = {300, 400},
		hp                = PLAYER_MAX_HP,
		level             = 1,
		current_exp       = 0,
		exp_to_next_level = 100,
	}
	return player
}
draw_gun :: proc(player: Player, gun_texture: rl.Texture2D) {
	// Calculate the direction from player to mouse
	direction := rl.Vector2{mouse_world_pos.x - player.pos.x, mouse_world_pos.y - player.pos.y}
	// Calculate the angle in radians
	angle_rad := math.atan2(direction.y, direction.x)
	// Convert to degrees for raylib
	angle_deg := angle_rad * (180.0 / math.PI)

	// Check if mouse is on the right side of the player
	facing_right := mouse_world_pos.x > player.pos.x

	source_rec := rl.Rectangle {
		x      = 0,
		y      = 0,
		width  = f32(gun_texture.width / 2),
		height = facing_right ? -f32(gun_texture.height / 2) : f32(gun_texture.height / 2), // Flip vertically when facing right
	}

	// Position the gun slightly offset from player center
	gun_offset := rl.Vector2{50, 50} // Adjust this offset as needed
	gun_pos := rl.Vector2{player.pos.x + gun_offset.x, player.pos.y + gun_offset.y}
	dest_rec := rl.Rectangle {
		x      = gun_pos.x,
		y      = gun_pos.y,
		width  = f32(gun_texture.width / 2),
		height = f32(gun_texture.height / 2),
	}
	// Set origin to center of gun for proper rotation
	// You might need to adjust this based on your gun sprite's design
	origin := rl.Vector2 {
		f32(gun_texture.width / 4), // Half of the displayed width
		f32(gun_texture.height / 4), // Half of the displayed height
	}
	// Since gun sprite points left by default, we need to add 180 degrees
	final_angle := angle_deg + 180
	rl.DrawTexturePro(gun_texture, source_rec, dest_rec, origin, final_angle, rl.WHITE)
	// Draw muzzle flash
	if muzzle_flash_timer > 0 {
		// Define the length of the gun barrel. You may need to adjust this value.
		gun_barrel_length := f32(dest_rec.width) * 0.5

		// Calculate the muzzle flash position based on the gun's rotation
		muzzle_pos := rl.Vector2 {
			gun_pos.x + gun_barrel_length * math.cos(angle_rad),
			gun_pos.y + gun_barrel_length * math.sin(angle_rad),
		}
		
		// Calculate flash properties
		flash_alpha := u8((muzzle_flash_timer / MUZZLE_FLASH_DURATION) * 255)
		flash_size := 12.0 * (muzzle_flash_timer / MUZZLE_FLASH_DURATION)

		// Draw the muzzle flash as a circle with fade effect
		flash_color := rl.Color{255, 255, 150, flash_alpha} // Yellow-white flash
		rl.DrawCircleV(muzzle_pos, flash_size, flash_color)

		//Add a smaller, brighter inner circle
		inner_flash_color := rl.Color{255, 255, 255, flash_alpha}
		rl.DrawCircleV(muzzle_pos, flash_size * 0.5, inner_flash_color)
	}
}

draw_player :: proc(player: Player, camera: ^rl.Camera2D, player_textures: Player_animations) {
	// Determine player color (white or flashing red if damaged)
	player_color := rl.WHITE
	if player.damage_timer > 0 {
		// Calculate shake intensity (strongest at start, fades out)
		shake_intensity := (player.damage_timer / PLAYER_DAMAGE_COOLDOWN) * 8.0

		// Generate random shake offset
		shake_x := (rand.float32() - 0.5) * shake_intensity
		shake_y := (rand.float32() - 0.5) * shake_intensity

		// Apply shake to camera offset
		base_offset_x := f32(window_width) / 2
		base_offset_y := f32(window_height) / 1.7
		camera.offset = {base_offset_x + shake_x, base_offset_y + shake_y}

		// Flash red when damaged
		flash_intensity := (player.damage_timer / PLAYER_DAMAGE_COOLDOWN) * 0.5
		player_color = rl.Color {
			255,
			u8(255 * (1 - flash_intensity)),
			u8(255 * (1 - flash_intensity)),
			255,
		}
	} else {
		// Reset to normal camera position
		camera.offset = {f32(window_width) / 2, f32(window_height) / 1.7}
	}

	// Get the current texture for the animation frame
	player_texture := player_textures.idle
	if is_moving {
		player_texture = player_textures.run
	}

	x_frame := f32(current_frame % int(player_textures.frames_width))
	y_frame := f32(current_frame / int(player_textures.frames_width))
	// Define the source rectangle from the texture. By default, it's the whole texture.
	player_source_rec := rl.Rectangle {
		x      = x_frame * f32(player_texture.width) / f32(player_textures.frames_width),
		y      = f32(player_texture.height) * y_frame / f32(player_textures.frames_height),
		width  = f32(player_texture.width / player_textures.frames_width),
		height = f32(player_texture.height / player_textures.frames_height),
	}
	// Define the destination rectangle on the screen, applying the scale.
	player_dest_rec := rl.Rectangle {
		x      = player.pos.x,
		y      = player.pos.y,
		width  = f32(
			player_texture.width /
			 /* make bigger to zoom player also below*/player_textures.frames_width,
		),
		height = f32(player_texture.height / player_textures.frames_height),
	}
	// If the player is not facing right, we set the source rectangle's width to be negative.
	// This tells DrawTexturePro to render it horizontally flipped.
	facing_right := mouse_world_pos.x > player.pos.x
	if facing_right {
		player_source_rec.width = -player_source_rec.width
	}
	// We use DrawTexturePro for its ability to render a flipped texture.
	// The origin is {0, 0} (top-left), and rotation is 0.
	rl.DrawTexturePro(
		player_texture,
		player_source_rec,
		player_dest_rec,
		rl.Vector2{0, 0},
		0,
		player_color,
	)
}
