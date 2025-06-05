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
    target_pos: rl.Vector2,  // Where the enemy is moving towards
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(window_width, window_height, "game")
	
	player_pos := rl.Vector2{300, 300}
	player_vel: rl.Vector2
	player_grounded: bool
	player_hp := PLAYER_MAX_HP
	player_damage_timer: f32 = 0  // For damage cooldown
	
	// Camera for side-scrolling
	camera := rl.Camera2D{
		offset = {f32(window_width) / 2, f32(window_height) / 2},
		target = player_pos,
		rotation = 0,
		zoom = 1.0,
	}
	
	// Load background texture (you can create a simple repeating background)
	// For now, we'll create a procedural background with rectangles
	
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
		
		// Update player damage cooldown
		if player_damage_timer > 0 {
			player_damage_timer -= dt
		}
		
		// Horizontal movement
		is_moving = false
		if rl.IsKeyDown(.A) {
			player_vel.x = -MOVE_SPEED
			facing_right = false
			is_moving = true
		} else if rl.IsKeyDown(.D) {
			player_vel.x = MOVE_SPEED
			facing_right = true
			is_moving = true
		} else {
			player_vel.x = 0
		}
		
		// Jumping - only when grounded and space is pressed
		if rl.IsKeyPressed(.SPACE) && player_grounded {
			player_vel.y = JUMP_FORCE
			player_grounded = false
		}
		
		// Shooting - left mouse button
		if rl.IsMouseButtonPressed(.LEFT) {
			// Get mouse position in world coordinates
			mouse_screen_pos := rl.GetMousePosition()
			mouse_world_pos := rl.GetScreenToWorld2D(mouse_screen_pos, camera)
			
			// Calculate player center for shooting from
			player_center := rl.Vector2{
				player_pos.x + PLAYER_SIZE / 2,
				player_pos.y + PLAYER_SIZE / 2,
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
		if !player_grounded {
			player_vel.y += GRAVITY * dt
		}
		
		// Update position
		player_pos += player_vel * dt
		
		// Clamp horizontal position to world bounds (not screen bounds)
		player_pos.x = clamp(player_pos.x, 0, WORLD_WIDTH - PLAYER_SIZE)
		player_pos.y = clamp(player_pos.y, 0, f32(window_height - PLAYER_SIZE))
		
		// Check if player is on the ground
		if player_pos.y == f32(window_height - PLAYER_SIZE) {
			player_vel.y = 0
			player_grounded = true
		}
		
		// Update camera to follow player smoothly
		player_center := rl.Vector2{
			player_pos.x + PLAYER_SIZE / 2,
			player_pos.y + PLAYER_SIZE / 2,
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
		
		// Update animation only when moving
		if is_moving {
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
					if enemy.active {
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
							
							// Remove enemy if HP reaches 0
							if enemy.hp <= 0 {
								enemy.active = false
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
		enemy_spawn_timer += dt
		if enemy_spawn_timer >= ENEMY_SPAWN_RATE {
			enemy_spawn_timer = 0
			spawn_enemy(&enemies, next_enemy_index, camera, player_pos)
			next_enemy_index = (next_enemy_index + 1) % MAX_ENEMIES
		}
		
		// Update enemy movement and AI
		for &enemy in enemies {
			if enemy.active {
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
						player_pos.x + f32((rl.GetRandomValue(-200, 200))),
						player_pos.y + f32((rl.GetRandomValue(-100, 100))),
					}
				}
				
				enemy.pos += enemy.vel * dt
				
				// Keep enemies within world bounds
				enemy.pos.x = clamp(enemy.pos.x, 0, WORLD_WIDTH - ENEMY_SIZE)
				enemy.pos.y = clamp(enemy.pos.y, 0, f32(window_height) - ENEMY_SIZE)
				
				// Check collision with player
				player_rect := rl.Rectangle{
					x = player_pos.x,
					y = player_pos.y,
					width = PLAYER_SIZE,
					height = PLAYER_SIZE,
				}
				enemy_rect := rl.Rectangle{
					x = enemy.pos.x,
					y = enemy.pos.y,
					width = ENEMY_SIZE,
					height = ENEMY_SIZE,
				}
				
				if rl.CheckCollisionRecs(player_rect, enemy_rect) && player_damage_timer <= 0 {
					// Player takes damage
					player_hp -= 20
					player_damage_timer = PLAYER_DAMAGE_COOLDOWN
					
					// Push enemy away slightly to prevent getting stuck
					push_direction := rl.Vector2{
						enemy.pos.x - player_pos.x,
						enemy.pos.y - player_pos.y,
					}
					push_length := math.sqrt(push_direction.x * push_direction.x + push_direction.y * push_direction.y)
					if push_length > 0 {
						enemy.pos.x += (push_direction.x / push_length) * 20
						enemy.pos.y += (push_direction.y / push_length) * 20
					}
				}
			}
		}
		
		rl.BeginDrawing()
		rl.ClearBackground(rl.SKYBLUE)
		
		rl.BeginMode2D(camera)
		
		// Draw background elements
		draw_background(camera)
		
		// Draw player (with damage flash effect)
		rotation: f32 = 0
		player_color := rl.WHITE
		if player_damage_timer > 0 {
			// Flash red when damaged
			flash_intensity := (player_damage_timer / PLAYER_DAMAGE_COOLDOWN) * 0.5
			player_color = rl.Color{255, u8(255 * (1 - flash_intensity)), u8(255 * (1 - flash_intensity)), 255}
		}
		rl.DrawTextureEx(player_textures[current_frame], player_pos, rotation, PLAYER_ZOOM, player_color)
		
		// Draw bullets
		for bullet in bullets {
			if bullet.active {
				rl.DrawCircleV(bullet.pos, 5, rl.YELLOW)
			}
		}
		
		// Draw enemies
		for enemy in enemies {
			if enemy.active {
				// Draw enemy body
				rl.DrawRectangleV(enemy.pos, {ENEMY_SIZE, ENEMY_SIZE}, rl.RED)
				rl.DrawRectangleLinesEx({enemy.pos.x, enemy.pos.y, ENEMY_SIZE, ENEMY_SIZE}, 2, rl.Color{139, 0, 0, 255}) // Dark red
				
				// Draw HP bar
				draw_hp_bar(enemy.pos, enemy.hp, enemy.max_hp)
			}
		}
		
		// Draw world bounds visualization
		rl.DrawRectangleLines(0, 0, c.int(WORLD_WIDTH), window_height, rl.RED)
		
		rl.EndMode2D()
		
		// Draw player HP bar (UI element, not affected by camera)
		draw_player_hp_bar(player_hp, PLAYER_MAX_HP)
		
		// Draw UI elements (not affected by camera)
		rl.DrawText("Use A/D to move, SPACE to jump, Mouse to shoot", 10, 10, 20, rl.WHITE)
		rl.DrawText(rl.TextFormat("Player X: %.1f", player_pos.x), 10, 35, 20, rl.WHITE)
		rl.DrawText(rl.TextFormat("World Width: %.0f", WORLD_WIDTH), 10, 60, 20, rl.WHITE)
		
		// Count active enemies
		active_enemies := 0
		for enemy in enemies {
			if enemy.active do active_enemies += 1
		}
		rl.DrawText(rl.TextFormat("Enemies: %d", active_enemies), 10, 85, 20, rl.WHITE)
		rl.DrawText(rl.TextFormat("Player HP: %d/%d", player_hp, PLAYER_MAX_HP), 10, 110, 20, rl.WHITE)
		
		rl.EndDrawing()
	}
	
	// Cleanup textures
	for texture in player_textures {
		rl.UnloadTexture(texture)
	}
	
	rl.CloseWindow()
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
