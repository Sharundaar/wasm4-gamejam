package main

PopulateData :: struct {
	chunk_x, chunk_y: u8,
	populate_func : proc "contextless" (),
}

when USE_TEST_MAP {
ents_c00 := PopulateData{
	0, 0,
	proc "contextless" () {
		MakeMiruEntity()
	},
}

ents_c01 := PopulateData{
	1, 0,
	proc "contextless" () {
		MakeSwordAltarEntity()
	},
}

ents_c10 := PopulateData {
	0, 1,
	proc "contextless" () {
		if !Quest_IsComplete( .KilledBat1 ) {
			MakeBatEntity( GetTileWorldCoordinate2( 8, 6 ) ).on_death = proc "contextless" () {
				Dialog_Start( &BatDeathDialog3 )
				Quest_Complete( .KilledBat1 )
			}
		}
		if !Quest_IsComplete( .KilledBat2 ) {
			MakeBatEntity( GetTileWorldCoordinate2( 3, 6 ) ).on_death = proc "contextless" () {
				Quest_Complete( .KilledBat2 )
			}
		}
		if !Quest_IsComplete( .KilledBat3 ) {
			MakeBatEntity( GetTileWorldCoordinate2( 4, 2 ) ).on_death = proc "contextless" () {
				Quest_Complete( .KilledBat3 )
			}
		}
	},
}

ents_c11 := PopulateData{
	1, 1,
	proc "contextless" () {
		torch_chest := MakeChestEntity( GetTileWorldCoordinate2( 4, 7 ) )
		if Quest_IsComplete( .GotTorch ) {
			AnimatedSprite_NextFrame( &torch_chest.animated_sprite )
		} else {
			torch_chest.flags += {.Interactible}
			torch_chest.interaction = &TorchChestContainer
		}

		DisableAllLightsAndEnableDarkness()
		lights[1].enabled = true
		lights[1].pos = GetTileWorldCoordinateMidPoint( 4, 0 )
		lights[1].s = 4
		lights[1].r = 0.125
	
		lights[2].enabled = true
		lights[2].pos = GetTileWorldCoordinate( 1, 1 )
		lights[2].s = 4
		lights[2].r = 0.125
	
		lights[3].enabled = true
		lights[3].pos = GetTileWorldCoordinateMidPoint( 1, 5 )
		lights[3].s = 4
		lights[3].r = 0.125
		
		lights[4].enabled = true
		lights[4].pos = GetTileWorldCoordinate( 7, 5 )
		lights[4].s = 4
		lights[4].r = 0.125
	
		lights[5].enabled = true
		lights[5].pos = GetTileWorldCoordinateMidPoint( 4, 7 )
		lights[5].s = 4
		lights[5].r = 0.125
	},
}
}

EntranceDialog := DialogDef {
	"",
	{
		{"I can't leave", "there's still"},
		{"adventures", "to do !!"},
	},
	nil,
}


ents_entrance := PopulateData{
	0, 3,
	proc "contextless" () {
		DisableAllLightsAndEnableDarkness()
		EnableLight( 1, GetTileWorldCoordinateMidPoint( 0, 4 ), GetTileWorldCoordinateMidPoint( 9, 4 ), 32, 0.5 )
		EnableLight( 2, GetTileWorldCoordinate( 0, 2 ), GetTileWorldCoordinate( 0, 7 ), 32, 0.5 )

		entrance_dialog := AllocateEntity()
		entrance_dialog.position.offsets = GetTileWorldCoordinate( 0, 4 )
		entrance_dialog.collider = {{}, GetTileWorldCoordinate( 1, 5 ) }
		entrance_dialog.flags += {.Interactible}
		entrance_dialog.interaction = &EntranceDialog
	},
}

ents_entrance_right := PopulateData{
	1, 3,
	proc "contextless" () {
		DisableAllLightsAndEnableDarkness()
		EnableLight( 1, GetTileWorldCoordinateMidPoint( 0, 4 ), GetTileWorldCoordinateMidPoint( 6, 4 ), 32, 0.5 )
		EnableLight( 3, GetTileWorldCoordinate( 10, 0 ), GetTileWorldCoordinate( 10, 9 ), 16, 0.5 )
	},
}

ents_mirus_room := PopulateData {
	2, 3,
	proc "contextless" () {
		if Quest_IsComplete( .TalkedToMiruAfterBatDeath ) || ( Quest_IsComplete( .TalkedToTom ) && !Quest_IsComplete( .KilledBat3 ) ){
			UpdateTileInChunk( &s_gglob.tilemap, 2, 3, 7, 1, 1 )
		} else {
			miru := MakeMiruEntity()
			miru.position.offsets = GetTileWorldCoordinate( 5, 1 )
		}
	},
}

