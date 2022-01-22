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


ents_entrance := PopulateData{
	0, 3,
	proc "contextless" () {
		DisableAllLightsAndEnableDarkness()
		EnableLight( 1, GetTileWorldCoordinateMidPoint( 1, 4 ) )
		EnableLight( 2, GetTileWorldCoordinateMidPoint( 3, 4 ) )
		EnableLight( 3, GetTileWorldCoordinateMidPoint( 5, 4 ) )
		EnableLight( 4, GetTileWorldCoordinateMidPoint( 7, 4 ) )
		EnableLight( 5, GetTileWorldCoordinateMidPoint( 9, 4 ) )
	},
}

ents_entrance_right := PopulateData{
	1, 3,
	proc "contextless" () {
		DisableAllLightsAndEnableDarkness()
		EnableLight( 1, GetTileWorldCoordinateMidPoint( 1, 4 ) )
		EnableLight( 2, GetTileWorldCoordinateMidPoint( 3, 4 ) )
		EnableLight( 3, GetTileWorldCoordinateMidPoint( 9, 4 ), 2, 0.5 )
	},
}

ents_mirus_room := PopulateData {
	2, 3,
	proc "contextless" () {
		if Quest_IsComplete( .TalkedToMiruAfterBatDeath ) {
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
	
		if !Quest_IsComplete( .KilledBat1 ) {
			MakeBatEntity( GetTileWorldCoordinate2( 8, 6 ) ).on_death = on_bat_death
		}
		if !Quest_IsComplete( .KilledBat2 ) {
			MakeBatEntity( GetTileWorldCoordinate2( 3, 6 ) ).on_death = on_bat_death
		}
		if !Quest_IsComplete( .KilledBat3 ) {
			MakeBatEntity( GetTileWorldCoordinate2( 4, 2 ) ).on_death = on_bat_death
		}
	
		if Quest_IsComplete( .TalkedToMiruAfterBatDeath ) {
			miru := MakeMiruEntity()
			miru.position.offsets = GetTileWorldCoordinate( 2, 1 )
		}
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
	
		DisableAllLightsAndEnableDarkness()
		EnableLight( 1, GetTileWorldCoordinateMidPoint( 1, 7 ), 2 )
		EnableLight( 2, GetTileWorldCoordinateMidPoint( 8, 7 ), 2 )
		EnableLight( 3, GetTileWorldCoordinateMidPoint( 5, 4 ), 2 )
		EnableLight( 4, GetTileWorldCoordinateMidPoint( 8, 2 ), 2 )
	},
}