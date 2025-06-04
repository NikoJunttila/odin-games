package packman
import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"
WINDOW_WIDTH :: 500
WINDOW_HEIGHT :: 500
NIBBAS_COUNT :: 3
TICK_RATE :: 0.1
vec2 :: [2]f32
Vec2i :: [2]int
CELLS_Y :: 10
CELLS_X :: 13
// Compute cell size dynamically to fit the screen
get_cell_size :: proc() -> vec2 {
	return vec2{f32(rl.GetScreenWidth()) / f32(CELLS_X), f32(rl.GetScreenHeight()) / f32(CELLS_Y)}
}
tick_timer: f32 = TICK_RATE
move_direction: Vec2i
max_score: int
all_cells: [CELLS_X][CELLS_Y]bool
create_cells :: proc() {
	for x in 0 ..< CELLS_X {
		for y in 0 ..< CELLS_Y {
			all_cells[x][y] = false
		}
	}
}
count_score :: proc() -> int {
	temp_score := 0
	for x in 0 ..< CELLS_X {
		for y in 0 ..< CELLS_Y {
			if all_cells[x][y] {
				temp_score += 1
			}
		}
	}
	return temp_score
}
all_walls: [CELLS_X][CELLS_Y]bool
wall_amount: int

// Audio variables
move_sound: rl.Sound
eat_sound: rl.Sound
win_sound: rl.Sound
wall_hit_sound: rl.Sound
nibba_beat_u_sound: rl.Sound

// Generate a simple tone wave
generate_tone :: proc(frequency: f32, duration: f32, sample_rate: u32 = 44100) -> rl.Wave {
	frame_count := u32(f32(sample_rate) * duration)
	wave := rl.Wave {
		frameCount = frame_count,
		sampleRate = sample_rate,
		sampleSize = 16, // 16-bit
		channels   = 1, // Mono
	}

	// Allocate memory for samples
	wave.data = rl.MemAlloc(u32(frame_count * 2)) // 2 bytes per 16-bit sample
	samples := cast([^]i16)wave.data

	for i in 0 ..< frame_count {
		// Generate sine wave
		t := f32(i) / f32(sample_rate)
		sample_value := math.sin(2.0 * math.PI * frequency * t)

		// Apply fade out to prevent clicks
		fade_samples := u32(f32(sample_rate) * 0.05) // 50ms fade
		if i > frame_count - fade_samples {
			fade := f32(frame_count - i) / f32(fade_samples)
			sample_value *= fade
		}

		// Convert to 16-bit integer
		samples[i] = i16(sample_value * 32767.0)
	}

	return wave
}

// Generate a noise burst (for hit effects)
generate_noise :: proc(duration: f32, sample_rate: u32 = 44100) -> rl.Wave {
	frame_count := u32(f32(sample_rate) * duration)
	wave := rl.Wave {
		frameCount = frame_count,
		sampleRate = sample_rate,
		sampleSize = 16,
		channels   = 1,
	}

	wave.data = rl.MemAlloc(u32(frame_count * 2))
	samples := cast([^]i16)wave.data

	for i in 0 ..< frame_count {
		// Generate random noise
		noise := f32(rand.int_max(65535) - 32767) / 32767.0

		// Apply envelope (quick attack, slow decay)
		envelope := math.exp(-f32(i) / f32(sample_rate) * 8.0)
		sample_value := noise * envelope * 0.1 // Reduce volume

		samples[i] = i16(sample_value * 32767.0)
	}

	return wave
}

// Initialize all sounds
init_audio :: proc() {
	rl.InitAudioDevice()

	// Create different tones for different actions
	move_wave := generate_tone(220.0, 0.1) // Low A note, short
	eat_wave := generate_tone(440.0, 0.2) // A note, medium
	win_wave := generate_tone(880.0, 0.5) // High A note, long
	wall_hit_wave := generate_noise(0.1) // Short noise burst

	// Convert waves to sounds
	move_sound = rl.LoadSoundFromWave(move_wave)
	eat_sound = rl.LoadSoundFromWave(eat_wave)
	win_sound = rl.LoadSoundFromWave(win_wave)
	wall_hit_sound = rl.LoadSoundFromWave(wall_hit_wave)
	nibba_beat_u_sound = rl.LoadSound("crash.wav")

	rl.SetSoundVolume(eat_sound, 0.1)
	rl.SetSoundVolume(win_sound, 0.2)
	rl.SetSoundVolume(nibba_beat_u_sound, 0.2)

	// Clean up wave data (sounds now own the data)
	rl.UnloadWave(move_wave)
	rl.UnloadWave(eat_wave)
	rl.UnloadWave(win_wave)
	rl.UnloadWave(wall_hit_wave)
}

