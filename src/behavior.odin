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

UpdateBatBehavior :: proc "contextless" ( entity: ^Entity ) {
	if s_gglob.game_state != GameState.Game do return
	if entity.name != EntityName.Bat do return
	if entity.received_damage > 0 do return

	player := GetEntityByName( EntityName.Player )
	if player == nil do return

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
			RandBetween( 0, TILEMAP_CHUNK_W - BAT_W ),
			RandBetween( 0, TILEMAP_CHUNK_H - BAT_H ),
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