package game

import rl "vendor:raylib"
import "core:math/rand"

// Add small random pitch changes to make each shot sound slightly different
play_shot_sound_with_variation :: proc(sound: rl.Sound) {
    // Generate random pitch between 0.9 and 1.1 (±10% variation)
    pitch_variation := 0.9 + (rand.float32() * 0.2)
    rl.SetSoundPitch(sound, pitch_variation)
    rl.PlaySound(sound)
}

play_sound_varied :: proc(sound: rl.Sound) {
    // Pitch variation: ±8% for subtle but noticeable difference
    pitch := 0.92 + (rand.float32() * 0.16)  // 0.92 to 1.08
    
    // Volume variation: ±10% to simulate distance/intensity differences
    volume := 0.9 + (rand.float32() * 0.2)   // 0.9 to 1.1
    
    rl.SetSoundPitch(sound, pitch)
    rl.SetSoundVolume(sound, volume)
    rl.PlaySound(sound)
}
