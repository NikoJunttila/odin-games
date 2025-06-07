package game

import rl "vendor:raylib"

load_player_textures :: proc() -> [6]rl.Texture2D {
	player_textures: [6]rl.Texture2D
	player_textures[0] = rl.LoadTexture("assets/player1.png")
	player_textures[1] = rl.LoadTexture("assets/player2.png")
	player_textures[2] = rl.LoadTexture("assets/player3.png")
	player_textures[3] = rl.LoadTexture("assets/player4.png")
	player_textures[4] = rl.LoadTexture("assets/player5.png")
	player_textures[5] = rl.LoadTexture("assets/player6.png")
	return player_textures
}
