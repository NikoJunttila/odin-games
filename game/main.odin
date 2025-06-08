package game

import "core:c"
import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
	rl.InitWindow(window_width, window_height, "cat game")
	rl.SetWindowMinSize(300, 300)
	rl.SetTargetFPS(200)
	rl.InitAudioDevice()
	sounds = load_sounds()
	// Initialize player
	player := init_player()
	skill_list := skills_list_init()
	// Game state
	game_state := GameState.PLAYING
	//load assets
	player_textures := load_player_textures()
	// Enemy system
	enemies: [MAX_ENEMIES]Enemy
	next_enemy_index: int = 0
	enemy_spawn_timer: f32 = 0

	camera := rl.Camera2D {
		target   = player.pos,
		rotation = 0,
		zoom     = 1.0,
	}

	for !rl.WindowShouldClose() {
		window_width = rl.GetScreenWidth()
		window_height = rl.GetScreenHeight()
		mouse_screen_pos := rl.GetMousePosition()
		mouse_world_pos = rl.GetScreenToWorld2D(mouse_screen_pos, camera)
		camera.zoom = f32(window_height / PIXEL_WINDOW_HEIGHT)
		dt = rl.GetFrameTime()

		switch game_state {
		case .PAUSED:
			if rl.IsKeyPressed(.P) {
				game_state = .PLAYING
			}
		case .PLAYING:
			// Update player damage cooldown
			if rl.IsKeyPressed(.P) {
				game_state = .PAUSED
			}
			if player.damage_timer > 0 {
				player.damage_timer -= dt
			}
			// Only allow input if player is not dying
			if !player.dying {
				player_alive_update(&player, &skill_list, camera)
			}
			// Update player death animation
			if player.dying {
				player_dying(&player, &game_state)
			}
			// Update camera to follow player smoothly (only if player is alive)
			if !player.dying {
        player_alive_camera_update(&camera, player)
      }

			// Update bullets
			for &bullet in bullets {
				bullet_logic_update(&bullet, &enemies, &player)
			}

			// Update enemies
			if !player.dying { 	// Don't spawn enemies if player is dying
				enemy_spawn_timer += dt
				if enemy_spawn_timer >= ENEMY_SPAWN_RATE {
					enemy_spawn_timer = 0
					spawn_enemy(&enemies, next_enemy_index, camera, player.pos)
					next_enemy_index = (next_enemy_index + 1) % MAX_ENEMIES
				}
			}
			// Update enemy movement and AI
			for &enemy in enemies {
				update_enemy(&enemy, &player)
			}

		case .GAME_OVER:
			// Game over input
			if rl.IsKeyPressed(.R) {
				// Restart game
				game_state = .PLAYING
				player = init_player()
				camera.target = player.pos
				// Clear bullets
				for &bullet in bullets {
					bullet.active = false
				}
				// Clear enemies
				for &enemy in enemies {
					enemy.active = false
				}
				enemy_spawn_timer = 0
			}
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.SKYBLUE)
		rl.BeginMode2D(camera)
		// Draw background elements
		draw_background(camera)

		if !player.dying {
			draw_player(player, &camera, player_textures)
		} else {
			// Draw death particles
			for particle in player.death_particles {
				if particle.life > 0 {
					rl.DrawCircleV(particle.pos, particle.size, particle.color)
				}
			}
		}

		// Draw bullets
		for bullet in bullets {
			if bullet.active {
				if bullet.enemy_bullet {
					rl.DrawCircleV(bullet.pos, 5, rl.BLACK)
				} else {
					rl.DrawCircleV(bullet.pos, 5, rl.YELLOW)
				}
			}
		}
		for &enemy in enemies {
			draw_enemy(enemy)
		}

		// Draw world bounds visualization
		rl.DrawRectangleLines(0, 0, WORLD_WIDTH, window_height, rl.RED)
		rl.EndMode2D()
		// Draw UI based on game state
		switch game_state {
		case .PAUSED:
			draw_game_paused_screen()
		case .PLAYING:
			draw_game_playing_texts(player, enemies[:], skill_list[:])
		case .GAME_OVER:
			draw_game_over_screen()
		}

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	unload_assets(&player_textures)
	rl.CloseAudioDevice()
	rl.CloseWindow()
}
