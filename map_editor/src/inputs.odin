package main

import SDL "vendor:sdl2"

InputKey :: enum {
    UNKNOWN,

    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    J,
    K,
    L,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z,

    NUM0,
    NUM1,
    NUM2,
    NUM3,
    NUM4,
    NUM5,
    NUM6,
    NUM7,
    NUM8,
    NUM9,

    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,

    LSHIFT,
    LCTRL,
    LALT,

    RSHIFT,
    RCTRL,
    RALT,

    LEFTARROW,
    UPARROW,
    RIGHTARROW,
    DOWNARROW,

    HOME,
    END,
    INSERT,
    DELETE,
    PAGEUP,
    PAGEDOWN,

    SPACE,
    ESCAPE,
    ENTER,
    BACKSPACE,
    TAB,

    MOUSE1,
    MOUSE2,
    MOUSE3,
    MOUSE4,
    MOUSE5,

    COUNT,
}
IK :: InputKey

SDLScancodeToInputKeyMap : [SDL.NUM_SCANCODES]InputKey = {}

IGlob :: struct {
    mouse_position : vec2,
    prev_mouse_position : vec2,
    mouse_wheel : vec2,

    key_down   : [InputKey.COUNT]bool,
    key_change : [InputKey.COUNT]bool,
    key_repeat : [InputKey.COUNT]bool,
}
iglob : IGlob

