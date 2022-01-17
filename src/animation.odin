package main

import "w4"

AnimationFlag :: enum {
	FlipX,
	FlipY,
	Pause,
}
AnimationFlags :: distinct bit_set[AnimationFlag; u8]

AnimationFrame :: struct {
	length: u8,
	x_offs: u8,
	flags : AnimationFlags,
}

AnimatedSprite :: struct {
	img: ^Image,
	w, h: u32, y_offs: u8,
	frames: []AnimationFrame,
}

AnimationController :: struct {
    sprite: ^AnimatedSprite,
    current_frame: u8,
	frame_counter: u8,
}

AnimationToBlitFlags :: proc "contextless" ( flags: AnimationFlags ) -> w4.Blit_Flags {
	blit_flags : w4.Blit_Flags
	blit_flags += {.FLIPX} if AnimationFlag.FlipX in flags else nil
	blit_flags += {.FLIPY} if AnimationFlag.FlipY in flags else nil
	return blit_flags
}

AnimatedSprite_NextFrame :: proc "contextless" ( controller: ^AnimationController ) {
	controller.frame_counter = 0
	controller.current_frame = u8( int( controller.current_frame + 1 ) % len( controller.sprite.frames ) )
}

DrawAnimatedSprite :: proc "contextless" ( using controller: ^AnimationController, x, y: i32, flags: AnimationFlags = nil ) {
	frame := &sprite.frames[current_frame]
	blit_flags := AnimationToBlitFlags( flags )
	blit_flags += sprite.img.flags
	blit_flags += AnimationToBlitFlags( frame.flags )
	
	w4.blit_sub( &sprite.img.bytes[0], x, y, sprite.w, sprite.h, u32(frame.x_offs), u32(sprite.y_offs), int(sprite.img.w), blit_flags )
	if frame.length > 0 && .Pause not_in flags { // length of 0 describes a blocked frame and needs to be advanced manually
		frame_counter += 1
		if frame_counter >= frame.length {
			AnimatedSprite_NextFrame( controller )
		}
	}
}
