package main

import "rand"
import "w4"

rand_gen : rand.Rand

InitRand :: proc "contextless" ( seed: u64 ) {
	rand.init( &rand_gen, seed )
}

Rand01 :: proc "contextless" () -> f32 {
	rnd := rand.uint32( &rand_gen )
	return f32(rnd) / f32(max(u32))
}

RandBetween :: proc "contextless" ( a, b: i32 ) -> i32 {
	rnd := Rand01()
	return i32(rnd * f32( b - a ) + f32(a))
}

UpdateBatBehavior :: proc "contextless" ( entity: ^Entity, force := false ) {
	if s_gglob.game_state != GameState.Game do return
	if !force do if entity.name != .Bat do return
	if entity.received_damage > 0 do return

	if entity.picked_point == entity.position.offsets && entity.picked_point_counter == 0 {
		entity.picked_point_counter = u8( RandBetween( 40, 90 ) )
		// print_int( i32(entity.picked_point_counter) )
	}

	BAT_W :: 8
	BAT_H :: 8

	if entity.picked_point_counter > 0 {
		entity.picked_point_counter -= 1
	}
	if entity.picked_point_counter == 0 && entity.picked_point == entity.position.offsets {
		entity.picked_point = {
			RandBetween( 16, TILEMAP_CHUNK_W - rect_width(entity.collider) - 16 ),
			RandBetween( 16, TILEMAP_CHUNK_H - rect_height(entity.collider) - 16 ),
		}
		print_int( entity.picked_point.x )
		print_int( entity.picked_point.y )
	}

	if entity.picked_point != entity.position.offsets {
		dir := entity.picked_point - entity.position.offsets
		dir_normalized := normalize_vec2( dir )
		dir = { i32( dir_normalized.x + 0.5 if dir_normalized.x > 0 else dir_normalized.x - 0.5 ), i32( dir_normalized.y + 0.5 if dir_normalized.y > 0 else dir_normalized.y - 0.5 ) }
		MoveEntity( entity, dir )
	}
}