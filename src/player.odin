package main
import "w4"

PLAYER_W, PLAYER_H :: 8, 8
HALF_PLAYER_W, HALF_PLAYER_H :: 4, 4

PlayerAnimation_Idle_Front := AnimatedSprite {
	ImageKey.mc, 8, 8, 0,
	{
		AnimationFrame{ 60, 0, nil },
		AnimationFrame{ 50, 8, nil },
	},
}
PlayerAnimation_Idle_Back := AnimatedSprite {
	ImageKey.mc, 8, 8, 0,
	{
		AnimationFrame{ 60, 16, nil },
		AnimationFrame{ 50, 24, nil },
	},
}
PlayerAnimation_Move_Front := AnimatedSprite {
	ImageKey.mc, 8, 8, 8,
	{
		AnimationFrame{ 15, 0, nil },
		AnimationFrame{ 15, 8, nil },
	},
}
PlayerAnimation_Move_Back := AnimatedSprite {
	ImageKey.mc, 8, 8, 8,
	{
		AnimationFrame{ 15, 16, nil },
		AnimationFrame{ 15, 24, nil },
	},
}

PlayerAnimation_SwingSword_LeftRight := AnimatedSprite {
	ImageKey.mc, 13, 8, 16,
	{
		AnimationFrame{ 5, 0, nil },
		AnimationFrame{ 0, 13, nil },
	},
}
PlayerAnimation_SwingSword_Front := AnimatedSprite {
	ImageKey.mc, 8, 10, 10,
	{
		AnimationFrame{ 5, 32, nil },
		AnimationFrame{ 0, 40, nil },
	},
}
PlayerAnimation_SwingSword_Back := AnimatedSprite {
	ImageKey.mc, 8, 10, 0,
	{
		AnimationFrame{ 5, 32, nil },
		AnimationFrame{ 0, 40, nil },
	},
}

GetWorldSpaceCollider :: proc "contextless" ( ent: ^Entity ) -> rect {
	return translate_rect( ent.collider, ent.position.offsets )
}

C_TestAABB :: proc "contextless" ( a, b: rect ) -> bool {
    if a.max.x <= b.min.x || a.min.x >= b.max.x do return false
    if a.max.y <= b.min.y || a.min.y >= b.max.y do return false
    return true
}

IsCollidingWithEntity :: proc "contextless" ( collider: rect, other: ^Entity ) -> bool {
	other_collider := GetWorldSpaceCollider( other )
	return C_TestAABB( collider, other_collider )
}

GetFirstEntityInside_Collidable :: proc "contextless" ( source: ^Entity, collider: rect ) -> ^Entity {
	for ent in &s_EntityPool {
		if .InUse not_in ent.flags do continue
		if .Collidable not_in ent.flags do continue
		if ent.id == source.id do continue
		if IsCollidingWithEntity( collider, &ent ) do return &ent
	}
	return nil
}

GetFirstEntityInside_Flags :: proc "contextless" ( source: ^Entity, collider: rect, flags: EntityFlags ) -> ^Entity {
	for ent in &s_EntityPool {
		if .InUse not_in ent.flags do continue
		if (flags & ent.flags) != nil do continue
		if ent.id == source.id do continue
		if IsCollidingWithEntity( collider, &ent ) do return &ent
	}
	return nil
}

GetFirstEntityInside :: proc {
	GetFirstEntityInside_Collidable,
	GetFirstEntityInside_Flags,
}

IsCollidingWithAnyEntity :: proc "contextless" ( entity: ^Entity, collider: rect ) -> bool {
	ent := GetFirstEntityInside( entity, collider, EntityFlags{.Collidable} )
	return ent != nil
}

