package game

import rl "vendor:raylib"
import "core:math"
Platform :: struct {
  texture : rl.Texture2D,
  rect : rl.Rectangle,
  color : rl.Color,
}
// Generate platforms for the map
generate_platforms :: proc(window_height: i32, allocator := context.allocator) -> []Platform {
    platforms := make([dynamic]Platform, allocator)
    
    // Ground level platforms
    append(&platforms, Platform{
        rect = {50, f32(window_height - PLAYER_SIZE), 200, 20},
        color = rl.BROWN,
    })
    append(&platforms, Platform{
        rect = {300, f32(window_height - PLAYER_SIZE), 150, 20},
        color = rl.DARKBROWN,
    })
    append(&platforms, Platform{
        rect = {500, f32(window_height - PLAYER_SIZE), 120, 20},
        color = rl.BROWN,
    })
    append(&platforms, Platform{
        rect = {700, f32(window_height - PLAYER_SIZE), 180, 20},
        color = rl.MAROON,
    })
    
    // Mid-level platforms
    append(&platforms, Platform{
        rect = {150, f32(window_height - PLAYER_SIZE - 120), 100, 15},
        color = rl.DARKGREEN,
    })
    append(&platforms, Platform{
        rect = {350, f32(window_height - PLAYER_SIZE - 100), 80, 15},
        color = rl.GREEN,
    })
    append(&platforms, Platform{
        rect = {550, f32(window_height - PLAYER_SIZE - 140), 90, 15},
        color = rl.LIME,
    })
    append(&platforms, Platform{
        rect = {750, f32(window_height - PLAYER_SIZE - 110), 110, 15},
        color = rl.DARKGREEN,
    })
    
    // High-level platforms
    append(&platforms, Platform{
        rect = {100, f32(window_height - PLAYER_SIZE - 220), 70, 22},
        color = rl.BLUE,
    })
    append(&platforms, Platform{
        rect = {250, f32(window_height - PLAYER_SIZE - 200), 60, 15},
        color = rl.DARKBLUE,
    })
    append(&platforms, Platform{
        rect = {400, f32(window_height - PLAYER_SIZE - 240), 85, 15},
        color = rl.SKYBLUE,
    })
    append(&platforms, Platform{
        rect = {600, f32(window_height - PLAYER_SIZE - 210), 75, 15},
        color = rl.BLUE,
    })
    append(&platforms, Platform{
        rect = {800, f32(window_height - PLAYER_SIZE - 230), 90, 15},
        color = rl.GOLD,
    })
    
    // Floating platforms
    append(&platforms, Platform{
        rect = {200, f32(window_height - PLAYER_SIZE - 320), 50, 15},
        color = rl.PURPLE,
    })
    append(&platforms, Platform{
        rect = {450, f32(window_height - PLAYER_SIZE - 340), 60, 20},
        color = rl.VIOLET,
    })
    append(&platforms, Platform{
        rect = {650, f32(window_height - PLAYER_SIZE - 300), 55, 20},
        color = rl.MAGENTA,
    })
    
    // Some wider platforms for variety
    append(&platforms, Platform{
        rect = {900, f32(window_height - PLAYER_SIZE), 250, 25},
        color = rl.GRAY,
    })
    append(&platforms, Platform{
        rect = {1200, f32(window_height - PLAYER_SIZE - 80), 200, 20},
        color = rl.DARKGRAY,
    })
    append(&platforms, Platform{
        rect = {1000, f32(window_height - PLAYER_SIZE - 180), 120, 15},
        color = rl.LIGHTGRAY,
    })
    
    // Narrow challenging platforms
    append(&platforms, Platform{
        rect = {320, f32(window_height - PLAYER_SIZE - 160), 40, 8},
        color = rl.RED,
    })
    append(&platforms, Platform{
        rect = {480, f32(window_height - PLAYER_SIZE - 180), 35, 8},
        color = rl.ORANGE,
    })
    append(&platforms, Platform{
        rect = {720, f32(window_height - PLAYER_SIZE - 170), 45, 8},
        color = rl.YELLOW,
    })
    
    return platforms[:]
}
//Tiled texture drawing (repeats texture instead of stretching)
draw_platforms :: proc(platforms: []Platform, platform_texture: rl.Texture2D) {
    for platform in platforms {
        // Draw colored rectangle as base
        // rl.DrawRectangleRec(platform.rect, platform.color)
        
        // Calculate how many times the texture fits
        tex_width := f32(platform_texture.width)
        tex_height := f32(platform_texture.height)
        
        tiles_x := int(math.ceil(platform.rect.width / tex_width))
        tiles_y := int(math.ceil(platform.rect.height / tex_height))
        
        // Draw tiled texture
        for x in 0..<tiles_x {
            for y in 0..<tiles_y {
                pos_x := platform.rect.x + f32(x) * tex_width
                pos_y := platform.rect.y + f32(y) * tex_height
                
                // Calculate how much of the texture to draw (for edge tiles)
                draw_width := min(tex_width, platform.rect.x + platform.rect.width - pos_x)
                draw_height := min(tex_height, platform.rect.y + platform.rect.height - pos_y)
                
                if draw_width > 0 && draw_height > 0 {
                    source_rect := rl.Rectangle{0, 0, draw_width, draw_height}
                    dest_rect := rl.Rectangle{pos_x, pos_y, draw_width, draw_height}
                    origin := rl.Vector2{0, 0}
                    
                    rl.DrawTexturePro(platform_texture, source_rect, dest_rect, origin, 0, rl.WHITE)
                }
            }
        }
        // Optional: Draw outline for better visibility
        // rl.DrawRectangleLinesEx(platform.rect, 1, rl.BLACK)
    }
}
