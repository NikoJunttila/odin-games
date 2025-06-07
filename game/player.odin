package game

import rl "vendor:raylib"

player_exp_update :: proc(player: ^Player, exp_amount: int) {
	player.current_exp += exp_amount
	if player.current_exp >= player.exp_to_next_level {
		player.level += 1
		player.current_exp -= player.exp_to_next_level
		player.exp_to_next_level += 100
	}
}

skills_list_init :: proc() -> [2]Skill {
	flash := Skill {
		name     = SkillList.FLASH,
		key      = "F",
		color    = rl.YELLOW,
		cooldown = 5,
	}
	heal := Skill {
		name     = SkillList.HEAL,
		key      = "E",
		color    = rl.GREEN,
		cooldown = 30,
	}
	skill_list := [2]Skill{flash, heal}
	return skill_list
}