// Clean up audio resources
cleanup_audio :: proc() {
	rl.UnloadSound(move_sound)
	rl.UnloadSound(eat_sound)
	rl.UnloadSound(win_sound)
	rl.UnloadSound(wall_hit_sound)
	rl.UnloadSound(nibba_beat_u_sound)
	rl.CloseAudioDevice()
}

// Check if all non-wall cells are reachable from starting position
is_maze_connected :: proc(start_pos: Vec2i) -> bool {
	visited: [CELLS_X][CELLS_Y]bool
	queue: [dynamic]Vec2i
	defer delete(queue)

	// Start flood fill from starting position
	append(&queue, start_pos)
	visited[start_pos.x][start_pos.y] = true
	visited_count := 1

	directions := []Vec2i{{0, 1}, {0, -1}, {1, 0}, {-1, 0}}

	for len(queue) > 0 {
		current := queue[0]
		ordered_remove(&queue, 0)

		// Check all 4 directions
		for dir in directions {
			new_pos := current + dir

			// Check bounds
			if new_pos.x < 0 || new_pos.x >= CELLS_X || new_pos.y < 0 || new_pos.y >= CELLS_Y {
				continue
			}

			// Skip if already visited, is a wall, or out of bounds
			if visited[new_pos.x][new_pos.y] || all_walls[new_pos.x][new_pos.y] {
				continue
			}

			visited[new_pos.x][new_pos.y] = true
			visited_count += 1
			append(&queue, new_pos)
		}
	}

	// Count total non-wall cells
	total_accessible := CELLS_X * CELLS_Y - wall_amount

	return visited_count == total_accessible
}

create_walls :: proc() {
	max_attempts := 100

	for attempt in 0 ..< max_attempts {
		// Reset walls
		for x in 0 ..< CELLS_X {
			for y in 0 ..< CELLS_Y {
				all_walls[x][y] = false
			}
		}
		wall_amount = 0

		// Generate random walls
		for x in 0 ..< CELLS_X {
			for y in 0 ..< CELLS_Y {
				rd := rand.int_max(5)
				if rd == 2 {
					wall_amount += 1
					all_walls[x][y] = true
				}
			}
		}

		// Make sure starting position isn't a wall
		start_pos := pac_cell
		if all_walls[start_pos.x][start_pos.y] {
			all_walls[start_pos.x][start_pos.y] = false
			wall_amount -= 1
		}

		// Check if maze is connected
		if is_maze_connected(start_pos) {
			fmt.println("Generated connected maze on attempt", attempt + 1)
			return
		}
	}

	// Fallback: create a simple maze with minimal walls
	fmt.println("Using fallback maze generation")
	for x in 0 ..< CELLS_X {
		for y in 0 ..< CELLS_Y {
			all_walls[x][y] = false
		}
	}
	wall_amount = 0

	// Add a few strategic walls that don't block connectivity
	if CELLS_X > 4 && CELLS_Y > 4 {
		all_walls[CELLS_X / 2][CELLS_Y / 2] = true
		all_walls[CELLS_X / 2 + 1][CELLS_Y / 2] = true
		wall_amount = 2
	}
}
nibba_cells: [NIBBAS_COUNT]Vec2i

