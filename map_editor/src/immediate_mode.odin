package main

import gl "vendor:OpenGL"
import "core:fmt"
import "core:math"

IM_VERTEX_COUNT :: 65536
IM_INDEX_COUNT  :: IM_VERTEX_COUNT

DrawType :: enum u32 {
    Point,
    
    Lines,
    LineStrip,
    LineLoop,
    
    Triangles,
    TriangleStrip,
    TriangleFan,

    Quads,
    QuadStrip,
}

IM_ShaderData :: struct {
    projection: mat4,
    view: mat4,
}

IM_Glob :: struct {
    vertices:   [IM_VERTEX_COUNT] vec3,
    colors:     [IM_VERTEX_COUNT] Color,
    uvs:        [IM_VERTEX_COUNT] vec2,
    vertex_count: u32,

    indices:    [IM_INDEX_COUNT] u32,
    index_count: u32,

    projection: mat4,
    view: mat4,

    shader_data: IM_ShaderData,

    vbo_vertices: u32,
    vbo_colors: u32,
    vbo_uvs: u32,
    vbo_indices: u32,
    ssbo: u32,
    vao: u32,

    current_shader: ^Shader,
    default_shader: Shader,
    clear_color: Color,
}
imglob : IM_Glob

DEFAULT_VS_SOURCE :: `
    #version 460 core
    layout (std430, binding = 3) buffer ShaderData {
        mat4 Projection;
        mat4 View;
    } shader_data;

    in vec3 iPosition;
    in vec4 iColor;
    out vec4 oColor;

    void main()
    {
        gl_Position = shader_data.Projection * shader_data.View * vec4( iPosition, 1.0 );
        oColor = iColor;
    }
`

DEFAULT_FS_SOURCE :: `
    #version 460 core
    in vec4 oColor;
    out vec4 FragColor;

    void main()
    {
        FragColor = oColor;
    }
`

IM_InitDefaultShader :: proc() {
    using imglob, gl

    Shader_Init( &default_shader )

    compile_error: [512]byte = ---

    vertex_shader, vertex_shader_ok := R_CompileShader( DEFAULT_VS_SOURCE, ShaderType.VERTEX ) ; defer gl.DeleteShader( vertex_shader )
    if !vertex_shader_ok {
        error := R_GetShaderError( vertex_shader ) ; defer delete( error )
        fmt.println( "Error compiling vertex shader:", error );
        assert( false )
    }

    frag_shader, frag_shader_ok := R_CompileShader( DEFAULT_FS_SOURCE, ShaderType.FRAGMENT ) ; defer DeleteShader( frag_shader )
    if !frag_shader_ok {
        error := R_GetShaderError( frag_shader ) ; defer delete( error )
        fmt.println( "Error compiling fragment shader:", error )
        assert( false )
    }

    linked_program, program_ok := R_LinkShaderProgram( { vertex_shader, frag_shader } )

    if !program_ok {
        error := R_GetProgramError( linked_program ) ; defer delete( error )
        fmt.println( "Error linking program:", error )
        assert( false )
    }

    default_shader.program = linked_program
    default_shader.attributes_location = Shader_DeductAttributesFromReflection( default_shader.program )
}

IM_ClearVAO :: proc() {
    using imglob, gl
    if current_shader == nil {
        return
    }

    BindVertexArray( vao )
    for attrib in current_shader.attributes_location {
        if attrib != -1 {
            DisableVertexAttribArray( cast(u32)attrib )
        }
    }
    BindVertexArray( 0 )
}

