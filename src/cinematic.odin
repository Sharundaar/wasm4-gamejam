package main

import "w4"

CinematicStep :: struct {
    update: proc "contextless" ( controller: ^CinematicController ) -> (advance_step: bool),
}

Cinematic :: struct {
    steps: []CinematicStep,
}

CinematicController :: struct {
    frame_counter: u8,
    current_step: u8,
    cinematic: ^Cinematic,
}

Cinematic_Play :: proc "contextless" ( cinematic: ^Cinematic ) {
    s_gglob.game_state = .Cinematic
    s_gglob.cinematic_controller = {}
    s_gglob.cinematic_controller.cinematic = cinematic
}

Cinematic_Update :: proc "contextless" ( controller: ^CinematicController ) {
    if s_gglob.game_state != .Cinematic do return
    if controller.cinematic.steps[controller.current_step].update( controller ) {
        controller.current_step += 1
        controller.frame_counter = 0
    } else {
        controller.frame_counter += 1
    }
    if controller.current_step >= u8(len(controller.cinematic.steps)) {
        s_gglob.game_state = .Game
    }
}

lerp :: proc "contextless" ( a, b: ivec2, t: f32 ) -> ivec2 {
    if t >= 1 do return b
    if t <= 0 do return a
    af := [2]f32{ f32( a.x ), f32( a.y ) }
    bf := [2]f32{ f32( b.x ), f32( b.y ) }
    cf := af + (bf-af)*t
    c := ivec2{ i32(cf.x), i32(cf.y) }
    return c
}

Cinematic_MoveEntityStep :: proc "contextless" ( $ent_name: EntityName, $target_x: i32, $target_y: i32, $length: u8, $absolute_pos: bool ) -> proc "contextless" ( controller: ^CinematicController ) -> bool {
    return proc "contextless" ( controller: ^CinematicController ) -> bool {
        tom := GetEntityByName( ent_name )
        if controller.frame_counter == 0 {
            tom.pushed_back_cached_pos = tom.position.offsets
        }
        when absolute_pos {
            target := ivec2{ target_x, target_y }
        } else {
            target := GetTileWorldCoordinate( target_x, target_y )
        }
        t := f32( controller.frame_counter ) / f32(length)
        l := lerp( tom.pushed_back_cached_pos, target, t )
        tom.position.offsets = l
        return controller.frame_counter >= u8(length)
    }
}
