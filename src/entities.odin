package main

/*
****************************
*           Bat            *
****************************
*/

BatAnimation := AnimatedSprite {
	ImageKey.bat, 8, 8, 0,
	{
		AnimationFrame{ 15, 0, nil },
		AnimationFrame{ 15, 8, nil },
	},
}
BatDeathDialog1 := DialogDef {
	"Bat",
	{
		{ "DOLORES", "NOOOO" },
	},
	nil,
}
BatDeathDialog2 := DialogDef {
	"Bat",
	{
		{ "she was my wife", "you bastard !" },
	},
	nil,
}
BatDeathDialog3 := DialogDef {
	"Bat",
	{
		{ "noo", "why did you kill mee" },
		{ "i had", "a family" },
	},
	nil,
}

MakeBatEntity :: proc "contextless" ( x, y: i32 ) -> ^Entity {
	ent := AllocateEntity( EntityName.Bat )

	ent.name = EntityName.Bat
	ent.position = { {}, { x, y } }
	ent.flags += { .AnimatedSprite, .DamageReceiver, .DamageMaker }
	ent.collider = { {}, {8, 8} }
	ent.hurt_box = { { 0, 2 }, {8, 7} }
	ent.animated_sprite.sprite = &BatAnimation
	ent.health_points = 2
	ent.palette_mask = 0x130
	ent.damage_flash_palette = 0x110
	ent.picked_point = ent.position.offsets

	return ent
}

/*
****************************
*           Miru           *
****************************
*/

MiruAnimation := AnimatedSprite {
	ImageKey.miru, 16, 16, 0,
	{
		AnimationFrame{ 50, 0, nil },
		AnimationFrame{ 50, 0, {.FlipX} },
	},
}
MirusDialog := DialogDef {
	"Miru",
	{
		{ "Oh hi !", "you're new ?" },
		{ "Can you give", "me a hand ?" },
		{ "Kill the bats", "south of here" },
		{ "There's a sword", "east of here" },
	},
	nil,
}
MirusDialog_KilledBat := DialogDef {
	"Miru",
	{
		{ "You did it!", "" },
		{ "Thanks, let me", "open the door"},
	},
	proc "contextless" () {
		if !Quest_IsComplete( .TalkedToMiruAfterBatDeath ) {
			Quest_Complete( .TalkedToMiruAfterBatDeath )
			UpdateTileInChunk( &s_gglob.tilemap, 2, 3, 7, 1, 1 )
			Sound_Play( &Sound_OpenDoor )
		}
	},
}
MirusDialog_InBatRoom := DialogDef {
	"Miru",
	{
		{ "*sigh*", "" },
		{ "Much better now", "that those dirty" },
		{ "things are dead.", "Go away now." },
	},
	nil,
}


MakeMiruEntity :: proc "contextless" () -> ^Entity {
	ent := AllocateEntity( EntityName.Miru )

	ent.position = { {}, GetTileWorldCoordinate( 3, 1 ) }
	ent.flags += {.Interactible, .AnimatedSprite, .Collidable}
	ent.animated_sprite.sprite = &MiruAnimation
	ent.looking_dir = { 0, 1 }
	ent.collider = { { 0, 0 }, { 16, 16 } }
	ent.palette_mask = 0x0210
	ent.interaction = &MirusDialog
	ent.max_health_points = 30
	ent.health_points = 30
	if Quest_IsComplete( .TalkedToMiruAfterBatDeath ) {
		ent.interaction = &MirusDialog_InBatRoom
	} else if Quest_AreComplete( {.KilledBat1, .KilledBat2, .KilledBat3} ) {
		ent.interaction = &MirusDialog_KilledBat
	}

	return ent
}

/*
****************************
*           Tom            *
****************************
*/

TomCinematic_BatAlive := Cinematic {
    {
        {Cinematic_MoveEntityStep( .Tom, 2, 3, 45, false )},
        {proc "contextless" (controller: ^CinematicController) -> bool {
			tom := GetEntityByName( .Tom )
			// Hack: Ideally I'd write a directional state for animated sprite
			tom.animated_sprite.sprite = &TomSprite_LeftRight
			tom.animated_sprite.current_frame = 0
			tom.animated_sprite.flags += {.FlipX}
			return Cinematic_MoveEntityStep( .Tom, -1, 3, 60, false )( controller )
		}},
        {proc "contextless" (controller: ^CinematicController) -> bool {
            DestroyEntity( GetEntityByName( .Tom ) )
            return true
        }},
    },
}

TomCinematic_BatDead := Cinematic {
    {
        {Cinematic_MoveEntityStep( .Tom, 7, 6, 60, false )},
        {Cinematic_MoveEntityStep( .Tom, 10, 6, 30, false )},
        {proc "contextless" (controller: ^CinematicController) -> bool {
            DestroyEntity( GetEntityByName( .Tom ) )
            return true
        }},
    },
}



