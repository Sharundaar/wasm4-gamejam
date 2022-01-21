package main

DEVELOPMENT_BUILD :: false
PRINT_FUNC :: false
USE_TEST_MAP :: false
SHOW_HURT_BOX :: false
SHOW_COLLIDER :: false
SHOW_LAST_VALID_POSITION :: false
SHOW_TILE_BROADPHASE_TEST :: false
SKIP_INTRO :: true
START_WITH_SWORD :: false
TEST_DEATH_ANIMATION :: false
NO_CLIP :: false

import "w4"
import "core:math"

when PRINT_FUNC {
	import "core:strconv"
	import "core:runtime"
}
print_float :: proc "contextless" ( f: f32 ) {
when PRINT_FUNC {
	buf : [24]byte
	context = runtime.default_context()
	str := strconv.ftoa( buf[:], f64(f), 'f', -1, 32 )
	w4.trace( str )
}
}

print_int :: proc "contextless" ( i: i32 ) {
when PRINT_FUNC {
	buf : [24]byte
	context = runtime.default_context()
	str := strconv.itoa( buf[:], int(i) )
	w4.trace( str )
}
}
	
ivec2 :: distinct [2]i32
i8vec2 :: distinct [2]i8
rect :: struct {
	min, max: ivec2,
}

translate_rect :: proc "contextless" ( r: rect, v: ivec2 ) -> rect {
	return {
		r.min + v,
		r.max + v,
	}
}

normalize_vec2 :: proc "contextless" ( v: ivec2 ) -> [2]f32 {
	l := math.sqrt( f32(v.x*v.x + v.y*v.y) )
	if l < 0.01 do return {}
	return { f32(v.x) / l, f32(v.y) / l }
}

GameState :: enum {
	MainMenu,
	GameOverScreen,
	Game,
	Dialog,
	NewItemAnimation,
	GameOverAnimation,
}

InputState :: struct {
	APressed, AReleased, ADown: bool,
	BPressed, BReleased, BDown: bool,
}

GameGlob :: struct {
	tilemap: TileMap,
	active_chunk_coords: ivec2,
	game_state: GameState,
	input_state: InputState,
	dialog_ui: DialogUIData,
	global_frame_counter: u64,
	fading_counter: u8,
	fading_out: b8,
	mid_fade_callback : proc "contextless" (),
	new_item_animation_counter : u16,
	new_item : InventoryItem,
	new_item_entity_target : ^Entity,
	quest_data: QuestData,
	darkness_enabled: bool,
	last_valid_player_position : ivec2,
}
s_gglob : GameGlob

GlobalCoordinates :: struct {
	chunk: ivec2,
	offsets: ivec2,
	// sub_pixel_offset: i8vec2, // when reach 100, regularize offsets to + 1, used for small movements
}

RegularizeCoordinate :: proc "contextless" ( coord: GlobalCoordinates, move_chunks := true ) -> GlobalCoordinates {
	result := coord
	when false {
		result = ApplySubPixelCoordinate( result )
	}
	if move_chunks {
		for n in 0..<2 {
			l := TILE_CHUNK_COUNT_W if n == 0 else TILE_CHUNK_COUNT_H
			l *= TILE_SIZE
			for result.offsets[n] >= l {
				result.offsets[n] -= l
				result.chunk[n] += 1
			}
			for result.offsets[n] < 0 {
				result.offsets[n] += l
				result.chunk[n] -= 1
			}
		}
	}
	return result
}

Light :: struct {
	enabled: bool,
	pos: ivec2,
	s: f32,
	r: f32,
}
lights : [8]Light

tiledef := []TileDefinition{
	{ { 16, 0 }, .Solid }, // wall
	{ { 16*2, 0 }, .None }, // floor
	{ { 0, 16 }, .Hole }, // hole
	{ { 16, 16 }, .Solid }, // door
}

BatAnimation := AnimatedSprite {
	ImageKey.bat, 8, 8, 0,
	{
		AnimationFrame{ 15, 0, nil },
		AnimationFrame{ 15, 8, nil },
	},
}

UpdateInputState :: proc "contextless" () {
	using s_gglob.input_state
	APressed = false ; AReleased = false
	BPressed = false ; BReleased = false

	wasADown, wasBDown := ADown, BDown
	ADown, BDown = .A in w4.GAMEPAD1^, .B in w4.GAMEPAD1^

	if !wasADown && ADown do APressed = true
	if wasADown && AReleased do AReleased = true
	if !wasBDown && BDown do BPressed = true
	if wasBDown && BReleased do BReleased = true
}

