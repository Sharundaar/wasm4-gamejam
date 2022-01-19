package rand

Rand :: struct {
	state: u64,
	inc:   u64,
}

init :: proc "contextless" (r: ^Rand, seed: u64) {
	r.state = 0
	r.inc = (seed << 1) | 1
	_random(r)
	r.state += seed
	_random(r)
}

_random :: proc "contextless" (r: ^Rand) -> u32 {
	r := r
	old_state := r.state
	r.state = old_state * 6364136223846793005 + (r.inc|1)
	xor_shifted := u32(((old_state>>18) ~ old_state) >> 27)
	rot := u32(old_state >> 59)
	return (xor_shifted >> rot) | (xor_shifted << ((-rot) & 31))
}

uint32 :: proc "contextless" (r: ^Rand = nil) -> u32 { return _random(r) }
