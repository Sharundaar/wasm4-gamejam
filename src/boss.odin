package main

import "w4"

s_MiruBossData : struct {
	enabled: bool,
	frame_counter: u32,
	phase: u8,
	light_idx: u8,
}

StartMiruBoss :: proc "contextless" () {
	s_MiruBossData.enabled = true
	s_MiruBossData.frame_counter = 0
}

UpdateFireBall :: proc "contextless" ( fireball: ^Entity ) {
	if fireball.name != .MirusFireball do return

	DestroyFireball :: proc "contextless" ( fireball: ^Entity ) -> bool {
		if fireball.swinging_sword > 0 {
			DisableLight( fireball.swinging_sword )
		}
		DestroyEntity( fireball )
		return true
	}
	if fireball.position.offsets.x < 0 - (fireball.collider.max.x - fireball.collider.min.x) \
	|| fireball.position.offsets.x >= 160 \
	|| fireball.position.offsets.y < 0 - (fireball.collider.max.y - fireball.collider.min.y) \
	|| fireball.position.offsets.y >= 160 \
	|| fireball.inflicted_damage > 0 {
		DestroyFireball( fireball )
		return
	}

	// looking_dir is used as a speed + direction scaled by 1000 for fireball, picked_point hold the decimal between frames
	fireball.position.offsets = 1000 * fireball.position.offsets + fireball.looking_dir + fireball.picked_point
	fireball.picked_point = fireball.position.offsets % 1000
	fireball.position.offsets /= 1000

	if fireball.swinging_sword == 0 {
		fireball.swinging_sword = EnableFirstAvailableLight( fireball.position.offsets + rect_size( fireball.hurt_box ) / 2 )
	} else {
		SetLightPosition( fireball.swinging_sword, fireball.position.offsets + rect_size( fireball.hurt_box ) / 2 )
	}
}

MakeFireBall :: proc "contextless" ( dir: ivec2 ) -> ^Entity {
	ent := AllocateEntity()
	ent.flags += {.DamageMaker, .AnimatedSprite}
	ent.name = .MirusFireball

	// determine sprite
	if dir.x >= 0 && abs( dir.y ) <= dir.x {
		ent.animated_sprite.sprite = &FireballSprite_LeftRight
	} else if dir.x <= 0 && abs( dir.y ) <= abs( dir.x ) {
		ent.animated_sprite.sprite = &FireballSprite_LeftRight
		ent.animated_sprite.flags += {.FlipX}
	} else if dir.y >= 0 && abs( dir.x ) <= dir.y {
		ent.animated_sprite.sprite = &FireballSprite_UpDown
		ent.animated_sprite.flags += {.FlipY}
	} else if dir.y <= 0 && abs( dir.x ) <= abs( dir.y ) {
		ent.animated_sprite.sprite = &FireballSprite_UpDown
	}
	ent.hurt_box = { {}, {i32(ent.animated_sprite.sprite.w), i32(ent.animated_sprite.sprite.h)} }
	ent.palette_mask = 0x1230
	ent.looking_dir = dir

	return ent
}

MirusPhase2Dialog := DialogDef {
	"Miru",
	{{ "You are strong.", "Let's see" },
	{ "How you fare", "in the dark" }},
	proc "contextless" () {
		DisableAllLightsAndEnableDarkness()
		s_MiruBossData.enabled = true
	},
}

MirusDeathSprite := AnimatedSprite {
	ImageKey.miru, 16, 16, 0,
	{
		{ 1, 0, {.NoSprite} }, // make it invisible for one frame the time the alive miru dissapear
		{ 120, 0, nil },
		{ 0, 16, nil },
	},
}

MirusDeathDialog := DialogDef {
	"Miru",
	{
		{"Urg...", "All that..."},
		{"for some dumb...", "bats...."},
	},
	proc "contextless" () {
		StartFade( proc "contextless" () { s_gglob.game_state = .EndingMiruScreen } )
		s_MiruBossData.enabled = false
	},
}

