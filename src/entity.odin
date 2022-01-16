package main
import "w4"

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
}

Entity :: struct {
	id: u8,
	name : EntityName,
	flags : EntityFlags,
	
	position : GlobalCoordinates,
	looking_dir : ivec2,

	animated_sprite: ^AnimatedSprite,
	pause_animation: bool,
	interaction: Interaction,
	collider: rect,
	hurt_box: rect, // if this box hit a collider it'll trigger a damage (providing the entity is hurtable)
	palette_mask: u16,
	
	health_points: u8, // 0 means entity is dead
	swinging_sword: u8, // 0 means we're not swinging, otherwise frame count since started swinging (clamp at 255)
	received_damage: u8, // 0 means no damage were received recently, otherwise frame count since last damage received
	inflicted_damage: u8, // 0 means no damage were inflicted recently, otherwise count frames since last damage inflicted, wrap around at 256
	damage_flash_palette: u16, saved_palette : u16,
	pushed_back_direction: ivec2, // when receiving damage, send entity in that direction for a couple of frames
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
	}
}

GetEntityByName :: proc "contextless" ( name: EntityName ) -> ^Entity {
	for entity in &s_EntityPool {
		if .InUse not_in entity.flags do continue
		if entity.name == name do return &entity
	}
	return nil
}


UpdateAnimatedSprite :: proc "contextless" ( entity: ^Entity ) {
	if .AnimatedSprite not_in entity.flags do return
	if entity.palette_mask != 0 {
		w4.DRAW_COLORS^ = entity.palette_mask
	}
	DrawAnimatedSprite( entity.animated_sprite, entity.position.offsets.x, entity.position.offsets.y, {.Pause} if entity.pause_animation else nil )
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
		if ent.health_points > 0 && IsCollidingWithEntity( hurt_box_world, &ent ) { // apply damage
			if InflictDamage( &ent ) {
				entity.inflicted_damage = 1
				dir := ent.position.offsets - entity.position.offsets
				dir_normalized := normalize_vec2( dir )
				ent.pushed_back_direction = {
					i32(dir_normalized.x * 2),
					i32(dir_normalized.y * 2),
				}
			}
		}
	}
}

InflictDamage :: proc "contextless" ( receiver: ^Entity ) -> bool {
	INVULNERABILITY_TIME :: 10 // invulnerable for 10 frames after receiving damage
	if receiver.received_damage == 255 || (receiver.received_damage > 0 && receiver.received_damage <= INVULNERABILITY_TIME) do return false

	receiver.received_damage = 255 // set at 255 so damage receiver module can start animation and stuff
	receiver.health_points -= 1

	return true
}

UpdateDamageReceiver :: proc "contextless" ( entity: ^Entity ) {
	if .DamageReceiver not_in entity.flags do return
	
	when SHOW_COLLIDER {
		w4.DRAW_COLORS^ = 0x21
		collider := GetWorldSpaceCollider( entity )
		w4.rect( collider.min.x, collider.min.y, u32( collider.max.x - collider.min.x ), u32( collider.max.y - collider.min.y ) )
	}

	if entity.received_damage == 0 do return
	if entity.saved_palette == 0 do entity.saved_palette = entity.palette_mask

	DAMAGE_ANIMATION_LENGTH :: 24
	if entity.received_damage == 255 {
		entity.received_damage = 1
	} else {
		entity.received_damage += 1
	}

	DAMAGE_PUSH_BACK_LENGTH :: 16
	if entity.health_points > 0 && entity.received_damage <= DAMAGE_PUSH_BACK_LENGTH {
		if entity.name != EntityName.Player { // Let the player handle its own movement
			entity.position.offsets += entity.pushed_back_direction
		}
	}

	if entity.received_damage <= DAMAGE_ANIMATION_LENGTH {
		entity.palette_mask = entity.damage_flash_palette if (entity.received_damage & 0b100) == 0 else entity.saved_palette
	} else {
		entity.palette_mask = entity.saved_palette
		entity.received_damage = 0
	}

	if entity.health_points == 0 { // make sure a dead entity can't inflict damage
		entity.flags -= {.DamageMaker}
		entity.pause_animation = true
	}

	if entity.health_points == 0 && entity.received_damage >= DAMAGE_ANIMATION_LENGTH {
		DestroyEntity( entity )
	}
}
