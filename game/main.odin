package game
import "core:c"
import "core:math"
import rl "vendor:raylib"

window_width: c.int = 700
window_height: c.int = 700
PLAYER_ZOOM :: 2
PLAYER_SIZE :: 100 * PLAYER_ZOOM
GRAVITY :: 2000.0
JUMP_FORCE :: -500.0
MOVE_SPEED :: 300.0
ANIMATION_SPEED :: 0.15 // Time between frame changes
BULLET_SPEED :: 800.0
MAX_BULLETS :: 50

// World and camera constants
WORLD_WIDTH :: 3000.0  // Total world width (much larger than screen)
CAMERA_FOLLOW_SPEED :: 5.0

// Enemy constants
MAX_ENEMIES :: 20
ENEMY_SIZE :: 60
ENEMY_SPEED :: 100.0
ENEMY_MAX_HP :: 100
ENEMY_SPAWN_RATE :: 2.0  // seconds between spawns
HP_BAR_WIDTH :: 80
HP_BAR_HEIGHT :: 8

// Player constants
PLAYER_MAX_HP :: 100
PLAYER_DAMAGE_COOLDOWN :: 1.0  // seconds of invincibility after taking damage

// Death animation constants
DEATH_ANIMATION_DURATION :: 1.0  // seconds
EXPLOSION_PARTICLES :: 10
PARTICLE_LIFETIME :: 2.0

// Game state enum
GameState :: enum {
    PLAYING,
    GAME_OVER,
}

Particle :: struct {
    pos: rl.Vector2,
    vel: rl.Vector2,
    color: rl.Color,
    life: f32,
    max_life: f32,
    size: f32,
}

Bullet :: struct {
    pos: rl.Vector2,
    vel: rl.Vector2,
    active: bool,
}

Enemy :: struct {
    pos: rl.Vector2,
    vel: rl.Vector2,
    hp: int,
    max_hp: int,
    active: bool,
    target_pos: rl.Vector2,
    // Death animation
    dying: bool,
    death_timer: f32,
    death_particles: [EXPLOSION_PARTICLES]Particle,
}