ents_bats_room := PopulateData{
	2, 4,
	proc "contextless" () {
		on_bat_death :: proc "contextless" () {
			if !Quest_IsComplete( .KilledBat1 ) { 
				Dialog_Start( &BatDeathDialog1 )
				Quest_Complete( .KilledBat1 )
			} else if !Quest_IsComplete( .KilledBat2 ) {
				Dialog_Start( &BatDeathDialog2 )
				Quest_Complete( .KilledBat2 )
			} else if !Quest_IsComplete( .KilledBat3 ) {
				Dialog_Start( &BatDeathDialog3 )
				Quest_Complete( .KilledBat3 )
			}
		}
	
		if !(Quest_IsComplete( .TalkedToTom ) && !Quest_IsComplete( .KilledBat3 )) {
			if !Quest_IsComplete( .KilledBat1 ) {
				MakeBatEntity( GetTileWorldCoordinate2( 8, 6 ) ).on_death = on_bat_death
			}
			if !Quest_IsComplete( .KilledBat2 ) {
				MakeBatEntity( GetTileWorldCoordinate2( 3, 6 ) ).on_death = on_bat_death
			}
			if !Quest_IsComplete( .KilledBat3 ) {
				MakeBatEntity( GetTileWorldCoordinate2( 4, 2 ) ).on_death = on_bat_death
			}
		} else {
			father := MakeBatEntity( GetTileWorldCoordinate2( 7, 6 ) ) ; father.name = .Default ; father.flags -= {.DamageMaker, .DamageReceiver}
			mother := MakeBatEntity( extract_ivec2( GetTileWorldCoordinate( 7, 6 ) + { 6, 4 } ) ) ; mother.name = .Default ; mother.flags -= {.DamageMaker, .DamageReceiver}
			dolores := MakeBatEntity( extract_ivec2( GetTileWorldCoordinate( 7, 6 ) + { -6, 4 } ) ) ; dolores.name = .Default ; dolores.flags -= {.DamageMaker, .DamageReceiver}
		}

		if Quest_IsComplete( .SawMirusFightCinematic ) {
			tom := MakeTomEntity()
			tom.position.offsets = GetTileWorldCoordinate( 1, 4 )
			tom.flags += {.Interactible}
			tom.interaction = &TomDialog_AfterMirusConfrontation
			tom.animated_sprite.sprite = &TomSprite_Hurt
		} else {
			if Quest_IsComplete( .TalkedToMiruAfterBatDeath ) || (Quest_IsComplete( .TalkedToTom ) && !Quest_IsComplete( .KilledBat3 )) {
				miru := MakeMiruEntity()
				miru.position.offsets = GetTileWorldCoordinate( 2, 1 )
			}
	
			if Quest_IsComplete( .TalkedToTom ) && !Quest_IsComplete( .KilledBat3 ) {
				tom := MakeTomEntity()
				tom.position.offsets = GetTileWorldCoordinate( 2, 2 )
				tom.flags += {.Interactible}
				tom.interaction = &TomDialog_ConfrontMiru
				tom.animated_sprite.sprite = &TomSprite_Back
				miru := GetEntityByName( .Miru )
				miru.interaction = &TomDialog_ConfrontMiru
			}
		}
	},
}

MiruBossStartInteraction := Trigger {
	proc "contextless" (ent_id: u8) {
		UpdateTileInChunk( &s_gglob.tilemap, 1, 4, 9, 7, 3 )
		Sound_Play( &Sound_OpenDoor )
		Dialog_Start( &MiruBossDialog )
		DestroyEntity( GetEntityById( ent_id ) )
	},
}
MiruBossDialog := DialogDef {
	"Miru",
	{{"blah blah", "let's fight"}},
	proc "contextless" () {
		StartMiruBoss()
	},
}

ents_mirus_boss_room := PopulateData {
	1, 4,
	proc "contextless" () {
		miru := MakeMiruEntity()
		miru.name = .MiruBoss
		miru.position.offsets = GetTileWorldCoordinate( 4, 1 )
		miru.flags -= {.Interactible, .Collidable}
		miru.flags += {.DamageMaker, .DamageReceiver}
		miru.picked_point = miru.position.offsets
		miru.on_death = MirusBossDeath

		boss_start_trigger := AllocateEntity()
		boss_start_trigger.flags += {.Interactible}
		boss_start_trigger.interaction = &MiruBossStartInteraction
		boss_start_trigger.collider = {GetTileWorldCoordinate(8, 7), GetTileWorldCoordinate(9, 8)}
		boss_start_trigger.collider.max.x -= 7
	},
}

TomBossDialog := DialogDef {
	"Tom",
	{{"blah blah", "let's fight"}},
	proc "contextless" () {
		StartTomBoss()
	},
}
TomBossStartInteraction := Trigger {
	proc "contextless" (ent_id: u8) {
		UpdateTileInChunk( &s_gglob.tilemap, 4, 1, 2, 8, 3 )
		Sound_Play( &Sound_OpenDoor )
		Dialog_Start( &TomBossDialog )
		s_gglob.last_valid_player_position = GetTileWorldCoordinate( 2, 7 ) + { 4, 4 }
		DestroyEntity( GetEntityById( ent_id ) )
	},
}