IN_InitSDLScancodeMap :: proc() {
    SDLScancodeToInputKeyMap[SDL.Scancode.UNKNOWN] = InputKey.UNKNOWN

    SDLScancodeToInputKeyMap[SDL.Scancode.A] = InputKey.A
    SDLScancodeToInputKeyMap[SDL.Scancode.B] = InputKey.B
    SDLScancodeToInputKeyMap[SDL.Scancode.C] = InputKey.C
    SDLScancodeToInputKeyMap[SDL.Scancode.D] = InputKey.D
    SDLScancodeToInputKeyMap[SDL.Scancode.E] = InputKey.E
    SDLScancodeToInputKeyMap[SDL.Scancode.F] = InputKey.F
    SDLScancodeToInputKeyMap[SDL.Scancode.G] = InputKey.G
    SDLScancodeToInputKeyMap[SDL.Scancode.H] = InputKey.H
    SDLScancodeToInputKeyMap[SDL.Scancode.I] = InputKey.I
    SDLScancodeToInputKeyMap[SDL.Scancode.J] = InputKey.J
    SDLScancodeToInputKeyMap[SDL.Scancode.K] = InputKey.K
    SDLScancodeToInputKeyMap[SDL.Scancode.L] = InputKey.L
    SDLScancodeToInputKeyMap[SDL.Scancode.M] = InputKey.M
    SDLScancodeToInputKeyMap[SDL.Scancode.N] = InputKey.N
    SDLScancodeToInputKeyMap[SDL.Scancode.O] = InputKey.O
    SDLScancodeToInputKeyMap[SDL.Scancode.P] = InputKey.P
    SDLScancodeToInputKeyMap[SDL.Scancode.Q] = InputKey.Q
    SDLScancodeToInputKeyMap[SDL.Scancode.R] = InputKey.R
    SDLScancodeToInputKeyMap[SDL.Scancode.S] = InputKey.S
    SDLScancodeToInputKeyMap[SDL.Scancode.T] = InputKey.T
    SDLScancodeToInputKeyMap[SDL.Scancode.U] = InputKey.U
    SDLScancodeToInputKeyMap[SDL.Scancode.V] = InputKey.V
    SDLScancodeToInputKeyMap[SDL.Scancode.W] = InputKey.W
    SDLScancodeToInputKeyMap[SDL.Scancode.X] = InputKey.X
    SDLScancodeToInputKeyMap[SDL.Scancode.Y] = InputKey.Y
    SDLScancodeToInputKeyMap[SDL.Scancode.Z] = InputKey.Z

    SDLScancodeToInputKeyMap[SDL.Scancode.NUM1] = InputKey.NUM1
    SDLScancodeToInputKeyMap[SDL.Scancode.NUM2] = InputKey.NUM2
    SDLScancodeToInputKeyMap[SDL.Scancode.NUM3] = InputKey.NUM3
    SDLScancodeToInputKeyMap[SDL.Scancode.NUM4] = InputKey.NUM4
    SDLScancodeToInputKeyMap[SDL.Scancode.NUM5] = InputKey.NUM5
    SDLScancodeToInputKeyMap[SDL.Scancode.NUM6] = InputKey.NUM6
    SDLScancodeToInputKeyMap[SDL.Scancode.NUM7] = InputKey.NUM7
    SDLScancodeToInputKeyMap[SDL.Scancode.NUM8] = InputKey.NUM8
    SDLScancodeToInputKeyMap[SDL.Scancode.NUM9] = InputKey.NUM9
    SDLScancodeToInputKeyMap[SDL.Scancode.NUM0] = InputKey.NUM0

    SDLScancodeToInputKeyMap[SDL.Scancode.RETURN] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.ESCAPE] = InputKey.ESCAPE
    SDLScancodeToInputKeyMap[SDL.Scancode.BACKSPACE] = InputKey.BACKSPACE
    SDLScancodeToInputKeyMap[SDL.Scancode.TAB] = InputKey.TAB
    SDLScancodeToInputKeyMap[SDL.Scancode.SPACE] = InputKey.SPACE

    SDLScancodeToInputKeyMap[SDL.Scancode.MINUS] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.EQUALS] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.LEFTBRACKET] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.RIGHTBRACKET] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.BACKSLASH] = InputKey.UNKNOWN

    SDLScancodeToInputKeyMap[SDL.Scancode.NONUSHASH] = InputKey.UNKNOWN

    SDLScancodeToInputKeyMap[SDL.Scancode.COMMA] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.PERIOD] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.SLASH] = InputKey.UNKNOWN

    SDLScancodeToInputKeyMap[SDL.Scancode.COMMA] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.PERIOD] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.SLASH] = InputKey.UNKNOWN

    SDLScancodeToInputKeyMap[SDL.Scancode.CAPSLOCK] = InputKey.UNKNOWN

    SDLScancodeToInputKeyMap[SDL.Scancode.F1] = InputKey.F1
    SDLScancodeToInputKeyMap[SDL.Scancode.F2] = InputKey.F2
    SDLScancodeToInputKeyMap[SDL.Scancode.F3] = InputKey.F3
    SDLScancodeToInputKeyMap[SDL.Scancode.F4] = InputKey.F4
    SDLScancodeToInputKeyMap[SDL.Scancode.F5] = InputKey.F5
    SDLScancodeToInputKeyMap[SDL.Scancode.F6] = InputKey.F6
    SDLScancodeToInputKeyMap[SDL.Scancode.F7] = InputKey.F7
    SDLScancodeToInputKeyMap[SDL.Scancode.F8] = InputKey.F8
    SDLScancodeToInputKeyMap[SDL.Scancode.F9] = InputKey.F9
    SDLScancodeToInputKeyMap[SDL.Scancode.F10] = InputKey.F10
    SDLScancodeToInputKeyMap[SDL.Scancode.F11] = InputKey.F11
    SDLScancodeToInputKeyMap[SDL.Scancode.F12] = InputKey.F12

    SDLScancodeToInputKeyMap[SDL.Scancode.PRINTSCREEN] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.SCROLLLOCK] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.PAUSE] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.INSERT] = InputKey.INSERT
    SDLScancodeToInputKeyMap[SDL.Scancode.HOME] = InputKey.HOME
    SDLScancodeToInputKeyMap[SDL.Scancode.PAGEUP] = InputKey.PAGEUP
    SDLScancodeToInputKeyMap[SDL.Scancode.DELETE] = InputKey.DELETE
    SDLScancodeToInputKeyMap[SDL.Scancode.END] = InputKey.END
    SDLScancodeToInputKeyMap[SDL.Scancode.PAGEDOWN] = InputKey.PAGEDOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.RIGHT] = InputKey.RIGHTARROW
    SDLScancodeToInputKeyMap[SDL.Scancode.LEFT] = InputKey.LEFTARROW
    SDLScancodeToInputKeyMap[SDL.Scancode.DOWN] = InputKey.DOWNARROW
    SDLScancodeToInputKeyMap[SDL.Scancode.UP] = InputKey.UPARROW

    SDLScancodeToInputKeyMap[SDL.Scancode.NUMLOCKCLEAR] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_DIVIDE] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_MULTIPLY] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_MINUS] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_PLUS] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_ENTER] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_1] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_2] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_3] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_4] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_5] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_6] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_7] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_8] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_9] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_0] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_PERIOD] = InputKey.UNKNOWN

    SDLScancodeToInputKeyMap[SDL.Scancode.NONUSBACKSLASH] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.APPLICATION] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.POWER] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_EQUALS] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.F13] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.F14] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.F15] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.F16] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.F17] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.F18] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.F19] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.F20] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.F21] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.F22] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.F23] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.F24] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.EXECUTE] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.HELP] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.MENU] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.SELECT] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.STOP] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.AGAIN] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.UNDO] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.CUT] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.COPY] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.PASTE] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.FIND] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.MUTE] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.VOLUMEUP] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.VOLUMEDOWN] = InputKey.UNKNOWN
    /*
    SDLScancodeToInputKeyMap[SDL.Scancode.LOCKINGCAPSLOCK] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.LOCKINGNUMLOCK] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.LOCKINGSCROLLLOCK] = InputKey.UNKNOWN
    */
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_COMMA] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_EQUALSAS400] = InputKey.UNKNOWN

    SDLScancodeToInputKeyMap[SDL.Scancode.INTERNATIONAL1] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.INTERNATIONAL2] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.INTERNATIONAL3] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.INTERNATIONAL4] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.INTERNATIONAL5] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.INTERNATIONAL6] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.INTERNATIONAL7] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.INTERNATIONAL8] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.INTERNATIONAL9] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.LANG1] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.LANG2] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.LANG3] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.LANG4] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.LANG5] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.LANG6] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.LANG7] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.LANG8] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.LANG9] = InputKey.UNKNOWN

    SDLScancodeToInputKeyMap[SDL.Scancode.ALTERASE] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.SYSREQ] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.CANCEL] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.CLEAR] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.PRIOR] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.RETURN2] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.SEPARATOR] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.OUT] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.OPER] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.CLEARAGAIN] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.CRSEL] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.EXSEL] = InputKey.UNKNOWN

    SDLScancodeToInputKeyMap[SDL.Scancode.KP_00] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_000] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.THOUSANDSSEPARATOR] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.DECIMALSEPARATOR] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.CURRENCYUNIT] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.CURRENCYSUBUNIT] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_LEFTPAREN] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_RIGHTPAREN] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_LEFTBRACE] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_RIGHTBRACE] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_TAB] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_BACKSPACE] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_A] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_B] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_C] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_D] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_E] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_F] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_XOR] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_POWER] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_PERCENT] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_LESS] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_GREATER] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_AMPERSAND] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_DBLAMPERSAND] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_VERTICALBAR] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_DBLVERTICALBAR] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_COLON] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_HASH] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_SPACE] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_AT] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_EXCLAM] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_MEMSTORE] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_MEMRECALL] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_MEMCLEAR] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_MEMADD] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_MEMSUBTRACT] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_MEMMULTIPLY] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_MEMDIVIDE] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_PLUSMINUS] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_CLEAR] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_CLEARENTRY] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_BINARY] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_OCTAL] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_DECIMAL] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KP_HEXADECIMAL] = InputKey.UNKNOWN

    SDLScancodeToInputKeyMap[SDL.Scancode.LCTRL] = InputKey.LCTRL
    SDLScancodeToInputKeyMap[SDL.Scancode.LSHIFT] = InputKey.LSHIFT
    SDLScancodeToInputKeyMap[SDL.Scancode.LALT] = InputKey.LALT
    SDLScancodeToInputKeyMap[SDL.Scancode.LGUI] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.RCTRL] = InputKey.RCTRL
    SDLScancodeToInputKeyMap[SDL.Scancode.RSHIFT] = InputKey.RSHIFT
    SDLScancodeToInputKeyMap[SDL.Scancode.RALT] = InputKey.RALT
    SDLScancodeToInputKeyMap[SDL.Scancode.RGUI] = InputKey.UNKNOWN

    SDLScancodeToInputKeyMap[SDL.Scancode.MODE] = InputKey.UNKNOWN

    SDLScancodeToInputKeyMap[SDL.Scancode.AUDIONEXT] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.AUDIOPREV] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.AUDIOSTOP] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.AUDIOPLAY] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.AUDIOMUTE] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.MEDIASELECT] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.WWW] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.MAIL] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.CALCULATOR] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.COMPUTER] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.AC_SEARCH] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.AC_HOME] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.AC_BACK] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.AC_FORWARD] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.AC_STOP] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.AC_REFRESH] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.AC_BOOKMARKS] = InputKey.UNKNOWN

    SDLScancodeToInputKeyMap[SDL.Scancode.BRIGHTNESSDOWN] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.BRIGHTNESSUP] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.DISPLAYSWITCH] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KBDILLUMTOGGLE] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KBDILLUMDOWN] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.KBDILLUMUP] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.EJECT] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.SLEEP] = InputKey.UNKNOWN

    SDLScancodeToInputKeyMap[SDL.Scancode.APP1] = InputKey.UNKNOWN
    SDLScancodeToInputKeyMap[SDL.Scancode.APP2] = InputKey.UNKNOWN
}