UpdatePlayer :: proc "contextless" ( using entity: ^Entity ) {
	if .Player not_in flags do return

	dir : ivec2 = { 0, 0 }
	if s_gglob.game_state == GameState.Game {
		if received_damage > 0 {
			// dir.x = pushed_back_direction.x
		} else {
			if .LEFT in w4.GAMEPAD1^ {
				dir.x -= 1
			}
			if .RIGHT in w4.GAMEPAD1^ {
				dir.x += 1
			}
		}

		if received_damage > 0 {
			// dir.y = pushed_back_direction.y
		} else {
			if .UP in w4.GAMEPAD1^ {
				dir.y -= 1
			}
			if .DOWN in w4.GAMEPAD1^ {
				dir.y += 1
			}
		}
		move := dir
	
		MoveEntity( entity, move )
	
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

	moving := dir.x != 0 || dir.y != 0
	if moving && swinging_sword == 0 && received_damage == 0 { // lock looking dir when swinging sword
		looking_dir = dir
	}

	if s_gglob.input_state.APressed {
		if s_gglob.game_state == GameState.Game {
			interaction_rect := GetWorldSpaceCollider( entity )
			interaction_rect = translate_rect( interaction_rect, looking_dir * {HALF_PLAYER_W, HALF_PLAYER_H} )
			
			ent := GetFirstEntityInside( entity, interaction_rect )
			if .Interactible in ent.flags {
				switch interaction in ent.interaction {
					case ^DialogDef: Dialog_Start( interaction )
					case ^Container:
						interaction.on_open()
				}
			} else { // perform inventory object use
				if entity.inventory.items[InventoryItem.Sword] && entity.inventory.current_item == u8(InventoryItem.Sword) {
					// swing sword action
					entity.swinging_sword = 1
					entity.flags += { .DamageMaker }
					if looking_dir.x < 0 {
						entity.animated_sprite.sprite = &PlayerAnimation_SwingSword_LeftRight
						entity.hurt_box = { { -5, 0 }, { -5 + 5, 0 + 8} }
					} else if looking_dir.x > 0 {
						entity.animated_sprite.sprite = &PlayerAnimation_SwingSword_LeftRight
						entity.hurt_box = { { 8, 0 }, { 8 + 5, 0 + 8} }
					} else if looking_dir.y > 0 {
						entity.animated_sprite.sprite = &PlayerAnimation_SwingSword_Front
						entity.hurt_box = { { 0, 6 }, { 7, 10 } }
					} else if looking_dir.y < 0 {
						entity.animated_sprite.sprite = &PlayerAnimation_SwingSword_Back
						entity.hurt_box = { { 0, -2 }, { 7, 2 } }
					}
					entity.animated_sprite.current_frame = 0
				}
				when DEVELOPMENT_BUILD do w4.rect( interaction_rect.min.x, interaction_rect.min.y, u32( interaction_rect.max.x - interaction_rect.min.x ), u32( interaction_rect.max.y - interaction_rect.min.y ) )
			}
		}
	}

	if s_gglob.input_state.BPressed {
		SelectNextItem( &entity.inventory )
	}

	if entity.swinging_sword > 0 {
		// if we release wait that we at least have done a full swing
		if ( !s_gglob.input_state.ADown || entity.inflicted_damage > 0 ) && entity.swinging_sword > entity.animated_sprite.sprite.frames[0].length + 3 {
			entity.swinging_sword = 0
			entity.flags -= { .DamageMaker }
			entity.inflicted_damage = 0
		} else {
			if entity.swinging_sword < 255 do entity.swinging_sword += 1
		}
	}

	if entity.swinging_sword == 0 {
		if moving {
			entity.animated_sprite.sprite = &PlayerAnimation_Move_Front if looking_dir.y >= 0 else &PlayerAnimation_Move_Back
		} else {
			entity.animated_sprite.sprite = &PlayerAnimation_Idle_Front if looking_dir.y >= 0 else &PlayerAnimation_Idle_Back
		}
	}

	// display player
	w4.DRAW_COLORS^ = entity.palette_mask
	if entity.swinging_sword > 0 {
		flip := true if looking_dir.x < 0 else false
		x, y := position.offsets.x, position.offsets.y
		if looking_dir.x != 0 && flip {
			x -= 5
		} else if looking_dir.y < 0 {
			y -= 2
		}
		if flip do entity.animated_sprite.flags += {.FlipX}
		   else do entity.animated_sprite.flags -= {.FlipX}
		DrawAnimatedSprite( &entity.animated_sprite, x, y )
	} else {
		if moving {
			flip := true if looking_dir.x < 0 else false
			if flip do entity.animated_sprite.flags += {.FlipX}
			   else do entity.animated_sprite.flags -= {.FlipX}
			DrawAnimatedSprite( &entity.animated_sprite, position.offsets.x, position.offsets.y )
		} else {
			flip := true if looking_dir.x < 0 else false
			if flip do entity.animated_sprite.flags += {.FlipX}
			   else do entity.animated_sprite.flags -= {.FlipX}
			DrawAnimatedSprite( &entity.animated_sprite, position.offsets.x, position.offsets.y )
		}
	}
}

MakePlayer :: proc "contextless" () -> ^Entity {
	player := AllocateEntity( EntityName.Player )
	player.flags += { .Player, .DamageReceiver, .Collidable }
	player.looking_dir = { 1, 1 }
	player.max_health_points = 6
	player.health_points = player.max_health_points
	player.position.chunk = { 0, 0 }
	player.collider = { { 0, 0 }, { 8, 8 } }
	player.damage_flash_palette = 0x0012
	player.palette_mask = 0x0021

	player.inventory.items[InventoryItem.Sword] = true when START_WITH_SWORD else false
	player.inventory.items[InventoryItem.Torch] = false
	SelectNextItem( &player.inventory )

	return player
}
