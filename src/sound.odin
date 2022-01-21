package main

import "w4"

SoundFrame :: struct {
	start_frequency, end_frequency: u16,
	start_frame: u8, // when to start
	duration: w4.Tone_Duration, // duration of this tone
	channel: w4.Tone_Channel,
	volume: u8,
}

Sound :: struct {
	frames: []SoundFrame,
}

SoundController :: struct {
	enabled_time: u64,
	sound: ^Sound,
}

s_SoundControllerPool : [8]SoundController

Sound_GetAvailableController :: proc "contextless" () -> ^SoundController {
	for ctrl in &s_SoundControllerPool {
		if ctrl.enabled_time == 0 do return &ctrl
	}
	return nil
}

Sound_GetEvictableController :: proc "contextless" () -> ^SoundController {
	oldest_ctrl : ^SoundController
	oldest_time := max(u64)
	for ctrl in &s_SoundControllerPool {
		if ctrl.enabled_time == 0 do continue
		if oldest_time > ctrl.enabled_time {
			oldest_time = ctrl.enabled_time
			oldest_ctrl = &ctrl
		}
	}

	return oldest_ctrl
}

Sound_Play :: proc "contextless" ( sound: ^Sound, evict := true ) {
	controller := Sound_GetAvailableController()
	if controller == nil && evict do Sound_GetEvictableController()
	if controller == nil do return

	controller.enabled_time = s_gglob.global_frame_counter
	controller.sound = sound
	Sound_UpdateSingle( controller )
}

Sound_UpdateSingle :: proc "contextless" ( ctrl: ^SoundController ) {
	time := s_gglob.global_frame_counter - ctrl.enabled_time
	played_sound : u8
	for frame in ctrl.sound.frames {
		if frame.start_frame == u8(time) {
			w4.tone_complex( frame.start_frequency, frame.end_frequency, frame.duration, u32( frame.volume ), frame.channel )
		}
		if frame.start_frame <= u8(time) do played_sound += 1
	}

	if played_sound == u8( len( ctrl.sound.frames ) ) {
		ctrl.sound = nil
		ctrl.enabled_time = 0
		w4.trace( "ended sound" )
	}
}

Sound_Update :: proc "contextless" () {
	for ctrl in &s_SoundControllerPool {
		if ctrl.enabled_time == 0 do continue
		Sound_UpdateSingle( &ctrl )
	}
}