IN_GetInputKeyFromSDLScancode :: proc( scancode: SDL.Scancode ) -> InputKey {
    return SDLScancodeToInputKeyMap[scancode]
}

IN_Init :: proc() {
    IN_InitSDLScancodeMap()
}

IN_FrameBegin :: proc() {
    using iglob
    prev_mouse_position = mouse_position
    key_change = {}
    key_repeat = {}
    mouse_wheel = {}
}

IN_IsKeyDown :: proc( key : InputKey ) -> bool {
    return iglob.key_down[key]
}

IN_IsKeyUp :: proc( key : InputKey ) -> bool {
    return !iglob.key_down[key];
}

IN_IsKeyPressed :: proc( key : InputKey ) -> bool {
    return iglob.key_change[key] && iglob.key_down[key]
}

IN_IsKeyReleased :: proc( key : InputKey ) -> bool {
    return iglob.key_change[key] && !iglob.key_down[key]
}

IN_MouseDelta :: proc() -> vec2 {
    return iglob.mouse_position - iglob.prev_mouse_position
}

IN_MousePosition :: proc() -> vec2 {
    return iglob.mouse_position
}

IN_MouseWheel :: proc() -> f32 {
    return iglob.mouse_wheel.y
}

IN_HandleSDLEvent :: proc( evt : SDL.Event ) -> bool {
    using iglob
    #partial switch( evt.type ) {
        case SDL.EventType.KEYDOWN: fallthrough 
        case SDL.EventType.KEYUP:
            key := IN_GetInputKeyFromSDLScancode( evt.key.keysym.scancode )
            if key != InputKey.UNKNOWN {
                key_down[key] = evt.key.state == SDL.PRESSED
                if( evt.key.repeat == 0 ) do key_change[key] = true
                else do key_repeat[key] = true
            }
            return true
        case SDL.EventType.MOUSEBUTTONDOWN: fallthrough 
        case SDL.EventType.MOUSEBUTTONUP: {
            key := InputKey.UNKNOWN
            switch( evt.button.button ) {
                case SDL.BUTTON_LEFT: key = InputKey.MOUSE1
                case SDL.BUTTON_RIGHT: key = InputKey.MOUSE2
                case SDL.BUTTON_MIDDLE: key = InputKey.MOUSE3
                case SDL.BUTTON_X1: key = InputKey.MOUSE4
                case SDL.BUTTON_X2: key = InputKey.MOUSE5
            }
            if key != InputKey.UNKNOWN {
                key_down[key] = evt.button.state == SDL.PRESSED
                key_change[key] = true
            }
            return true
        }
        case SDL.EventType.MOUSEWHEEL:
            mouse_wheel = { auto_cast( evt.wheel.x ), auto_cast( evt.wheel.y ) }
            return true
        case SDL.EventType.MOUSEMOTION:
            mouse_position = { auto_cast( evt.motion.x ), auto_cast( evt.motion.y ) }
            return true
    }

    return false
}
