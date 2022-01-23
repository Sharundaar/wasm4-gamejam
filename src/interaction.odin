package main

Container :: struct {
	on_open: proc "contextless" ( ent_id: u8 ),
}

Trigger :: struct {
	on_trigger: proc "contextless" ( ent_id: u8 ),
}

Interaction :: union {
	^DialogDef,
	^Container,
	^Trigger,
}

Interaction_CheckTriggerInteraction :: proc "contextless" ( trigger: ^Entity ) {
	player := GetEntityByName( .Player )
	if player != nil {
		player_collider := GetWorldSpaceCollider( player )
		trigger_collider := GetWorldSpaceCollider( trigger )
		if C_TestAABB( trigger_collider, player_collider ) {
			#partial switch i in trigger.interaction {
				case ^Trigger: i.on_trigger( trigger.id )
			}
		}
	}
}
