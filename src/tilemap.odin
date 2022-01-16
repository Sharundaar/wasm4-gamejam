package main

TILE_SIZE : i32 : 16
TILE_CHUNK_COUNT_W : i32 : 10
TILE_CHUNK_COUNT_H : i32 : 9

TILEMAP_CHUNK_COUNT_W : i32 : 10
TILEMAP_CHUNK_COUNT_H : i32 : 10

TileDefinition :: struct {
	offsets: ivec2, // offsets in the source texture
	solid: bool,
}

TileChunk :: struct {
	// indices into the map tiledef array
	tiles: [TILE_CHUNK_COUNT_W*TILE_CHUNK_COUNT_H]u8,
	entities: []EntityTemplate,
}

TileMap :: struct {
	chunks: [TILEMAP_CHUNK_COUNT_W * TILEMAP_CHUNK_COUNT_H]TileChunk,
	tileset: ^Image,
	tiledef: []TileDefinition,
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

GetChunkFromChunkCoordinates :: proc "contextless" ( tilemap: ^TileMap, x, y: i32 ) -> ^TileChunk {
	if x < 0 || y < 0 || x >= TILEMAP_CHUNK_COUNT_W || y >= TILEMAP_CHUNK_COUNT_H do return nil
	return &tilemap.chunks[y*TILEMAP_CHUNK_COUNT_W + x];
}
