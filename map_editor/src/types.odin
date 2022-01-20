package main

import lgl "core:math/linalg/glsl"
import l "core:math/linalg"
import "core:builtin"
import "core:intrinsics"

vec2 :: lgl.vec2
vec3 :: lgl.vec3
vec4 :: lgl.vec4

ivec2 :: lgl.ivec2

length :: lgl.length
distance :: lgl.distance
normalize :: lgl.normalize
sign :: lgl.sign
floor :: lgl.floor
dot :: lgl.dot

distancesq_vec2 :: proc( a: vec2, b: vec2 ) -> f32 { return (a.x-b.x)*(a.x-b.x)+(a.y-b.y)*(a.y-b.y) }
distancesq :: proc {
	distancesq_vec2,
}

min :: lgl.min
max :: lgl.max
abs :: lgl.abs


mat2 :: lgl.mat2
mat3 :: lgl.mat3
mat4 :: lgl.mat4

identity :: lgl.identity
inverse :: lgl.inverse
mul :: proc {
    matrix_mul_vector,
}


matrix_mul_vector :: proc(a: $A/matrix[$I, $J]$E, b: $B/[I]E) -> (c: B)
	where !intrinsics.type_is_array(E), intrinsics.type_is_numeric(E) #no_bounds_check {
	for i in 0..<I {
		for j in 0..<J {
			c[j] += a[j, i] * b[i]
		}
	}
	return
}

// clamp n between a and b
clamp :: proc( n: $T, a: T, b: T ) -> T {
	return min( b, max( n, a ) )
}

// represent a color ranged [0..1]
Color :: distinct vec4

COLOR_BLACK :: Color{ 0, 0, 0, 1 }
COLOR_WHITE :: Color{ 1, 1, 1, 1 }

Rect :: struct { x, y, w, h: f32 }

rect_top_left :: proc( using rect: ^Rect ) -> vec2 {
    return { x, y }
}

rect_bottom_right :: proc( using rect: ^Rect ) -> vec2 {
    return { x + w, y + h }
}

rect_center :: proc( using rect: ^Rect ) -> vec2 {
	return { x + w / 2, y + h / 2 }
}
