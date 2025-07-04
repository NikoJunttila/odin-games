package game

import rl "vendor:raylib"

Player_animations :: struct {
	idle:          rl.Texture2D,
	run:           rl.Texture2D,
	frames_width:  i32,
	frames_height: i32,
	gun:           rl.Texture2D,
}
Sounds :: struct {
	shot:         rl.Sound,
	damage_taken: rl.Sound,
	game_over:    rl.Sound,
	heal:         rl.Sound,
	flash:        rl.Sound,
	level_up:     rl.Sound,
	explosion:    rl.Sound,
	score:        rl.Sound,
}

load_player_textures :: proc() -> Player_animations {
	idle := rl.LoadTexture("assets/cat_idle_sheet.png")
	run := rl.LoadTexture("assets/cat_run_sheet.png")
	gun := rl.LoadTexture("assets/gun.png")
	anims := Player_animations {
		idle          = idle,
		run           = run,
		gun           = gun,
		frames_height = 2,
		frames_width  = 3,
	}
	return anims
}

load_sounds :: proc() -> Sounds {
	shot_sound := rl.LoadSound("assets/shot.wav")
	game_over_sound := rl.LoadSound("assets/game-over.wav")
	damage_taken_sound := rl.LoadSound("assets/damage.wav")
	heal := rl.LoadSound("assets/heal.wav")
	level_up := rl.LoadSound("assets/level-up.wav")
	bomb := rl.LoadSound("assets/bomb_explosion.wav")
	score := rl.LoadSound("assets/score.wav")
	flash := rl.LoadSound("assets/flash.wav")
	sounds := Sounds {
		shot         = shot_sound,
		game_over    = game_over_sound,
		damage_taken = damage_taken_sound,
		heal         = heal,
		flash        = flash,
		level_up     = level_up,
		explosion    = bomb,
		score        = score,
	}
	return sounds
}

unload_assets :: proc(assets: ^Player_animations) {
	rl.UnloadTexture(assets.idle)
	rl.UnloadTexture(assets.run)
	rl.UnloadTexture(assets.gun)
	rl.UnloadSound(sounds.shot)
	rl.UnloadSound(sounds.damage_taken)
	rl.UnloadSound(sounds.game_over)
	rl.UnloadSound(sounds.explosion)
	rl.UnloadSound(sounds.heal)
	rl.UnloadSound(sounds.level_up)
	rl.UnloadSound(sounds.score)
	rl.UnloadSound(sounds.flash)
}
