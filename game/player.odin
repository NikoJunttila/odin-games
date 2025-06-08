package game

import rl "vendor:raylib"
import "core:math/rand"

player_exp_update :: proc(player: ^Player, exp_amount: int) {
	player.current_exp += exp_amount
	if player.current_exp >= player.exp_to_next_level {
		player.level += 1
		player.current_exp -= player.exp_to_next_level
		player.exp_to_next_level += 100
	}
}

skills_list_init :: proc() -> [2]Skill {
	flash := Skill {
		name     = SkillList.FLASH,
		key      = "F",
		color    = rl.YELLOW,
		cooldown = 5,
	}
	heal := Skill {
		name     = SkillList.HEAL,
		key      = "E",
		color    = rl.GREEN,
		cooldown = 30,
	}
	skill_list := [2]Skill{flash, heal}
	return skill_list
}

draw_player ::proc(player: Player, camera : ^rl.Camera2D, player_textures : Player_animations, ){
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

			// Draw muzzle flash
			if muzzle_flash_timer > 0 {
				// Calculate flash properties
				flash_alpha := u8((muzzle_flash_timer / MUZZLE_FLASH_DURATION) * 255)
				flash_size := 12.0 * (muzzle_flash_timer / MUZZLE_FLASH_DURATION)

				// Calculate muzzle position (front of the player)
				muzzle_offset_x: f32 =
					facing_right ? player_dest_rec.width * 0.92 : player_dest_rec.width * 0.08
				muzzle_pos := rl.Vector2 {
					player.pos.x + muzzle_offset_x,
					player.pos.y + player_dest_rec.height * 0.5, // Roughly chest height
				}

				// Draw the muzzle flash as a circle with fade effect
				flash_color := rl.Color{255, 255, 150, flash_alpha} // Yellow-white flash
				rl.DrawCircleV(muzzle_pos, flash_size, flash_color)

				// Optional: Add a smaller, brighter inner circle
				inner_flash_color := rl.Color{255, 255, 255, flash_alpha}
				rl.DrawCircleV(muzzle_pos, flash_size * 0.5, inner_flash_color)
			}
}