IM_SetupVAO :: proc() {
    using imglob, gl

    BindVertexArray( vao )

    if attrib, ok := Shader_TryGetAttributeLocation( current_shader, ShaderAttributeType.Position ); ok {
        BindBuffer( ARRAY_BUFFER, vbo_vertices )
        VertexAttribPointer( attrib, 3, FLOAT, FALSE, size_of( vertices[0] ), 0 )
        EnableVertexAttribArray( attrib )
        BindBuffer( ARRAY_BUFFER, 0 )
    }

    if attrib, ok := Shader_TryGetAttributeLocation( current_shader, ShaderAttributeType.Color ); ok {
        BindBuffer( ARRAY_BUFFER, vbo_colors )
        VertexAttribPointer( attrib, 4, FLOAT, FALSE, size_of( colors[0] ), 0 )
        EnableVertexAttribArray( attrib )
        BindBuffer( ARRAY_BUFFER, 0 )
    }

    if attrib, ok := Shader_TryGetAttributeLocation( current_shader, ShaderAttributeType.UV ); ok {
        BindBuffer( ARRAY_BUFFER, vbo_uvs )
        VertexAttribPointer( attrib, 2, FLOAT, FALSE, size_of( uvs[0] ), 0 )
        EnableVertexAttribArray( attrib )
        BindBuffer( ARRAY_BUFFER, 0 )
    }

    BindBuffer( ELEMENT_ARRAY_BUFFER, vbo_indices )
    BindVertexArray( 0 )
    BindBuffer( ELEMENT_ARRAY_BUFFER, 0 )
}

IM_SetShader :: proc( shader: ^Shader ) {
    using imglob
    if current_shader != nil {
        IM_ClearVAO()
    }
    current_shader = shader
    if current_shader != nil {
        IM_SetupVAO()
    }
}

IM_ClearColorAndDepthBuffer :: proc() {
    cc := imglob.clear_color
    gl.ClearColor( cc.r, cc.g, cc.b, cc.a )
    gl.Clear( gl.COLOR_BUFFER_BIT )

    gl.ClearColor( 0, 0, 0, 0 )
    gl.Clear( gl.DEPTH_BUFFER_BIT )
}

IM_SetClearColor :: proc( color: Color ) {
    imglob.clear_color = color
}

IM_Init :: proc() {
    using imglob, gl

    IM_SetClearColor( { 0, 0.5, 0.5, 1 } )
    IM_InitDefaultShader()

    GenBuffers( 5, &vbo_vertices )
    GenVertexArrays( 1, &vao )

    IM_SetProjectionMatrix( identity( mat4 ) )
    IM_SetViewMatrix( identity( mat4 ) )

    IM_SetShader( &default_shader )
}

IM_Shutdown :: proc() {
    using imglob, gl
    DeleteBuffers( 5, &vbo_vertices )
    DeleteVertexArrays( 1, &vao )
}

IM_Clear :: proc() {
    using imglob

    vertex_count = 0
    index_count = 0
}

IM_Flush :: proc() {
    using imglob, gl

    if vertex_count == 0 || index_count == 0 {
        IM_Clear()
        return
    }

    if current_shader == nil {
        IM_SetShader( &default_shader )
    }
    UseProgram( current_shader.program )

    UploadArrayBuffer :: proc( vbo: u32, data: []$T ) {
        BindBuffer( ARRAY_BUFFER, vbo )
        BufferData( ARRAY_BUFFER, cast(int)( vertex_count * size_of( T ) ), &data[0], DYNAMIC_DRAW )
        BindBuffer( ARRAY_BUFFER, 0 )
    }
    
    if Shader_HasAttribute( current_shader, ShaderAttributeType.Position ) {
        UploadArrayBuffer( vbo_vertices, vertices[0:vertex_count] )
    }

    if Shader_HasAttribute( current_shader, ShaderAttributeType.Color ) {
        UploadArrayBuffer( vbo_colors, colors[0:vertex_count] )
    }

    if Shader_HasAttribute( current_shader, ShaderAttributeType.UV ) {
        UploadArrayBuffer( vbo_uvs, uvs[0:vertex_count] )
    }

    BlendEquation(FUNC_ADD);
    BlendFunc(SRC_ALPHA, ONE_MINUS_SRC_ALPHA);
    Enable( BLEND )

    BindBuffer( SHADER_STORAGE_BUFFER, ssbo )
    BufferData( SHADER_STORAGE_BUFFER, size_of( shader_data ), &shader_data, DYNAMIC_DRAW )
    BindBufferBase( SHADER_STORAGE_BUFFER, 3, ssbo )
    BindBuffer( SHADER_STORAGE_BUFFER, 0 )

    BindBuffer( ELEMENT_ARRAY_BUFFER, vbo_indices )
    BufferData( ELEMENT_ARRAY_BUFFER, cast(int)( index_count * size_of( indices[0] ) ), &indices[0], DYNAMIC_DRAW )
    BindBuffer( ELEMENT_ARRAY_BUFFER, 0 )

    BindVertexArray( vao )
    DrawElements( cast(u32)DrawType.Triangles, cast(i32)index_count, UNSIGNED_INT, nil )
    BindVertexArray( 0 )

    IM_Clear()
}

