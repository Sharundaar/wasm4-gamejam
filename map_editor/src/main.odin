package main

import "core:fmt"
import "core:os"
import SDL "vendor:sdl2"
import gl "vendor:OpenGL"
import "core:math"
import l "core:math/linalg"
import lgl "core:math/linalg/glsl"
import "core:time"
import "core:strings"

Timer :: struct {
    last_tick : time.Tick,
}

TILE_SIZE :: 16

TILE_CHUNK_COUNT_W :: 10
TILE_CHUNK_COUNT_H :: 9

TILEMAP_CHUNK_COUNT_W :: 6
TILEMAP_CHUNK_COUNT_H :: 5

TILE_TOTAL_W :: TILE_CHUNK_COUNT_W * TILEMAP_CHUNK_COUNT_W
TILE_TOTAL_H :: TILE_CHUNK_COUNT_H * TILEMAP_CHUNK_COUNT_H

TileDefinition :: struct {
	color: Color,
}

TileMap :: struct {
    tiles: [TILE_CHUNK_COUNT_W*TILE_CHUNK_COUNT_H*TILEMAP_CHUNK_COUNT_W*TILEMAP_CHUNK_COUNT_H]u8,
    tiledefs: []TileDefinition,
}
tiledefs := []TileDefinition {
    { color_from_str( "#AA2323" ) },
    { color_from_str( "#2323AA" ) },
    { color_from_str( "#23AA23" ) },
    { color_from_str( "#FF7777" ) },
    { color_from_str( "#FFFFFF" ) },
}
tilemap := TileMap{ {}, tiledefs }
camera  : Camera

DrawTilemap :: proc() {
    first_tile_x := clamp( i32( (camera.center.x - camera.width / 2) / TILE_SIZE ), 0, TILE_CHUNK_COUNT_W*TILEMAP_CHUNK_COUNT_W )
    first_tile_y := clamp( i32( (camera.center.y - camera.height / 2) / TILE_SIZE ), 0, TILE_CHUNK_COUNT_H*TILEMAP_CHUNK_COUNT_H )
    last_tile_x := clamp( i32( (camera.center.x + camera.width / 2) / TILE_SIZE ) + 1, 0, TILE_CHUNK_COUNT_W*TILEMAP_CHUNK_COUNT_W )
    last_tile_y := clamp( i32( (camera.center.y + camera.height / 2) / TILE_SIZE ) + 1, 0, TILE_CHUNK_COUNT_H*TILEMAP_CHUNK_COUNT_H )

    // fmt.println( camera.width, camera.height, first_tile_x, first_tile_y, last_tile_x, last_tile_y )

    for idxy in first_tile_y..<last_tile_y {
        for idxx in first_tile_x..<last_tile_x {
            idx := idxy * TILE_CHUNK_COUNT_W*TILEMAP_CHUNK_COUNT_W + idxx
            x1 : f32 = f32(idxx * TILE_SIZE)
            y1 : f32 = f32(idxy * TILE_SIZE)
            x2 := x1 + TILE_SIZE
            y2 := y1 + TILE_SIZE
            color := tilemap.tiledefs[tilemap.tiles[idx]].color
            IM_DrawRect( { x1, y1 }, { x2, y2 }, color )
            IM_Flush()
        }
    }
}

Camera :: struct {
    center: vec2,
    height, width: f32,
}

G_InitCamera :: proc() -> Camera {
    camera : Camera

    camera.height = f32(TILE_SIZE * TILE_CHUNK_COUNT_H *1.25)
    camera.width = R_WinAspectRatio() * camera.height
    camera.center = { camera.width / 2, camera.height / 2 }

    return camera
}

Camera_ComputeProjectionMatrix :: proc( camera: ^Camera ) -> mat4 {
    aspect_ratio := R_WinAspectRatio()
    return lgl.mat4Ortho3d( 0, aspect_ratio * camera.height, camera.height, 0, -1000.0, 1000.0 )
}

timer_tick :: proc( timer: ^Timer ) -> time.Duration {
    tick := time.tick_now()
    duration := time.tick_diff( timer.last_tick, tick )
    timer.last_tick = tick
    return duration
}

selected_tiledef : int

SelectNextTileDef :: proc() {
    selected_tiledef = (selected_tiledef + 1) % len( tiledefs )
}

