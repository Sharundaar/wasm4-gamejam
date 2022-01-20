package main

import "core:fmt"
import SDL "vendor:sdl2"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"

RGlob :: struct {
    window: ^SDL.Window,
    glcontext: SDL.GLContext,

    wh : i32,
    ww : i32,
}
rglob : RGlob

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

@(private="file")
GetOpenGLProcAddress :: proc( p: rawptr, name: cstring ) {
    (^rawptr)(p)^ = SDL.GL_GetProcAddress(name)
}

@(private="file")
SetupGLAttributes :: proc() {
    SDL.GL_SetAttribute( SDL.GLattr.ACCELERATED_VISUAL, 1 )
    SDL.GL_SetAttribute( SDL.GLattr.ACCELERATED_VISUAL, 1 )
    SDL.GL_SetAttribute( SDL.GLattr.CONTEXT_MAJOR_VERSION, 4 )
    SDL.GL_SetAttribute( SDL.GLattr.CONTEXT_MINOR_VERSION, 5 )

    SDL.GL_SetAttribute( SDL.GLattr.RED_SIZE,      8 )
    SDL.GL_SetAttribute( SDL.GLattr.BLUE_SIZE,     8 )
    SDL.GL_SetAttribute( SDL.GLattr.GREEN_SIZE,    8 )
    SDL.GL_SetAttribute( SDL.GLattr.DEPTH_SIZE,   16 )
    SDL.GL_SetAttribute( SDL.GLattr.DOUBLEBUFFER,  1 )
}

R_CreateWindow :: proc( width, height: i32 ) {
    flags := SDL.WINDOW_SHOWN | SDL.WINDOW_OPENGL | SDL.WINDOW_RESIZABLE
    rglob.window = SDL.CreateWindow( "Map Editor", 
                                        SDL.WINDOWPOS_UNDEFINED, SDL.WINDOWPOS_UNDEFINED,
                                        width, height,
                                        flags )
    rglob.wh = height
    rglob.ww = width
}

R_OnWindowResize :: proc( width, height: i32 ) {
    gl.Viewport( 0, 0, width, height )
    rglob.wh = height
    rglob.ww = width
}

R_WinWidth :: proc() -> i32 {
    return rglob.ww
}

R_WinWidthf :: proc() -> f32 {
    return f32(rglob.ww)
}

R_WinHeight :: proc() -> i32 {
    return rglob.wh
}

R_WinHeightf :: proc() -> f32 {
    return f32(rglob.wh)
}

R_WinAspectRatio :: proc() -> f32 {
    return f32(rglob.ww) / f32(rglob.wh)
}

R_CreateGLContext :: proc() {
    rglob.glcontext = SDL.GL_CreateContext( rglob.window )
}

R_Init :: proc() {
    SDL.Init( SDL.INIT_VIDEO )
    SetupGLAttributes()
    R_CreateWindow( WINDOW_WIDTH, WINDOW_HEIGHT )
    R_CreateGLContext()
    gl.load_up_to( 4, 6, GetOpenGLProcAddress )

    fmt.println( "Vendor:", gl.GetString( gl.VENDOR ) )
    fmt.println( "Renderer:", gl.GetString( gl.RENDERER ) )
    fmt.println( "Version:", gl.GetString( gl.VERSION ) )

    SDL.GL_SetSwapInterval( 1 )
}

R_SwapWindow :: proc() {
    SDL.GL_SwapWindow( rglob.window )
}

R_HandleSDLEvent :: proc( evt: SDL.Event ) -> bool {
    if evt.type == SDL.EventType.WINDOWEVENT {
        #partial switch evt.window.event {
            case SDL.WindowEventID.RESIZED:
                R_OnWindowResize( evt.window.data1, evt.window.data2 )
                return true
        }
    }

    return false
}
