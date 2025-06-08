package game

import rl "vendor:raylib"
import "core:math/rand"

play_sound_varied :: proc(sound: rl.Sound) {
    // Pitch variation: ±8% for subtle but noticeable difference
    pitch := 0.92 + (rand.float32() * 0.16)  // 0.92 to 1.08
    // Volume variation: ±10% to simulate distance/intensity differences
    volume := 0.9 + (rand.float32() * 0.2)   // 0.9 to 1.1
    rl.SetSoundPitch(sound, pitch)
    rl.SetSoundVolume(sound, volume)
    rl.PlaySound(sound)
}
play_sound_varied_low :: proc(sound: rl.Sound) {
    // Pitch variation: ±8% for subtle but noticeable difference
    pitch := 0.92 + (rand.float32() * 0.16)  // 0.92 to 1.08
    // Volume variation: ±10% to simulate distance/intensity differences
    volume := 0.5 + (rand.float32() * 0.2)   // 0.9 to 1.1
    rl.SetSoundPitch(sound, pitch)
    rl.SetSoundVolume(sound, volume)
    rl.PlaySound(sound)
}