start :: proc() {
	create_cells()
	create_walls()
	max_score = CELLS_Y * CELLS_X - wall_amount
	game_started = true
	game_won = false
	tick_count = 0
	last_frame_sound = 0
	beaten_by_nibba = false
	for &nibba in nibba_cells {
		nibba.x = rand.int_max(CELLS_X - 1) + 1
		nibba.y = rand.int_max(CELLS_Y - 1) + 1
	}
}
game_started: bool
game_won: bool
beaten_by_nibba: bool
pac_cell: Vec2i
tick_count: u64
last_frame_sound: u64
main :: proc() {
	init_audio()
	defer cleanup_audio()

	start()
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "packman")
	rl.SetWindowMinSize(300, 300) // Minimum window size
	rl.SetTargetFPS(150)
	prev_cell := pac_cell
	for !rl.WindowShouldClose() {
		if game_started && !game_won && !beaten_by_nibba {
			tick_timer -= rl.GetFrameTime()
		} else if game_won || beaten_by_nibba {
			if rl.IsKeyDown(.SPACE) {
				start()
			}
		} else {
			if rl.IsKeyDown(.SPACE) {
				game_started = true
			}
		}
		if tick_timer <= 0 {
			if rl.IsKeyDown(.UP) {
				move_direction = {0, -1}
			}
			if rl.IsKeyDown(.DOWN) {
				move_direction = {0, 1}
			}
			if rl.IsKeyDown(.LEFT) {
				move_direction = {-1, 0}
			}
			if rl.IsKeyDown(.RIGHT) {
				move_direction = {1, 0}
			}
			pac_cell += move_direction
			pac_cell.x = clamp(pac_cell.x, 0, CELLS_X - 1)
			pac_cell.y = clamp(pac_cell.y, 0, CELLS_Y - 1)

			// Check for wall collision
			if all_walls[pac_cell.x][pac_cell.y] {
				pac_cell = prev_cell
				// rl.PlaySound(wall_hit_sound) // Play hit sound
			} else {
				// Check if this is a new cell (eating)
				if !all_cells[pac_cell.x][pac_cell.y] {
					if 2 < (tick_count - last_frame_sound) {
						rl.PlaySound(eat_sound) // Play eating sound
						last_frame_sound = tick_count
					}
				} else {
					// rl.PlaySound(move_sound) // Play movement sound
				}
			}
			for &nibba in nibba_cells {
				if tick_count % 3 == 0 {
					random := rand.int_max(4)
					//up-right-down-left
					switch random {
					case 0:
						nibba += {0, -1}
					case 1:
						nibba += {1, 0}
					case 2:
						nibba += {0, 1}
					case 3:
						nibba += {-1, 0}
					}
				}

				nibba.x = clamp(nibba.x, 0, CELLS_X - 1)
				nibba.y = clamp(nibba.y, 0, CELLS_Y - 1)
				if nibba == pac_cell {
					beaten_by_nibba = true
					rl.PlaySound(nibba_beat_u_sound)
				}
			}


			all_cells[pac_cell.x][pac_cell.y] = true
			prev_cell = pac_cell
			tick_timer += TICK_RATE
			tick_count += 1
		}
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		camera := rl.Camera2D {
			zoom   = 1.0,
			offset = vec2{0, 0}, // No need to offset, fits the screen
			target = vec2{0, 0}, // Top-left of the grid
		}
		rl.BeginMode2D(camera)
		for x in 0 ..< CELLS_X {
			for y in 0 ..< CELLS_Y {

				cell_size := get_cell_size() // Get current cell size based on window
				pos := vec2{cell_size[0] * f32(x), cell_size[1] * f32(y)}
				size := cell_size
				color: rl.Color
				if all_walls[x][y] {
					color = rl.DARKGRAY
				} else if all_cells[x][y] {
					color = rl.RED
				} else {
					color = rl.BLUE
				}
				rl.DrawRectangleV(pos, size, color)
				if pac_cell == {x, y} {
					rl.DrawRectangleV(pos, size, rl.YELLOW)
				}
				for nibba in nibba_cells {
					if nibba == {x, y} {
						rl.DrawRectangleV(pos, size, rl.BLACK)
					}
				}
			}
		}
		score := count_score()
		if !game_started {
			window_width := rl.GetScreenWidth()
			window_height := rl.GetScreenHeight()
			text_width := rl.MeasureText("Start game with space", 50)
			rl.DrawText(
				"Start game with space",
				window_width / 2 - text_width / 2,
				window_height / 2,
				50,
				rl.WHITE,
			)
		}
		if beaten_by_nibba {
			rl.DrawText(
				"Nibba beat you \n Try again with space",
				rl.GetScreenWidth() / 2 - 150,
				rl.GetScreenHeight() / 2,
				25,
				rl.WHITE,
			)
		}
		if score == max_score {
			if !game_won { 	// Only play sound once when winning
				rl.PlaySound(win_sound)
			}
			window_width := rl.GetScreenWidth()
			window_height := rl.GetScreenHeight()
			win_text : cstring = "Game won!! \n All tiles colored."
			restart_text : cstring = "start again with space"

			win_text_width := rl.MeasureText("Game won!!", 25)
			restart_text_width := rl.MeasureText(restart_text, 25)

			rl.DrawText(
				win_text,
				window_width / 2 - win_text_width / 2,
				window_height / 2,
				25,
				rl.WHITE,
			)
			game_won = true
			rl.DrawText(
				restart_text,
				window_width / 2 - restart_text_width / 2,
				window_height - 50,
				25,
				rl.WHITE,
			)
		} else {
			score_str := fmt.ctprintf("Score: %v", score)
			max_score_str := fmt.ctprintf("Max score: %v", max_score)
			window_height := rl.GetScreenHeight()
			rl.DrawText(score_str, 4, window_height - 25, 20, rl.WHITE)
			rl.DrawText(max_score_str, 4, window_height - 50, 20, rl.PURPLE)
		}
		rl.EndMode2D()
		rl.EndDrawing()
		free_all(context.temp_allocator)}
	rl.CloseWindow()
}