SelectPreviousTileDef :: proc() {
    selected_tiledef = selected_tiledef - 1
    if selected_tiledef < 0 {
        selected_tiledef = len( tiledefs ) - 1
    }
}

Camera_ComputeViewMatrix :: proc( camera: ^Camera ) -> mat4 {
    // return identity( mat4 )
    aspect_ratio := R_WinAspectRatio()
    c := vec2{ camera.height * aspect_ratio / 2.0, camera.height / 2.0 }
    v := camera.center - c
    return lgl.mat4Translate( vec3{ -v.x, -v.y, 0 } )
}

LoadTilemap :: proc( input: string = "map.txt") {
    content, success := os.read_entire_file( input )
    if success {
        fmt.println( "Successfully read", input )
        for chunk_y in 0..<TILEMAP_CHUNK_COUNT_H {
            for chunk_x in 0..<TILEMAP_CHUNK_COUNT_W {
                for tile_y in 0..<TILE_CHUNK_COUNT_H {
                    for tile_x in 0..<TILE_CHUNK_COUNT_W {
                        idx := tile_x + tile_y * TILE_CHUNK_COUNT_W * TILEMAP_CHUNK_COUNT_W + chunk_x * TILE_CHUNK_COUNT_W + chunk_y * TILE_CHUNK_COUNT_W * TILE_CHUNK_COUNT_H * TILEMAP_CHUNK_COUNT_W
                        content_idx := tile_x + tile_y * TILE_CHUNK_COUNT_W * TILEMAP_CHUNK_COUNT_W + chunk_x * TILE_CHUNK_COUNT_W + chunk_y * TILE_CHUNK_COUNT_W * TILE_CHUNK_COUNT_H * TILEMAP_CHUNK_COUNT_W
                        tilemap.tiles[idx] = u8( content[content_idx] - '0' )
                    }
                }
            }
        }
    } else {
        fmt.println( "Failed to read", input )
    }
}

SaveTilemap :: proc() {
    data : [dynamic]byte ; defer delete( data )
    for t in tilemap.tiles {
        append( &data, byte(t + '0') )
    }
    os.write_entire_file( "map.txt", data[:] )
}

ExportTilemap :: proc ( output : string = "../../src/tilemap_export.odin" ) {
    builder := strings.make_builder()
    strings.write_string( &builder, "package main\n" )
    strings.write_string( &builder, "tilemap_chunks : [TILEMAP_CHUNK_COUNT_W * TILEMAP_CHUNK_COUNT_H]TileChunk = {\n" )
    for chunk_y in 0..<TILEMAP_CHUNK_COUNT_H {
        for chunk_x in 0..<TILEMAP_CHUNK_COUNT_W {
            strings.write_string( &builder, "\t{ { " )
            for tile_y in 0..<TILE_CHUNK_COUNT_H {
                for tile_x in 0..<TILE_CHUNK_COUNT_W {
                    def := tilemap.tiles[tile_x + tile_y * TILE_CHUNK_COUNT_W * TILEMAP_CHUNK_COUNT_W + chunk_x * TILE_CHUNK_COUNT_W + chunk_y * TILE_CHUNK_COUNT_W * TILE_CHUNK_COUNT_H * TILEMAP_CHUNK_COUNT_W]
                    strings.write_byte( &builder, def + '0' )
                    strings.write_string( &builder, ", " )
                }
            }
            strings.write_string( &builder, "}, nil },\n" )
        }
    }
    strings.write_string( &builder, "}\n" )
    os.write_entire_file( output, transmute( []u8 )( strings.to_string( builder ) ) )
}

DrawGrid :: proc() {
    for x in 0..<TILEMAP_CHUNK_COUNT_W * TILE_CHUNK_COUNT_W {
        thickness : f32 = 0.5
        if x % TILE_CHUNK_COUNT_W == 0 do thickness = 1.0
        IM_DrawLine( { f32(x) * TILE_SIZE, 0 }, { f32(x) * TILE_SIZE, TILEMAP_CHUNK_COUNT_H * TILE_CHUNK_COUNT_H * TILE_SIZE }, COLOR_BLACK, thickness )
        IM_Flush()
    }
    for y in 0..<TILEMAP_CHUNK_COUNT_H * TILE_CHUNK_COUNT_H {
        thickness : f32 = 0.5
        if y % TILE_CHUNK_COUNT_H == 0 do thickness = 1.0
        IM_DrawLine( { 0, f32(y) * TILE_SIZE }, { TILEMAP_CHUNK_COUNT_W * TILE_CHUNK_COUNT_W * TILE_SIZE, f32(y) * TILE_SIZE }, COLOR_BLACK, thickness )
        IM_Flush()
    }
}

