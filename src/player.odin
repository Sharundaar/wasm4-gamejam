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
PlayerAnimation_Falling := AnimatedSprite {
	ImageKey.mc, 8, 8, 24,
	{
		AnimationFrame{ 30, 0, nil },
		AnimationFrame{ 20, 8, nil },
		AnimationFrame{ 10, 16, nil },
		AnimationFrame{ 0, 16, {.NoSprite} },
	},
}
PlayerAnimation_Death := AnimatedSprite {
	ImageKey.mc, 8, 8, 24,
	{
		AnimationFrame{ 60, 24, nil },
		AnimationFrame{ 100, 32, nil },
		AnimationFrame{ 255, 40, nil },
	},
}

PlayerSound_Death := Sound {
	{
		{ 800, 400, 60, {sustain=10}, .Noise, 25 },
		{ 600, 400, 160, {sustain=15}, .Noise, 25 },
	},
}

PlayerSound_SwingSword := Sound {
	{
		{ 490, 490, 0, {sustain=5}, .Noise, 7 },
	},
}
PlayerSound_Hurt := Sound {
	{
		{ 2700, 1200, 0, {sustain=3}, .Triangle, 25 },
	},
}

PlayerSound_Falling := Sound {
	{
		{ 1700, 1, 0, {sustain=60}, .Pulse1, 25 },
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
		if (flags & ent.flags) == nil do continue
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

	dir : ivec2
	if s_gglob.game_state == GameState.Game {
		center := entity.position.offsets + { HALF_PLAYER_W, HALF_PLAYER_H }
		tile := GetTileDefForCoordinates( &s_gglob.tilemap, entity.position.chunk.x, entity.position.chunk.y, center.x, center.y )
		if NO_CLIP == false && tile.collider_type == .Hole { // falling
			entity.walking_sound_counter = 0
			tile_pos := GetTileLocalCoordinate( center )
			tile_midpoint := GetTileWorldCoordinateMidPoint( tile_pos.x, tile_pos.y )
			dir = tile_midpoint - center
			if dir.x < 0 do dir.x = -1
			if dir.y < 0 do dir.y = -1
			if dir.x > 0 do dir.x =  1
			if dir.y > 0 do dir.y =  1
			if dir == { 0, 0 } { // reached middle
				entity.falling_frame_counter += 1
			} else {
				entity.falling_frame_counter = 1
			}
		} else {
			if received_damage == 0 { // damage received means pushed_back so no movement here
				if .LEFT in w4.GAMEPAD1^ {
					dir.x -= 1
				}
				if .RIGHT in w4.GAMEPAD1^ {
					dir.x += 1
				}
				if .UP in w4.GAMEPAD1^ {
					dir.y -= 1
				}
				if .DOWN in w4.GAMEPAD1^ {
					dir.y += 1
				}

				if dir != {} {
					entity.walking_sound_counter += 1
				} else {
					entity.walking_sound_counter = 0
				}
			}
		}
		
		move := dir
	
		MoveEntity( entity, move )
	}

	if entity.walking_sound_counter > 0 {
		if entity.walking_sound_counter == 15 {
			w4.tone( 50, 2, 8, .Pulse2 )
		} else if entity.walking_sound_counter >= 30 {
			w4.tone( 75, 2, 8, .Pulse2 )
			entity.walking_sound_counter = 0
		}
	}

	moving := dir.x != 0 || dir.y != 0
	if entity.falling_frame_counter > 0 { // when falling, still move where you look
		if entity.falling_frame_counter == 1 {
			Sound_Play( &PlayerSound_Falling )
		}
		new_looking_dir : ivec2
		if .LEFT in w4.GAMEPAD1^ {
			new_looking_dir.x -= 1
		}
		if .RIGHT in w4.GAMEPAD1^ {
			new_looking_dir.x += 1
		}
		if .UP in w4.GAMEPAD1^ {
			new_looking_dir.y -= 1
		}
		if .DOWN in w4.GAMEPAD1^ {
			new_looking_dir.y += 1
		}
		if new_looking_dir != { 0, 0 } {
			looking_dir = new_looking_dir
		}
		// falling animation ?
		if entity.falling_frame_counter > 60 {
			entity.position.offsets = s_gglob.last_valid_player_position
			entity.pushed_back_cached_pos = entity.position.offsets
			entity.pushed_back_dist = {}
			entity.falling_frame_counter = 0
			InflictDamage( entity, true )
		}
	} else if moving && swinging_sword == 0 && received_damage == 0 { // lock looking dir when swinging sword
		looking_dir = dir
	}

	// actions
	if s_gglob.input_state.APressed {
		if s_gglob.game_state == GameState.Game && entity.falling_frame_counter == 0 {
			interaction_rect := GetWorldSpaceCollider( entity )
			interaction_rect = translate_rect( interaction_rect, looking_dir * {HALF_PLAYER_W, HALF_PLAYER_H} )
			
			ent := GetFirstEntityInside( entity, interaction_rect, EntityFlags{.Interactible} )
			if .Interactible in ent.flags {
				switch interaction in ent.interaction {
					case ^DialogDef: Dialog_Start( interaction )
					case ^Container:
						interaction.on_open( ent.id )
					case ^Trigger:
				}
			} else { // perform inventory object use
				if entity.inventory.items[InventoryItem.Sword] && entity.inventory.current_item == u8(InventoryItem.Sword) {
					// swing sword action
					Sound_Play( &PlayerSound_SwingSword )
					entity.swinging_sword = 1
					entity.flags += { .DamageMaker }
					sprite : ^AnimatedSprite
					if looking_dir.x < 0 {
						sprite = &PlayerAnimation_SwingSword_LeftRight
						entity.hurt_box = { { -5, 0 }, { -5 + 5, 0 + 8} }
					} else if looking_dir.x > 0 {
						sprite = &PlayerAnimation_SwingSword_LeftRight
						entity.hurt_box = { { 8, 0 }, { 8 + 5, 0 + 8} }
					} else if looking_dir.y > 0 {
						sprite = &PlayerAnimation_SwingSword_Front
						entity.hurt_box = { { 0, 6 }, { 7, 10 } }
					} else if looking_dir.y < 0 {
						sprite = &PlayerAnimation_SwingSword_Back
						entity.hurt_box = { { 0, -2 }, { 7, 2 } }
					}
					AnimationController_SetSprite( &entity.animated_sprite, sprite )
				}
				when DEVELOPMENT_BUILD do w4.rect( interaction_rect.min.x, interaction_rect.min.y, u32( interaction_rect.max.x - interaction_rect.min.x ), u32( interaction_rect.max.y - interaction_rect.min.y ) )
			}
		}
	}

	if s_gglob.input_state.BPressed {
		Inventory_SelectNextItem( &entity.inventory )
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

	if entity.falling_frame_counter > 0 {
		if entity.falling_frame_counter == 1 {
			AnimationController_SetSprite( &entity.animated_sprite, &PlayerAnimation_Falling )
		}
	} else if entity.swinging_sword == 0 {
		if moving {
			AnimationController_SetSprite( &entity.animated_sprite, &PlayerAnimation_Move_Front if looking_dir.y >= 0 else &PlayerAnimation_Move_Back, true )
		} else {
			AnimationController_SetSprite( &entity.animated_sprite, &PlayerAnimation_Idle_Front if looking_dir.y >= 0 else &PlayerAnimation_Idle_Back, true )
		}
	}

	// display player
	w4.DRAW_COLORS^ = entity.palette_mask
	if entity.falling_frame_counter > 0 {
		DrawAnimatedSprite( &entity.animated_sprite, position.offsets.x, position.offsets.y )
	} else if entity.swinging_sword > 0 {
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
	when NO_CLIP {
		player.flags -= {.Collidable}
	}
	player.looking_dir = { 1, 1 }
	player.max_health_points = 6
	player.health_points = player.max_health_points
	player.collider = { { 0, 0 }, { 8, 8 } }
	player.damage_flash_palette = 0x0012
	player.palette_mask = 0x0021

	when TEST_DEATH_ANIMATION {
		player.health_points = 1
	}

	when START_WITH_SWORD {
		Quest_Complete( .GotSword )
		Inventory_GiveNewItem_Immediate( player, .Sword )
	}
	Inventory_SelectNextItem( &player.inventory )

	return player
}