TomSprite_Front := AnimatedSprite {
	ImageKey.tom, 16, 16, 0,
	{
		AnimationFrame{ 50, 0, nil },
		AnimationFrame{ 50, 0, {.FlipX} },
	},
}
TomSprite_Back := AnimatedSprite {
	ImageKey.tom, 16, 16, 0,
	{
		AnimationFrame{ 50, 32, nil },
		AnimationFrame{ 50, 32, {.FlipX} },
	},
}
TomSprite_LeftRight := AnimatedSprite {
	ImageKey.tom, 16, 16, 0,
	{
		AnimationFrame{ 50, 16, nil },
	},
}
TomSprite_Hurt := AnimatedSprite {
	ImageKey.tom, 16, 16, 0,
	{
		AnimationFrame{ 0, 48, nil },
	},
}


TomDialog_BatDead := DialogDef {
	"Tom",
	{
		{ "YOU DID WHAT ?!", "" },
		{ "THE ECOSYSTEM !", "" },
		{ "THE GROTTO !", "" },
	},
	proc "contextless" () {
		Cinematic_Play( &TomCinematic_BatDead )
		Quest_Complete( .TalkedToTom )
	},
}
TomDialog_BatAlive := DialogDef {
	"Tom",
	{
		{ "Hey ! I'm Tom", "What's up" },
		{ "They asked", "you what ?"},
		{ "KILL THE BAT ?!", "They're insane" },
		{ "I'll go", "talk to them" },
	},
	proc "contextless" () {
		// run to bat room
		Cinematic_Play( &TomCinematic_BatAlive )
		Quest_Complete( .TalkedToTom )
	},
}
TomDialog_ConfrontMiru := DialogDef {
	"Tom",
	{
		{ "You can't kill", "the bats !" },
		{ "The grotto ecosystem", "depends on it" },
	},
	proc "contextless" () {
		Dialog_Start( &MirusDialog_FightTom )
	},
}
TomDialog_AfterMirusConfrontation := DialogDef {
	"Tom",
	{
		{"Go, stop her", ""},
		{"I'm too", "weak..."},
	},
	nil,
}

MirusDialog_FightTom := DialogDef {
	"Miru",
	{
		{ "Do I look", "like I care ?" },
		{ "They're gross", "" },
		{ "Get out of", "my face" },
	},
	proc "contextless" () {
		// cinematic
		Cinematic_Play( &MirusCinematic_FightTom )
	},
}

FireballSprite_LeftRight := AnimatedSprite {
	ImageKey.mirus_fireball, 15, 10, 2,
	{
		{ 25, 0, nil },
		{ 25, 0, {.FlipY} },
	},
}

FireballSprite_UpDown := AnimatedSprite {
	ImageKey.mirus_fireball, 10, 15, 1,
	{
		{ 25, 18, nil },
		{ 25, 18, {.FlipX} },
	},
}

MirusCinematic_FightTom := Cinematic {
	{
		{Cinematic_MoveEntityStep(.Tom, 2, 4, 15, false)},
		{proc "contextless" (controller: ^CinematicController) -> bool {
			if controller.frame_counter == 0 {
				fireball := AllocateEntity()
				fireball.flags += {.AnimatedSprite}
				fireball.animated_sprite.sprite = &FireballSprite_UpDown
				fireball.animated_sprite.flags += {.FlipY}
				fireball.name = .MirusFireball
				fireball.position = {{ 2, 4 }, GetTileWorldCoordinate(2, 2) + { 4, 0 }}
				fireball.palette_mask = 0x1230
				Sound_Play( &PlayerSound_SwingSword )
			}
			return Cinematic_MoveEntityStep( .MirusFireball, 2 * TILE_SIZE + 4, 4 * TILE_SIZE, 10, true )( controller )
		}},
		{proc "contextless" (controller: ^CinematicController) -> bool {
			if controller.frame_counter == 0 {
				tom := GetEntityByName( .Tom )
				tom.flags += {.DamageReceiver}
				tom.pushed_back_cached_pos = tom.position.offsets
				tom.pushed_back_dist = {
					-16,
					0,
				}
				InflictDamage( tom )
			}
			return controller.frame_counter >= 24
		}},
		{proc "contextless" (controller: ^CinematicController) -> bool {
			if controller.frame_counter == 0 {
				tom := GetEntityByName( .Tom )
				AnimationController_SetSprite( &tom.animated_sprite, &TomSprite_Hurt )
				tom.flags -= {.DamageReceiver}
				DestroyEntity( GetEntityByName( .MirusFireball ) )
			}
			return Cinematic_MoveEntityStep( .Miru, 2, 7, 30, false )( controller )
		}},
		{proc "contextless" (controller: ^CinematicController) -> bool {
			if controller.frame_counter == 0 {
				UpdateTileInChunk( &s_gglob.tilemap, 2, 4, 0, 7, 1 )
				Sound_Play( &Sound_OpenDoor )
			}
			return Cinematic_MoveEntityStep( .Miru, -1, 7, 15, false )( controller )
		}},
		{proc "contextless" (controller: ^CinematicController) -> bool {
			Quest_Complete( .SawMirusFightCinematic )
			tom := GetEntityByName( .Tom )
			tom.interaction = &TomDialog_AfterMirusConfrontation
			miru := GetEntityByName( .Miru )
			if miru != nil {
				DestroyEntity( miru )
			}
			return true
		}},
	},
}

