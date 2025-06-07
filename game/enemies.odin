package game

import "core:c"
import "core:math"
import rl "vendor:raylib"

// --- Enemy AI Functions ---
update_melee_enemy :: proc(enemy: ^Enemy, player_pos: rl.Vector2, dt: f32) {
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
	bullets: ^[MAX_BULLETS]Bullet,
	next_bullet_index: ^int,
	dt: f32,
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

			bullets[next_bullet_index^] = Bullet {
				pos          = {enemy.pos.x + ENEMY_SIZE / 2, enemy.pos.y + ENEMY_SIZE / 2},
				vel          = direction,
				active       = true,
				enemy_bullet = true,
			}
			next_bullet_index^ = (next_bullet_index^ + 1) % MAX_BULLETS
		}
	}
}

update_exploder_enemy :: proc(enemy: ^Enemy, player: ^Player, dt: f32) {
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
  spawn_pos : rl.Vector2

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
