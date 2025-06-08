package game

import "core:c"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

draw_exp_bar :: proc(current_exp: int, target_exp: int, current_level: int) {
	// Bar dimensions
	bar_width: f32 = 300
	bar_height: f32 = 25
	border_thickness: f32 = 2

	// Position at top middle of screen
	bar_x := (f32(window_width) - bar_width) / 2 // Center horizontally
	bar_y: f32 = 50 // 20 pixels from top

	// Calculate experience progress (0.0 to 1.0)
	exp_progress: f32 = 0.0
	if target_exp > 0 {
		exp_progress = f32(current_exp) / f32(target_exp)
		exp_progress = clamp(exp_progress, 0.0, 1.0) // Ensure it's between 0 and 1
	}

	// Draw background (dark gray)
	rl.DrawRectangleV({bar_x, bar_y}, {bar_width, bar_height}, rl.DARKGRAY)

	// Draw experience fill (blue to purple gradient effect)
	fill_width := bar_width * exp_progress
	if fill_width > 0 {
		// You can use a simple color or create a gradient effect
		exp_color := rl.Color{50, 150, 255, 255} // Blue

		// Optional: Color changes based on progress
		if exp_progress > 0.75 {
			exp_color = rl.Color{150, 50, 255, 255} // Purple when close to level up
		} else if exp_progress > 0.5 {
			exp_color = rl.Color{100, 100, 255, 255} // Blue-purple mix
		}

		rl.DrawRectangleV({bar_x, bar_y}, {fill_width, bar_height}, exp_color)
	}

	// Draw border
	rl.DrawRectangleLinesEx({bar_x, bar_y, bar_width, bar_height}, border_thickness, rl.WHITE)

	// Draw level text on the left side of the bar
	level_text := rl.TextFormat("LVL %d", current_level)
	level_text_size: c.int = 18
	level_text_width := rl.MeasureText(level_text, level_text_size)
	level_text_x := bar_x - f32(level_text_width) - 10 // 10 pixels gap from bar
	level_text_y := bar_y + (bar_height - f32(level_text_size)) / 2 // Center vertically with bar

	rl.DrawText(level_text, c.int(level_text_x), c.int(level_text_y), level_text_size, rl.WHITE)

	// Draw experience text inside the bar
	exp_text := rl.TextFormat("%d / %d", current_exp, target_exp)
	exp_text_size: c.int = 14
	exp_text_width := rl.MeasureText(exp_text, exp_text_size)
	exp_text_x := bar_x + (bar_width - f32(exp_text_width)) / 2 // Center horizontally in bar
	exp_text_y := bar_y + (bar_height - f32(exp_text_size)) / 2 // Center vertically in bar

	// Use black text on light areas, white text on dark areas
	text_color := exp_progress > 0.5 ? rl.WHITE : rl.BLACK
	rl.DrawText(exp_text, c.int(exp_text_x), c.int(exp_text_y), exp_text_size, text_color)

	// Optional: Draw percentage text above the bar
	percentage_text := rl.TextFormat("%.1f%%", exp_progress * 100)
	percentage_text_size: c.int = 12
	percentage_text_width := rl.MeasureText(percentage_text, percentage_text_size)
	percentage_text_x := bar_x + (bar_width - f32(percentage_text_width)) / 2
	percentage_text_y := bar_y - f32(percentage_text_size) - 5 // 5 pixels above bar

	rl.DrawText(
		percentage_text,
		c.int(percentage_text_x),
		c.int(percentage_text_y),
		percentage_text_size,
		rl.LIGHTGRAY,
	)

	// Optional: Add a subtle glow effect when close to leveling up
	if exp_progress > 0.9 {
		glow_intensity := math.sin(rl.GetTime() * 6) * 0.3 + 0.7 // Pulsing effect
		glow_color := rl.Color{255, 255, 0, u8(glow_intensity * 100)} // Yellow glow

		// Draw slightly larger rectangle behind for glow effect
		glow_padding: f32 = 3
		rl.DrawRectangleLinesEx(
			{
				bar_x - glow_padding,
				bar_y - glow_padding,
				bar_width + glow_padding * 2,
				bar_height + glow_padding * 2,
			},
			1,
			glow_color,
		)
	}
}

