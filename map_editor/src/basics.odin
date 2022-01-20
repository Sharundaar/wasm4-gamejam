package main

from_hex :: proc( x: byte ) -> i32 {
	switch x {
	case '0'..='9':
		return i32(x) - '0'
	case 'a'..='f':
		return i32(x) - 'a' + 10
	case 'A'..='F':
		return i32(x) - 'A' + 10
	}
	return 16
}

clone :: proc(s: []$T, allocator := context.allocator, loc := #caller_location) -> []T {
	c := make([]T, len(s), allocator, loc)
	copy(c, s)
	return c[:len(s)]
}

color_from_str :: proc( str: string ) -> Color {
    c : Color = { 0, 0, 0, 1 }
    if len( str ) == 0 do return c
    if str[0] == '#' { // parse as hex
        str := str[1:]
        alpha := 1
        switch len( str ) {
            case 2:
                gray := f32( from_hex( str[0] ) * 16 + from_hex( str[1] ) )
                c.r = gray ; c.g = gray ; c.b = gray
            case 6:
                c.r = f32(from_hex( str[0] ) * 16 + from_hex( str[1] )) / 255.0
                c.g = f32(from_hex( str[2] ) * 16 + from_hex( str[3] )) / 255.0
                c.b = f32(from_hex( str[4] ) * 16 + from_hex( str[5] )) / 255.0
            case 8:
                c.r = f32(from_hex( str[0] ) * 16 + from_hex( str[1] )) / 255.0
                c.g = f32(from_hex( str[2] ) * 16 + from_hex( str[3] )) / 255.0
                c.b = f32(from_hex( str[4] ) * 16 + from_hex( str[5] )) / 255.0
                c.a = f32(from_hex( str[6] ) * 16 + from_hex( str[7] )) / 255.0
            case:
                assert( false, "Failed to parse color." )
        }
    }

    return c
}
