package game

import "core:math"
import rl "vendor:raylib"
import "core:math/rand"

bullet_logic_update :: proc(bullet: ^Bullet, enemies: ^[20]Enemy, player: ^Player) {
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

				if !bullet.enemy_bullet && rl.CheckCollisionPointRec(bullet.pos, enemy_rect) {
					// Hit enemy
					enemy.hp -= 25 // Damage per bullet
					bullet.active = false

					// Start death animation if HP reaches 0
					if enemy.hp <= 0 {
						player_exp_update(player, 20)
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
				play_sound_varied(sounds.damage_taken)
				player.hp -= 15 // Adjust damage as needed
				player.damage_timer = PLAYER_DAMAGE_COOLDOWN
				bullet.active = false

				// Check if player dies
				if player.hp <= 0 {
					player.hp = 0
					start_player_death_animation(player)
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

player_dying :: proc(player: ^Player, game_state: ^GameState) {
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
		game_state^ = .GAME_OVER
		rl.PlaySound(sounds.game_over)
	}
}

player_alive_camera_update :: proc(camera: ^rl.Camera2D, player: Player) {
	player_center := rl.Vector2{player.pos.x + PLAYER_SIZE / 2, player.pos.y + PLAYER_SIZE / 2}

	// Smooth camera following
	diff := rl.Vector2{player_center.x - camera.target.x, player_center.y - camera.target.y}
	camera.target.x += diff.x * CAMERA_FOLLOW_SPEED * dt
	camera.target.y += diff.y * CAMERA_FOLLOW_SPEED * dt

	// Constrain camera to world bounds
	camera.target.x = clamp(
		camera.target.x,
		f32(window_width) / 2,
		WORLD_WIDTH - f32(window_width) / 2,
	)
	//update frames
	animation_timer += dt
	if animation_timer >= ANIMATION_SPEED {
		animation_timer = 0
		current_frame = (current_frame + 1) % 6
	}
}

player_alive_update :: proc(
	player: ^Player,
	skill_list: ^[SKILL_COUNT]Skill,
	camera: rl.Camera2D,
	level: ^Level,
	player_feet_collider: rl.Rectangle,
) {
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
		skill_flash(player, camera)
	}

	if rl.IsKeyPressed(.E) && !skill_list[1].on_cd { 	//heal
		skill_list[1].on_cd = true
		skill_list[1].cd_left = skill_list[1].cooldown
		skill_heal(player)
	}

	if muzzle_flash_timer > 0 {
		muzzle_flash_timer -= rl.GetFrameTime()
	}

	// Shooting - left mouse button
	if rl.IsMouseButtonPressed(.LEFT) {
		play_sound_varied_low(sounds.shot)
		muzzle_flash_timer = MUZZLE_FLASH_DURATION
		// Calculate player center for shooting from
		player_center := rl.Vector2{player.pos.x + PLAYER_SIZE / 2, player.pos.y + PLAYER_SIZE / 2}
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
			// Generate random bright color (avoiding black/dark colors)
			color := rl.Color {
				u8(128 + rand.int31() % 128), // 128-255 range
				u8(128 + rand.int31() % 128), // 128-255 range  
				u8(128 + rand.int31() % 128), // 128-255 range
				255,
			}
			bullets[next_bullet_index] = Bullet {
				pos    = player_center,
				vel    = direction,
				active = true,
				color  = color,
			}
			next_bullet_index = (next_bullet_index + 1) % MAX_BULLETS
		}
	}

	// Apply gravity only when not grounded
	if !player.grounded {
		player.vel.y += GRAVITY * dt
	}
	// Update horizontal position first
	player.pos.x += player.vel.x * dt
	// Clamp horizontal position to world bounds
	player.pos.x = clamp(player.pos.x, 0, WORLD_WIDTH - PLAYER_SIZE)
	// Reset grounded state - it will be set to true if we're on a platform
	player.grounded = false
	for &platform in level.platforms {
		if rl.CheckCollisionRecs(player_feet_collider, platform_to_rect(platform, level.p_size)) &&
		   player.vel.y >= 0 &&
		   player_feet_collider.y <= platform.pos.y + 10 {
			player.vel.y = 0
			player.pos.y = platform.pos.y - PLAYER_SIZE + 9
			player.grounded = true
		}
	}
	if !player.grounded {
		player.pos.y += player.vel.y * dt
	}
	// Ground collision (bottom of screen)
	if player.pos.y >= f32(window_height - PLAYER_SIZE) {
		player.pos.y = f32(window_height - PLAYER_SIZE)
		player.vel.y = 0
		player.grounded = true
	}

	// Prevent going above screen
	if player.pos.y < 0 {
		player.pos.y = 0
		player.vel.y = 0
	}
}