IM_SetProjectionMatrix :: proc( m: mat4 ) {
    imglob.shader_data.projection = m
}

IM_SetViewMatrix :: proc( m: mat4 ) {
    imglob.shader_data.view = m
}


IM_DrawTriangle :: proc( p1: vec3, c1: Color,
                         p2: vec3, c2: Color,
                         p3: vec3, c3: Color ) 
{
    using imglob
    if vertex_count + 3 >= IM_VERTEX_COUNT || index_count + 3 >= IM_INDEX_COUNT {
        IM_Flush()
    }

    vertices[vertex_count] = p1
    colors[vertex_count] = c1
    indices[index_count] = vertex_count
    index_count += 1
    vertex_count += 1

    vertices[vertex_count] = p2
    colors[vertex_count] = c2
    indices[index_count] = vertex_count
    index_count += 1
    vertex_count += 1

    vertices[vertex_count] = p3
    colors[vertex_count] = c3
    indices[index_count] = vertex_count
    index_count += 1
    vertex_count += 1
}

IM_DrawRect :: proc( top_left: vec2, bottom_right: vec2, color: Color )
{
    using imglob

    // top_left.xy ======   p2
    // ||              //// ||
    // ||         /////     ||
    // ||     ////          ||
    // || ////              ||
    // p3 ================ bottom_right.xy

    IM_DrawTriangle( { top_left.x, top_left.y, 0 }, color,
                     { bottom_right.x, top_left.y, 0 }, color,
                     { top_left.x, bottom_right.y, 0 }, color )
    IM_DrawTriangle( { top_left.x, bottom_right.y, 0 }, color,
                     { bottom_right.x, top_left.y, 0 }, color,
                     { bottom_right.x, bottom_right.y, 0 }, color )
}

IM_DrawCircle :: proc( center: vec2, radius: f32, color: Color, resolution: i32 = 8 ) {
    angle : f32 = 0
    angle_delta : f32 = math.TAU / f32(resolution)
    for angle = 0; angle < math.TAU; angle += angle_delta {
        IM_DrawTriangle( { center.x, center.y, 0 }, color,
                         { center.x + math.cos( angle ) * radius, center.y + math.sin( angle ) * radius, 0 }, color,
                         { center.x + math.cos( angle + angle_delta ) * radius, center.y + math.sin( angle + angle_delta ) * radius, 0 }, color )
    }
}

IM_DrawLine :: proc( start: vec2, end: vec2, color: Color, thickness: f32 ) {
    start := vec3{ start.x, start.y, 0}
    end := vec3{ end.x, end.y, 0 }
    dir := end - start
    if length( dir ) < 0.001 do return

    half_thickness := thickness / 2.0
    perp := normalize( vec3{ dir.y, -dir.x, 0 } )
    p1 := start + perp * half_thickness
    p2 := start + dir + perp * half_thickness
    p3 := start - perp * half_thickness
    p4 := start + dir - perp * half_thickness

    IM_DrawTriangle( p1, color, p2, color, p3, color )
    IM_DrawTriangle( p3, color, p2, color, p4, color )
}