MirusDeathCinematic := Cinematic {
	{
		{proc "contextless" ( controller: ^CinematicController ) -> bool {
			return controller.frame_counter >= 120
		}},
		{proc "contextless" ( controller: ^CinematicController ) -> bool {
			Dialog_Start( &MirusDeathDialog )
			return false
		}},
	},
}

MirusBossDeath :: proc "contextless" () {
	DisableDarkness()
	miru := GetEntityByName( .MiruBoss )
	dead_miru := AllocateEntity()
	dead_miru.flags += {.AnimatedSprite}
	dead_miru.animated_sprite.sprite = &MirusDeathSprite
	dead_miru.position.offsets = miru.position.offsets
	dead_miru.palette_mask = 0x0210

	miru.position.offsets = GetTileWorldCoordinate( 4, 1 )

	Cinematic_Play( &MirusDeathCinematic )
}

UpdateMiruBoss :: proc "contextless" ( miru: ^Entity ) {
	if miru.name != .MiruBoss do return
	if !s_MiruBossData.enabled do return
	player := GetEntityByName( .Player )
	if player == nil do return
	
	switch s_MiruBossData.phase {
	case 0:
		if s_MiruBossData.frame_counter > 0 && s_MiruBossData.frame_counter % 120 == 0 {
			v := player.position.offsets - miru.position.offsets
			v_norm := normalize_vec2( v )
			dir := v_norm * 1000
	
			fireball := MakeFireBall( ivec2{ i32(dir.x), i32(dir.y) } )
			fireball.position = miru.position
		}

		UpdateBatBehavior( miru, true )
	case 1:
		if s_MiruBossData.frame_counter < 60 {
			miru.position.offsets = { -16, -16 }
		}
		if s_MiruBossData.frame_counter >= 60 && s_MiruBossData.frame_counter % 120 == 0 {
			v := player.position.offsets - miru.position.offsets
			v_norm := normalize_vec2( v )
			dir := v_norm * 1000
	
			fireball := MakeFireBall( ivec2{ i32(dir.x), i32(dir.y) } )
			fireball.position = miru.position
		}
		if s_MiruBossData.frame_counter == 60 {
			choice := i32(Rand01() * 300) % 4
			switch choice {
				case 0: miru.position.offsets = GetTileWorldCoordinate( 2, 2 )
				case 1: miru.position.offsets = GetTileWorldCoordinate( 2, 6 )
				case 2: miru.position.offsets = GetTileWorldCoordinate( 7, 2 )
				case 3: miru.position.offsets = GetTileWorldCoordinate( 7, 6 )
			}
			s_MiruBossData.light_idx = EnableFirstAvailableLight( miru.position.offsets + rect_size( miru.collider ) / 2, 2, 0.25 )
		}
		if s_MiruBossData.frame_counter >= 160 {
			DisableLight( s_MiruBossData.light_idx )
			s_MiruBossData.frame_counter = 0
		}
	}

	if miru.health_points == 15 && miru.received_damage == 1 {
		s_MiruBossData.phase = 1
		s_MiruBossData.frame_counter = 0
		s_MiruBossData.enabled = false
		Dialog_Start( &MirusPhase2Dialog )
	}
	
	s_MiruBossData.frame_counter += 1
}

s_TomBossData : struct {
	enabled: bool,
	frame_counter: u32,
	phase: i32,
}

TomsDeathDialog := DialogDef {
	"Tom",
	{
		{"I hope", "you're happy"},
	},
	proc "contextless" () {
		DestroyEntity( GetEntityByName( .TomBoss ) )
		StartFade( proc "contextless" () { s_gglob.game_state = .EndingTomScreen } )
		s_TomBossData.enabled = false
	},
}

StartTomBoss :: proc "contextless" () {
	s_TomBossData.enabled = true
}

