package game
import "core:c"
import rl "vendor:raylib"

window_width: c.int = 700
window_height: c.int = 700
PLAYER_ZOOM :: 2
PLAYER_SIZE :: 100 * PLAYER_ZOOM
GRAVITY :: 2000.0
JUMP_FORCE :: -500.0
MOVE_SPEED :: 300.0
ANIMATION_SPEED :: 0.15 // Time between frame changes

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(window_width, window_height, "game")

	player_pos := rl.Vector2{300, 300}
	player_vel: rl.Vector2
	player_grounded: bool

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

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		rl.BeginDrawing()

		// Horizontal movement
		is_moving = false
		if rl.IsKeyDown(.LEFT) {
			player_vel.x = -MOVE_SPEED
			facing_right = false
			is_moving = true
		} else if rl.IsKeyDown(.RIGHT) {
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

		// Apply gravity when not grounded
		if !player_grounded {
			player_vel.y += GRAVITY * dt
		}

		// Update position
		player_pos += player_vel * dt

		// Clamp horizontal position
		player_pos.x = clamp(player_pos.x, 0, f32(rl.GetScreenWidth() - PLAYER_SIZE))
		player_pos.y = clamp(player_pos.y, 0, f32(rl.GetScreenHeight() - PLAYER_SIZE))

		// Check if player is on the ground
		if player_pos.y == f32(rl.GetScreenHeight() - PLAYER_SIZE) {
			player_vel.y = 0
			player_grounded = true
		}

		// Update animation
		animation_timer += dt
		if animation_timer >= ANIMATION_SPEED {
			animation_timer = 0
			current_frame = (current_frame + 1) % 6
		}

		rl.ClearBackground(rl.BLUE)

		// Draw player with rotation based on direction
		rotation: f32 = 0
		scale: f32 = PLAYER_ZOOM

		// Flip horizontally if facing left by using negative scale
		if !facing_right {
			scale = -PLAYER_ZOOM
		}

		rl.DrawTextureEx(player_textures[current_frame], player_pos, rotation, scale, rl.WHITE)
		rl.EndDrawing()
	}

	// Cleanup textures
	for texture in player_textures {
		rl.UnloadTexture(texture)
	}

	rl.CloseWindow()
}