DrawRect :: proc "contextless" ( r: rect, color: u16 = 0 ) {
	w4.DRAW_COLORS^ = color
	if color == 0 do w4.DRAW_COLORS^ = 0x12
	w4.rect( r.min.x, r.min.y, u32( r.max.x - r.min.x ), u32( r.max.y - r.min.y ) )
}

// draw chunk with x/y offset from top of the screen
DrawTileChunk :: proc "contextless" ( tilemap: ^TileMap, chunk_x, chunk_y, x_offs, y_offs: i32 ) {
	chunk := &tilemap.chunks[TILEMAP_CHUNK_COUNT_W * i32(chunk_y) + i32(chunk_x)];
	print_buffer : [256]byte
	for y in 0..<TILE_CHUNK_COUNT_H do for x in 0..<TILE_CHUNK_COUNT_W {
		w4.DRAW_COLORS^ = 0x1234
		tile := chunk.tiles[y * TILE_CHUNK_COUNT_W + x]
		// context = runtime.default_context()
		// str := fmt.bprint( print_buffer[:], tile )
		// w4.trace( str )
		def := tilemap.tiledef[tile]
		pos_screen := ivec2 {
			i32(x_offs) + x * TILE_SIZE,
			i32(y_offs) + y * TILE_SIZE,
		}
		w4.blit_sub( &tilemap.tileset.bytes[0], pos_screen.x, pos_screen.y, u32( TILE_SIZE ), u32( TILE_SIZE ), u32( def.offsets.x ), u32( def.offsets.y ), int(tilemap.tileset.w), tilemap.tileset.flags )

		when SHOW_COLLIDER {
			{
				c := tilemap.active_chunk_colliders[y * TILE_CHUNK_COUNT_W + x]
				using c
				if has_collider {
					DrawRect( collider )
				}
			}
		}
	}
}

DrawDitherPattern :: proc "contextless" () {
	DW, DH :: 160, 144
	texture : [(DW/8)*DH]u8
	
	w4.DRAW_COLORS^ = 0x0004
	color_at_px_for_light :: proc "contextless" ( l: Light, x, y: i32 ) -> f32 {
		if !l.enabled do return 0
		pxx, pyy := f32(l.pos.x) / DW, f32(l.pos.y) / DH
		xx, yy := f32(x) / DW, f32(y) / DH
		xx -= pxx
		yy -= pyy
		xx *= l.s
		yy *= l.s
		c := math.sqrt(xx*xx+yy*yy)
		if c >= 1 do return 0
		return 1 - c
	}

	nearest :: proc "contextless" ( c: f32 ) -> u8 {
		if c > 0.5 do return 1
		else do return 0
	}

	bayer_matrix := [4][4]f32 {
		{    -0.5,       0,  -0.375,   0.125 },
		{    0.25,   -0.25,   0.375, - 0.125 },
		{ -0.3125,  0.1875, -0.4375,  0.0625 },
		{  0.4375, -0.0625,  0.3125, -0.1875 },
	}

	for y in i32(0)..<DH do for x in i32(0)..<DW {
		c : u8
		for l in lights {
			c += nearest( color_at_px_for_light(l, x, y) + l.r * bayer_matrix[y % 4][x % 4] )
		}
		if c > 1 do c = 1
		bit := u32( y * DW + x )
		idx := bit / 8
		bit = (8-(bit % 8)) - 1
		texture[idx] = texture[idx] | (c << bit)
	}
	w4.blit( &texture[0], 0, 0, DW, DH )
}