draw_skills_bar :: proc(skills: []Skill) {
	// Calculate positions for bottom middle of screen
	bar_height: f32 = 40
	key_size: f32 = 40
	bar_width: f32 = f32(len(skills)) * key_size

	// Position at bottom middle of screen
	bar_x := (f32(window_width) - bar_width) / 2 // Center horizontally
	bar_y := f32(window_height) - bar_height - 20 // 20 pixels from bottom

	// Draw main skills bar (gray background)
	rl.DrawRectangleV({bar_x, bar_y}, {bar_width, bar_height}, rl.GRAY)

	// Draw key indicator box (yellow, positioned at the left of the bar)
	key_y := bar_y // Same Y position as bar
	text_size: c.int = 20
	cooldown_text_size: c.int = 16

	for skill, index in skills {
		key_x := bar_x + f32(index) * key_size // Align with left edge of bar
		color := skill.color

		if skill.on_cd {
			color = rl.GRAY
		}

		// Draw skill box
		rl.DrawRectangleV({key_x, key_y}, {key_size, key_size}, color)

		if skill.on_cd {
			// Draw cooldown overlay (semi-transparent dark overlay)
			cooldown_progress := skill.cd_left / skill.cooldown
			overlay_height := key_size * cooldown_progress
			overlay_color := rl.Color{0, 0, 0, 120} // Semi-transparent black

			rl.DrawRectangleV({key_x, key_y}, {key_size, overlay_height}, overlay_color)

			// Draw cooldown text (seconds remaining)
			cooldown_text := rl.TextFormat("%.1f", skill.cd_left)
			cooldown_text_width := rl.MeasureText(cooldown_text, cooldown_text_size)
			cooldown_text_x := key_x + (key_size - f32(cooldown_text_width)) / 2
			cooldown_text_y := key_y + key_size + 5 // Just below the skill box

			rl.DrawText(
				cooldown_text,
				c.int(cooldown_text_x),
				c.int(cooldown_text_y),
				cooldown_text_size,
				rl.WHITE,
			)
		}

		// Draw skill key letter
		text_width := rl.MeasureText(skill.key, text_size)
		text_x := key_x + (key_size - f32(text_width)) / 2 // Center horizontally in box
		text_y := key_y + (key_size - f32(text_size)) / 2 // Center vertically in box

		// Use white text if skill is on cooldown for better contrast
		key_text_color := skill.on_cd ? rl.WHITE : rl.BLACK
		rl.DrawText(skill.key, c.int(text_x), c.int(text_y), text_size, key_text_color)

		// Optional: Add border to make it look nicer
		border_color := skill.on_cd ? rl.DARKGRAY : rl.ORANGE
		rl.DrawRectangleLinesEx({key_x, key_y, key_size, key_size}, 2, border_color)
	}

	// Draw outer border for the entire skills bar
	rl.DrawRectangleLinesEx({bar_x, bar_y, bar_width, bar_height}, 2, rl.DARKGRAY)
}


