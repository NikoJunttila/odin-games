package game

import "core:c"
import rl "vendor:raylib"

window_width: c.int = 700
window_height: c.int = 700

is_moving: bool = false
current_frame: int = 0
mouse_world_pos: rl.Vector2
muzzle_flash_timer: f32

dt: f32
sounds: Sounds

bullets: [MAX_BULLETS]Bullet
next_bullet_index: int = 0
animation_timer: f32 = 0