DrawStatusUI :: proc "contextless" () {
	status_bar := GetImage( ImageKey.status_bar )
	w4.DRAW_COLORS^ = 0x0001
	w4.blit( &status_bar.bytes[0], 0, i32(160-status_bar.h), status_bar.w, status_bar.h, status_bar.flags )
	
	player := GetEntityByName( EntityName.Player )
	
	// draw health
	half_heart := GetImage( ImageKey.half_heart )
	HEART_LEFT_OFFSET :: 8
	HEART_TOP_POSITION :: 160 - 16 + 4
	HEART_SPACING :: 6
	x : i32 = HEART_LEFT_OFFSET
	w4.DRAW_COLORS^ = 0x0320
	for i in 0..<player.max_health_points {
		even := (i % 2) == 0
		flags := half_heart.flags
		if !even do flags += {.FLIPX}
		w4.blit( &half_heart.bytes[0], x, HEART_TOP_POSITION, half_heart.w, half_heart.h, flags )
		if player.health_points <= (i+1) do w4.DRAW_COLORS^ = 0x0020
		x += i32(half_heart.w) if even else HEART_SPACING
	}

	// draw inventory
	INVENTORY_LEFT_OFFSET  :: 160 - ( i32(InventoryItem.Count) * ( INVENTORY_ITEM_SIZE + INVENTORY_ITEM_SPACING ) )
	INVENTORY_TOP_POSITION :: 160 - 16 + 4
	DrawInventory( INVENTORY_LEFT_OFFSET, INVENTORY_TOP_POSITION, &player.inventory )
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

Sound_OpenDoor := Sound {
	{
		{ 500, 300, 0, {sustain=10}, .Noise, 25 },
	},
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
	if Quest_IsComplete( .TalkedToMiruAfterBatDeath ) {
		ent.interaction = &MirusDialog_InBatRoom
	} else if Quest_AreComplete( {.KilledBat1, .KilledBat2, .KilledBat3} ) {
		ent.interaction = &MirusDialog_KilledBat
	}

	return ent
}

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

ents_c00 :: proc "contextless" () {
	MakeMiruEntity()
}

ents_c01 :: proc "contextless" () {
	MakeSwordAltarEntity()
}

EnableLight :: proc "contextless" ( idx: u8, pos: ivec2, s : f32 = 4, r: f32 = 0.125 ) {
	lights[idx].enabled = true
	lights[idx].pos = pos
	lights[idx].s = s
	lights[idx].r = r
}

ents_entrance :: proc "contextless" () {
	DisableAllLightsAndEnableDarkness()
	EnableLight( 1, GetTileWorldCoordinateMidPoint( 1, 4 ) )
	EnableLight( 2, GetTileWorldCoordinateMidPoint( 3, 4 ) )
	EnableLight( 3, GetTileWorldCoordinateMidPoint( 5, 4 ) )
	EnableLight( 4, GetTileWorldCoordinateMidPoint( 7, 4 ) )
	EnableLight( 5, GetTileWorldCoordinateMidPoint( 9, 4 ) )
}

ents_entrance_right :: proc "contextless" () {
	DisableAllLightsAndEnableDarkness()
	EnableLight( 1, GetTileWorldCoordinateMidPoint( 1, 4 ) )
	EnableLight( 2, GetTileWorldCoordinateMidPoint( 3, 4 ) )
	EnableLight( 3, GetTileWorldCoordinateMidPoint( 9, 4 ), 2, 0.5 )
}

ents_mirus_room :: proc "contextless" () {
	if Quest_IsComplete( .TalkedToMiruAfterBatDeath ) {
		UpdateTileInChunk( &s_gglob.tilemap, 2, 3, 7, 1, 1 )
	} else {
		miru := MakeMiruEntity()
		miru.position.offsets = GetTileWorldCoordinate( 5, 1 )
	}
}

ents_bats_room :: proc "contextless" () {
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
}

ents_corridor_to_tom :: proc "contextless" () {
	DisableAllLightsAndEnableDarkness()
	EnableLight( 1, GetTileWorldCoordinateMidPoint( 0, 7 ), 2, 0.5 )
}

ents_sword_altar_room :: proc "contextless" () {
	altar := MakeSwordAltarEntity()
	altar.position.offsets = GetTileWorldCoordinate( 6, 3 ) - { i32( altar.animated_sprite.sprite.w / 2 ), i32( altar.animated_sprite.sprite.h / 2 ) }
}

ents_torch_chest_room :: proc "contextless" () {
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

ents_c10 :: proc "contextless" () {
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
}

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

DisableAllLightsAndEnableDarkness :: proc "contextless" () {
	s_gglob.darkness_enabled = true
	for i in 1..<len(lights) {
		lights[i].enabled = false
	}
}

ents_c11 :: proc "contextless" () {
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

MakeWorldMap :: proc "contextless" () {
	using s_gglob

	tilemap.chunks = tilemap_chunks[:]
	GetChunkFromChunkCoordinates( &tilemap, 0, 0 ).populate_function = ents_c00
	GetChunkFromChunkCoordinates( &tilemap, 1, 0 ).populate_function = ents_c01
	GetChunkFromChunkCoordinates( &tilemap, 0, 1 ).populate_function = ents_c10
	GetChunkFromChunkCoordinates( &tilemap, 1, 1 ).populate_function = ents_c11

	GetChunkFromChunkCoordinates( &tilemap, 0, 3 ).populate_function = ents_entrance
	GetChunkFromChunkCoordinates( &tilemap, 1, 3 ).populate_function = ents_entrance_right
	GetChunkFromChunkCoordinates( &tilemap, 2, 3 ).populate_function = ents_mirus_room
	GetChunkFromChunkCoordinates( &tilemap, 2, 4 ).populate_function = ents_bats_room
	GetChunkFromChunkCoordinates( &tilemap, 3, 3 ).populate_function = ents_corridor_to_tom
	GetChunkFromChunkCoordinates( &tilemap, 3, 4 ).populate_function = ents_sword_altar_room
	GetChunkFromChunkCoordinates( &tilemap, 4, 2 ).populate_function = ents_torch_chest_room

	tilemap.tileset = GetImage( ImageKey.tileset )
	tilemap.tiledef = tiledef
}

@export
start :: proc "c" () {
	using s_gglob

	print_int( size_of( Entity ) )

	(w4.PALETTE^)[0] = 0xdad3af
	(w4.PALETTE^)[1] = 0xd58863
	(w4.PALETTE^)[2] = 0xc23a73
	(w4.PALETTE^)[3] = 0x2c1e74

	{
		player := MakePlayer()
		when USE_TEST_MAP {
			player.position.chunk = { 0, 0 }
			player.position.offsets = { 76, 76 }
		} else {
			// official entrance
			// player.position.chunk = { 0, 3 }
			// player.position.offsets = GetTileWorldCoordinate( 1, 4 ) + { 2, 4 }

			// sword altar room
			// player.position.chunk = { 3, 4 }
			// player.position.offsets = GetTileWorldCoordinate( 4, 2 ) + { 2, 4 }

			// mirus room
			player.position.chunk = { 2, 3 }
			player.position.offsets = GetTileWorldCoordinate( 4, 2 ) + { 2, 4 }

			Quest_Complete( .KilledBat1 )
			Quest_Complete( .KilledBat2 )
			Quest_Complete( .KilledBat3 )
		}
		s_gglob.last_valid_player_position = player.position.offsets
	}
	active_chunk_coords = { -1, -1 }

	MakeWorldMap()

	when SKIP_INTRO {
		game_state = GameState.Game
		InitRand( 0 )
	}
}

fake_sin :: proc "contextless" ( x: f32 ) -> f32 {
	sign : f32 = 1 if x >= 0 else -1
	x := x if x >= 0 else -x

	for x > math.PI {
		x -= math.PI
		sign = -sign
	}

	return sign * 4*x / (math.PI*math.PI) * (math.PI - x)
}



UpdateFade :: proc "contextless" () {
	if s_gglob.fading_counter > 0 {
		s_gglob.fading_counter += 1
		if s_gglob.fading_out {
			if s_gglob.fading_counter > 120 {
				s_gglob.fading_out = false
				s_gglob.fading_counter = 1
				s_gglob.mid_fade_callback()
			}
			else if s_gglob.fading_counter > 90 {
				(w4.PALETTE^)[0] = 0x2c1e73
				(w4.PALETTE^)[1] = 0x2c1e73
				(w4.PALETTE^)[2] = 0x2c1e73
			} else if s_gglob.fading_counter > 60 {
				(w4.PALETTE^)[0] = 0x665A88
				(w4.PALETTE^)[1] = 0x64416E
				(w4.PALETTE^)[2] = 0x5E2774
			} else if s_gglob.fading_counter > 30 {
				(w4.PALETTE^)[0] = 0xA0979B
				(w4.PALETTE^)[1] = 0x9D6569
				(w4.PALETTE^)[2] = 0x903173
			}
		} else {
			if s_gglob.fading_counter > 120 {
				s_gglob.fading_counter = 0
			} else if s_gglob.fading_counter > 90 {
				(w4.PALETTE^)[0] = 0xdad3af
				(w4.PALETTE^)[1] = 0xd58863
				(w4.PALETTE^)[2] = 0xc23a73
			} else if s_gglob.fading_counter > 60 {
				(w4.PALETTE^)[0] = 0xA0979B
				(w4.PALETTE^)[1] = 0x9D6569
				(w4.PALETTE^)[2] = 0x903173
			} else if s_gglob.fading_counter > 30 {
				(w4.PALETTE^)[0] = 0x665A88
				(w4.PALETTE^)[1] = 0x64416E
				(w4.PALETTE^)[2] = 0x5E2774
			}
		}
	}
}

StartFade :: proc "contextless" ( mid_fade_callback: proc "contextless" () ) {
	s_gglob.fading_counter = 1
	s_gglob.fading_out = true
	s_gglob.mid_fade_callback = mid_fade_callback
}

GameOverAnimation_Update :: proc "contextless" () {
	if s_gglob.game_state != .GameOverAnimation do return

	player := GetEntityByName( .Player )
	if player.animated_sprite.sprite != &PlayerAnimation_Death {
		player.flags -= { .Player, .Collidable, .DamageReceiver }
		player.flags += { .AnimatedSprite }
		player.animated_sprite.flags -= {.Pause}
		AnimationController_SetSprite( &player.animated_sprite, &PlayerAnimation_Death )
		Sound_Play( &PlayerSound_Death )

		// destroy all entities that are not the player
		for entity in &s_EntityPool {
			if .InUse not_in entity.flags do continue
			if &entity == player do continue
			DestroyEntity( &entity )
		}
	}
	if player.animated_sprite.current_frame == 2 && player.animated_sprite.frame_counter >= 60 && s_gglob.fading_counter == 0 { // Hack, animation technically stops at 70 but we only need 60 frames
		StartFade( proc "contextless" () { s_gglob.game_state = .GameOverScreen } )
	}
}

@export
update :: proc "c" () {
	using s_gglob
	s_gglob.global_frame_counter += 1
	UpdateInputState()

	if s_gglob.game_state == .MainMenu {
		w4.DRAW_COLORS^ = 0x2341
		title_screen := GetImage( ImageKey.title_screen )
		w4.blit( &title_screen.bytes[0], 0, 0, u32( title_screen.w ), u32( title_screen.h ), title_screen.flags )
		if s_gglob.input_state.APressed && !bool( s_gglob.fading_out ) {
			StartFade( proc "contextless" () { s_gglob.game_state = .Game } )
			InitRand( s_gglob.global_frame_counter )
		}
	} else if s_gglob.game_state == .GameOverScreen {
		w4.DRAW_COLORS^ = 0x2431
		game_over_screen := GetImage( ImageKey.game_over_screen )
		w4.blit( &game_over_screen.bytes[0], 0, 0, u32( game_over_screen.w ), u32( game_over_screen.h ), game_over_screen.flags )
	} else {
		player := GetEntityByName( EntityName.Player )
		if player != nil && player.position.chunk != active_chunk_coords {
			active_chunk_coords = player.position.chunk
			ActivateChunk( &s_gglob.tilemap, active_chunk_coords )
		}
	
		DrawTileChunk( &tilemap, active_chunk_coords.x, active_chunk_coords.y, 0, 0 )
	
		UpdateEntities()
	
		lights[0].enabled = Inventory_HasItemSelected( player, .Torch ) || s_gglob.game_state == GameState.GameOverAnimation
		lights[0].pos = player.position.offsets
		lights[0].r = f32(((fake_sin(f32(global_frame_counter) / 60 ) + 1) / 2.0 ) * (0.35 - 0.125) + 0.125)
		lights[0].s = 3
	
		GameOverAnimation_Update()
		DrawStatusUI()
		Dialog_Update()
		NewItemAnimation_Update()

		when SHOW_LAST_VALID_POSITION {
			DrawRect( { s_gglob.last_valid_player_position + { 2, 2 }, s_gglob.last_valid_player_position + { 6, 6 } } )
		}

		chunk := GetChunkFromChunkCoordinates( &tilemap, active_chunk_coords.x, active_chunk_coords.y )
		if s_gglob.darkness_enabled {
			DrawDitherPattern()
		}
	}

	Sound_Update()
	UpdateFade()
}
