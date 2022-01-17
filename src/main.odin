package main

DEVELOPMENT_BUILD :: false
SHOW_HURT_BOX :: false
SHOW_COLLIDER :: false

import "w4"
when DEVELOPMENT_BUILD {
	import "core:fmt"
	import "core:runtime"
}
import "core:math"

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
	Game,
	Dialog,
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


print :: proc "contextless" ( args: ..any ) {
	when DEVELOPMENT_BUILD {
		context = runtime.default_context()
		buffer : [256]u8
		str := fmt.bprint( buffer[:], args )
		w4.trace( string( buffer[:] ) )
	}
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

DrawRect :: proc "contextless" ( r: rect ) {
	w4.DRAW_COLORS^ = 0x21
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
			switch r in tilemap.active_chunk_colliders[y * TILE_CHUNK_COUNT_W + x] {
				case rect: DrawRect( r )
				case:
			}
		}
	}
}

r : f32 = 0.125
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
		AnimationFrame{ 0, 6, nil },
	},
}
MakeSwordAltarEntity :: proc "contextless" () -> EntityTemplate {
	ent : EntityTemplate

	ent.position = { {}, GetTileWorldCoordinate( 5, 4 ) }
	ent.flags += {.Interactible, .AnimatedSprite, .Collidable}
	ent.animated_sprite.sprite = &SwordAltarSprite
	ent.palette_mask = 0x0210
	ent.collider = { { 0, 0 }, { 5, 7 } }

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

@export
start :: proc "c" () {
	using s_gglob

	(w4.PALETTE^)[0] = 0xdad3af
	(w4.PALETTE^)[1] = 0xd58863
	(w4.PALETTE^)[2] = 0xc23a73
	(w4.PALETTE^)[3] = 0x2c1e74

	{
		player := AllocateEntity( EntityName.Player )
		player.flags += { .Player, .DamageReceiver, .Collidable }
		player.looking_dir = { 1, 1 }
		player.health_points = 3
		player.position.chunk = { 0, 0 }
		player.position.offsets = { 76, 76 }
		player.collider = { { 0, 0 }, { 8, 8 } }
		player.damage_flash_palette = 0x0012
		player.palette_mask = 0x0021

	}
	active_chunk_coords = { -1, -1 }


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
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	}
	tilemap.tileset = GetImage( ImageKey.tileset )
	tilemap.tiledef = tiledef

	lights[0].enabled = true
	lights[0].r = 0.125
	lights[0].s = 4.0

	lights[1].enabled = true
	lights[1].pos.x = 64
	lights[1].pos.y = 24
	lights[1].r = 0.125
	lights[1].s = 1.0
}

@export
update :: proc "c" () {
	using s_gglob
	UpdateInputState()

	player := GetEntityByName( EntityName.Player )
	if player != nil && player.position.chunk != active_chunk_coords {
		active_chunk_coords = player.position.chunk
		ActivateChunk( &s_gglob.tilemap, active_chunk_coords )
	}

	DrawTileChunk( &tilemap, active_chunk_coords.x, active_chunk_coords.y, 0, 0 )

	UpdateEntities()
	lights[0].pos = player.position.offsets

	DrawStatusUI()
	Dialog_Update()

	// GenerateDitherPattern(0,0)

	/*
	w4.text("Hello from Odin!", 16, 130)
	w4.text("Press X to blink", 16, 140)
	*/
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
