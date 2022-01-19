package main

TILE_SIZE : i32 : 16
TILE_CHUNK_COUNT_W : i32 : 10
TILE_CHUNK_COUNT_H : i32 : 9

TILEMAP_CHUNK_COUNT_W : i32 : 10
TILEMAP_CHUNK_COUNT_H : i32 : 10

TILEMAP_CHUNK_W :: TILE_SIZE * TILE_CHUNK_COUNT_W
TILEMAP_CHUNK_H :: TILE_SIZE * TILE_CHUNK_COUNT_H

TileDefinition :: struct {
	offsets: ivec2, // offsets in the source texture
	solid: bool,
}

TileChunk :: struct {
	// indices into the map tiledef array
	tiles: [TILE_CHUNK_COUNT_W*TILE_CHUNK_COUNT_H]u8,
	populate_function: proc "contextless" (),
	enable_darkness: bool,
}

chunk_tile_collider :: struct {
	collider: rect,
	has_collider: b8,
}

TileMap :: struct {
	chunks: [TILEMAP_CHUNK_COUNT_W * TILEMAP_CHUNK_COUNT_H]TileChunk,
	tileset: ^Image,
	tiledef: []TileDefinition,
	active_chunk_colliders: [TILE_CHUNK_COUNT_W*TILE_CHUNK_COUNT_H] chunk_tile_collider,
}

ActivateChunk :: proc "contextless" ( tilemap: ^TileMap, active_chunk_coords: ivec2 ) {
	// setup entities
	// destroy ents outside current active chunk
	for ent in &s_EntityPool {
		if .InUse not_in ent.flags do continue
		if ent.position.chunk != active_chunk_coords {
			DestroyEntity( &ent )
		}
	}
	// create entities linked to this chunk
	active_chunk := GetChunkFromChunkCoordinates( tilemap, active_chunk_coords.x, active_chunk_coords.y )
	active_chunk.populate_function()
	for ent in &s_EntityPool {
		if .InUse not_in ent.flags do continue
		ent.position.chunk = active_chunk_coords
	}

	// update colliders
	for tile, i in active_chunk.tiles {
		def := tilemap.tiledef[tile]
		if def.solid {
			x, y := i32(i) % TILE_CHUNK_COUNT_W, i32(i) / TILE_CHUNK_COUNT_W
			tilemap.active_chunk_colliders[i].collider = rect{ {x * TILE_SIZE, y * TILE_SIZE}, {x * TILE_SIZE + TILE_SIZE, y * TILE_SIZE + TILE_SIZE} }
			tilemap.active_chunk_colliders[i].has_collider = true
		} else {
			tilemap.active_chunk_colliders[i].has_collider = false
		}
	}
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

IsCollidingWithTilemap_Collider :: proc "contextless" ( tilemap: ^TileMap, chunk: ivec2, collider: rect ) -> bool {
	tile_pos_min := collider.min / TILE_SIZE
	if tile_pos_min.x < 0 do tile_pos_min.x = 0
	if tile_pos_min.y < 0 do tile_pos_min.y = 0
	if tile_pos_min.x >= TILE_CHUNK_COUNT_W do tile_pos_min.x = TILE_CHUNK_COUNT_W - 1
	if tile_pos_min.y >= TILE_CHUNK_COUNT_H do tile_pos_min.y = TILE_CHUNK_COUNT_H - 1
	
	tile_pos_max := collider.max / TILE_SIZE
	if tile_pos_max.x < 0 do tile_pos_max.x = 0
	if tile_pos_max.y < 0 do tile_pos_max.y = 0
	if tile_pos_max.x >= TILE_CHUNK_COUNT_W do tile_pos_max.x = TILE_CHUNK_COUNT_W - 1
	if tile_pos_max.y >= TILE_CHUNK_COUNT_H do tile_pos_max.y = TILE_CHUNK_COUNT_H - 1

	chunk_idx := chunk.y * TILEMAP_CHUNK_COUNT_W + chunk.x
	for tile_y in tile_pos_min.y .. tile_pos_max.y {
		for tile_x in tile_pos_min.x .. tile_pos_max.x {
			idx := tile_y * TILE_CHUNK_COUNT_W + tile_x
			tile := tilemap.chunks[chunk_idx].tiles[idx]
			if tilemap.tiledef[tile].solid do return true
		}
	}

	return false
}

GetTileWorldCoordinate :: proc "contextless" ( x, y: i32 ) -> ivec2 {
	return { x*TILE_SIZE, y*TILE_SIZE }
}

GetTileWorldCoordinate2 :: proc "contextless" ( x, y: i32 ) -> ( i32, i32 ) {
	return x*TILE_SIZE, y*TILE_SIZE
}

GetTileWorldCoordinateMidPoint :: proc "contextless" ( x, y: i32 ) -> ( ivec2 ) {
	pos := GetTileWorldCoordinate( x, y )
	pos += { TILE_SIZE / 2, TILE_SIZE / 2 }
	return pos
}

GetTileLocalCoordinate_XY :: proc "contextless" ( x, y: i32 ) -> ivec2 {
	return { x / TILE_SIZE, y / TILE_SIZE }
}

GetTileLocalCoordinate_Vec :: proc "contextless" ( p: ivec2 ) -> ivec2 {
	return p / TILE_SIZE
}

GetTileLocalCoordinate :: proc {
	GetTileLocalCoordinate_XY,
	GetTileLocalCoordinate_Vec,
}

GetChunkFromChunkCoordinates :: proc "contextless" ( tilemap: ^TileMap, x, y: i32 ) -> ^TileChunk {
	if x < 0 || y < 0 || x >= TILEMAP_CHUNK_COUNT_W || y >= TILEMAP_CHUNK_COUNT_H do return nil
	return &tilemap.chunks[y*TILEMAP_CHUNK_COUNT_W + x];
}

GetTilesTouchedByWorldRect :: proc "contextless" ( r: rect ) -> rect {
	return {
		{ r.min.x / TILE_SIZE, r.min.y / TILE_SIZE },
		{ (r.max.x - 1) / TILE_SIZE, (r.max.y - 1) / TILE_SIZE },
	}
}
