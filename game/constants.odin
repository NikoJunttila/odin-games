package game

PLAYER_ZOOM :: 1
PLAYER_SIZE :: 100 * PLAYER_ZOOM
GRAVITY :: 2000.0
JUMP_FORCE :: -750.0
MOVE_SPEED :: 300.0
ANIMATION_SPEED :: 0.15 // Time between frame changes
BULLET_SPEED :: 800.0
MAX_BULLETS :: 50
MUZZLE_FLASH_DURATION :: 0.10
PIXEL_WINDOW_HEIGHT :: 1000

// skills
FLASH_DISTANCE :: 200
HEAL_AMOUNT :: 50

// World and camera constants
WORLD_WIDTH :: 4000.0  // Total world width (much larger than screen)
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

