package main
import "w4"

PLAYER_W, PLAYER_H :: 8, 8

PlayerAnimation_Idle_Front := AnimatedSprite {
	&Images.mc, 8, 8, 0,
	{
		AnimationFrame{ 60, 0, nil },
		AnimationFrame{ 50, 8, nil },
	},
	0, 0,
}
PlayerAnimation_Idle_Back := AnimatedSprite {
	&Images.mc, 8, 8, 0,
	{
		AnimationFrame{ 60, 16, nil },
		AnimationFrame{ 50, 24, nil },
	},
	0, 0,
}
PlayerAnimation_Move_Front := AnimatedSprite {
	&Images.mc, 8, 8, 8,
	{
		AnimationFrame{ 15, 0, nil },
		AnimationFrame{ 15, 8, nil },
	},
	0, 0,
}
PlayerAnimation_Move_Back := AnimatedSprite {
	&Images.mc, 8, 8, 8,
	{
		AnimationFrame{ 15, 16, nil },
		AnimationFrame{ 15, 24, nil },
	},
	0, 0,
}

UpdatePlayer :: proc "contextless" ( using entity: ^Entity ) {
	if .Player not_in flags do return

	dir : ivec2 = { 0, 0 }
	if .LEFT in w4.GAMEPAD1^ {
		dir.x -= 1
	}
	if .RIGHT in w4.GAMEPAD1^ {
		dir.x += 1
	}

	testing_pos := position; testing_pos.offsets += dir
	if IsCollidingWithTilemap( &s_gglob.tilemap, testing_pos, 8, 8 ) {
		dir.x = 0
	}

	if .UP in w4.GAMEPAD1^ {
		dir.y -= 1
	}
	if .DOWN in w4.GAMEPAD1^ {
		dir.y += 1
	}

	testing_pos = position; testing_pos.offsets += dir
	if IsCollidingWithTilemap( &s_gglob.tilemap, testing_pos, 8, 8 ) {
		dir.y = 0
	}

	position.offsets += dir

	{ // trigger smooth transition ?
		if position.offsets.x + PLAYER_W >= TILE_CHUNK_COUNT_W * TILE_SIZE {
			position.offsets.x = 0
			position.chunk.x += 1
		}
		if position.offsets.y + PLAYER_H >= TILE_CHUNK_COUNT_H * TILE_SIZE {
			position.offsets.y = 0
			position.chunk.y += 1
		}
		if position.offsets.x < 0 {
			position.offsets.x = TILE_CHUNK_COUNT_W * TILE_SIZE - PLAYER_W
			position.chunk.x -= 1
		}
		if position.offsets.y < 0 {
			position.offsets.y = TILE_CHUNK_COUNT_H * TILE_SIZE - PLAYER_H
			position.chunk.y -= 1
		}
	}

	// shouldn't be necessary but for safety
	position = RegularizeCoordinate( position )

	// draw player
	w4.DRAW_COLORS^ = 0x0120
	if dir.x != 0 || dir.y != 0 {
		if dir.x != 0 do looking_dir.x = dir.x
		if dir.y != 0 do looking_dir.y = dir.y

		flip : AnimationFlags = {.FlipX} if looking_dir.x < 0 else nil
		anim := &PlayerAnimation_Move_Front if looking_dir.y > 0 else &PlayerAnimation_Move_Back
		DrawAnimatedSprite( anim, position.offsets.x, position.offsets.y, flip )
	} else {
		flip : AnimationFlags = {.FlipX} if looking_dir.x < 0 else nil
		anim := &PlayerAnimation_Idle_Front if looking_dir.y > 0 else &PlayerAnimation_Idle_Back
		DrawAnimatedSprite( anim, position.offsets.x, position.offsets.y, flip )
	}
}