package breakout
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"
print :: fmt.println

SCREEN_SIZE :: 250
PADDLE_WIDTH :: 50
PADDLE_HEIGHT :: 6
PADDLE_POS_Y :: 230
PADDLE_SPEED :: 250
WINDOW :: 1000
BALL_SPEED :: 260
BALL_RADIUS :: 4
BALL_START_Y :: 160
NUM_BLOCK_X :: 10
NUM_BLOCKS_Y :: 8
BLOCK_WIDTH :: 21
BLOCK_HEIGHT :: 8

block_color :: enum {
	Yellow,
	Green,
	Orange,
	Red,
}

row_colors := [NUM_BLOCKS_Y]block_color {
	.Red,
	.Red,
	.Orange,
	.Orange,
	.Green,
	.Green,
	.Yellow,
	.Yellow,
}

block_color_values := [block_color]rl.Color {
	.Yellow = {253, 249, 150, 255},
	.Green  = {180, 245, 190, 255},
	.Orange = {170, 120, 250, 255},
	.Red    = {250, 90, 85, 255},
}

block_color_score := [block_color]int {
	.Yellow = 2,
	.Green  = 4,
	.Orange = 6,
	.Red    = 8,
}

blocks: [NUM_BLOCK_X][NUM_BLOCKS_Y]bool

//53min

paddle_pos_x: f32
paddle_pos_y: f32
ball_pos: rl.Vector2
ball_dir: rl.Vector2
started: bool
score: int = 0
game_over: bool
accumulated_time: f32
previous_ball_pos : rl.Vector2
previous_paddle_pos_x : f32

reflect :: proc(dir, normal: rl.Vector2) -> rl.Vector2 {
	new_direction := linalg.normalize(linalg.reflect(dir, linalg.normalize(normal)))
	return new_direction
}

calc_block_rect :: proc(x, y: int) -> rl.Rectangle {
	return rl.Rectangle {
		f32(20 + x * BLOCK_WIDTH),
		f32(40 + y * BLOCK_HEIGHT),
		BLOCK_WIDTH,
		BLOCK_HEIGHT,
	}
}


restart :: proc() {
	paddle_pos_x = (SCREEN_SIZE / 2) - (PADDLE_WIDTH / 2)
	ball_pos = {SCREEN_SIZE / 2, BALL_START_Y}
	started = false
	game_over = false
    previous_ball_pos = ball_pos
    previous_paddle_pos_x = paddle_pos_x
	score = 0
	for x in 0 ..< NUM_BLOCK_X {
		for y in 0 ..< NUM_BLOCKS_Y {
			blocks[x][y] = true
		}
	}
}

