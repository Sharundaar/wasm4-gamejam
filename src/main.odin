package main

import "w4"
import "core:fmt"
import "core:runtime"
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

AnimationFlag :: enum {
	FlipX,
	FlipY,
}
AnimationFlags :: distinct bit_set[AnimationFlag; u8]

AnimationFrame :: struct {
	length: u8,
	x_offs: u8,
	flags : AnimationFlags,
}

AnimatedSprite :: struct {
	img: ^Image,
	w, h: u32, y_offs: u8,
	frames: []AnimationFrame,
	current_frame: u32,
	frame_counter: u32,
}

GameGlob :: struct {
	tilemap: TileMap,
	active_chunk_coords: ivec2,
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
	&Images.bat, 8, 8, 0,
	{
		AnimationFrame{ 15, 0, nil },
		AnimationFrame{ 15, 8, nil },
	},
	0, 0,
}

FireAnimation := AnimatedSprite {
	&Images.fire, 16, 16, 0,
	{
		AnimationFrame{ 15, 0, nil },
		AnimationFrame{ 15, 0, { .FlipX } },
	},
	0, 0,
}


print :: proc "contextless" ( args: ..any ) {
	context = runtime.default_context()
	buffer : [256]u8
	str := fmt.bprint( buffer[:], args )
	w4.trace( str )
}

// draw chunk with x/y offset from top of the screen
DrawTileChunk :: proc "contextless" ( tilemap: ^TileMap, chunk_x, chunk_y, x_offs, y_offs: i32 ) {
	w4.DRAW_COLORS^ = 0x1234
	chunk := &tilemap.chunks[TILEMAP_CHUNK_COUNT_W * i32(chunk_y) + i32(chunk_x)];
	print_buffer : [256]byte
	for y in 0..<TILE_CHUNK_COUNT_H do for x in 0..<TILE_CHUNK_COUNT_W {
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
	}
}

AnimationToBlitFlags :: proc "contextless" ( flags: AnimationFlags ) -> w4.Blit_Flags {
	blit_flags : w4.Blit_Flags
	blit_flags += {.FLIPX} if AnimationFlag.FlipX in flags else nil
	blit_flags += {.FLIPY} if AnimationFlag.FlipY in flags else nil
	return blit_flags
}

DrawAnimatedSprite :: proc "contextless" ( sprite: ^AnimatedSprite, x, y: i32, flags: AnimationFlags = nil ) {
	frame := &sprite.frames[sprite.current_frame]
	flags := AnimationToBlitFlags( flags )
	flags += sprite.img.flags
	flags += AnimationToBlitFlags( frame.flags )
	
	w4.blit_sub( &sprite.img.bytes[0], x, y, sprite.w, sprite.h, u32(frame.x_offs), u32(sprite.y_offs), int(sprite.img.w), flags )
	sprite.frame_counter += 1
	if sprite.frame_counter >= u32(frame.length) {
		sprite.frame_counter = 0
		sprite.current_frame = u32( int( sprite.current_frame + 1 ) % len( sprite.frames ) )
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
	w4.DRAW_COLORS^ = 0x0001
	w4.blit( &Images.status_bar.bytes[0], 0, i32(160-Images.status_bar.h), Images.status_bar.w, Images.status_bar.h, Images.status_bar.flags )
}

MiruAnimation := AnimatedSprite {
	&Images.miru, 16, 16, 0,
	{
		AnimationFrame{ 50, 0, nil },
		AnimationFrame{ 50, 0, {.FlipX} },
	},
	0, 0,
}
MakeMiruEntity :: proc "contextless" () -> EntityTemplate {
	ent : EntityTemplate

	ent.position = { { 0, 0 }, GetTileWorldCoordinate( 3, 1 ) }
	ent.flags += {.Talkable, .AnimatedSprite, .Collidable}
	ent.animated_sprite = &MiruAnimation
	ent.looking_dir = { 0, 1 }
	ent.collider = { { 0, 0 }, { 16, 16 } }

	return ent
}

ents_c00 := []EntityTemplate {
	MakeMiruEntity(),
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
		player.flags += {.Player}
		player.looking_dir = { 1, 1 }
		player.position.chunk = { 0, 0 }
		player.position.offsets = { 76, 76 }
		player.collider = { { 0, 0 }, { 8, 8 } }
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
	tilemap.tileset = &Images.tileset
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

	player := GetEntityByName( EntityName.Player )
	DrawTileChunk( &tilemap, player.position.chunk.x, player.position.chunk.y, 0, 0 )

	if player.position.chunk != active_chunk_coords {
		active_chunk_coords = player.position.chunk
		// destroy ents outside current active chunk
		for ent in &s_EntityPool {
			if .InUse not_in ent.flags do continue
			if ent.position.chunk != active_chunk_coords {
				DestroyEntity( &ent )
			}
		}
		// create entities linked to this chunk
		active_chunk := GetChunkFromChunkCoordinates( &tilemap, player.position.chunk.x, player.position.chunk.y )
		for ent_template in &active_chunk.entities {
			AllocateEntity( &ent_template )
		}
	}

	UpdateEntities()
	lights[0].pos = player.position.offsets

	when false
	{
		w4.DRAW_COLORS^ = 0x4320
		w4.blit(&Images.key.bytes[0], 20, 20, Images.key.w, Images.key.h)
		w4.blit(&Images.dude.bytes[0], 30, 20, Images.dude.w, Images.dude.h)
		w4.blit_sub(&Images.chest.bytes[0], 20, 30, 16, 16, 0, 0, int(Images.chest.w), Images.chest.flags)
		w4.blit_sub(&Images.chest.bytes[0], 40, 30, 16, 16, 16, 0, int(Images.chest.w), Images.chest.flags)
	
		w4.DRAW_COLORS^ = 0x4320
		DrawAnimatedSprite( &BatAnimation, 40, 20 )
		w4.DRAW_COLORS^ = 0x4230
		DrawAnimatedSprite( &FireAnimation, 60, 20 )
	}

	// GenerateDitherPattern(0,0)

	/*
	w4.text("Hello from Odin!", 16, 130)
	w4.text("Press X to blink", 16, 140)
	*/
	DrawStatusUI()
}