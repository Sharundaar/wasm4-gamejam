package main

import "w4"
import "core:fmt"
import "core:runtime"

ivec2 :: distinct [2]i32

smiley := [8]u8{
	0b11000011,
	0b10000001,
	0b00100100,
	0b00100100,
	0b00000000,
	0b00100100,
	0b10011001,
	0b11000011,
}

AnimationFrame :: struct {
	length: u8,
	x_offs: u8,
}

AnimatedSprite :: struct {
	img: ^Image,
	w, h: u32,
	frames: []AnimationFrame,
	current_frame: u32,
	frame_counter: u32,
}

BatAnimation := AnimatedSprite {
	&Images.bat, 8, 8,
	{
		AnimationFrame{ 15, 0 },
		AnimationFrame{ 15, 8 },
	},
	0, 0,
}

GameState :: enum {
	Normal,
	Transition,
}

GameData : struct {
	player_pos: GlobalCoordinates,
	tilemap: TileMap,
} = {}

TILE_SIZE : i32 : 16
TILE_CHUNK_COUNT_W : i32 : 10
TILE_CHUNK_COUNT_H : i32 : 8

TILEMAP_CHUNK_COUNT_W : i32 : 10
TILEMAP_CHUNK_COUNT_H : i32 : 10

TileDefinition :: struct {
	offsets: ivec2, // offsets in the source texture
	solid: bool,
}

TileChunk :: struct {
	// indices into the map tiledef array
	tiles: [TILE_CHUNK_COUNT_W*TILE_CHUNK_COUNT_H]u8,
}

TileMap :: struct {
	chunks: [TILEMAP_CHUNK_COUNT_W * TILEMAP_CHUNK_COUNT_H]TileChunk,
	tileset: ^Image,
	tiledef: []TileDefinition,
}

print :: proc "contextless" ( args: ..any ) {
	context = runtime.default_context()
	buffer : [256]u8
	str := fmt.bprint( buffer[:], args )
	w4.trace( str )
}

IsCollidingWithTilemap :: proc "contextless" ( tilemap: ^TileMap, top_left: GlobalCoordinates, w, h: i32 ) -> bool {
	tile_pos_min := top_left.offsets / TILE_SIZE
	if tile_pos_min.x < 0 do tile_pos_min.x = 0
	if tile_pos_min.y < 0 do tile_pos_min.y = 0
	if tile_pos_min.x >= TILE_CHUNK_COUNT_W do tile_pos_min.x = TILE_CHUNK_COUNT_W - 1
	if tile_pos_min.y >= TILE_CHUNK_COUNT_H do tile_pos_min.y = TILE_CHUNK_COUNT_H - 1
	
	tile_pos_max := (top_left.offsets + ivec2{w, h}) / TILE_SIZE
	if tile_pos_max.x < 0 do tile_pos_max.x = 0
	if tile_pos_max.y < 0 do tile_pos_max.y = 0
	if tile_pos_max.x >= TILE_CHUNK_COUNT_W do tile_pos_max.x = TILE_CHUNK_COUNT_W - 1
	if tile_pos_max.y >= TILE_CHUNK_COUNT_H do tile_pos_max.y = TILE_CHUNK_COUNT_H - 1

	chunk_idx := top_left.chunk.y * TILEMAP_CHUNK_COUNT_W + top_left.chunk.x
	for tile_y in tile_pos_min.y .. tile_pos_max.y {
		for tile_x in tile_pos_min.x .. tile_pos_max.x {
			idx := tile_y * TILE_CHUNK_COUNT_W + tile_x
			tile := tilemap.chunks[chunk_idx].tiles[idx]
			if tilemap.tiledef[tile].solid do return true
		}
	}

	return false
}

