package game

import "core:c"
import "core:math"
import rl "vendor:raylib"


update_enemy :: proc(enemy : ^Enemy, player : ^Player) {
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
				update_melee_enemy(enemy, player.pos)
			case .FLYER:
				update_flyer_enemy(enemy, player.pos)
			case .EXPLODER:
				update_exploder_enemy(enemy, player)
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

				if rl.CheckCollisionRecs(player_rect, enemy_rect) && player.damage_timer <= 0 {
					// Player takes damage
					player.hp -= 20
					rl.PlaySound(sounds.damage_taken)
					player.damage_timer = PLAYER_DAMAGE_COOLDOWN

					// Check if player dies
					if player.hp <= 0 {
						player.hp = 0
						start_player_death_animation(player)
					}
					// Push enemy away slightly to prevent getting stuck
					push_direction := rl.Vector2 {
						enemy.pos.x - player.pos.x,
						enemy.pos.y - player.pos.y,
					}
					push_length := math.sqrt(
						push_direction.x * push_direction.x + push_direction.y * push_direction.y,
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

// --- Enemy AI Functions ---
update_melee_enemy :: proc(enemy: ^Enemy, player_pos: rl.Vector2) {
	// Move towards the player
	direction := rl.Vector2{player_pos.x - enemy.pos.x, player_pos.y - enemy.pos.y}

	length := math.sqrt(direction.x * direction.x + direction.y * direction.y)
	if length > 5.0 {
		enemy.vel.x = (direction.x / length) * ENEMY_SPEED
		enemy.vel.y = (direction.y / length) * ENEMY_SPEED
	} else {
		enemy.vel = {0, 0}
	}

	enemy.pos += enemy.vel * dt

	enemy.pos.y = clamp(enemy.pos.y, 0, f32(window_height - ENEMY_SIZE))
}

update_flyer_enemy :: proc(
	enemy: ^Enemy,
	player_pos: rl.Vector2,
) {
	// Flies, so no gravity
	// Stays at a distance and shoots
	distance_to_player := rl.Vector2{player_pos.x - enemy.pos.x, player_pos.y - enemy.pos.y}
	length := math.sqrt(
		distance_to_player.x * distance_to_player.x + distance_to_player.y * distance_to_player.y,
	)

	// Try to maintain a certain distance
	ideal_distance: f32 = 300
	if length > ideal_distance + 50 {
		// Move closer
		enemy.vel.x = (distance_to_player.x / length) * ENEMY_SPEED * 0.8
		enemy.vel.y = (distance_to_player.y / length) * ENEMY_SPEED * 0.8
	} else if length < ideal_distance - 50 {
		// Move away
		enemy.vel.x = -(distance_to_player.x / length) * ENEMY_SPEED * 0.8
		enemy.vel.y = -(distance_to_player.y / length) * ENEMY_SPEED * 0.8
	} else {
		// Stay put or circle
		enemy.vel = {0, 0}
	}

	enemy.pos += enemy.vel * dt

	// Shooting logic
	enemy.shoot_timer -= dt
	if enemy.shoot_timer <= 0 {
		enemy.shoot_timer = 2.0 // Reset timer

		// Shoot a bullet at the player
		direction := rl.Vector2{player_pos.x - enemy.pos.x, player_pos.y - enemy.pos.y}
		bullet_length := math.sqrt(direction.x * direction.x + direction.y * direction.y)
		if bullet_length > 0 {
			direction.x = (direction.x / bullet_length) * BULLET_SPEED
			direction.y = (direction.y / bullet_length) * BULLET_SPEED

			bullets[next_bullet_index] = Bullet {
				pos          = {enemy.pos.x + ENEMY_SIZE / 2, enemy.pos.y + ENEMY_SIZE / 2},
				vel          = direction,
				active       = true,
				enemy_bullet = true,
			}
			next_bullet_index = (next_bullet_index + 1) % MAX_BULLETS
		}
	}
}

update_exploder_enemy :: proc(enemy: ^Enemy, player: ^Player) {
	if enemy.is_exploding {
		// Countdown to explosion
		enemy.death_timer += dt
		if enemy.death_timer > 1.0 {
			// Explode
			player_dist := rl.Vector2Distance(enemy.pos, player.pos)
			if player_dist < enemy.explosion_radius && player.damage_timer <= 0 {
				player.hp -= 40 // High damage
				player.damage_timer = PLAYER_DAMAGE_COOLDOWN
				if player.hp <= 0 {
					start_player_death_animation(player)
				}
			}
			// "Kill" the enemy after explosion
			start_enemy_death_animation(enemy)
		}
		return
	}

	// Move towards the player
	direction := rl.Vector2{player.pos.x - enemy.pos.x, player.pos.y - enemy.pos.y}
	length := math.sqrt(direction.x * direction.x + direction.y * direction.y)

	// If close enough, start exploding
	if length < 80 {
		enemy.is_exploding = true
		enemy.vel = {0, 0}
	} else {
		// Move faster than normal melee
		enemy.vel.x = (direction.x / length) * ENEMY_SPEED * 2
		enemy.vel.y = (direction.y / length) * ENEMY_SPEED * 1.5
		enemy.pos += enemy.vel * dt
	}
}

// Spawn an enemy at the edge of the player's screen
spawn_enemy :: proc(
	enemies: ^[MAX_ENEMIES]Enemy,
	index: int,
	camera: rl.Camera2D,
	player_pos: rl.Vector2,
) {
	// Don't spawn if the slot is already occupied by an active enemy
	if enemies[index].active do return

	// Calculate the screen boundaries in world coordinates
	screen_left := camera.target.x - f32(window_width) / 2
	screen_right := camera.target.x + f32(window_width) / 2
	screen_top := camera.target.y - f32(window_height) / 2
	screen_bottom := camera.target.y - f32(window_height) / 2

	// Randomly choose a side to spawn from (0: left, 1: right, 2: top, 3: bottom)
	// Create an enemy with an initial target near the player
	target_pos := rl.Vector2 {
		player_pos.x + f32(rl.GetRandomValue(-150, 150)),
		player_pos.y + f32(rl.GetRandomValue(-100, 100)),
	}

	// Randomly select an enemy type for spawning
	enemy_type := EnemyType(rl.GetRandomValue(0, 2))
	spawn_side := rl.GetRandomValue(0, 1)
	spawn_pos: rl.Vector2

	switch enemy_type {
	case .MELEE, .EXPLODER:
		spawn_pos.y = f32(window_height)
		if spawn_side == 0 {
			spawn_pos.x = screen_left - ENEMY_SIZE
		} else {
			spawn_pos.x = screen_right
		}
	case .FLYER:
		spawn_pos.x = f32(rl.GetRandomValue(c.int(screen_left), c.int(screen_right)))
		spawn_pos.y = screen_top - ENEMY_SIZE
	}

	enemies[index] = Enemy {
		pos              = spawn_pos,
		vel              = {0, 0},
		hp               = ENEMY_MAX_HP,
		max_hp           = ENEMY_MAX_HP,
		active           = true,
		target_pos       = target_pos,
		enemy_type       = enemy_type,
		shoot_timer      = 2.0, // Initial shooting delay for the flyer
		is_exploding     = false,
		explosion_radius = 150,
	}
}
draw_enemy :: proc(enemy: Enemy) {
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
