package game

import "core:c"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

window_width: c.int = 700
window_height: c.int = 700

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
	rl.InitWindow(window_width, window_height, "game")
	rl.SetWindowMinSize(300, 300)
	rl.SetTargetFPS(200)
  rl.InitAudioDevice()
  

	// Initialize player
	player := Player {
		pos               = {300, 400},
		hp                = PLAYER_MAX_HP,
		level             = 1,
		current_exp       = 0,
		exp_to_next_level = 100,
	}
	skill_list := skills_list_init()
	// Game state
	game_state := GameState.PLAYING
	// Camera for side-scrolling
	camera := rl.Camera2D {
		target   = player.pos,
		rotation = 0,
		zoom     = 1.0,
	}
	// Load all 6 player textures
	player_textures := load_player_textures()
  shot_sound := rl.LoadSound("assets/shot.wav")
  game_over_sound := rl.LoadSound("assets/game-over.wav")
  damage_taken_sound := rl.LoadSound("assets/damage.wav")
	// Animation variables
	current_frame: int = 0
	animation_timer: f32 = 0
	is_moving: bool = false

	// Bullet system
	bullets: [MAX_BULLETS]Bullet
	next_bullet_index: int = 0

	// Enemy system
	enemies: [MAX_ENEMIES]Enemy
	next_enemy_index: int = 0
	enemy_spawn_timer: f32 = 0
	muzzle_flash_timer: f32
	for !rl.WindowShouldClose() {
		window_width = rl.GetScreenWidth()
		window_height = rl.GetScreenHeight()
		mouse_screen_pos := rl.GetMousePosition()
		mouse_world_pos := rl.GetScreenToWorld2D(mouse_screen_pos, camera)
		dt := rl.GetFrameTime()

		switch game_state {
		case .PLAYING:
			// Update player damage cooldown
			if player.damage_timer > 0 {
				player.damage_timer -= dt
			}

			// Only allow input if player is not dying
			if !player.dying {
				// Horizontal movement
				is_moving = false
				if rl.IsKeyDown(.A) {
					player.vel.x = -MOVE_SPEED
					is_moving = true
				} else if rl.IsKeyDown(.D) {
					player.vel.x = MOVE_SPEED
					is_moving = true
				} else {
					player.vel.x = 0
				}
				//update skills
				for &skill in skill_list {
					if skill.on_cd {
						skill.cd_left -= dt
						if skill.cd_left <= 0 {
							skill.on_cd = false
							skill.cd_left = 0
						}
					}
				}
				// Jumping - only when grounded and space is pressed
				if rl.IsKeyPressed(.SPACE) && player.grounded {
					player.vel.y = JUMP_FORCE
					player.grounded = false
				}

				if rl.IsKeyPressed(.F) && !skill_list[0].on_cd { 	//flash
					skill_list[0].on_cd = true
					skill_list[0].cd_left = skill_list[0].cooldown
					skill_flash(&player, camera)
				}
				if rl.IsKeyPressed(.E) && !skill_list[1].on_cd { 	//heal
					skill_list[1].on_cd = true
					skill_list[1].cd_left = skill_list[1].cooldown
					player.hp += HEAL_AMOUNT
					player.hp = clamp(player.hp, 0, PLAYER_MAX_HP)
				}

				if muzzle_flash_timer > 0 {
					muzzle_flash_timer -= rl.GetFrameTime()
				}
				// Shooting - left mouse button
				if rl.IsMouseButtonPressed(.LEFT) {
          play_sound_varied(shot_sound)
					muzzle_flash_timer = MUZZLE_FLASH_DURATION
					// Calculate player center for shooting from
					player_center := rl.Vector2 {
						player.pos.x + PLAYER_SIZE / 2,
						player.pos.y + PLAYER_SIZE / 2,
					}

					// Calculate direction vector from player to mouse
					direction := rl.Vector2 {
						mouse_world_pos.x - player_center.x,
						mouse_world_pos.y - player_center.y,
					}

					// Normalize direction and apply bullet speed
					length := math.sqrt(direction.x * direction.x + direction.y * direction.y)
					if length > 0 {
						direction.x = (direction.x / length) * BULLET_SPEED
						direction.y = (direction.y / length) * BULLET_SPEED

						// Create new bullet
						bullets[next_bullet_index] = Bullet {
							pos    = player_center,
							vel    = direction,
							active = true,
						}
						next_bullet_index = (next_bullet_index + 1) % MAX_BULLETS
					}
				}

				// Apply gravity when not grounded
				if !player.grounded {
					player.vel.y += GRAVITY * dt
				}

				// Update position
				player.pos += player.vel * dt

				// Clamp horizontal position to world bounds (not screen bounds)
				player.pos.x = clamp(player.pos.x, 0, WORLD_WIDTH - PLAYER_SIZE)
				player.pos.y = clamp(player.pos.y, 0, f32(window_height - PLAYER_SIZE))

				// Check if player is on the ground
				if player.pos.y == f32(window_height - PLAYER_SIZE) {
					player.vel.y = 0
					player.grounded = true
				}
			}

			// Update player death animation
			if player.dying {
				player.death_timer += dt

				// Update death particles
				for &particle in player.death_particles {
					if particle.life > 0 {
						particle.pos += particle.vel * dt
						particle.vel.y += 200 * dt // Gravity on particles
						particle.life -= dt
						particle.size = (particle.life / particle.max_life) * 20 // Shrink over time
					}
				}

				if player.death_timer >= DEATH_ANIMATION_DURATION {
					game_state = .GAME_OVER
          rl.PlaySound(game_over_sound)
				}
			}

			// Update camera to follow player smoothly (only if player is alive)
			if !player.dying {
				player_center := rl.Vector2 {
					player.pos.x + PLAYER_SIZE / 2,
					player.pos.y + PLAYER_SIZE / 2,
				}

				// Smooth camera following
				diff := rl.Vector2 {
					player_center.x - camera.target.x,
					player_center.y - camera.target.y,
				}
				camera.target.x += diff.x * CAMERA_FOLLOW_SPEED * dt
				camera.target.y += diff.y * CAMERA_FOLLOW_SPEED * dt

				// Constrain camera to world bounds
				camera.target.x = clamp(
					camera.target.x,
					f32(window_width) / 2,
					WORLD_WIDTH - f32(window_width) / 2,
				)
			}

			// Update animation only when moving and alive
			if !player.dying {
				animation_timer += dt
				if animation_timer >= ANIMATION_SPEED {
					animation_timer = 0
					current_frame = (current_frame + 1) % 6
				}
			}

			// Update bullets
			for &bullet in bullets {
				if bullet.active {
					bullet.pos += bullet.vel * dt

					// Check bullet-enemy collision
					for &enemy in enemies {
						if enemy.active && !enemy.dying {
							enemy_rect := rl.Rectangle {
								x      = enemy.pos.x,
								y      = enemy.pos.y,
								width  = ENEMY_SIZE,
								height = ENEMY_SIZE,
							}

							if !bullet.enemy_bullet &&
							   rl.CheckCollisionPointRec(bullet.pos, enemy_rect) {
								// Hit enemy
								enemy.hp -= 25 // Damage per bullet
								bullet.active = false

								// Start death animation if HP reaches 0
								if enemy.hp <= 0 {
									player_exp_update(&player, 20)
									start_enemy_death_animation(&enemy)
								}
								break
							}
						}
					}
					//Check enemy bullet-player collision
					if bullet.enemy_bullet && !player.dying && player.damage_timer <= 0 {
						player_rect := rl.Rectangle {
							x      = player.pos.x,
							y      = player.pos.y,
							width  = PLAYER_SIZE,
							height = PLAYER_SIZE,
						}

						if rl.CheckCollisionPointRec(bullet.pos, player_rect) {
							// Player takes damage from enemy bullet
              play_sound_varied(damage_taken_sound)
							player.hp -= 15 // Adjust damage as needed
							player.damage_timer = PLAYER_DAMAGE_COOLDOWN
							bullet.active = false

							// Check if player dies
							if player.hp <= 0 {
								player.hp = 0
								start_player_death_animation(&player)
							}
						}
					}

					// Deactivate bullets that go off world bounds
					if bullet.pos.x < -10 ||
					   bullet.pos.x > WORLD_WIDTH + 10 ||
					   bullet.pos.y < -10 ||
					   bullet.pos.y > f32(window_height) + 10 {
						bullet.active = false
					}
				}
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
				if enemy.active {
					if enemy.dying {
						// Update death animation
						enemy.death_timer += dt

						// Update death particles
						for &particle in enemy.death_particles {
							if particle.life > 0 {
								particle.pos += particle.vel * dt
								particle.vel.y += 200 * dt // Gravity on particles
								particle.life -= dt
								particle.size = (particle.life / particle.max_life) * 10 // Shrink over time
							}
						}

						// Remove enemy after death animation
						if enemy.death_timer >= DEATH_ANIMATION_DURATION {
							enemy.active = false
						}
					} else {
						// Update based on enemy type
						switch enemy.enemy_type {
						case .MELEE:
							update_melee_enemy(&enemy, player.pos, dt)
						case .FLYER:
							update_flyer_enemy(
								&enemy,
								player.pos,
								&bullets,
								&next_bullet_index,
								dt,
							)
						case .EXPLODER:
							update_exploder_enemy(&enemy, &player, dt)
						}

						// Keep enemies within world bounds
						enemy.pos.x = clamp(enemy.pos.x, 0, WORLD_WIDTH - ENEMY_SIZE)
						enemy.pos.y = clamp(enemy.pos.y, 0, f32(window_height) - ENEMY_SIZE)

						// Check collision with player (only if player is not dying)
						if !player.dying && enemy.enemy_type == .MELEE {
							player_rect := rl.Rectangle {
								x      = player.pos.x,
								y      = player.pos.y,
								width  = PLAYER_SIZE,
								height = PLAYER_SIZE,
							}
							enemy_rect := rl.Rectangle {
								x      = enemy.pos.x,
								y      = enemy.pos.y,
								width  = ENEMY_SIZE,
								height = ENEMY_SIZE,
							}

							if rl.CheckCollisionRecs(player_rect, enemy_rect) &&
							   player.damage_timer <= 0 {
								// Player takes damage
								player.hp -= 20
                rl.PlaySound(damage_taken_sound)
								player.damage_timer = PLAYER_DAMAGE_COOLDOWN

								// Check if player dies
								if player.hp <= 0 {
									player.hp = 0
									start_player_death_animation(&player)
								}

								// Push enemy away slightly to prevent getting stuck
								push_direction := rl.Vector2 {
									enemy.pos.x - player.pos.x,
									enemy.pos.y - player.pos.y,
								}
								push_length := math.sqrt(
									push_direction.x * push_direction.x +
									push_direction.y * push_direction.y,
								)
								if push_length > 0 {
									enemy.pos.x += (push_direction.x / push_length) * 20
									enemy.pos.y += (push_direction.y / push_length) * 20
								}
							}
						}
					}
				}
			}

		case .GAME_OVER:
			// Game over input
			if rl.IsKeyPressed(.R) {
				// Restart game
				game_state = .PLAYING
				player = Player {
					pos = {300, 300},
					hp  = PLAYER_MAX_HP,
				}
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

		// Draw player (with damage flash effect and death animation)
		if !player.dying {
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
			texture := player_textures[current_frame]

			// Define the source rectangle from the texture. By default, it's the whole texture.
			source_rec := rl.Rectangle {
				x      = 0,
				y      = 0,
				width  = f32(texture.width),
				height = f32(texture.height),
			}

			// Define the destination rectangle on the screen, applying the scale.
			dest_rec := rl.Rectangle {
				x      = player.pos.x,
				y      = player.pos.y,
				width  = f32(texture.width) * PLAYER_ZOOM,
				height = f32(texture.height) * PLAYER_ZOOM,
			}
			// If the player is not facing right, we set the source rectangle's width to be negative.
			// This tells DrawTexturePro to render it horizontally flipped.
			facing_right := mouse_world_pos.x > player.pos.x
			if facing_right {
				source_rec.width = -source_rec.width
			}
			// We use DrawTexturePro for its ability to render a flipped texture.
			// The origin is {0, 0} (top-left), and rotation is 0.
			rl.DrawTexturePro(texture, source_rec, dest_rec, rl.Vector2{0, 0}, 0, player_color)
			// Draw muzzle flash
			if muzzle_flash_timer > 0 {
				// Calculate flash properties
				flash_alpha := u8((muzzle_flash_timer / MUZZLE_FLASH_DURATION) * 255)
				flash_size := 12.0 * PLAYER_ZOOM * (muzzle_flash_timer / MUZZLE_FLASH_DURATION)

				// Calculate muzzle position (front of the player)
				muzzle_offset_x: f32 = facing_right ? dest_rec.width * 0.92 : dest_rec.width * 0.08
				muzzle_pos := rl.Vector2 {
					player.pos.x + muzzle_offset_x,
					player.pos.y + dest_rec.height * 0.5, // Roughly chest height
				}

				// Draw the muzzle flash as a circle with fade effect
				flash_color := rl.Color{255, 255, 150, flash_alpha} // Yellow-white flash
				rl.DrawCircleV(muzzle_pos, flash_size, flash_color)

				// Optional: Add a smaller, brighter inner circle
				inner_flash_color := rl.Color{255, 255, 255, flash_alpha}
				rl.DrawCircleV(muzzle_pos, flash_size * 0.5, inner_flash_color)
			}
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

		// Draw enemies
		for &enemy in enemies {
			if enemy.active {
				if !enemy.dying {
					// Draw enemy body based on type
					switch enemy.enemy_type {
					case .MELEE:
						rl.DrawRectangleV(enemy.pos, {ENEMY_SIZE, ENEMY_SIZE}, rl.BLACK)
					case .FLYER:
						rl.DrawRectangleV(enemy.pos, {ENEMY_SIZE, ENEMY_SIZE}, rl.PURPLE)
					case .EXPLODER:
						color := rl.ORANGE
						if enemy.is_exploding {
							// Flash when about to explode
							if math.sin(rl.GetTime() * 20) > 0 {
								color = rl.RED
							}
						}
						rl.DrawRectangleV(enemy.pos, {ENEMY_SIZE, ENEMY_SIZE}, color)
					}

					rl.DrawRectangleLinesEx(
						{enemy.pos.x, enemy.pos.y, ENEMY_SIZE, ENEMY_SIZE},
						2,
						rl.Color{139, 0, 0, 255},
					) // Dark red border

					// Draw HP bar
					draw_hp_bar(enemy.pos, enemy.hp, enemy.max_hp)
				} else {
					// Draw death particles
					for particle in enemy.death_particles {
						if particle.life > 0 {
							rl.DrawCircleV(particle.pos, particle.size, particle.color)
						}
					}
				}
			}
		}

		// Draw world bounds visualization
		rl.DrawRectangleLines(0, 0, WORLD_WIDTH, window_height, rl.RED)
		rl.EndMode2D()
		// Draw UI based on game state
		switch game_state {
		case .PLAYING:
			draw_exp_bar(player.current_exp, player.exp_to_next_level, player.level)
			// Draw player HP bar (UI element, not affected by camera)
			draw_player_hp_bar(player.hp, PLAYER_MAX_HP)
			draw_skills_bar(skill_list[:])
			// Draw UI elements (not affected by camera)
			rl.DrawText("Use A/D to move, SPACE to jump, Mouse to shoot", 10, 10, 20, rl.WHITE)
			rl.DrawText(rl.TextFormat("Player X: %.1f", player.pos.x), 10, 35, 20, rl.WHITE)
			// rl.DrawText(rl.TextFormat("SCORE: %v", score), 10, 60, 20, rl.WHITE)

			// Count active enemies
			active_enemies := 0
			for enemy in enemies {
				if enemy.active && !enemy.dying do active_enemies += 1
			}
			rl.DrawText(rl.TextFormat("Enemies: %d", active_enemies), 10, 85, 20, rl.WHITE)
			rl.DrawText(
				rl.TextFormat("Player HP: %d/%d", player.hp, PLAYER_MAX_HP),
				10,
				110,
				20,
				rl.WHITE,
			)

		// debug_mouse_info(camera)

		case .GAME_OVER:
			// Draw game over screen
			draw_game_over_screen()
		}

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	// Cleanup textures
	for texture in player_textures {
		rl.UnloadTexture(texture)
	}
  rl.UnloadSound(game_over_sound)
  rl.UnloadSound(damage_taken_sound)
  rl.UnloadSound(shot_sound)
  rl.CloseAudioDevice()
	rl.CloseWindow()
}
