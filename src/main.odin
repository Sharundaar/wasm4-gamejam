package main

DEVELOPMENT_BUILD :: false
PRINT_FUNC :: false
USE_TEST_MAP :: false
SHOW_HURT_BOX :: false
SHOW_COLLIDER :: false
SHOW_TILE_BROADPHASE_TEST :: false
SKIP_INTRO :: true

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
	Game,
	Dialog,
	NewItemAnimation,
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
	
}
s_gglob : GameGlob

GlobalCoordinates :: struct {
	chunk: ivec2,
	offsets: ivec2,
}

RegularizeCoordinate :: proc "contextless" ( coord: GlobalCoordinates ) -> GlobalCoordinates {
	result := coord
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
	{ { 16, 0 }, true }, // wall
	{ { 16*2, 0 }, false }, // floor
	{ { 0, 16 }, true }, // light from outside
	{ { 16, 16 }, true }, // door
}

BatAnimation := AnimatedSprite {
	ImageKey.bat, 8, 8, 0,
	{
		AnimationFrame{ 15, 0, nil },
		AnimationFrame{ 15, 8, nil },
	},
}

FireAnimation := AnimatedSprite {
	ImageKey.fire, 16, 16, 0,
	{
		AnimationFrame{ 15, 0, nil },
		AnimationFrame{ 15, 0, { .FlipX } },
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

GenerateDitherPattern :: proc "contextless" ( w, h: i32 ) {
	DW, DH :: 160, 128+16
	texture : [(DW/8)*DH]u8
	
	w4.DRAW_COLORS^ = 0x0004
	color_at_px_for_light :: proc "contextless" ( l: Light, x, y: i32 ) -> f32 {
		if !l.enabled do return 0
		pxx, pyy := f32(l.pos.x + 4) / DW, f32(l.pos.y + 4) / DH
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

MakeBatEntity :: proc "contextless" ( x, y: i32 ) -> EntityTemplate {
	ent: EntityTemplate

	ent.name = EntityName.Bat
	ent.position = { {}, { x, y } }
	ent.flags += { .AnimatedSprite, .DamageReceiver, .DamageMaker }
	ent.collider = { {}, {8, 8} }
	ent.hurt_box = { { 0, 2 }, {8, 7} }
	ent.animated_sprite.sprite = &BatAnimation
	ent.health_points = 2
	ent.palette_mask = 0x130
	ent.damage_flash_palette = 0x110

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
		{ "Oh hi !", "It's been a while" },
		{ "Can you give", "me a hand ?" },
	},
}

MakeMiruEntity :: proc "contextless" () -> EntityTemplate {
	ent : EntityTemplate

	ent.position = { {}, GetTileWorldCoordinate( 3, 1 ) }
	ent.flags += {.Interactible, .AnimatedSprite, .Collidable}
	ent.animated_sprite.sprite = &MiruAnimation
	ent.looking_dir = { 0, 1 }
	ent.collider = { { 0, 0 }, { 16, 16 } }
	ent.palette_mask = 0x0210
	ent.interaction = &MirusDialog

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
	proc "contextless" () {
		altar := GetEntityByName( EntityName.SwordAltar )
		altar.flags -= {.Interactible}
		AnimatedSprite_NextFrame( &altar.animated_sprite )
		player := GetEntityByName( EntityName.Player )
		player.inventory.items[InventoryItem.Sword] = true
	},
}
MakeSwordAltarEntity :: proc "contextless" () -> EntityTemplate {
	ent : EntityTemplate

	ent.position = { {}, GetTileWorldCoordinate( 5, 4 ) }
	ent.name = EntityName.SwordAltar
	ent.flags += {.Interactible, .AnimatedSprite, .Collidable}
	ent.animated_sprite.sprite = &SwordAltarSprite
	ent.palette_mask = 0x0210
	ent.collider = { { 0, 0 }, { 5, 7 } }
	ent.interaction = &SwordAltarContainer

	return ent
}

ents_c00 := []EntityTemplate {
	MakeMiruEntity(),
}

ents_c01 := []EntityTemplate {
	MakeSwordAltarEntity(),
}

ents_c10 := []EntityTemplate {
	MakeBatEntity( GetTileWorldCoordinate2( 8, 6 ) ),
	MakeBatEntity( GetTileWorldCoordinate2( 3, 6 ) ),
	MakeBatEntity( GetTileWorldCoordinate2( 4, 2 ) ),
}

ents_c11 := []EntityTemplate {
	MakeChestEntity( GetTileWorldCoordinate2( 4, 7 ) ),
}

ChestSprite := AnimatedSprite {
	ImageKey.chest, 8, 8, 0,
	{
		AnimationFrame{ 0, 0, nil },
		AnimationFrame{ 0, 8, nil },
	},
}
MakeChestEntity :: proc "contextless" ( x, y: i32 ) -> EntityTemplate{
	ent : EntityTemplate

	ent.position = { {}, { x + 4, y + 4 } }
	ent.flags += { .AnimatedSprite, .Collidable }
	ent.animated_sprite.sprite = &ChestSprite
	ent.palette_mask = 0x4320
	ent.collider = { { 0, 0 }, { 8, 8 } }

	return ent
}

MakeWorldMap :: proc "contextless" () {
	using s_gglob

	tilemap.chunks[0].tiles = {
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 1,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
	}
	tilemap.chunks[0].entities = ents_c00

	tilemap.chunks[1].tiles = {
		0, 0, 0, 0, 0, 0, 0, 3, 0, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		1, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
	}
	tilemap.chunks[1].entities = ents_c01

	tilemap.chunks[0+TILE_CHUNK_COUNT_W].tiles = {
		0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	}
	tilemap.chunks[0+TILE_CHUNK_COUNT_W].entities = ents_c10

	tilemap.chunks[1+TILE_CHUNK_COUNT_W].tiles = {
		0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
		0, 1, 1, 1, 1, 0, 1, 1, 1, 0,
		0, 1, 0, 0, 0, 0, 1, 0, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 0, 1, 0,
		0, 1, 0, 0, 0, 0, 0, 0, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 0, 1, 0,
		0, 1, 0, 0, 0, 0, 1, 0, 1, 0,
		0, 1, 1, 0, 1, 1, 1, 1, 1, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	}
	tilemap.chunks[1+TILE_CHUNK_COUNT_W].entities = ents_c11

	tilemap.tileset = GetImage( ImageKey.tileset )
	tilemap.tiledef = tiledef
}

when USE_TEST_MAP {

MakeTestMap :: proc "contextless" () {
	using s_gglob
	tilemap.chunks[0].tiles = {
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 0, 0, 0, 1, 0, 0, 0, 1, 0,
		0, 1, 1, 1, 1, 0, 1, 0, 1, 0,
		0, 1, 1, 1, 1, 0, 0, 0, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 1,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	}
	tilemap.tileset = GetImage( ImageKey.tileset )
	tilemap.tiledef = tiledef
}

}

@export
start :: proc "c" () {
	using s_gglob

	(w4.PALETTE^)[0] = 0xdad3af
	(w4.PALETTE^)[1] = 0xd58863
	(w4.PALETTE^)[2] = 0xc23a73
	(w4.PALETTE^)[3] = 0x2c1e74

	{
		player := MakePlayer()
		when USE_TEST_MAP {
			player.position.offsets = GetTileWorldCoordinate( 1, 4 ) + { 4, 4 }
		} else {
			player.position.offsets = { 76, 76 }
		}
	}
	active_chunk_coords = { -1, -1 }

	when USE_TEST_MAP {
		MakeTestMap()
	} else {
		MakeWorldMap()
	}

	lights[0].enabled = true
	lights[0].r = 0.125
	lights[0].s = 4.0

	lights[1].enabled = false
	lights[1].pos.x = 64
	lights[1].pos.y = 24
	lights[1].r = 0.125
	lights[1].s = 1.0

	when SKIP_INTRO {
		game_state = GameState.Game
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

@export
update :: proc "c" () {
	using s_gglob
	s_gglob.global_frame_counter += 1
	UpdateInputState()

	if s_gglob.game_state == GameState.MainMenu {
		w4.DRAW_COLORS^ = 0x2341
		title_screen := GetImage( ImageKey.title_screen )
		w4.blit( &title_screen.bytes[0], 0, 0, u32( title_screen.w ), u32( title_screen.h ), title_screen.flags )
		if s_gglob.input_state.APressed {
			StartFade( proc "contextless" () { s_gglob.game_state = GameState.Game } )
		}
	} else {
		player := GetEntityByName( EntityName.Player )
		if player != nil && player.position.chunk != active_chunk_coords {
			active_chunk_coords = player.position.chunk
			ActivateChunk( &s_gglob.tilemap, active_chunk_coords )
		}
	
		DrawTileChunk( &tilemap, active_chunk_coords.x, active_chunk_coords.y, 0, 0 )
	
		UpdateEntities()
	
		lights[0].pos = player.position.offsets
		lights[0].r = f32(((fake_sin(f32(global_frame_counter) / 60 ) + 1) / 2.0 ) * (0.35 - 0.125) + 0.125)
	
		DrawStatusUI()
		Dialog_Update()
		NewItemAnimation_Update()
	
		// GenerateDitherPattern(0,0)
	}

	UpdateFade()
}


TestGallery :: proc "contextless" () {
	when false
	{
		w4.DRAW_COLORS^ = 0x4320
		w4.blit(ImageKey.key.bytes[0], 20, 20, Images.key.w, Images.key.h)
		w4.blit(ImageKey.dude.bytes[0], 30, 20, Images.dude.w, Images.dude.h)
		w4.blit_sub(ImageKey.chest.bytes[0], 20, 30, 16, 16, 0, 0, int(Images.chest.w), Images.chest.flags)
		w4.blit_sub(ImageKey.chest.bytes[0], 40, 30, 16, 16, 16, 0, int(Images.chest.w), Images.chest.flags)
	
		w4.DRAW_COLORS^ = 0x4320
		DrawAnimatedSprite( &BatAnimation, 40, 20 )
		w4.DRAW_COLORS^ = 0x4230
		DrawAnimatedSprite( &FireAnimation, 60, 20 )
	}
}