main :: proc() {
    args := os.args
    if len( args ) > 1 {
        input: string = "map.txt"
        output: string = "../../src/tilemap_export.odin"
        k := 1
        for k < len( args ) {
            if args[k] == "-export" {
                output = args[k+1]
                k += 1
            } else if args[k] == "-input" {
                input = args[k+1]
                k += 1
            }
            k += 1
        }
        fmt.println( input, output )
        LoadTilemap( input )
        ExportTilemap( output )
        return
    }

    R_Init()
    IM_Init()
    IN_Init()

    camera = G_InitCamera()

    timer : time.Duration = 0
    main_clock: Timer

    IM_SetClearColor( color_from_str( "#000000" ) )
    LoadTilemap()

    main_loop: for {
        timer = timer_tick( &main_clock )
        IN_FrameBegin()

        evt : SDL.Event
        for SDL.PollEvent( &evt ) > 0 {
            if IN_HandleSDLEvent( evt ) do continue
            if R_HandleSDLEvent( evt ) do continue

            #partial switch evt.type {
                case SDL.EventType.QUIT:
                    break main_loop
                case:
            }
        }

        if IN_IsKeyReleased( InputKey.ESCAPE ) do break main_loop

        if IN_IsKeyDown( InputKey.LCTRL ) {
            if IN_IsKeyPressed( InputKey.S ) {
                SaveTilemap()
                ExportTilemap()
            }
            if IN_IsKeyPressed( InputKey.E ) {
                ExportTilemap()
            }
        }

        IM_ClearColorAndDepthBuffer()
        IM_SetProjectionMatrix( Camera_ComputeProjectionMatrix( &camera ) )
        IM_SetViewMatrix( Camera_ComputeViewMatrix( &camera ) )
        DrawTilemap()
        DrawGrid()

        if IN_MouseWheel() > 0 {
            SelectNextTileDef()
        } else if IN_MouseWheel() < 0 {
            SelectPreviousTileDef()
        }

        if IN_IsKeyDown( InputKey.SPACE ) {
            if IN_IsKeyDown( InputKey.MOUSE1 ) {
                delta := IN_MouseDelta()
                delta.x *= camera.width / R_WinWidthf()
                delta.y *= camera.height / R_WinHeightf()
                camera.center -= delta
            }
        } else {
            mouse_pos_world := IN_MousePosition()
            mouse_pos_world *= vec2{ camera.width / R_WinWidthf(), camera.height / R_WinHeightf() }
            mouse_pos_world += camera.center - { camera.width / 2, camera.height / 2 }
            mouse_tile_pos := mouse_pos_world / TILE_SIZE
            mouse_tile_pos.x = math.floor_f32( mouse_tile_pos.x )
            mouse_tile_pos.y = math.floor_f32( mouse_tile_pos.y )
            if mouse_tile_pos.x >= 0 && mouse_tile_pos.x < TILE_TOTAL_W \
                && mouse_tile_pos.y >= 0 && mouse_tile_pos.y < TILE_TOTAL_H {
                    def := tilemap.tiles[i32(mouse_tile_pos.y) * TILE_TOTAL_W + i32(mouse_tile_pos.x)]
                    if IN_IsKeyDown( InputKey.MOUSE1 ) {
                        tilemap.tiles[i32(mouse_tile_pos.y) * TILE_TOTAL_W + i32(mouse_tile_pos.x)] = u8(selected_tiledef)
                    }
                    if IN_IsKeyPressed( InputKey.MOUSE2 ) {
                        selected_tiledef = int(def)
                    }
                    current_color := tiledefs[def].color
                    wanted_color := tiledefs[selected_tiledef].color
                    IM_DrawRect( mouse_tile_pos * TILE_SIZE, mouse_tile_pos * TILE_SIZE + { TILE_SIZE, TILE_SIZE }, current_color )
                    IM_DrawRect( mouse_tile_pos * TILE_SIZE + { 4, 4 }, mouse_tile_pos * TILE_SIZE + { TILE_SIZE - 4, TILE_SIZE - 4 }, wanted_color )
                    IM_Flush()
                }
        }

        R_SwapWindow()
    }

    SaveTilemap()
}