TomBossDeath :: proc "contextless" () {
	tom := GetEntityByName( .TomBoss )
	dead_tom := AllocateEntity()
	dead_tom.flags += {.AnimatedSprite}
	dead_tom.animated_sprite.sprite = &TomSprite_Hurt
	dead_tom.position.offsets = tom.position.offsets
	dead_tom.palette_mask = 0x1420

	Dialog_Start( &TomsDeathDialog )
}

TomPhase2Dialog := DialogDef {
	"Tom",
	{
		{"You are strong", ""},
		{"BATS !!", "TO ME !!"},
	},
	proc "contextless" () {
		s_TomBossData.enabled = true
	},
}

UpdateTomBoss :: proc "contextless" ( tom: ^Entity ) {
	if tom.name != .TomBoss do return
	if !s_TomBossData.enabled do return
	
	if tom.picked_point == tom.position.offsets && tom.picked_point_counter == 0 {
		tom.picked_point_counter = u8( RandBetween( 40, 90 ) )
	}
	if tom.picked_point_counter > 0 {
		tom.picked_point_counter -= 1
	}
	if tom.picked_point_counter == 0 && tom.picked_point == tom.position.offsets {
		valid_choice := false
		picked_tile : ivec2
		for !valid_choice {
			choice := i32(Rand01() * 256) % 4
			switch choice {
				case 0: picked_tile = tom.position.offsets + { -2 * TILE_SIZE, 0 } // go left
				case 1: picked_tile = tom.position.offsets + {  2 * TILE_SIZE, 0 } // go right
				case 2: picked_tile = tom.position.offsets + { 0,  2 * TILE_SIZE } // go down
				case 3: picked_tile = tom.position.offsets + { 0, -2 * TILE_SIZE } // go up
			}
			tiledef := GetTileDefForCoordinates( &s_gglob.tilemap, tom.position.chunk.x, tom.position.chunk.y, picked_tile.x, picked_tile.y )
			if tiledef != nil && tiledef.collider_type == .None {
				valid_choice = true
			}
		}

		tom.picked_point = picked_tile
	}

	if tom.picked_point != tom.position.offsets {
		dir := tom.picked_point - tom.position.offsets
		dir_normalized := normalize_vec2( dir )
		dir = { i32( dir_normalized.x + 0.5 if dir_normalized.x > 0 else dir_normalized.x - 0.5 ), i32( dir_normalized.y + 0.5 if dir_normalized.y > 0 else dir_normalized.y - 0.5 ) }
		MoveEntity( tom, dir )
	}

	if s_TomBossData.phase == 1 {
		if s_TomBossData.frame_counter % (60*5) == 0{
			p := GetEntityByName( .Player )
			opposite_corner := p.position.offsets - (GetTileWorldCoordinate( 4, 4 ) + { TILE_SIZE / 2, TILE_SIZE / 2 })
			if opposite_corner.x < 0 && opposite_corner.y < 0 {
				opposite_corner = GetTileWorldCoordinate(10, 9)
			} else if opposite_corner.x >= 0 && opposite_corner.y < 0 {
				opposite_corner = GetTileWorldCoordinate(-1, 9)
			} else if opposite_corner.x < 0 && opposite_corner.y >= 0 {
				opposite_corner = GetTileWorldCoordinate(10, -1)
			} else if opposite_corner.x >= 0 && opposite_corner.y >= 0 {
				opposite_corner = GetTileWorldCoordinate(-1, -1)
			}
			bat := MakeBatEntity( opposite_corner.x, opposite_corner.y )
			bat.picked_point = p.position.offsets
		}
	}

	if tom.health_points == 10 && tom.received_damage == 1 {
		s_TomBossData.phase = 1
		s_TomBossData.enabled = false
		Dialog_Start( &TomPhase2Dialog )
		s_TomBossData.frame_counter = 0
	} else {
		s_TomBossData.frame_counter += 1
	}

}