// Draw HP bar above enemy
draw_hp_bar :: proc(enemy_pos: rl.Vector2, current_hp: int, max_hp: int) {
	bar_pos := rl.Vector2 {
		enemy_pos.x + (ENEMY_SIZE - HP_BAR_WIDTH) / 2, // Center above enemy
		enemy_pos.y - HP_BAR_HEIGHT - 5, // Above enemy
	}

	// Background (dark red)
	rl.DrawRectangleV(bar_pos, {HP_BAR_WIDTH, HP_BAR_HEIGHT}, rl.Color{139, 0, 0, 255})

	// HP bar (green to red gradient based on health)
	hp_percentage := f32(current_hp) / f32(max_hp)
	hp_width := HP_BAR_WIDTH * hp_percentage

	// Color interpolation from green to red
	hp_color: rl.Color
	if hp_percentage > 0.6 {
		hp_color = rl.GREEN
	} else if hp_percentage > 0.3 {
		hp_color = rl.YELLOW
	} else {
		hp_color = rl.RED
	}

	if hp_width > 0 {
		rl.DrawRectangleV(bar_pos, {hp_width, HP_BAR_HEIGHT}, hp_color)
	}

	// Border
	rl.DrawRectangleLinesEx({bar_pos.x, bar_pos.y, HP_BAR_WIDTH, HP_BAR_HEIGHT}, 1, rl.BLACK)
}

// Draw player HP bar in UI
draw_player_hp_bar :: proc(current_hp: int, max_hp: int) {
	bar_pos := rl.Vector2{10, 140}
	bar_width: f32 = 200
	bar_height: f32 = 20

	// Background (dark red)
	rl.DrawRectangleV(bar_pos, {bar_width, bar_height}, rl.Color{139, 0, 0, 255})

	// HP bar
	hp_percentage := f32(current_hp) / f32(max_hp)
	hp_width := bar_width * hp_percentage

	// Color based on health
	hp_color: rl.Color
	if hp_percentage > 0.6 {
		hp_color = rl.GREEN
	} else if hp_percentage > 0.3 {
		hp_color = rl.YELLOW
	} else {
		hp_color = rl.RED
	}

	if hp_width > 0 {
		rl.DrawRectangleV(bar_pos, {hp_width, bar_height}, hp_color)
	}

	// Border
	rl.DrawRectangleLinesEx({bar_pos.x, bar_pos.y, bar_width, bar_height}, 2, rl.BLACK)

	// HP text
	rl.DrawText(
		rl.TextFormat("HP: %d/%d", current_hp, max_hp),
		c.int(bar_pos.x + 5),
		c.int(bar_pos.y + 2),
		16,
		rl.WHITE,
	)
}

// Start enemy death animation
start_enemy_death_animation :: proc(enemy: ^Enemy) {
	enemy.dying = true
	enemy.death_timer = 0

	// Create explosion particles
	for i in 0 ..< EXPLOSION_PARTICLES {
		angle := f32(i) * (2 * math.PI / EXPLOSION_PARTICLES)
		speed := f32(rl.GetRandomValue(50, 150))

		enemy.death_particles[i] = Particle {
			pos      = {enemy.pos.x + ENEMY_SIZE / 2, enemy.pos.y + ENEMY_SIZE / 2},
			vel      = {math.cos(angle) * speed, math.sin(angle) * speed},
			color    = rl.Color{255, u8(rl.GetRandomValue(100, 255)), 0, 255}, // Orange/red colors
			life     = PARTICLE_LIFETIME,
			max_life = PARTICLE_LIFETIME,
			size     = f32(rl.GetRandomValue(5, 15)),
		}
	}
}

// Start player death animation
start_player_death_animation :: proc(player: ^Player) {
	player.dying = true
	player.death_timer = 0

	// Create explosion particles
	for i in 0 ..< EXPLOSION_PARTICLES {
		angle := f32(i) * (2 * math.PI / EXPLOSION_PARTICLES)
		speed := f32(rl.GetRandomValue(100, 200))

		player.death_particles[i] = Particle {
			pos      = {player.pos.x + PLAYER_SIZE / 2, player.pos.y + PLAYER_SIZE / 2},
			vel      = {math.cos(angle) * speed, math.sin(angle) * speed},
			color    = rl.Color {
				u8(rl.GetRandomValue(200, 255)),
				u8(rl.GetRandomValue(200, 255)),
				255,
				255,
			}, // Blue/white colors
			life     = PARTICLE_LIFETIME,
			max_life = PARTICLE_LIFETIME,
			size     = f32(rl.GetRandomValue(10, 25)),
		}
	}
}

