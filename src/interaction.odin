package main

Container :: struct {
	on_open: proc "contextless" (),
}

Interaction :: union {
	^DialogDef,
	^Container,
}
