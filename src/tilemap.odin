package main

TILE_SIZE : i32 : 16
TILE_CHUNK_COUNT_W : i32 : 10
TILE_CHUNK_COUNT_H : i32 : 9

TILEMAP_CHUNK_COUNT_W : i32 : 6
TILEMAP_CHUNK_COUNT_H : i32 : 5

TILEMAP_CHUNK_W :: TILE_SIZE * TILE_CHUNK_COUNT_W
TILEMAP_CHUNK_H :: TILE_SIZE * TILE_CHUNK_COUNT_H

TileColliderType :: enum u8 {
	None,
	Solid,
	Hole,
}

TileDefinition :: struct {
	offsets: ivec2, // offsets in the source texture
	collider_type: TileColliderType,
}

TileChunk :: struct #packed {
	// indices into the map tiledef array
	tiles: [TILE_CHUNK_COUNT_W*TILE_CHUNK_COUNT_H]u8,
	populate_function: proc "contextless" (),
}

chunk_tile_collider :: struct {
	collider: rect,
	collider_type: TileColliderType,
}

TileMap :: struct #packed {
	chunks: []TileChunk,
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

	// disable darkness
	s_gglob.darkness_enabled = false

	// create entities linked to this chunk
	active_chunk := GetChunkFromChunkCoordinates( tilemap, active_chunk_coords.x, active_chunk_coords.y )
	if active_chunk.populate_function != nil {
		active_chunk.populate_function()
	}
	for ent in &s_EntityPool {
		if .InUse not_in ent.flags do continue
		ent.position.chunk = active_chunk_coords
	}

	// update colliders
	for tile, i in active_chunk.tiles {
		def := tilemap.tiledef[tile]
		x, y := i32(i) % TILE_CHUNK_COUNT_W, i32(i) / TILE_CHUNK_COUNT_W
		tilemap.active_chunk_colliders[i].collider = rect{ {x * TILE_SIZE, y * TILE_SIZE}, {x * TILE_SIZE + TILE_SIZE, y * TILE_SIZE + TILE_SIZE} }
		tilemap.active_chunk_colliders[i].collider_type = def.collider_type
	}
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

GetTileDefForCoordinates :: proc "contextless" ( tilemap: ^TileMap, chunk_x, chunk_y, x, y: i32 ) -> ^TileDefinition {
	coords := GetTileLocalCoordinate( x, y )
	if coords.x < 0 || coords.x >= TILE_CHUNK_COUNT_W || coords.y < 0 || coords.y >= TILE_CHUNK_COUNT_H do return nil
	return &tilemap.tiledef[tilemap.chunks[chunk_y * TILEMAP_CHUNK_COUNT_W + chunk_x].tiles[coords.y * TILE_CHUNK_COUNT_W + coords.x]]
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

UpdateTileInChunk :: proc "contextless" ( tilemap: ^TileMap, chunk_x, chunk_y: i32, tile_x, tile_y: i32, newDef: u8 ) {
	tileIdx := tile_y * TILE_CHUNK_COUNT_W + tile_x
	tilemap.chunks[chunk_y * TILEMAP_CHUNK_COUNT_W + chunk_x].tiles[tileIdx] = newDef
	if s_gglob.active_chunk_coords == { chunk_x, chunk_y } {
		def := tilemap.tiledef[newDef]
		tilemap.active_chunk_colliders[tileIdx].collider_type = def.collider_type
	}
}
