package game

import "core:math"
import rl "vendor:raylib"

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
		cooldown = 2,
	}
	skill_list := [2]Skill{flash, heal}
	return skill_list
}
FLASH_ANIMATION_DURATION :: 0.50
flash_animation_timer: f32
flash_start_pos: rl.Vector2
flash_end_pos: rl.Vector2

// draw_flash_animation :: proc(){
//   rl.DrawCircleV(flash_start_pos, 20, rl.YELLOW)
//   rl.DrawCircleV(flash_end_pos, 20, rl.YELLOW)
// }
HEAL_ANIMATION_DURATION :: 0.50
heal_animation_timer: f32

draw_heal_animation :: proc(player_pos_0: rl.Vector2) {
  player_pos := player_pos_0 + 40

	// Calculate animation progress (0.0 to 1.0)
	progress := 1.0 - (heal_animation_timer / HEAL_ANIMATION_DURATION)

	// Different phases
	expand_phase := min(progress * 2, 1.0) // First 50% - expansion
	fade_phase := max((progress - 0.6) * 2.5, 0.0) // Last 40% - fade out

	// Pulsing heartbeat effect
	heartbeat := math.sin(progress * math.PI * 12) * 0.2 + 0.8

	// Main healing aura - expanding outward
	{
		aura_radius := expand_phase * 80 * heartbeat
		aura_alpha := u8((1.0 - fade_phase) * 60)
		aura_color := rl.Color{50, 255, 50, aura_alpha} // Bright green

		if aura_radius > 0 {
			rl.DrawCircleV(player_pos, aura_radius, aura_color)

			// Inner bright core
			core_alpha := u8((1.0 - fade_phase) * 120)
			core_color := rl.Color{150, 255, 150, core_alpha}
			rl.DrawCircleV(player_pos, aura_radius * 0.3, core_color)
		}
	}

	// Concentric healing rings
	{
		ring_count := 3
		for i in 0 ..< ring_count {
			ring_delay := f32(i) * 0.15
			ring_progress := max(progress - ring_delay, 0.0) * 1.5
			if ring_progress <= 0 do continue

			ring_radius := min(ring_progress, 1.0) * (60 + f32(i) * 15)
			ring_alpha := u8((1.0 - min(ring_progress, 1.0)) * 150)
			ring_color := rl.Color{100, 255, 100, ring_alpha}

			// Draw ring outline
			rl.DrawRingLines(player_pos, ring_radius - 2, ring_radius + 2, 0, 360, 32, ring_color)
		}
	}

	// Floating heal particles (plus signs)
	{
		particle_count := 12
		for i in 0 ..< particle_count {
			angle := f32(i) * (math.PI * 2) / f32(particle_count) + progress * math.PI

			// Spiral upward motion
			spiral_radius := 30 + math.sin(progress * math.PI * 3) * 10
			height_offset := -progress * 60 // Move upward

			particle_pos := rl.Vector2 {
				player_pos.x + math.cos(angle) * spiral_radius,
				player_pos.y + math.sin(angle) * spiral_radius * 0.3 + height_offset,
			}

			particle_alpha := u8((1.0 - progress) * 255)
			particle_color := rl.Color{255, 255, 255, particle_alpha}

			// Draw plus sign
			plus_size := 4
			rl.DrawRectangle(
				i32(particle_pos.x - f32(plus_size / 2)),
				i32(particle_pos.y - 1),
				i32(plus_size),
				3,
				particle_color,
			)
			rl.DrawRectangle(
				i32(particle_pos.x - 1),
				i32(particle_pos.y - f32(plus_size / 2)),
				3,
				i32(plus_size),
				particle_color,
			)
		}
	}

	// Sparkle effects
	{
		sparkle_count := 8
		for i in 0 ..< sparkle_count {
			sparkle_angle := f32(i) * (math.PI * 2) / f32(sparkle_count)
			sparkle_distance := 40 + math.sin(progress * math.PI * 6 + f32(i)) * 20

			sparkle_pos := rl.Vector2 {
				player_pos.x + math.cos(sparkle_angle) * sparkle_distance,
				player_pos.y + math.sin(sparkle_angle) * sparkle_distance,
			}

			twinkle := math.sin(progress * math.PI * 10 + f32(i) * 2) * 0.5 + 0.5
			sparkle_alpha := u8((1.0 - fade_phase) * twinkle * 200)
			sparkle_color := rl.Color{255, 255, 200, sparkle_alpha}

			sparkle_size := 3
			rl.DrawLineEx(
				rl.Vector2{sparkle_pos.x - f32(sparkle_size), sparkle_pos.y},
				rl.Vector2{sparkle_pos.x + f32(sparkle_size), sparkle_pos.y},
				1,
				sparkle_color,
			)
			rl.DrawLineEx(
				rl.Vector2{sparkle_pos.x, sparkle_pos.y - f32(sparkle_size)},
				rl.Vector2{sparkle_pos.x, sparkle_pos.y + f32(sparkle_size)},
				1,
				sparkle_color,
			)
		}
	}

	{
		if progress < 0.8 {
			text_alpha := u8((0.8 - progress) * 1.25 * 255)
			text_color := rl.Color{255, 255, 255, text_alpha}

			heal_text: cstring = "+HP"
			text_y := player_pos.y - 40 - (progress * 30)

			shake := math.sin(progress * math.PI * 20) * 2
			text_pos := rl.Vector2{player_pos.x + shake, text_y}

			shadow_color := rl.Color{0, 0, 0, text_alpha / 2}
			rl.DrawTextEx(
				rl.GetFontDefault(),
				heal_text,
				rl.Vector2{text_pos.x + 1, text_pos.y + 1},
				20,
				1,
				shadow_color,
			)
			rl.DrawTextEx(rl.GetFontDefault(), heal_text, text_pos, 20, 1, text_color)
		}
	}
}