block_exists :: proc(x, y: int) -> bool {
	if x < 0 || y < 0 || x >= NUM_BLOCK_X || y >= NUM_BLOCKS_Y {
		return false
	}
	return blocks[x][y]
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT}) //sets max fps to screen refresh rate
	rl.InitWindow(WINDOW, WINDOW, "Breakout")
	rl.InitAudioDevice()
	rl.SetTargetFPS(300) // if v sync force disabled sets hard limit to fps
	ball_texture := rl.LoadTexture("breakout_assets/ball.png")
	paddle_texture := rl.LoadTexture("breakout_assets/paddle.png")
	hit_block_sound := rl.LoadSound("breakout_assets/hit_block.wav")
	hit_paddle_sound := rl.LoadSound("breakout_assets/hit_paddle.wav")
	game_over_sound := rl.LoadSound("breakout_assets/game_over.wav")


	restart()
	for !rl.WindowShouldClose() {
		DT :: 1.0 / 60.0 // 16ms, 0.016 s
		dt: f32
		if !started {
			ball_pos = {
				SCREEN_SIZE / 2 + f32(math.cos(rl.GetTime()) * SCREEN_SIZE / 2.5),
				BALL_START_Y,
			}
            previous_ball_pos = ball_pos
			if rl.IsKeyPressed(.SPACE) {
				paddle_middle := rl.Vector2{paddle_pos_x + PADDLE_WIDTH / 2, PADDLE_POS_Y}
				ball_to_paddle := paddle_middle - ball_pos
				ball_dir = linalg.normalize0(ball_to_paddle)
				started = true
			}
		} else if game_over {
			dt = rl.GetFrameTime()
			if rl.IsKeyPressed(.SPACE) {
				restart()
			}
		} else {
			accumulated_time += rl.GetFrameTime()
		}
        // accumulated_time = 0.031 s
		for accumulated_time >= DT {
			previous_ball_pos = ball_pos
			previous_paddle_pos_x = paddle_pos_x
			ball_pos += ball_dir * BALL_SPEED * DT

			if ball_pos.x + BALL_RADIUS > SCREEN_SIZE {
				ball_pos.x = SCREEN_SIZE - BALL_RADIUS
				ball_dir = reflect(ball_dir, {-1, 0})
			}

			if ball_pos.x - BALL_RADIUS < 0 {
				ball_pos.x = BALL_RADIUS
				ball_dir = reflect(ball_dir, {1, 0})
			}
			if ball_pos.y - BALL_RADIUS < 0 {
				ball_pos.y = BALL_RADIUS
				ball_dir = reflect(ball_dir, {0, 1})
			}

			if !game_over && ball_pos.y > SCREEN_SIZE + BALL_RADIUS * 5 {
				game_over = true
				rl.PlaySound(game_over_sound)
			}

			paddle_move_velocity: f32

			if rl.IsKeyDown(.LEFT) {
				paddle_move_velocity -= PADDLE_SPEED
			}
			if rl.IsKeyDown(.RIGHT) {
				paddle_move_velocity += PADDLE_SPEED
			}

			paddle_pos_x += paddle_move_velocity * DT
			paddle_pos_x = clamp(paddle_pos_x, 0, SCREEN_SIZE - PADDLE_WIDTH)
			paddle_rect: rl.Rectangle = {paddle_pos_x, PADDLE_POS_Y, PADDLE_WIDTH, PADDLE_HEIGHT}

			if rl.CheckCollisionCircleRec(ball_pos, BALL_RADIUS, paddle_rect) {
				collision_normal: rl.Vector2

				if previous_ball_pos.y < paddle_rect.y + paddle_rect.height {
					collision_normal += {0, -1}
					ball_pos.y = paddle_rect.y - BALL_RADIUS
				}
				if previous_ball_pos.y > paddle_rect.y + paddle_rect.height {
					collision_normal += {0, 1}
					ball_pos.y = paddle_rect.y + paddle_rect.height + BALL_RADIUS
				}
				if previous_ball_pos.x < paddle_rect.x {
					collision_normal += {-1, 0}
				}
				if previous_ball_pos.x > paddle_rect.x + paddle_rect.width {
					collision_normal += {1, 0}
				}
				if collision_normal != 0 {
					ball_dir = reflect(ball_dir, collision_normal)
				}
				rl.PlaySound(hit_paddle_sound)
			}

			block_x_loop: for x in 0 ..< NUM_BLOCK_X {
				for y in 0 ..< NUM_BLOCKS_Y {
					if blocks[x][y] == false {
						continue
					}
					block_rect := calc_block_rect(x, y)

					if rl.CheckCollisionCircleRec(ball_pos, BALL_RADIUS, block_rect) {
						collision_normal: rl.Vector2
						if previous_ball_pos.y < block_rect.y {
							collision_normal += {0, -1}
						}
						if previous_ball_pos.y > block_rect.y + block_rect.height {
							collision_normal += {0, 1}
						}
						if previous_ball_pos.x < block_rect.x {
							collision_normal += {-1, 0}
						}
						if previous_ball_pos.x > block_rect.x + block_rect.width {
							collision_normal += {1, 0}
						}

						if block_exists(x + int(collision_normal.x), y) {
							collision_normal.x = 0
						}
						if block_exists(x, y + int(collision_normal.y)) {
							collision_normal.y = 0
						}
						if collision_normal != 0 {
							ball_dir = reflect(ball_dir, collision_normal)
						}
						blocks[x][y] = false
						row_color := row_colors[y]
						score += block_color_score[row_color]
						rl.SetSoundPitch(hit_block_sound, rand.float32_range(0.8, 1.2))
						rl.PlaySound(hit_block_sound)
						break block_x_loop
					}
				}
			}
			accumulated_time -= DT
        }
        blend := accumulated_time / DT
        ball_render_pos := math.lerp(previous_ball_pos, ball_pos, blend)
        paddle_render_pos := math.lerp(previous_paddle_pos_x, paddle_pos_x, blend)

		rl.BeginDrawing()
		rl.ClearBackground({150, 190, 220, 255})
		camera := rl.Camera2D {
			zoom = f32(rl.GetScreenHeight() / SCREEN_SIZE),
			// zoom = 2
		}
		rl.BeginMode2D(camera)
		// rl.DrawRectangleRec(paddle_rect, rl.GREEN)
		rl.DrawTextureV(paddle_texture, {paddle_render_pos, PADDLE_POS_Y}, rl.WHITE)
		rl.DrawTextureV(ball_texture, ball_render_pos - {BALL_RADIUS, BALL_RADIUS}, rl.WHITE)
		// rl.DrawCircleV(ball_pos, BALL_RADIUS, rl.RED)
		for x in 0 ..< NUM_BLOCK_X {
			for y in 0 ..< NUM_BLOCKS_Y {
				if blocks[x][y] == false {
					continue
				}
				block_rect := rl.Rectangle {
					f32(20 + x * BLOCK_WIDTH),
					f32(40 + y * BLOCK_HEIGHT),
					BLOCK_WIDTH,
					BLOCK_HEIGHT,
				}

				top_left := rl.Vector2{block_rect.x, block_rect.y}
				top_right := rl.Vector2{block_rect.x + block_rect.width, block_rect.y}
				bottom_left := rl.Vector2{block_rect.x, block_rect.y + block_rect.height}
				bottom_right := rl.Vector2 {
					block_rect.x + block_rect.width,
					block_rect.y + block_rect.height,
				}

				rl.DrawRectangleRec(block_rect, block_color_values[row_colors[y]])
				rl.DrawLineEx(top_left, top_right, 1, {255, 255, 150, 100})
				rl.DrawLineEx(top_left, bottom_left, 1, {255, 255, 150, 100})
				rl.DrawLineEx(top_right, bottom_right, 1, {0, 0, 50, 100})
				rl.DrawLineEx(bottom_left, bottom_right, 1, {0, 0, 50, 100})
			}
		}

		score_text := fmt.ctprint(score)
		rl.DrawText(score_text, 5, 5, 10, rl.WHITE)
		if !started {
			start_text := fmt.ctprint("Start game SPACE")
			start_text_width := rl.MeasureText(start_text, 15)
			rl.DrawText(
				start_text,
				SCREEN_SIZE / 2 - start_text_width / 2,
				BALL_START_Y - 30,
				15,
				rl.WHITE,
			)
		}
		if game_over {
			game_over_text := fmt.ctprintf("Score: %v. Reset: SPACE", score)
			game_over_text_width := rl.MeasureText(game_over_text, 15)
			rl.DrawText(
				game_over_text,
				SCREEN_SIZE / 2 - game_over_text_width / 2,
				BALL_START_Y - 30,
				15,
				rl.WHITE,
			)
		}
		rl.EndMode2D()
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}

	rl.CloseAudioDevice()
	rl.CloseWindow()
}
