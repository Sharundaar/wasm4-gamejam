package main
import "w4"

PLAYER_W, PLAYER_H :: 8, 8
HALF_PLAYER_W, HALF_PLAYER_H :: 4, 4

PlayerAnimation_Idle_Front := AnimatedSprite {
	&Images.mc, 8, 8, 0,
	{
		AnimationFrame{ 60, 0, nil },
		AnimationFrame{ 50, 8, nil },
	},
	0, 0,
}
PlayerAnimation_Idle_Back := AnimatedSprite {
	&Images.mc, 8, 8, 0,
	{
		AnimationFrame{ 60, 16, nil },
		AnimationFrame{ 50, 24, nil },
	},
	0, 0,
}
PlayerAnimation_Move_Front := AnimatedSprite {
	&Images.mc, 8, 8, 8,
	{
		AnimationFrame{ 15, 0, nil },
		AnimationFrame{ 15, 8, nil },
	},
	0, 0,
}
PlayerAnimation_Move_Back := AnimatedSprite {
	&Images.mc, 8, 8, 8,
	{
		AnimationFrame{ 15, 16, nil },
		AnimationFrame{ 15, 24, nil },
	},
	0, 0,
}

GetWorldSpaceCollider :: proc "contextless" ( ent: ^Entity ) -> rect {
	return translate_rect( ent.collider, ent.position.offsets )
}

C_TestAABB :: proc "contextless" ( a, b: rect ) -> bool {
    if a.max.x < b.min.x || a.min.x > b.max.x do return false
    if a.max.y < b.min.y || a.min.y > b.max.y do return false
    return true
}

IsCollidingWithEntity :: proc "contextless" ( collider: rect, other: ^Entity ) -> bool {
	other_collider := GetWorldSpaceCollider( other )
	return C_TestAABB( collider, other_collider )
}

GetFirstEntityInside :: proc "contextless" ( source: ^Entity, collider: rect ) -> ^Entity {
	for ent in &s_EntityPool {
		if .InUse not_in ent.flags do continue
		if .Collidable not_in ent.flags do continue
		if ent.id == source.id do continue
		if IsCollidingWithEntity( collider, &ent ) do return &ent
	}
	return nil
}

IsCollidingWithAnyEntity :: proc "contextless" ( entity: ^Entity, collider: rect ) -> bool {
	ent := GetFirstEntityInside( entity, collider )
	return ent != nil
}

UpdatePlayer :: proc "contextless" ( using entity: ^Entity ) {
	if .Player not_in flags do return

	dir : ivec2 = { 0, 0 }
	if s_gglob.game_state == GameState.Game {
		if .LEFT in w4.GAMEPAD1^ {
			dir.x -= 1
		}
		if .RIGHT in w4.GAMEPAD1^ {
			dir.x += 1
		}
	
		move := dir
		if move.x != 0 {
			testing_pos := position; testing_pos.offsets += move
			world_space_collider := translate_rect( entity.collider, testing_pos.offsets )
			if IsCollidingWithTilemap_Collider( &s_gglob.tilemap, testing_pos.chunk, world_space_collider ) || IsCollidingWithAnyEntity( entity, world_space_collider ) {
				move.x = 0
			}
		}
	
		if .UP in w4.GAMEPAD1^ {
			dir.y -= 1
		}
		if .DOWN in w4.GAMEPAD1^ {
			dir.y += 1
		}
		move.y = dir.y
		if move.y != 0 {
			testing_pos := position; testing_pos.offsets += move
			world_space_collider := translate_rect( entity.collider, testing_pos.offsets )
			if IsCollidingWithTilemap_Collider( &s_gglob.tilemap, testing_pos.chunk, world_space_collider ) || IsCollidingWithAnyEntity( entity, world_space_collider ) {
				move.y = 0
			}
		}
	
		position.offsets += move
	
		{ // trigger smooth transition ?
			if position.offsets.x + PLAYER_W >= TILE_CHUNK_COUNT_W * TILE_SIZE {
				position.offsets.x = 0
				position.chunk.x += 1
			}
			if position.offsets.y + PLAYER_H >= TILE_CHUNK_COUNT_H * TILE_SIZE {
				position.offsets.y = 0
				position.chunk.y += 1
			}
			if position.offsets.x < 0 {
				position.offsets.x = TILE_CHUNK_COUNT_W * TILE_SIZE - PLAYER_W
				position.chunk.x -= 1
			}
			if position.offsets.y < 0 {
				position.offsets.y = TILE_CHUNK_COUNT_H * TILE_SIZE - PLAYER_H
				position.chunk.y -= 1
			}
		}

		// shouldn't be necessary but for safety
		position = RegularizeCoordinate( position )
	}

	// draw player
	w4.DRAW_COLORS^ = 0x0021
	if dir.x != 0 || dir.y != 0 {
		looking_dir.x = dir.x
		looking_dir.y = dir.y

		flip : AnimationFlags = {.FlipX} if looking_dir.x < 0 else nil
		anim := &PlayerAnimation_Move_Front if looking_dir.y >= 0 else &PlayerAnimation_Move_Back
		DrawAnimatedSprite( anim, position.offsets.x, position.offsets.y, flip )
	} else {
		flip : AnimationFlags = {.FlipX} if looking_dir.x < 0 else nil
		anim := &PlayerAnimation_Idle_Front if looking_dir.y >= 0 else &PlayerAnimation_Idle_Back
		DrawAnimatedSprite( anim, position.offsets.x, position.offsets.y, flip )
	}

	if s_gglob.input_state.APressed {
		if s_gglob.game_state == GameState.Game {
			interaction_rect := GetWorldSpaceCollider( entity )
			interaction_rect = translate_rect( interaction_rect, looking_dir * {HALF_PLAYER_W, HALF_PLAYER_H} )
	
			ent := GetFirstEntityInside( entity, interaction_rect )
			if .Interactible in ent.flags {
				switch interaction in ent.interaction {
					case ^DialogDef:
						Dialog_Start( interaction )
				}
			} else { // perform inventory object use

			}
			when DEVELOPMENT_BUILD do w4.rect( interaction_rect.min.x, interaction_rect.min.y, u32( interaction_rect.max.x - interaction_rect.min.x ), u32( interaction_rect.max.y - interaction_rect.min.y ) )
		}
	}
}