Player :: struct {
    pos: rl.Vector2,
    vel: rl.Vector2,
    hp: int,
    grounded: bool,
    damage_timer: f32,
    // Death animation
    dying: bool,
    death_timer: f32,
    death_particles: [EXPLOSION_PARTICLES]Particle,
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(window_width, window_height, "game")
	
	// Initialize player
	player := Player{
		pos = {300, 300},
		hp = PLAYER_MAX_HP,
	}
	
	// Game state
	game_state := GameState.PLAYING
	
	// Camera for side-scrolling
	camera := rl.Camera2D{
		offset = {f32(window_width) / 2, f32(window_height) / 2},
		target = player.pos,
		rotation = 0,
		zoom = 1.0,
	}
	
	// Load all 6 player textures
	player_textures: [6]rl.Texture2D
	player_textures[0] = rl.LoadTexture("assets/player1.png")
	player_textures[1] = rl.LoadTexture("assets/player2.png")
	player_textures[2] = rl.LoadTexture("assets/player3.png")
	player_textures[3] = rl.LoadTexture("assets/player4.png")
	player_textures[4] = rl.LoadTexture("assets/player5.png")
	player_textures[5] = rl.LoadTexture("assets/player6.png")
	
	// Animation variables
	current_frame: int = 0
	animation_timer: f32 = 0
	facing_right: bool = true
	is_moving: bool = false
	
	// Bullet system
	bullets: [MAX_BULLETS]Bullet
	next_bullet_index: int = 0
	
	// Enemy system
	enemies: [MAX_ENEMIES]Enemy
	next_enemy_index: int = 0
	enemy_spawn_timer: f32 = 0
	
	for !rl.WindowShouldClose() {
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
					facing_right = false
					is_moving = true
				} else if rl.IsKeyDown(.D) {
					player.vel.x = MOVE_SPEED
					facing_right = true
					is_moving = true
				} else {
					player.vel.x = 0
				}
				
				// Jumping - only when grounded and space is pressed
				if rl.IsKeyPressed(.SPACE) && player.grounded {
					player.vel.y = JUMP_FORCE
					player.grounded = false
				}
				
				// Shooting - left mouse button
				if rl.IsMouseButtonPressed(.LEFT) {
					// Get mouse position in world coordinates
					mouse_screen_pos := rl.GetMousePosition()
					mouse_world_pos := rl.GetScreenToWorld2D(mouse_screen_pos, camera)
					
					// Calculate player center for shooting from
					player_center := rl.Vector2{
						player.pos.x + PLAYER_SIZE / 2,
						player.pos.y + PLAYER_SIZE / 2,
					}
					
					// Calculate direction vector from player to mouse
					direction := rl.Vector2{
						mouse_world_pos.x - player_center.x,
						mouse_world_pos.y - player_center.y,
					}
					
					// Normalize direction and apply bullet speed
					length := math.sqrt(direction.x * direction.x + direction.y * direction.y)
					if length > 0 {
						direction.x = (direction.x / length) * BULLET_SPEED
						direction.y = (direction.y / length) * BULLET_SPEED
						
						// Create new bullet
						bullets[next_bullet_index] = Bullet{
							pos = player_center,
							vel = direction,
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
						particle.vel.y += 200 * dt  // Gravity on particles
						particle.life -= dt
						particle.size = (particle.life / particle.max_life) * 20  // Shrink over time
					}
				}
				
				if player.death_timer >= DEATH_ANIMATION_DURATION {
					game_state = .GAME_OVER
				}
			}
			
			// Update camera to follow player smoothly (only if player is alive)
			if !player.dying {
				player_center := rl.Vector2{
					player.pos.x + PLAYER_SIZE / 2,
					player.pos.y + PLAYER_SIZE / 2,
				}
				
				// Smooth camera following
				diff := rl.Vector2{
					player_center.x - camera.target.x,
					player_center.y - camera.target.y,
				}
				camera.target.x += diff.x * CAMERA_FOLLOW_SPEED * dt
				camera.target.y += diff.y * CAMERA_FOLLOW_SPEED * dt
				
				// Constrain camera to world bounds
				camera.target.x = clamp(camera.target.x, f32(window_width) / 2, WORLD_WIDTH - f32(window_width) / 2)
			}
			
			// Update animation only when moving and alive
			if is_moving && !player.dying {
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
							enemy_rect := rl.Rectangle{
								x = enemy.pos.x,
								y = enemy.pos.y,
								width = ENEMY_SIZE,
								height = ENEMY_SIZE,
							}
							
							if rl.CheckCollisionPointRec(bullet.pos, enemy_rect) {
								// Hit enemy
								enemy.hp -= 25  // Damage per bullet
								bullet.active = false
								
								// Start death animation if HP reaches 0
								if enemy.hp <= 0 {
									start_enemy_death_animation(&enemy)
								}
								break
							}
						}
					}
					
					// Deactivate bullets that go off world bounds
					if bullet.pos.x < -10 || bullet.pos.x > WORLD_WIDTH + 10 ||
					   bullet.pos.y < -10 || bullet.pos.y > f32(window_height) + 10 {
						bullet.active = false
					}
				}
			}
			
			// Update enemies
			if !player.dying {  // Don't spawn enemies if player is dying
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
								particle.vel.y += 200 * dt  // Gravity on particles
								particle.life -= dt
								particle.size = (particle.life / particle.max_life) * 10  // Shrink over time
							}
						}
						
						// Remove enemy after death animation
						if enemy.death_timer >= DEATH_ANIMATION_DURATION {
							enemy.active = false
						}
					} else {
						// Normal enemy behavior
						// Move towards target position
						direction := rl.Vector2{
							enemy.target_pos.x - enemy.pos.x,
							enemy.target_pos.y - enemy.pos.y,
						}
						
						length := math.sqrt(direction.x * direction.x + direction.y * direction.y)
						if length > 5.0 {  // If not close to target
							enemy.vel.x = (direction.x / length) * ENEMY_SPEED
							enemy.vel.y = (direction.y / length) * ENEMY_SPEED
						} else {
							// Reached target, pick new random target near player
							enemy.target_pos = rl.Vector2{
								player.pos.x + f32((rl.GetRandomValue(-200, 200))),
								player.pos.y + f32((rl.GetRandomValue(-100, 100))),
							}
						}
						
						enemy.pos += enemy.vel * dt
						
						// Keep enemies within world bounds
						enemy.pos.x = clamp(enemy.pos.x, 0, WORLD_WIDTH - ENEMY_SIZE)
						enemy.pos.y = clamp(enemy.pos.y, 0, f32(window_height) - ENEMY_SIZE)
						
						// Check collision with player (only if player is not dying)
						if !player.dying {
							player_rect := rl.Rectangle{
								x = player.pos.x,
								y = player.pos.y,
								width = PLAYER_SIZE,
								height = PLAYER_SIZE,
							}
							enemy_rect := rl.Rectangle{
								x = enemy.pos.x,
								y = enemy.pos.y,
								width = ENEMY_SIZE,
								height = ENEMY_SIZE,
							}
							
							if rl.CheckCollisionRecs(player_rect, enemy_rect) && player.damage_timer <= 0 {
								// Player takes damage
								player.hp -= 20
								player.damage_timer = PLAYER_DAMAGE_COOLDOWN
								
								// Check if player dies
								if player.hp <= 0 {
									player.hp = 0
									start_player_death_animation(&player)
								}
								
								// Push enemy away slightly to prevent getting stuck
								push_direction := rl.Vector2{
									enemy.pos.x - player.pos.x,
									enemy.pos.y - player.pos.y,
								}
								push_length := math.sqrt(push_direction.x * push_direction.x + push_direction.y * push_direction.y)
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
				player = Player{
					pos = {300, 300},
					hp = PLAYER_MAX_HP,
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
			rotation: f32 = 0
			player_color := rl.WHITE
			if player.damage_timer > 0 {
				// Flash red when damaged
				flash_intensity := (player.damage_timer / PLAYER_DAMAGE_COOLDOWN) * 0.5
				player_color = rl.Color{255, u8(255 * (1 - flash_intensity)), u8(255 * (1 - flash_intensity)), 255}
			}
			rl.DrawTextureEx(player_textures[current_frame], player.pos, rotation, PLAYER_ZOOM, player_color)
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
				rl.DrawCircleV(bullet.pos, 5, rl.YELLOW)
			}
		}
		
		// Draw enemies
		for enemy in enemies {
			if enemy.active {
				if !enemy.dying {
					// Draw enemy body
					rl.DrawRectangleV(enemy.pos, {ENEMY_SIZE, ENEMY_SIZE}, rl.RED)
					rl.DrawRectangleLinesEx({enemy.pos.x, enemy.pos.y, ENEMY_SIZE, ENEMY_SIZE}, 2, rl.Color{139, 0, 0, 255}) // Dark red
					
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
		rl.DrawRectangleLines(0, 0, c.int(WORLD_WIDTH), window_height, rl.RED)
		
		rl.EndMode2D()
		
		// Draw UI based on game state
		switch game_state {
		case .PLAYING:
			// Draw player HP bar (UI element, not affected by camera)
			draw_player_hp_bar(player.hp, PLAYER_MAX_HP)
			
			// Draw UI elements (not affected by camera)
			rl.DrawText("Use A/D to move, SPACE to jump, Mouse to shoot", 10, 10, 20, rl.WHITE)
			rl.DrawText(rl.TextFormat("Player X: %.1f", player.pos.x), 10, 35, 20, rl.WHITE)
			rl.DrawText(rl.TextFormat("World Width: %.0f", WORLD_WIDTH), 10, 60, 20, rl.WHITE)
			
			// Count active enemies
			active_enemies := 0
			for enemy in enemies {
				if enemy.active && !enemy.dying do active_enemies += 1
			}
			rl.DrawText(rl.TextFormat("Enemies: %d", active_enemies), 10, 85, 20, rl.WHITE)
			rl.DrawText(rl.TextFormat("Player HP: %d/%d", player.hp, PLAYER_MAX_HP), 10, 110, 20, rl.WHITE)
			
		case .GAME_OVER:
			// Draw game over screen
			draw_game_over_screen()
		}
		
		rl.EndDrawing()
	}
	
	// Cleanup textures
	for texture in player_textures {
		rl.UnloadTexture(texture)
	}
	
	rl.CloseWindow()
}

// Start enemy death animation
start_enemy_death_animation :: proc(enemy: ^Enemy) {
	enemy.dying = true
	enemy.death_timer = 0
	
	// Create explosion particles
	for i in 0..<EXPLOSION_PARTICLES {
		angle := f32(i) * (2 * math.PI / EXPLOSION_PARTICLES)
		speed := f32(rl.GetRandomValue(50, 150))
		
		enemy.death_particles[i] = Particle{
			pos = {enemy.pos.x + ENEMY_SIZE/2, enemy.pos.y + ENEMY_SIZE/2},
			vel = {math.cos(angle) * speed, math.sin(angle) * speed},
			color = rl.Color{255, u8(rl.GetRandomValue(100, 255)), 0, 255},  // Orange/red colors
			life = PARTICLE_LIFETIME,
			max_life = PARTICLE_LIFETIME,
			size = f32(rl.GetRandomValue(5, 15)),
		}
	}
}

// Start player death animation
start_player_death_animation :: proc(player: ^Player) {
	player.dying = true
	player.death_timer = 0
	
	// Create explosion particles
	for i in 0..<EXPLOSION_PARTICLES {
		angle := f32(i) * (2 * math.PI / EXPLOSION_PARTICLES)
		speed := f32(rl.GetRandomValue(100, 200))
		
		player.death_particles[i] = Particle{
			pos = {player.pos.x + PLAYER_SIZE/2, player.pos.y + PLAYER_SIZE/2},
			vel = {math.cos(angle) * speed, math.sin(angle) * speed},
			color = rl.Color{u8(rl.GetRandomValue(200, 255)), u8(rl.GetRandomValue(200, 255)), 255, 255},  // Blue/white colors
			life = PARTICLE_LIFETIME,
			max_life = PARTICLE_LIFETIME,
			size = f32(rl.GetRandomValue(10, 25)),
		}
	}
}

// Draw game over screen
draw_game_over_screen :: proc() {
	// Semi-transparent overlay
	rl.DrawRectangle(0, 0, window_width, window_height, rl.Color{0, 0, 0, 150})
	
	// Game Over text
	game_over_text : cstring = "GAME OVER"
	text_width := rl.MeasureText(game_over_text, 60)
	rl.DrawText(game_over_text, (window_width - text_width) / 2, window_height / 2 - 100, 60, rl.RED)
	
	// Instructions
	restart_text : cstring = "Press R to Restart"
	restart_width := rl.MeasureText(restart_text, 30)
	rl.DrawText(restart_text, (window_width - restart_width) / 2, window_height / 2 - 20, 30, rl.WHITE)
	
	quit_text : cstring = "Press ESC to Quit"
	quit_width := rl.MeasureText(quit_text, 30)
	rl.DrawText(quit_text, (window_width - quit_width) / 2, window_height / 2 + 20, 30, rl.WHITE)
}

// Spawn an enemy at a random position around the camera view
spawn_enemy :: proc(enemies: ^[MAX_ENEMIES]Enemy, index: int, camera: rl.Camera2D, player_pos: rl.Vector2) {
	// Don't spawn if slot is already occupied
	if enemies[index].active do return
	
	// Random spawn position around the camera view
	spawn_side := rl.GetRandomValue(0, 3)  // 0=left, 1=right, 2=top, 3=bottom
	spawn_pos: rl.Vector2
	
	camera_left := camera.target.x - f32(window_width) / 2
	camera_right := camera.target.x + f32(window_width) / 2
	camera_top := camera.target.y - f32(window_height) / 2
	camera_bottom := camera.target.y + f32(window_height) / 2
	
	switch spawn_side {
	case 0: // Left side
		spawn_pos = {
			camera_left - ENEMY_SIZE - 50,
			f32(rl.GetRandomValue(c.int(camera_top), c.int(camera_bottom))),
		}
	case 1: // Right side
		spawn_pos = {
			camera_right + 50,
			f32(rl.GetRandomValue(c.int(camera_top), c.int(camera_bottom))),
		}
	case 2: // Top side
		spawn_pos = {
			f32(rl.GetRandomValue(c.int(camera_left), c.int(camera_right))),
			camera_top - ENEMY_SIZE - 50,
		}
	case 3: // Bottom side
		spawn_pos = {
			f32(rl.GetRandomValue(c.int(camera_left), c.int(camera_right))),
			camera_bottom + 50,
		}
	}
	
	// Ensure spawn position is within world bounds
	spawn_pos.x = clamp(spawn_pos.x, 0, WORLD_WIDTH - ENEMY_SIZE)
	spawn_pos.y = clamp(spawn_pos.y, 0, f32(window_height) - ENEMY_SIZE)
	
	// Create enemy with initial target near player
	target_pos := rl.Vector2{
		player_pos.x + f32(rl.GetRandomValue(-150, 150)),
		player_pos.y + f32(rl.GetRandomValue(-100, 100)),
	}
	
	enemies[index] = Enemy{
		pos = spawn_pos,
		vel = {0, 0},
		hp = ENEMY_MAX_HP,
		max_hp = ENEMY_MAX_HP,
		active = true,
		target_pos = target_pos,
	}
}

// Draw HP bar above enemy
draw_hp_bar :: proc(enemy_pos: rl.Vector2, current_hp: int, max_hp: int) {
	bar_pos := rl.Vector2{
		enemy_pos.x + (ENEMY_SIZE - HP_BAR_WIDTH) / 2,  // Center above enemy
		enemy_pos.y - HP_BAR_HEIGHT - 5,                // Above enemy
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
	rl.DrawText(rl.TextFormat("HP: %d/%d", current_hp, max_hp), c.int(bar_pos.x + 5), c.int(bar_pos.y + 2), 16, rl.WHITE)
}

// Draw a procedural background with parallax-like elements
draw_background :: proc(camera: rl.Camera2D) {
	// Draw ground
	rl.DrawRectangle(0, window_height - 50, c.int(WORLD_WIDTH), 50, rl.DARKGREEN)
	
	// Draw background mountains/hills (far background - slower parallax)
	mountain_offset := camera.target.x * 0.2  // Move slower than camera
	mountain_spacing: f32 = 400
	
	for i in 0..<int(WORLD_WIDTH / mountain_spacing) + 2 {
		x := f32(i) * mountain_spacing - mountain_offset
		if x > camera.target.x - f32(window_width) && x < camera.target.x + f32(window_width) {
			// Draw simple mountain shape
			points := [3]rl.Vector2{
				{x, f32(window_height - 50)},
				{x + 150, f32(window_height - 200)},
				{x + 300, f32(window_height - 50)},
			}
			rl.DrawTriangle(points[0], points[1], points[2], rl.DARKGRAY)
		}
	}
	
	// Draw middle-ground trees
	tree_offset := camera.target.x * 0.5  // Medium parallax speed
	tree_spacing: f32 = 200
	
	for i in 0..<int(WORLD_WIDTH / tree_spacing) + 2 {
		x := f32(i) * tree_spacing - tree_offset
		if x > camera.target.x - f32(window_width) && x < camera.target.x + f32(window_width) {
			// Draw simple tree
			rl.DrawRectangle(c.int(x + 15), window_height - 100, 20, 50, rl.BROWN)  // Trunk
			rl.DrawCircle(c.int(x + 25), window_height - 120, 30, rl.GREEN)         // Leaves
		}
	}
	
	// Draw foreground grass patches (moves with world)
	grass_spacing: f32 = 100
	for i in 0..<int(WORLD_WIDTH / grass_spacing) {
		x := f32(i) * grass_spacing
		if x > camera.target.x - f32(window_width) && x < camera.target.x + f32(window_width) {
			// Draw grass patches
			for j in 0..<5 {
				grass_x := x + f32(j * 20)
				rl.DrawRectangle(c.int(grass_x), window_height - 55, 3, 10, rl.LIME)
			}
		}
	}
	
	// Draw clouds (very slow parallax for far background)
	cloud_offset := camera.target.x * 0.1
	cloud_spacing: f32 = 500
	
	for i in 0..<int(WORLD_WIDTH / cloud_spacing) + 2 {
		x := f32(i) * cloud_spacing - cloud_offset
		if x > camera.target.x - f32(window_width) && x < camera.target.x + f32(window_width) {
			// Draw simple cloud
			y: f32 = 100 + f32(i % 3) * 30  // Vary cloud heights
			rl.DrawCircle(c.int(x), c.int(y), 25, rl.WHITE)
			rl.DrawCircle(c.int(x + 30), c.int(y), 35, rl.WHITE)
			rl.DrawCircle(c.int(x + 60), c.int(y), 25, rl.WHITE)
		}
	}
}

