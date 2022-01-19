package main

Container :: struct {
	on_open: proc "contextless" ( container: ^Entity ),
}

Interaction :: union {
	^DialogDef,
	^Container,
}
