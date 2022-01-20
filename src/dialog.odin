package main
import "w4"

DialogDef :: struct {
    author: string,
    blocks: [][2]string, // line1 line2
    on_dialog_complete : proc "contextless" (),
}

DialogUIState :: enum u8 {
    None,
    Text,
    TransitionIn,
    TransitionOut,
}

DialogUIData :: struct {
    y_offs: u8,
    state: DialogUIState,
    current_dialog: ^DialogDef,
    current_block: u8,
}

Dialog_Start :: proc "contextless" ( def: ^DialogDef ) {
    if s_gglob.game_state == GameState.Dialog {
        when DEVELOPMENT_BUILD do w4.trace( "Can't start a dialog while one is already running." )
        return
    }

    s_gglob.game_state = GameState.Dialog
    s_gglob.dialog_ui.current_dialog = def
    s_gglob.dialog_ui.state = DialogUIState.TransitionIn
    s_gglob.dialog_ui.current_block = 0

    w4.tone_complex( 1, 120, {sustain=30}, 50, .Triangle )
}

Dialog_Update :: proc "contextless" () {
    if s_gglob.game_state != GameState.Dialog do return
    ui := &s_gglob.dialog_ui
    using ui
    
    transition_speed : u8 : 2
    switch state {
        case .None:
        case .Text:
            if s_gglob.input_state.APressed {
                last_block_idx := u8(len( current_dialog.blocks ) - 1)
                if current_block < last_block_idx {
                    current_block += 1
                } else {
                    current_block = last_block_idx
                    state = DialogUIState.TransitionOut
                }
                w4.tone( 1000, 2, 25, .Pulse1 )
            }
        case .TransitionIn:
            y_offs += transition_speed
            if y_offs >= 32 {
                y_offs = 32
                state = DialogUIState.Text
            }
        case .TransitionOut:
            y_offs -= transition_speed
            if y_offs == 0 || y_offs > 32 { // >32 check in case of underflow
                y_offs = 0
                Dialog_End()
            }
    }

    w4.DRAW_COLORS^ = 0x0021
    dialog_background := GetImage( ImageKey.dialog_background )
    w4.blit( &dialog_background.bytes[0], 0, 160 - i32(y_offs), dialog_background.w, dialog_background.h, dialog_background.flags )

    top_padding : i32 : 4
    left_padding : i32 : 3
    name_text_padding : i32 : 2
    font_size : i32 : 8
    half_font_size : i32 : font_size / 2
    if state == DialogUIState.Text || state == DialogUIState.TransitionOut {
        w4.DRAW_COLORS^ = 0x0013
        w4.text( current_dialog.author, left_padding, 160 - i32(y_offs) + top_padding - 1 )
        min_x_first_line := i32(len(current_dialog.author)) * font_size + left_padding + name_text_padding
        msg := current_dialog.blocks[current_block]
        w4.DRAW_COLORS^ = 0x0012
        y : i32 = 0
        for line, i in msg {
            x := i32((160 / 2) - i32(len( line )) * half_font_size)
            if i == 0 && x <= min_x_first_line do x = min_x_first_line
            w4.text( line, x, 160 - i32(y_offs) + top_padding + y )
            y += 12
        }
    }
}

Dialog_End :: proc "contextless" () {
    if s_gglob.game_state != GameState.Dialog do return

    s_gglob.game_state = GameState.Game

    if s_gglob.dialog_ui.current_dialog.on_dialog_complete != nil {
        s_gglob.dialog_ui.current_dialog.on_dialog_complete()
    }

    s_gglob.dialog_ui.current_dialog = nil
    s_gglob.dialog_ui.state = DialogUIState.None
}
