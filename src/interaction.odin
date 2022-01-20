package main

Container :: struct {
	on_open: proc "contextless" ( ent_id: u8 ),
}

Interaction :: union {
	^DialogDef,
	^Container,
}
