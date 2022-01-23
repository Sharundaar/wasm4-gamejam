package main

DEVELOPMENT_BUILD :: false
PRINT_FUNC :: false
USE_TEST_MAP :: false
SHOW_HURT_BOX :: false
SHOW_COLLIDER :: false
SHOW_LAST_VALID_POSITION :: false
SHOW_TILE_BROADPHASE_TEST :: false
SKIP_INTRO :: false
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

rect_size :: proc "contextless" ( v:rect ) -> ivec2 {
	return { rect_width( v ), rect_height( v ) }
}

rect_width :: proc "contextless" ( v: rect ) -> i32 {
	return v.max.x - v.min.x
}

rect_height :: proc "contextless" ( v: rect ) -> i32 {
	return v.max.y - v.min.y
}

extract_ivec2 :: proc "contextless" ( v: ivec2 ) -> ( i32, i32 ) {
	return v.x, v.y
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
	EndingMiruScreen,
	EndingTomScreen,
	Game,
	Dialog,
	NewItemAnimation,
	GameOverAnimation,
	Cinematic,
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
	cinematic_controller: CinematicController,
}
s_gglob : GameGlob

GlobalCoordinates :: struct {
	chunk: ivec2,
	offsets: ivec2,
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

LightType :: enum {
	Point,
	Tube,
}

Light :: struct {
	enabled: bool,
	pos: ivec2, pos2: ivec2,
	s: f32,
	r: f32,
	t: LightType,
}
lights : [8]Light


EnableLight :: proc {
	EnablePointLight,
	EnableTubeLight,
}
EnablePointLight :: proc "contextless" ( idx : u8, pos: ivec2, s: f32 = 4, r: f32 = 0.125 ) {
	lights[idx].enabled = true
	lights[idx].pos = pos
	lights[idx].s = s
	lights[idx].r = r
	lights[idx].t = .Point
}
EnableTubeLight :: proc "contextless" ( idx: u8, start_pos: ivec2, end_pos: ivec2, s: f32 = 4, r: f32 = 0.125 ) {
	lights[idx].enabled = true
	lights[idx].pos = start_pos
	lights[idx].pos2 = end_pos
	lights[idx].s = s
	lights[idx].r = r
	lights[idx].t = .Tube
}

EnableFirstAvailableLight :: proc "contextless" ( pos: ivec2, s: f32 = 4, r: f32 = 0.125 ) -> u8 {
	for l, i in &lights { // ignore 0 as it's the player's light
		if i == 0 do continue
		if !l.enabled {
			EnablePointLight( u8(i), pos, s, r )
			return u8(i)
		}
	}
	return 1
}

SetLightPosition :: proc "contextless" ( idx: u8, pos: ivec2 ) {
	lights[idx].pos = pos
}

DisableLight :: proc "contextless" ( idx: u8 ) {
	lights[idx].enabled = false
}

DisableAllLightsAndEnableDarkness :: proc "contextless" () {
	s_gglob.darkness_enabled = true
	for i in 1..<len(lights) {
		lights[i].enabled = false
	}
}

DisableDarkness :: proc "contextless" () {
	s_gglob.darkness_enabled = false
}

tiledef := []TileDefinition{
	{ { 16, 0 }, .Solid }, // wall
	{ { 32, 0 }, .None }, // floor
	{ { 0, 16 }, .Hole }, // hole
	{ { 16, 16 }, .Solid }, // door
	{ { 32, 16 }, .Solid }, // outside
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
				if c.collider_type == .Solid {
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
		pxx, pyy := f32(l.pos.x) / DW, f32(l.pos.y) / DW
		xx, yy := f32(x) / DW, f32(y) / DW
		c : f32
		switch l.t {
		case .Point:
			xx -= pxx
			yy -= pyy
			xx *= l.s
			yy *= l.s
			c = math.sqrt(xx*xx+yy*yy)
		case .Tube:
			v1 := l.pos2 - l.pos
			v2 := ivec2{ x, y } - l.pos
			v1f := [2]f32{ f32(v1.x), f32(v1.y) }
			v2f := [2]f32{ f32(v2.x), f32(v2.y) }
			t := ( v2f.x*v1f.x + v2f.y*v1f.y ) / ( v1f.x*v1f.x + v1f.y*v1f.y )
			if t > 1.0 {
				v2 = ivec2{ x, y } - l.pos2
				v2f = [2]f32{ f32(v2.x), f32(v2.y) }
				d_mag := math.sqrt( v2f.x*v2f.x + v2f.y*v2f.y )
				c = (d_mag / l.s)
			} else if t < 0.0 {
				d_mag := math.sqrt( v2f.x*v2f.x + v2f.y*v2f.y )
				c = (d_mag / l.s)
			} else {
				p := [2]f32{ f32(l.pos.x), f32(l.pos.y) } + t*v1f
				d := [2]f32{ f32(x), f32(y) } - p
				d_mag := math.sqrt( d.x*d.x + d.y*d.y )
				c = (d_mag / l.s)
			}
		}
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
		if player.health_points == 0 do w4.DRAW_COLORS^ = 0x0020
		w4.blit( &half_heart.bytes[0], x, HEART_TOP_POSITION, half_heart.w, half_heart.h, flags )
		if player.health_points <= (i+1) do w4.DRAW_COLORS^ = 0x0020
		x += i32(half_heart.w) if even else HEART_SPACING
	}

	// draw inventory
	INVENTORY_LEFT_OFFSET  :: 160 - ( i32(InventoryItem.Count) * ( INVENTORY_ITEM_SIZE + INVENTORY_ITEM_SPACING ) )
	INVENTORY_TOP_POSITION :: 160 - 16 + 4
	DrawInventory( INVENTORY_LEFT_OFFSET, INVENTORY_TOP_POSITION, &player.inventory )
}

Sound_OpenDoor := Sound {
	{
		{ 500, 300, 0, {sustain=10}, .Noise, 25 },
	},
}

MakeWorldMap :: proc "contextless" () {
	using s_gglob

	tilemap.chunks = tilemap_chunks[:]
	EnablePopulateFunc :: proc "contextless" ( data: ^PopulateData ) {
		GetChunkFromChunkCoordinates( &tilemap, i32(data.chunk_x), i32(data.chunk_y) ).populate_function = data.populate_func
	}
	when USE_TEST_MAP {
	EnablePopulateFunc( &ents_c00 )
	EnablePopulateFunc( &ents_c01 )
	EnablePopulateFunc( &ents_c10 )
	EnablePopulateFunc( &ents_c11 )
	}

	for p in populate_funcs {
		EnablePopulateFunc( p )
	}
	
	tilemap.tileset = GetImage( ImageKey.tileset )
	tilemap.tiledef = tiledef
}

InitPlayer :: proc "contextless" () {
	player := MakePlayer()
	when USE_TEST_MAP {
		player.position.chunk = { 0, 0 }
		player.position.offsets = { 76, 76 }
	} else {
		// official entrance
		player.position.chunk = { 0, 3 }
		player.position.offsets = GetTileWorldCoordinate( 1, 4 ) + { 2, 4 }

		// tom room
		// player.position.chunk = { 3, 2 }
		// player.position.offsets = GetTileWorldCoordinate( 1, 4 ) + { 2, 4 }

		// sword altar room
		// player.position.chunk = { 3, 4 }
		// player.position.offsets = GetTileWorldCoordinate( 4, 2 ) + { 2, 4 }

		// mirus boss room
		// player.position.chunk = { 1, 4 }
		// player.position.offsets = GetTileWorldCoordinate( 9, 7 ) + { 2, 2 }

		// toms boss room
		// player.position.chunk = { 4, 1 }
		// player.position.offsets = GetTileWorldCoordinate( 2, 8 ) + { 2, 2 }
		// Quest_Complete( .KilledBat3 )

		// mirus room
		// player.position.chunk = { 2, 3 }
		// player.position.offsets = GetTileWorldCoordinate( 4, 2 ) + { 2, 4 }

		// Quest_Complete( .KilledBat1 )
		// Quest_Complete( .KilledBat2 )
		// Quest_Complete( .KilledBat3 )
	}

	if Quest_IsComplete( .GotSword ) {
		Inventory_GiveNewItem_Immediate( player, .Sword )
	}
	if Quest_IsComplete( .GotTorch ) {
		Inventory_GiveNewItem_Immediate( player, .Torch )
	}
	if Quest_IsComplete( .GotHeartContainer ) {
		Inventory_GiveNewItem_Immediate( player, .Heart )
	}

	s_MiruBossData = {}
	s_TomBossData = {}

	s_gglob.last_valid_player_position = player.position.offsets
}

@export
start :: proc "c" () {
	using s_gglob

	print_int( size_of( Entity ) )

	(w4.PALETTE^)[0] = 0xdad3af
	(w4.PALETTE^)[1] = 0xd58863
	(w4.PALETTE^)[2] = 0xc23a73
	(w4.PALETTE^)[3] = 0x2c1e74

	InitPlayer()
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
		StartFade( proc "contextless" () { DestroyEntity( GetEntityByName( .Player ) ) ; s_gglob.game_state = .GameOverScreen } )
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
		if s_gglob.input_state.APressed && s_gglob.fading_counter == 0 {
			InitPlayer()
			StartFade( proc "contextless" () { s_gglob.game_state = .Game } )
		}
	} else if s_gglob.game_state == .EndingMiruScreen {
		w4.DRAW_COLORS^ = 0x1111
		title_screen := GetImage( ImageKey.title_screen )
		w4.blit( &title_screen.bytes[0], 0, 0, u32( title_screen.w ), u32( title_screen.h ), title_screen.flags )
		w4.DRAW_COLORS^ = 0x0002
		w4.text( "You defeated Miru", 12, 10 )
		w4.text( "The grotto grows", 15, 40 )
		w4.text( "quieter", 160 / 2 - 25, 50 )
		w4.text( "Maybe for the best", 10, 70 )
		w4.text( "Thanks for playing !", 2, 110 )
	} else if s_gglob.game_state == .EndingTomScreen {
		w4.DRAW_COLORS^ = 0x4444
		title_screen := GetImage( ImageKey.title_screen )
		w4.blit( &title_screen.bytes[0], 0, 0, u32( title_screen.w ), u32( title_screen.h ), title_screen.flags )
		w4.DRAW_COLORS^ = 0x0003
		w4.text( "You defeated Tom", 14, 10 )
		w4.text( "The grotto grows", 15, 40 )
		w4.text( "quieter", 160 / 2 - 25, 50 )
		w4.text( "Maybe for the worse", 5, 70 )
		w4.text( "There might be", 25, 110 )
		w4.text( "something else", 25, 120 )
		w4.text( "Restart with R", 25, 145 )
	} else {
		player := GetEntityByName( EntityName.Player )
		if player != nil && player.position.chunk != active_chunk_coords {
			active_chunk_coords = player.position.chunk
			ActivateChunk( &s_gglob.tilemap, active_chunk_coords )
		}
	
		DrawTileChunk( &tilemap, active_chunk_coords.x, active_chunk_coords.y, 0, 0 )
	
		UpdateEntities()
	
		lights[0].enabled = Inventory_HasItemSelected( player, .Torch ) || s_gglob.game_state == GameState.GameOverAnimation
		lights[0].pos = player.position.offsets + { HALF_PLAYER_W, HALF_PLAYER_H }
		lights[0].r = f32(((fake_sin(f32(global_frame_counter) / 60 ) + 1) / 2.0 ) * (0.35 - 0.125) + 0.125)
		lights[0].s = 3
	
		GameOverAnimation_Update()
		NewItemAnimation_Update()
		Cinematic_Update( &s_gglob.cinematic_controller )

		when SHOW_LAST_VALID_POSITION {
			DrawRect( { s_gglob.last_valid_player_position + { 2, 2 }, s_gglob.last_valid_player_position + { 6, 6 } } )
		}

		chunk := GetChunkFromChunkCoordinates( &tilemap, active_chunk_coords.x, active_chunk_coords.y )
		if s_gglob.darkness_enabled {
			DrawDitherPattern()
		}

		DrawStatusUI()
		Dialog_Update()
	}

	Sound_Update()
	UpdateFade()
}
