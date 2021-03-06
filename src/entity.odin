package main
import "w4"

when DEVELOPMENT_BUILD {
	import "core:strconv"
	import "core:runtime"
}

EntityFlag :: enum u8 {
	InUse,
	Player,
	Interactible,
	AnimatedSprite,
	Collidable,
	DamageMaker,
	DamageReceiver,
}
EntityFlags :: distinct bit_set[EntityFlag; u8]

EntityName :: enum u8 {
	Default,
	Player,
	Miru,
	Tom,
	Bat,
	SwordAltar,
	MirusFireball,
	TomBoss,
	MiruBoss,
}

Entity :: struct {
	id: u8,
	name : EntityName,
	flags : EntityFlags,
	
	position : GlobalCoordinates,
	looking_dir : ivec2,

	animated_sprite: AnimationController,
	interaction: Interaction,
	collider: rect,
	hurt_box: rect, // if this box hit a collider it'll trigger a damage (providing the entity is hurtable)
	palette_mask: u16,
	
	health_points: u8, // 0 means entity is dead
	max_health_points: u8, // 0 means entity is dead
	swinging_sword: u8, // 0 means we're not swinging, otherwise frame count since started swinging (clamp at 255)
	received_damage: u8, // 0 means no damage were received recently, otherwise frame count since last damage received
	inflicted_damage: u8, // 0 means no damage were inflicted recently, otherwise count frames since last damage inflicted, wrap around at 256
	damage_flash_palette: u16, saved_palette : u16,
	pushed_back_dist: ivec2, // when receiving damage, push entity over an amount of frames
	pushed_back_cached_pos: ivec2,
	inventory: Inventory, // player inventory
	
	picked_point: ivec2, // picked point by bat brains to go to
	picked_point_counter: u8, // timer to wait before picking a new point after reaching destination
	falling_frame_counter: u8,
	walking_sound_counter: u8,

	on_death: proc "contextless" (), // function call when hp fall to 0
}
EntityTemplate :: distinct Entity // compression ?

ENTITY_POOL_SIZE :: 16 // I doubt we'll ever have more than a few entities active at any time
s_EntityPool : [ENTITY_POOL_SIZE]Entity

EntityPool_GetFirstFreeIndex :: proc "contextless" () -> i32 {
	for e, idx in &s_EntityPool {
		if .InUse not_in e.flags {
			return i32(idx)
		}
	}
	return -1
}

AllocateEntity_Basic :: proc "contextless" ( name := EntityName.Default ) -> ^Entity {
	idx := EntityPool_GetFirstFreeIndex()
	if idx == -1 {
		w4.trace( "No entity available" )
		return nil // this is a panic...
	}

	e := &s_EntityPool[idx]
	e.id = u8(idx + 1)
	e.flags += {.InUse}
	e.name = name
	return e
}

AllocateEntity_Template :: proc "contextless" ( template: ^EntityTemplate ) -> ^Entity {
	idx := EntityPool_GetFirstFreeIndex()
	if idx == -1 {
		w4.trace( "No entity available" )
		return nil // this is a panic...
	}

	e := &s_EntityPool[idx]
	e^ = (cast(^Entity)template)^

	e.id = u8(idx + 1)
	e.flags += {.InUse}
	return e
}

AllocateEntity :: proc {
	AllocateEntity_Basic,
	AllocateEntity_Template,
}

DestroyEntity :: proc "contextless" ( entity: ^Entity ) {
	entity^ = {}
}

UpdateEntities :: proc "contextless" () {
	for entity in &s_EntityPool {
		if .InUse not_in entity.flags do continue
		UpdatePlayer( &entity )
		UpdateAnimatedSprite( &entity )
		UpdateDamageMaker( &entity )
		UpdateDamageReceiver( &entity )
		UpdateTrigger( &entity )

		UpdateBatBehavior( &entity )
		UpdateTomBoss( &entity )
		UpdateMiruBoss( &entity )
		UpdateFireBall( &entity )
	}
}

GetEntityByName :: proc "contextless" ( name: EntityName ) -> ^Entity {
	for entity in &s_EntityPool {
		if .InUse not_in entity.flags do continue
		if entity.name == name do return &entity
	}
	return nil
}

GetEntityById :: proc "contextless" ( id: u8 ) -> ^Entity {
	idx := id - 1
	if idx > len(s_EntityPool) do return nil
	ent := &s_EntityPool[idx]
	if .InUse in ent.flags do return ent
	return nil
}