ents_toms_boss_room := PopulateData {
	4, 1,
	proc "contextless" () {
		tom := MakeTomEntity()
		tom.name = .TomBoss
		tom.position.offsets = GetTileWorldCoordinate( 5, 1 )
		tom.flags -= {.Collidable}
		tom.flags += {.DamageMaker, .DamageReceiver}
		tom.hurt_box = { {}, { 16, 16 } }
		tom.damage_flash_palette = 0x4120
		tom.on_death = TomBossDeath
		tom.picked_point = tom.position.offsets

		boss_start_trigger := AllocateEntity()
		boss_start_trigger.flags += {.Interactible}
		boss_start_trigger.interaction = &TomBossStartInteraction
		boss_start_trigger.collider = {GetTileWorldCoordinate(2, 7), GetTileWorldCoordinate(3, 8)}
		boss_start_trigger.collider.max.y -= 7
	},
}

ents_corridor_to_tom := PopulateData {
	3, 3,
	proc "contextless" () {
		DisableAllLightsAndEnableDarkness()
		EnableLight( 1, GetTileWorldCoordinateMidPoint( 0, 7 ), 2, 0.5 )
		EnableLight( 2, GetTileWorldCoordinateMidPoint( 6, 0 ), 4, 0.5 )
	},
}

SignTomsRoomShortcutDialog := DialogDef {
	"Sign",
	{
		{"In corridor", "to tom"},
		{ "start at", "intersection" },
		{"count 5 north", "count 2 east"},
		{"then go south", "then east"},
		{"finally north", "will be the exit"},
	},
	nil,
}

ents_toms_room := PopulateData {
	3, 2,
	proc "contextless" () {
		if !Quest_IsComplete( .TalkedToTom ) {
			tom := MakeTomEntity()
			tom.position.offsets = GetTileWorldCoordinate( 2, 1 )
			tom.flags += {.Interactible}
			if Quest_IsComplete( .KilledBat3 ) {
				tom.interaction = &TomDialog_BatDead
			} else {
				tom.interaction = &TomDialog_BatAlive
			}

			MakeSignEntity( GetTileWorldCoordinate2( 6, 0 ), &SignTomsRoomShortcutDialog )
		}
	},
}

ents_sword_altar_room := PopulateData{
	3, 4,
	proc "contextless" () {
		altar := MakeSwordAltarEntity()
		altar.position.offsets = GetTileWorldCoordinate( 6, 3 ) - { i32( altar.animated_sprite.sprite.w / 2 ), i32( altar.animated_sprite.sprite.h / 2 ) }

		sign := MakeSignEntity( GetTileWorldCoordinate2( 4, 0 ), &SignTomDialog )
	},
}

ents_torch_chest_room := PopulateData{
	4, 2,
	proc "contextless" () {
		torch_chest := MakeChestEntity( GetTileWorldCoordinate2( 8, 2 ) )
		if Quest_IsComplete( .GotTorch ) {
			AnimatedSprite_NextFrame( &torch_chest.animated_sprite )
		} else {
			torch_chest.flags += {.Interactible}
			torch_chest.interaction = &TorchChestContainer
		}

		if !Quest_IsComplete( .TalkedToTom ) {
			UpdateTileInChunk( &s_gglob.tilemap, 4, 2, 2, 0, 3 )
		}
	
		DisableAllLightsAndEnableDarkness()
		EnableLight( 1, GetTileWorldCoordinateMidPoint( 1, 7 ), 2 )
		EnableLight( 2, GetTileWorldCoordinateMidPoint( 8, 7 ), 2 )
		EnableLight( 3, GetTileWorldCoordinateMidPoint( 5, 4 ), 2 )
		EnableLight( 4, GetTileWorldCoordinateMidPoint( 8, 2 ), 2 )
	},
}

ents_from_miru_to_tom := PopulateData {
	2, 2,
	proc "contextless" () {
		DisableAllLightsAndEnableDarkness()
		EnableLight( 1, GetTileWorldCoordinateMidPoint( 8, 8 ), GetTileWorldCoordinateMidPoint( 8, 3 ), 48 )
	},
}

HeartChest := Container {
	proc "contextless" ( ent_id: u8 ) {
		chest := GetEntityById( ent_id )
		chest.flags -= {.Interactible}
		AnimatedSprite_NextFrame( &chest.animated_sprite )
		player := GetEntityByName( .Player )
		Inventory_GiveNewItem( player, .Heart )
		Quest_Complete( .GotHeartContainer )
	},
}

ents_heart_chest := PopulateData {
	1, 2,
	proc "contextless" () {
		DisableAllLightsAndEnableDarkness()
		heart_chest := MakeChestEntity( GetTileWorldCoordinate2( 3, 4 ) )
		if Quest_IsComplete( .GotHeartContainer ) {
			AnimatedSprite_NextFrame( &heart_chest.animated_sprite )
		} else {
			heart_chest.flags += {.Interactible}
			heart_chest.interaction = &HeartChest
		}
	},
}


populate_funcs := []^PopulateData {
	&ents_entrance,
	&ents_entrance_right,
	&ents_mirus_room,
	&ents_bats_room,
	&ents_corridor_to_tom,
	&ents_sword_altar_room,
	&ents_torch_chest_room,
	&ents_toms_room,
	&ents_mirus_boss_room,
	&ents_toms_boss_room,
	&ents_from_miru_to_tom,
	&ents_heart_chest,
}