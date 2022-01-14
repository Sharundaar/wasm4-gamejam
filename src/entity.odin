package main
import "w4"

EntityFlag :: enum {
	InUse,
	Player,
	Talkable,
	AnimatedSprite,
	Collidable,
}
EntityFlags :: distinct bit_set[EntityFlag; u8]

EntityName :: enum u8 {
	Default,
	Player,
	Miru,
}

Entity :: struct {
	id: u8,
	position : GlobalCoordinates,
	flags : EntityFlags,
	name : EntityName,

	looking_dir : ivec2,

	animated_sprite: ^AnimatedSprite,
	collider: rect,
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
	DrawAnimatedSprite( entity.animated_sprite, entity.position.offsets.x, entity.position.offsets.y )
}