UpdateAnimatedSprite :: proc "contextless" ( entity: ^Entity ) {
	if .AnimatedSprite not_in entity.flags do return
	if entity.palette_mask != 0 {
		w4.DRAW_COLORS^ = entity.palette_mask
	}
	DrawAnimatedSprite( &entity.animated_sprite, entity.position.offsets.x, entity.position.offsets.y )
}

UpdateDamageMaker :: proc "contextless" ( entity: ^Entity ) {
	if .DamageMaker not_in entity.flags do return
	if entity.inflicted_damage > 0 do entity.inflicted_damage += 1
	pos := entity.position
	hurt_box_world := translate_rect( entity.hurt_box, pos.offsets )
	when SHOW_HURT_BOX {
		w4.DRAW_COLORS^ = 0x21
		w4.rect( hurt_box_world.min.x, hurt_box_world.min.y, u32( hurt_box_world.max.x - hurt_box_world.min.x ), u32( hurt_box_world.max.y - hurt_box_world.min.y ) )
	}
	for ent in &s_EntityPool {
		if .InUse not_in ent.flags do continue
		if .DamageReceiver not_in ent.flags do continue
		if ent.id == entity.id do continue
		if ent.name == entity.name do continue // ideally this should be a "collision layer" check, but I think this should be good enough
		if entity.name == .MirusFireball && (ent.name == .MiruBoss || ent.name == .Miru) do continue // same here, should be collision layer check
		if entity.name == .Bat && (ent.name == .TomBoss || ent.name == .Tom) do continue
		if ent.name == .Bat && (entity.name == .TomBoss || entity.name == .Tom) do continue
		if ent.health_points > 0 && IsCollidingWithEntity( hurt_box_world, &ent ) { // apply damage
			if InflictDamage( &ent ) {
				entity.inflicted_damage = 1
				dir := ent.position.offsets - entity.position.offsets
				dir_normalized := normalize_vec2( dir )
				ent.pushed_back_dist = {
					i32(dir_normalized.x * 20),
					i32(dir_normalized.y * 20),
				}
				ent.pushed_back_cached_pos = ent.position.offsets
			}
		}
	}
}

InflictDamage :: proc "contextless" ( receiver: ^Entity, force_damage := false ) -> bool {
	INVULNERABILITY_TIME :: 10 // invulnerable for 10 frames after receiving damage
	if !force_damage {
		if receiver.received_damage == 255 || (receiver.received_damage > 0 && receiver.received_damage <= INVULNERABILITY_TIME) do return false
	}

	receiver.received_damage = 255 // set at 255 so damage receiver module can start animation and stuff
	receiver.health_points -= 1

	return true
}

UpdateDamageReceiver :: proc "contextless" ( entity: ^Entity ) {
	if .DamageReceiver not_in entity.flags do return
	
	when SHOW_COLLIDER {
		collider := GetWorldSpaceCollider( entity )
		DrawRect( collider )
	}

	if entity.received_damage == 0 do return
	if entity.saved_palette == 0 do entity.saved_palette = entity.palette_mask

	DAMAGE_ANIMATION_LENGTH :: 24
	if entity.received_damage == 255 {
		entity.received_damage = 1
		if entity.name == EntityName.Player {
			Sound_Play( &PlayerSound_Hurt )
		} else {
			w4.tone( 100, 2, 25, .Pulse1 )
		}
	} else {
		entity.received_damage += 1
	}

	DAMAGE_PUSH_BACK_LENGTH :: 16
	if !(entity.name == .MiruBoss || entity.name == .TomBoss) && entity.health_points > 0 && entity.received_damage <= DAMAGE_PUSH_BACK_LENGTH {
		move : ivec2
		if entity.received_damage == DAMAGE_PUSH_BACK_LENGTH {
			move = entity.pushed_back_dist
		} else {
			dist_x : f32 = f32( entity.pushed_back_dist.x ) / DAMAGE_PUSH_BACK_LENGTH * f32( entity.received_damage )
			dist_y : f32 = f32( entity.pushed_back_dist.y ) / DAMAGE_PUSH_BACK_LENGTH * f32( entity.received_damage )
			move = { i32(dist_x), i32(dist_y) }
		}
		entity.position.offsets = entity.pushed_back_cached_pos // kind of hackish
		MoveEntity( entity, move )
	}

	if entity.received_damage <= DAMAGE_ANIMATION_LENGTH {
		entity.palette_mask = entity.damage_flash_palette if (entity.received_damage & 0b100) == 0 else entity.saved_palette
	} else {
		entity.palette_mask = entity.saved_palette
		entity.received_damage = 0
	}

	if entity.health_points == 0 && entity.received_damage == 1 { // make sure a dead entity can't inflict damage
		entity.flags -= {.DamageMaker}
		entity.animated_sprite.flags += {.Pause}
	}

	if entity.health_points == 0 && entity.received_damage >= DAMAGE_ANIMATION_LENGTH {
		if entity.on_death != nil {
			entity.on_death()
		}
		if entity.name == EntityName.Player {
			s_gglob.game_state = GameState.GameOverAnimation
			entity.palette_mask = entity.saved_palette
			entity.received_damage = 0
		} else {
			DestroyEntity( entity )
		}
	}
}

