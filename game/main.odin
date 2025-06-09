package game

import "core:c"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer {
		for _, entry in track.allocation_map {
			fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
		}
		for entry in track.bad_free_array {
			fmt.eprintf("%v bad free\n", entry.location)
		}
		mem.tracking_allocator_destroy(&track)
	}

	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
	rl.InitWindow(window_width, window_height, "cat game")
	rl.SetWindowMinSize(300, 300)
	rl.SetTargetFPS(200)
	rl.InitAudioDevice()
	// Initialize player
	player := init_player()
	skill_list := skills_list_init()
	// Game state
	game_state := GameState.PLAYING
	spawn_enemies := true
	//load assets
	sounds = load_sounds()
	player_textures := load_player_textures()
	platform_texture := rl.LoadTexture("assets/platform.png")
	// Enemy system
	enemies: [MAX_ENEMIES]Enemy
	next_enemy_index: int = 0
	enemy_spawn_timer: f32 = 0

	camera := rl.Camera2D {
		target   = player.pos,
		rotation = 0,
		zoom     = 1.0,
	}
	level := Level {
		p_size = {200, 20},
	}
	editing := false
	init_level(&level)
	for !rl.WindowShouldClose() {
		window_width = rl.GetScreenWidth()
		window_height = rl.GetScreenHeight()
		mouse_world_pos = rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
		camera.zoom = f32(window_height / PIXEL_WINDOW_HEIGHT)
		dt = rl.GetFrameTime()

		player_feet_collider := rl.Rectangle {
			player.pos.x + 30,
			player.pos.y + PLAYER_SIZE,
			PLAYER_SIZE - 50,
			10,
		}

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
				player_alive_update(&player, &skill_list, camera, &level, player_feet_collider)
				player_alive_camera_update(&camera, player)
			}
			// Update player death animation
			if player.dying {
				player_dying(&player, &game_state)
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
					if spawn_enemies {
						spawn_enemy(&enemies, next_enemy_index, camera, player.pos)
					}
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

		draw_platforms(level.platforms[:], platform_texture, level)
		if !player.dying {
			draw_player(player, &camera, player_textures)
			draw_gun(player, player_textures.gun)
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
		if flash_animation_timer > 0 {
			draw_flash_animation()
			flash_animation_timer -= dt
		}
		if heal_animation_timer > 0 {
			draw_heal_animation(player.pos)
			heal_animation_timer -= dt
		}
		//debug draws
		rl.DrawRectangleRec(player_feet_collider, rl.PURPLE)

		if rl.IsKeyPressed(.F2) {
			editing = !editing
		}

		if editing {
			// Handle editor input
			handle_editor_input(&level, mouse_world_pos)

			// Draw platform preview at mouse position
			rl.DrawTextureV(platform_texture, mouse_world_pos, {255, 255, 255, 128})
		}

		// Draw world bounds visualization
		rl.DrawRectangleLines(0, 0, WORLD_WIDTH, window_height, rl.RED)
		rl.EndMode2D()
		// Draw UI based on game state
		switch game_state {
		case .PAUSED:
			draw_game_paused_screen()
		case .PLAYING:
      if !editing{
			draw_game_playing_texts(player, enemies[:], skill_list[:])
      }
		case .GAME_OVER:
			draw_game_over_screen()
		}
		draw_editor_ui(&level, editing)

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
	unload_assets(&player_textures)
	rl.UnloadTexture(platform_texture)
	rl.CloseAudioDevice()
	rl.CloseWindow()

	//kinda unnecessary because memory is freed anyways after program exits
	delete(level.platforms)
}
