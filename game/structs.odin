package game

import rl "vendor:raylib"

// Game state enum
GameState :: enum {
    PLAYING,
    GAME_OVER,
    PAUSED
}

// Enemy Type enum
EnemyType :: enum {
    MELEE,
    FLYER,
    EXPLODER,
}
SkillList :: enum {
  FLASH,
  HEAL,
}

Skill :: struct {
  name : SkillList,
  key : cstring,
  color : rl.Color,
  cooldown : f32,
  cd_left : f32,
  on_cd : bool
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
    enemy_bullet : bool,
}

Enemy :: struct {
    pos: rl.Vector2,
    vel: rl.Vector2,
    hp: int,
    max_hp: int,
    active: bool,
    target_pos: rl.Vector2,
    enemy_type: EnemyType, // New field for enemy type
    shoot_timer: f32,      // For flyer
    is_exploding: bool,    // For exploder
    explosion_radius: f32, // For exploder
    // Death animation
    dying: bool,
    death_timer: f32,
    death_particles: [EXPLOSION_PARTICLES]Particle,
}

Player :: struct {
    pos: rl.Vector2,
    vel: rl.Vector2,
    hp: int,
    level : int,
    current_exp : int,
    exp_to_next_level : int,
    grounded: bool,
    damage_timer: f32,
    // Death animation
    dying: bool,
    death_timer: f32,
    death_particles: [EXPLOSION_PARTICLES]Particle,
}