GetSweptBroadphaseBox :: proc "contextless" (b: rect, velocity: ivec2 ) -> rect
{
	broadphasebox : rect
	broadphasebox.min.x = b.min.x if velocity.x > 0 else b.min.x + velocity.x
	broadphasebox.min.y = b.min.y if velocity.y > 0 else b.min.y + velocity.y
	broadphasebox.max.x = b.max.x + velocity.x if velocity.x > 0 else b.max.x
	broadphasebox.max.y = b.max.y + velocity.y if velocity.y > 0 else b.max.y

	return broadphasebox; 
}

SweepAABB :: proc "contextless" ( moving_box: rect, velocity: ivec2, static_box: rect ) -> (t: f32, normal: [2]f32) {
	xInvEntry, yInvEntry: f32
	xInvExit, yInvExit: f32

	// find the distance between the objects on the near and far sides for both x and y 
	if velocity.x > 0 {
		xInvEntry = f32(static_box.min.x - moving_box.max.x)
		xInvExit = f32(static_box.max.x - moving_box.min.x)
	} else {
		xInvEntry = f32(static_box.max.x - moving_box.min.x)
		xInvExit = f32(static_box.min.x - moving_box.max.x)
	}

	if velocity.y > 0 {
		yInvEntry = f32(static_box.min.y - moving_box.max.y)
		yInvExit = f32(static_box.max.y - moving_box.min.y)
	} else {
		yInvEntry = f32(static_box.max.y - moving_box.min.y)
		yInvExit = f32(static_box.min.y - moving_box.max.y)
	}

	xEntry, yEntry : f32
	xExit, yExit : f32

	if velocity.x == 0 {
		xEntry = min(f32)
		xExit = max(f32)
	} else {
		xEntry = xInvEntry / f32(velocity.x)
		xExit = xInvExit / f32(velocity.x)
	}

	if velocity.y == 0 {
		yEntry = min(f32)
		yExit = max(f32)
	} else {
		yEntry = yInvEntry / f32(velocity.y)
		yExit = yInvExit / f32(velocity.y)
	}

	entryTime := max( xEntry, yEntry )
	exitTime := min( xExit, yExit )

	if entryTime > exitTime || (xEntry < 0 && yEntry < 0) || xEntry > 1 || yEntry > 1 {
		t = 1
		normal = {}
		return
	} else {
		if xEntry > yEntry {
			normal.x = 1 if xInvEntry < 0 else -1
			normal.y = 0
		} else {
			normal.x = 0
			normal.y = 1 if yInvEntry < 0 else -1
		}
		t = entryTime

		return
	}
}