skill_heal :: proc(player: ^Player) {
	player.hp += HEAL_AMOUNT
	player.hp = clamp(player.hp, 0, PLAYER_MAX_HP)
	heal_animation_timer = HEAL_ANIMATION_DURATION
}

draw_flash_animation :: proc() {
	// Calculate animation progress (0.0 to 1.0)
	progress := 1.0 - (flash_animation_timer / FLASH_ANIMATION_DURATION)

	// Different phases of the animation
	fade_in_phase := min(progress * 3, 1.0) // First 33% of animation
	fade_out_phase := max((progress - 0.7) * 3.33, 0.0) // Last 30% of animation

	// Pulsing effect
	pulse := math.sin(progress * math.PI * 8) * 0.3 + 0.7

	// Start position effects
	{
		// Main flash circle - shrinks over time
		start_radius := (1.0 - progress) * 40 * pulse
		start_alpha := u8((1.0 - progress) * 255)
		start_color := rl.Color{255, 255, 0, start_alpha} // Yellow

		if start_radius > 0 {
			rl.DrawCircleV(flash_start_pos, start_radius, start_color)

			// Outer ring effect
			ring_thickness := 3
			ring_alpha := u8((1.0 - progress) * 128)
			ring_color := rl.Color{255, 200, 0, ring_alpha} // Orange
			rl.DrawRingLines(
				flash_start_pos,
				start_radius + 5,
				start_radius + 5 + f32(ring_thickness),
				0,
				360,
				16,
				ring_color,
			)
		}

		// Particle burst effect
		particle_count := 8
		for i in 0 ..< particle_count {
			angle := f32(i) * (math.PI * 2) / f32(particle_count)
			distance := progress * 60 // Particles move outward
			particle_pos := rl.Vector2 {
				flash_start_pos.x + math.cos(angle) * distance,
				flash_start_pos.y + math.sin(angle) * distance,
			}
			particle_alpha := u8((1.0 - progress) * 200)
			particle_color := rl.Color{255, 255, 200, particle_alpha}
			rl.DrawCircleV(particle_pos, 2, particle_color)
		}
	}

	// End position effects
	{
		// Main flash circle - grows over time
		end_radius := progress * 35 * pulse
		end_alpha := u8(fade_in_phase * (1.0 - fade_out_phase) * 255)
		end_color := rl.Color{0, 255, 255, end_alpha} // Cyan

		if end_radius > 0 {
			rl.DrawCircleV(flash_end_pos, end_radius, end_color)

			// Inner glow
			glow_alpha := u8(fade_in_phase * (1.0 - fade_out_phase) * 100)
			glow_color := rl.Color{255, 255, 255, glow_alpha} // White glow
			rl.DrawCircleV(flash_end_pos, end_radius * 0.6, glow_color)
		}

		// Lightning effect - connecting lines
		if progress > 0.1 && progress < 0.8 {
			lightning_alpha := u8(fade_in_phase * (1.0 - fade_out_phase) * 180)
			lightning_color := rl.Color{255, 255, 255, lightning_alpha}

			// Draw jagged line between start and end
			segments := 6
			for i in 0 ..< segments {
				t1 := f32(i) / f32(segments)
				t2 := f32(i + 1) / f32(segments)

				// Add random offset to make it look like lightning
				offset_strength := 15.0 * (1.0 - abs(t1 - 0.5) * 2) // Stronger in middle
				random_offset := rl.Vector2 {
					(math.sin(t1 * math.PI * 4 + progress * 10) * offset_strength),
					(math.cos(t1 * math.PI * 3 + progress * 8) * offset_strength),
				}

				pos1 := rl.Vector2 {
					flash_start_pos.x +
					(flash_end_pos.x - flash_start_pos.x) * t1 +
					random_offset.x,
					flash_start_pos.y +
					(flash_end_pos.y - flash_start_pos.y) * t1 +
					random_offset.y,
				}
				pos2 := rl.Vector2 {
					flash_start_pos.x + (flash_end_pos.x - flash_start_pos.x) * t2,
					flash_start_pos.y + (flash_end_pos.y - flash_start_pos.y) * t2,
				}

				rl.DrawLineEx(pos1, pos2, 2, lightning_color)
			}
		}
	}
	// Screen flash effect
	if progress < 0.2 {
		flash_intensity := (0.2 - progress) * 5 // Strong flash at beginning
		screen_alpha := u8(flash_intensity * 40)
		screen_color := rl.Color{255, 255, 255, screen_alpha}
		rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), screen_color)
	}
}

skill_flash :: proc(player: ^Player, camera: rl.Camera2D) {
	flash_animation_timer = FLASH_ANIMATION_DURATION
	flash_start_pos = player.pos
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
	flash_end_pos = player.pos
}