// Draw game over screen
draw_game_over_screen :: proc() {
	// Semi-transparent overlay
	rl.DrawRectangle(0, 0, window_width, window_height, rl.Color{0, 0, 0, 150})

	// Game Over text
	game_over_text: cstring = "GAME OVER"
	text_width := rl.MeasureText(game_over_text, 60)
	rl.DrawText(
		game_over_text,
		(window_width - text_width) / 2,
		window_height / 2 - 100,
		60,
		rl.RED,
	)

	// Instructions
	restart_text: cstring = "Press R to Restart"
	restart_width := rl.MeasureText(restart_text, 30)
	rl.DrawText(
		restart_text,
		(window_width - restart_width) / 2,
		window_height / 2 - 20,
		30,
		rl.WHITE,
	)

	quit_text: cstring = "Press ESC to Quit"
	quit_width := rl.MeasureText(quit_text, 30)
	rl.DrawText(quit_text, (window_width - quit_width) / 2, window_height / 2 + 20, 30, rl.WHITE)
}

// Draw game over screen
draw_game_paused_screen :: proc() {
	// Semi-transparent overlay
	rl.DrawRectangle(0, 0, window_width, window_height, rl.Color{0, 0, 0, 150})

	// Game Over text
	game_over_text: cstring = "GAME PAUSED"
	text_width := rl.MeasureText(game_over_text, 60)
	rl.DrawText(
		game_over_text,
		(window_width - text_width) / 2,
		window_height / 2 - 100,
		60,
		rl.RED,
	)

	// Instructions
	restart_text: cstring = "Press P to unpause"
	restart_width := rl.MeasureText(restart_text, 30)
	rl.DrawText(
		restart_text,
		(window_width - restart_width) / 2,
		window_height / 2 - 20,
		30,
		rl.WHITE,
	)

	quit_text: cstring = "Press ESC to Quit"
	quit_width := rl.MeasureText(quit_text, 30)
	rl.DrawText(quit_text, (window_width - quit_width) / 2, window_height / 2 + 20, 30, rl.WHITE)
}

draw_game_playing_texts :: proc(player : Player, enemies : []Enemy, skill_list : []Skill) {
	draw_exp_bar(player.current_exp, player.exp_to_next_level, player.level)
	draw_player_hp_bar(player.hp, PLAYER_MAX_HP)
	draw_skills_bar(skill_list[:])
	// Draw UI elements (not affected by camera)
	rl.DrawText("Use A/D to move, SPACE to jump, P to pause, Mouse to shoot", 10, 10, 20, rl.WHITE)
	rl.DrawText(rl.TextFormat("Player X: %.1f", player.pos.x), 10, 35, 20, rl.WHITE)
	// rl.DrawText(rl.TextFormat("SCORE: %v", score), 10, 60, 20, rl.WHITE)

	active_enemies := 0
	for enemy in enemies {
		if enemy.active && !enemy.dying do active_enemies += 1
	}
	rl.DrawText(rl.TextFormat("Enemies: %d", active_enemies), 10, 85, 20, rl.WHITE)
	rl.DrawText(rl.TextFormat("Player HP: %d/%d", player.hp, PLAYER_MAX_HP), 10, 110, 20, rl.WHITE)
	// debug_mouse_info(camera)
}

debug_mouse_info :: proc(camera: rl.Camera2D) {
	mouse_screen_pos := rl.GetMousePosition()
	mouse_world_pos := rl.GetScreenToWorld2D(mouse_screen_pos, camera)

	rl.DrawText(
		rl.TextFormat("Mouse Screen: (%.1f, %.1f)", mouse_screen_pos.x, mouse_screen_pos.y),
		10,
		200,
		16,
		rl.WHITE,
	)
	rl.DrawText(
		rl.TextFormat("Mouse World: (%.1f, %.1f)", mouse_world_pos.x, mouse_world_pos.y),
		10,
		220,
		16,
		rl.WHITE,
	)
}