// move an entity ensuring collision is evaluated properly
MoveEntity :: proc "contextless" ( entity: ^Entity, move: ivec2 ) {
	if move == {} do return
	if .Collidable not_in entity.flags {
		entity.position.offsets += move
	} else {
		move := move
		collider := GetWorldSpaceCollider( entity )
		broadphasebox := GetSweptBroadphaseBox( collider, move )
		when SHOW_COLLIDER {
			DrawRect( broadphasebox, 0x33 )
		}

		tile_touched := GetTilesTouchedByWorldRect( broadphasebox )
		start_tile_coords := ivec2 {
			broadphasebox.min.x / TILE_SIZE if move.x >= 0 else broadphasebox.max.x / TILE_SIZE,
			broadphasebox.min.y / TILE_SIZE if move.y >= 0 else broadphasebox.max.y / TILE_SIZE,
		}
		last_tile_touched := ivec2 {
			tile_touched.min.x if move.x < 0 else tile_touched.max.x,
			tile_touched.min.y if move.y < 0 else tile_touched.max.y,
		}
		tile_direction := ivec2 {
			-1 if move.x < 0 else 1,
			-1 if move.y < 0 else 1,
		}
		when SHOW_TILE_BROADPHASE_TEST {
			DrawRect( {
				{ tile_touched.min.x * TILE_SIZE, tile_touched.min.y * TILE_SIZE },
				{ (tile_touched.max.x + 1) * TILE_SIZE, (tile_touched.max.y + 1) * TILE_SIZE },
			} )
			DrawRect( { tested_tile_coords * TILE_SIZE, (tested_tile_coords + { 1, 1 }) * TILE_SIZE }, 0x33 )
			DrawRect( { last_tile_touched * TILE_SIZE, (last_tile_touched + { 1, 1 }) * TILE_SIZE }, 0x11 )
		}
		for y := start_tile_coords.y; tile_direction.y * (last_tile_touched.y - y) >= 0; y += tile_direction.y {
			for x := start_tile_coords.x; tile_direction.x * (last_tile_touched.x - x) >= 0; x += tile_direction.x {
				if x < 0 || x >= TILE_CHUNK_COUNT_W do continue
				if y < 0 || y >= TILE_CHUNK_COUNT_H do continue
				c := s_gglob.tilemap.active_chunk_colliders[y * TILE_CHUNK_COUNT_W + x]
				if c.collider_type != .Solid do continue
				if C_TestAABB( broadphasebox, c.collider ) {
					t, n := SweepAABB( collider, move, c.collider )
					if t == 1 do continue
					
					partial_move := ivec2{ i32( t * f32( move.x ) ), i32( t * f32( move.y ) ) }
					entity.position.offsets += partial_move
					dotprod := ( f32(move.x) * n.y + f32(move.y) * n.x ) * ( 1 - t )
					move.x, move.y = i32(dotprod * n.y), i32(dotprod * n.x)
					collider = GetWorldSpaceCollider( entity )
					broadphasebox = GetSweptBroadphaseBox( collider, move )
				}
			}
		}

		for ent in &s_EntityPool {
			if .InUse not_in ent.flags do continue
			if .Collidable not_in ent.flags do continue
			if ent.id == entity.id do continue
			other_collider := GetWorldSpaceCollider( &ent )
			if C_TestAABB( broadphasebox, other_collider ) {
				t, n := SweepAABB( collider, move, other_collider )
				if t == 1 do continue
				
				partial_move := ivec2{ i32( t * f32( move.x ) ), i32( t * f32( move.y ) ) }
				entity.position.offsets += partial_move
				dotprod := ( f32(move.x) * n.y + f32(move.y) * n.x ) * ( 1 - t )
				move.x, move.y = i32(dotprod * n.y), i32(dotprod * n.x)
				collider = GetWorldSpaceCollider( entity )
				broadphasebox = GetSweptBroadphaseBox( collider, move )
			}
		}

		entity.position.offsets += move
	}

	if entity.name == EntityName.Player { // hacks in case you get pushed outside your current chunk
		regularized := false
		if entity.position.offsets.x + entity.collider.max.x - entity.collider.min.x >= TILE_CHUNK_COUNT_W * TILE_SIZE {
			entity.position.offsets.x = 0
			entity.position.chunk.x += 1
			regularized = true
		}
		if entity.position.offsets.y + entity.collider.max.y - entity.collider.min.y >= TILE_CHUNK_COUNT_H * TILE_SIZE {
			entity.position.offsets.y = 0
			entity.position.chunk.y += 1
			regularized = true
		}
		if entity.position.offsets.x < 0 {
			entity.position.offsets.x = TILE_CHUNK_COUNT_W * TILE_SIZE - PLAYER_W - 1
			entity.position.chunk.x -= 1
			regularized = true
		}
		if entity.position.offsets.y < 0 {
			entity.position.offsets.y = TILE_CHUNK_COUNT_H * TILE_SIZE - PLAYER_H - 1
			entity.position.chunk.y -= 1
			regularized = true
		}

		// shouldn't be necessary but for safety
		entity.position = RegularizeCoordinate( entity.position )

		if regularized {
			s_gglob.last_valid_player_position = entity.position.offsets
			entity.pushed_back_cached_pos = entity.position.offsets
		}
	} else {
		entity.position = RegularizeCoordinate( entity.position, false )
	}

}

UpdateTrigger :: proc "contextless" ( entity: ^Entity ) {
	if .Interactible not_in entity.flags do return
	#partial switch i in entity.interaction {
		case ^Trigger: Interaction_CheckTriggerInteraction( entity )
	}
}
