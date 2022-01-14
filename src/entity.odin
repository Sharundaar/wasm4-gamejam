package main
import "w4"

EntityFlag :: enum {
    InUse,
    Player,
    Interactible,
}
EntityFlags :: distinct bit_set[EntityFlag; u8]

EntityName :: enum u8 {
    Default,
    Player,
}

Entity :: struct {
    position : GlobalCoordinates,
    flags : EntityFlags,
    name : EntityName,

    looking_dir : ivec2,
}

ENTITY_POOL_SIZE :: 16 // I doubt we'll ever have more than a few entities active at a time
s_EntityPool : [ENTITY_POOL_SIZE]Entity

AllocateEntity :: proc "contextless" ( name := EntityName.Default ) -> ^Entity {
    for e, idx in &s_EntityPool {
        if .InUse not_in e.flags {
            e.flags += {.InUse}
            e.name = name
            return &s_EntityPool[idx]
        }
    }
    w4.trace( "No entity available" )
    return nil // this is a panic...
}

DestroyEntity :: proc "contextless" ( entity: ^Entity ) {
    entity^ = {}
}

UpdateEntities :: proc "contextless" () {
    for entity in &s_EntityPool {
        if .InUse not_in entity.flags do continue
        UpdatePlayer( &entity )
    }
}

GetEntityByName :: proc "contextless" ( name: EntityName ) -> ^Entity {
    for entity in &s_EntityPool {
        if .InUse not_in entity.flags do continue
        if entity.name == name do return &entity
    }
    return nil
}
