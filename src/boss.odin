package main

import "w4"

s_MiruBossData : struct {
    enabled: bool,
    frame_counter: u32,
}

StartMiruBoss :: proc "contextless" () {
    s_MiruBossData.enabled = true
    s_MiruBossData.frame_counter = 0
}

UpdateFireBall :: proc "contextless" ( fireball: ^Entity ) {
    if fireball.name != .MirusFireball do return
    if fireball.position.offsets.x < 0 - (fireball.collider.max.x - fireball.collider.min.x) do DestroyEntity( fireball )
    if fireball.position.offsets.x >= 160 do DestroyEntity( fireball )
    if fireball.position.offsets.y < 0 - (fireball.collider.max.y - fireball.collider.min.y) do DestroyEntity( fireball )
    if fireball.position.offsets.y >= 160 do DestroyEntity( fireball )

    if fireball.inflicted_damage > 0 do DestroyEntity( fireball )

    // looking_dir is used as a speed + direction scaled by 1000 for fireball
    fireball.position.offsets = 1000 * fireball.position.offsets + fireball.looking_dir + fireball.picked_point
    fireball.picked_point = fireball.position.offsets % 500
    fireball.position.offsets /= 1000
}

MakeFireBall :: proc "contextless" () -> ^Entity {
    ent := AllocateEntity()
    ent.flags += {.DamageMaker, .AnimatedSprite}
    ent.name = .MirusFireball
    ent.animated_sprite.sprite = &FireballSprite_UpDown
    ent.animated_sprite.flags += {.FlipY}
    ent.hurt_box = { {}, {i32(ent.animated_sprite.sprite.w), i32(ent.animated_sprite.sprite.h)} }
    ent.palette_mask = 0x1230
    return ent
}

UpdateMiruBoss :: proc "contextless" ( miru: ^Entity ) {
    if miru.name != .MiruBoss do return
    if !s_MiruBossData.enabled do return
    player := GetEntityByName( .Player )
    if player == nil do return
    w4.trace( "update miru boss" )
    
    if s_MiruBossData.frame_counter > 0 && s_MiruBossData.frame_counter % 60 == 0 {
        v := player.position.offsets - miru.position.offsets
        v_norm := normalize_vec2( v )
        dir := v_norm * 1000

        fireball := MakeFireBall()
        fireball.position = miru.position
        fireball.looking_dir = ivec2{ i32(dir.x), i32(dir.y) }

    }
    
    s_MiruBossData.frame_counter += 1
}