// draw chunk with x/y offset from top of the screen
DrawTileChunk :: proc "contextless" ( tilemap: ^TileMap, chunk_x, chunk_y, x_offs, y_offs: i32 ) {
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


DrawAnimatedSprite :: proc "contextless" ( sprite: ^AnimatedSprite, x, y: i32 ) {
	w4.blit_sub( &sprite.img.bytes[0], x, y, sprite.w, sprite.h, u32(sprite.frames[sprite.current_frame].x_offs), 0, int(sprite.img.w), sprite.img.flags )
	sprite.frame_counter += 1
	if sprite.frame_counter >= u32(sprite.frames[sprite.current_frame].length) {
		sprite.frame_counter = 0
		sprite.current_frame = u32( int( sprite.current_frame + 1 ) % len( sprite.frames ) )
	}
}

tiledef := []TileDefinition{
	{ { 16, 0 }, true }, // wall
	{ { 16*2, 0 }, false }, // floor
	{ { 0, 16 }, true }, // light from outside
	{ { 16, 16 }, true }, // door
}

@export
start :: proc "c" () {
	using GameData
	player_pos.chunk.x, player_pos.chunk.y = 0, 0
	player_pos.offsets.x, player_pos.offsets.y = 76, 76

	(w4.PALETTE^)[0] = 0xdad3af
	(w4.PALETTE^)[1] = 0xd58863
	(w4.PALETTE^)[2] = 0xc23a73
	(w4.PALETTE^)[3] = 0x2c1e74

	tilemap.chunks[0].tiles = {
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 1,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
	}
	tilemap.chunks[1].tiles = {
		0, 0, 0, 0, 0, 0, 0, 3, 0, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		1, 1, 1, 1, 1, 1, 1, 1, 1, 0,
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
		0, 0, 0, 0, 2, 2, 0, 0, 0, 0,
	}
	tilemap.tileset = &Images.tileset
	tilemap.tiledef = tiledef
}

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

@export
update :: proc "c" () {
	using GameData
	w4.DRAW_COLORS^ = 0x1234
	DrawTileChunk( &tilemap, player_pos.chunk.x, player_pos.chunk.y, 0, 0 )

	w4.DRAW_COLORS^ = 0x0002
	if .A in w4.GAMEPAD1^ {
		w4.DRAW_COLORS^ = 0x0004
	}

	new_player_pos := player_pos
	if .LEFT in w4.GAMEPAD1^ {
		new_player_pos.offsets.x -= 1
	}
	if .RIGHT in w4.GAMEPAD1^ {
		new_player_pos.offsets.x += 1
	}
	if IsCollidingWithTilemap( &tilemap, new_player_pos, 8, 8 ) {
		new_player_pos = player_pos
	} else {
		player_pos = new_player_pos
	}

	if .UP in w4.GAMEPAD1^ {
		new_player_pos.offsets.y -= 1
	}
	if .DOWN in w4.GAMEPAD1^ {
		new_player_pos.offsets.y += 1
	}
	if IsCollidingWithTilemap( &tilemap, new_player_pos, 8, 8 ) {
		new_player_pos = player_pos
	}

	player_pos = RegularizeCoordinate( new_player_pos )

	w4.blit(&smiley[0], player_pos.offsets.x, player_pos.offsets.y, 8, 8)

	w4.text("Hello from Odin!", 16, 130)
	w4.text("Press X to blink", 16, 140)

	{
		w4.DRAW_COLORS^ = 0x4320
		w4.blit(&Images.key.bytes[0], 20, 20, Images.key.w, Images.key.h)
		w4.blit(&Images.dude.bytes[0], 30, 20, Images.dude.w, Images.dude.h)
		w4.blit_sub(&Images.chest.bytes[0], 20, 30, 16, 16, 0, 0, int(Images.chest.w), Images.chest.flags)
		w4.blit_sub(&Images.chest.bytes[0], 40, 30, 16, 16, 16, 0, int(Images.chest.w), Images.chest.flags)
	
		w4.DRAW_COLORS^ = 0x4320
		DrawAnimatedSprite( &BatAnimation, 40, 20 )
	}
}