MakeTomEntity :: proc "contextless" () -> ^Entity {
	ent := AllocateEntity( EntityName.Tom )

	ent.name = .Tom
	ent.position = { {}, {} }
	ent.flags += {.AnimatedSprite, .Collidable}
	ent.animated_sprite.sprite = &TomSprite_Front
	ent.looking_dir = { 0, 1 }
	ent.collider = { { 0, 0 }, { 16, 16 } }
	ent.palette_mask = 0x1420
	ent.max_health_points = 30
	ent.health_points = 30

	return ent
}


/*
****************************
*       Sword Altar        *
****************************
*/


SwordAltarSprite := AnimatedSprite {
	ImageKey.sword_altar, 5, 7, 0,
	{
		AnimationFrame{ 0, 0, nil },
		AnimationFrame{ 0, 5, nil },
	},
}
SwordAltarContainer := Container {
	proc "contextless" ( ent_id: u8 ) {
		altar := GetEntityById( ent_id )
		altar.flags -= {.Interactible}
		AnimatedSprite_NextFrame( &altar.animated_sprite )
		player := GetEntityByName( EntityName.Player )
		Inventory_GiveNewItem( player, InventoryItem.Sword )
		Quest_Complete( .GotSword )
	},
}
MakeSwordAltarEntity :: proc "contextless" () -> ^Entity {
	ent := AllocateEntity( EntityName.SwordAltar )

	ent.position = { {}, GetTileWorldCoordinate( 5, 4 ) }
	ent.name = EntityName.SwordAltar
	ent.flags += {.Interactible, .AnimatedSprite, .Collidable}
	ent.animated_sprite.sprite = &SwordAltarSprite
	ent.palette_mask = 0x0210
	ent.collider = { { 0, 0 }, { 5, 7 } }
	ent.interaction = &SwordAltarContainer

	if Quest_IsComplete( .GotSword ) {
		player := GetEntityByName( .Player )
		if player != nil && !Inventory_HasItem( player, .Sword ) {
			Inventory_GiveNewItem_Immediate( player, .Sword )
		}
		ent.flags -= {.Interactible}
		AnimatedSprite_NextFrame( &ent.animated_sprite )
	}

	return ent
}

/*
****************************
*           Chest          *
****************************
*/

TorchChestContainer := Container {
	proc "contextless" ( ent_id: u8 ) {
		chest := GetEntityById( ent_id )
		chest.flags -= {.Interactible}
		AnimatedSprite_NextFrame( &chest.animated_sprite )
		player := GetEntityByName( .Player )
		Inventory_GiveNewItem( player, .Torch)
		Quest_Complete( .GotTorch )
	},
}


ChestSprite := AnimatedSprite {
	ImageKey.chest, 8, 8, 0,
	{
		AnimationFrame{ 0, 0, nil },
		AnimationFrame{ 0, 8, nil },
	},
}
MakeChestEntity :: proc "contextless" ( x, y: i32 ) -> ^Entity {
	ent := AllocateEntity()

	ent.position = { {}, { x + 4, y + 4 } }
	ent.flags += { .AnimatedSprite, .Collidable }
	ent.animated_sprite.sprite = &ChestSprite
	ent.palette_mask = 0x4320
	ent.collider = { { 0, 0 }, { 8, 8 } }

	return ent
}

/*
****************************
*           Sign           *
****************************
*/

SignTomDialog := DialogDef {
	"Sign",
	{
		{ "Please, do not", "kill the bats." },
		{ "", "        -- Tom" },
	},
	nil,
}
SignSprite := AnimatedSprite {
	ImageKey.sign, 8, 8, 0,
	{
		AnimationFrame{ 0, 0, nil },
	},
}

MakeSignEntity :: proc "contextless" ( tile_x, tile_y: i32, content: ^DialogDef ) -> ^Entity {
	ent := AllocateEntity()

	ent.flags += {.AnimatedSprite, .Interactible}
	ent.position = { {}, { tile_x + 4, tile_y + 8 } }
	ent.interaction = content
	ent.collider = { {-4, -4}, { 12, 12 } }
	ent.animated_sprite.sprite = &SignSprite
	ent.palette_mask = 0x0412

	return ent
}
