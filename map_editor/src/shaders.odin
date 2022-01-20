package main

import gl "vendor:OpenGL"
import "core:strings"

ShaderType :: enum {
    VERTEX = gl.VERTEX_SHADER,
    FRAGMENT = gl.FRAGMENT_SHADER,
}

ShaderAttributeType :: enum u32 {
    Position,
    Color,
    UV,
    Count,
}

Shader :: struct {
    program: u32,
    attributes_location: [ShaderAttributeType.Count] i32,
}

Shader_Init :: proc( using shader: ^Shader ) {
    program = 0
    attributes_location = -1
}

Shader_HasAttribute :: proc( shader: ^Shader, attrib: ShaderAttributeType ) -> bool {
    return shader.attributes_location[i32(attrib)] != -1
}

Shader_TryGetAttributeLocation :: proc( shader: ^Shader, attrib: ShaderAttributeType ) -> (attrib_location: u32, ok: bool) {
    attrib := shader.attributes_location[i32(attrib)]
    return cast(u32)attrib, attrib != -1
}

Shader_GetAttributeLocation :: proc( shader: ^Shader, attrib: ShaderAttributeType ) -> i32 {
    return shader.attributes_location[i32(attrib)]
}

Shader_DeductAttributesFromReflection :: proc( shader_id: u32 ) -> [ShaderAttributeType.Count] i32 {
    attribs := [ShaderAttributeType.Count]i32{}
    for i:=0; i<int(ShaderAttributeType.Count); i += 1 {
        attribs[i] = -1;
    }
    attribs[ShaderAttributeType.Position] = gl.GetAttribLocation( shader_id, "iPosition" )
    attribs[ShaderAttributeType.Color]    = gl.GetAttribLocation( shader_id, "iColor" )
    attribs[ShaderAttributeType.UV]       = gl.GetAttribLocation( shader_id, "iUV" )

    return attribs
}

R_GetShaderError :: proc( shader_id : u32 ) -> string {
    log_length : i32 = ---
    gl.GetShaderiv( shader_id, gl.INFO_LOG_LENGTH, &log_length )
    compile_error := make([]byte, log_length ) ; defer delete( compile_error )
    gl.GetShaderInfoLog( shader_id, log_length, nil, &compile_error[0] )
    return strings.clone( string( compile_error[0:log_length-1] ) )
}

R_GetProgramError :: proc( program_id: u32 ) -> string {
    log_length : i32 = ---
    gl.GetProgramiv( program_id, gl.INFO_LOG_LENGTH, &log_length )
    compile_error := make([]byte, log_length ) ; defer delete( compile_error )
    gl.GetProgramInfoLog( program_id, log_length, nil, &compile_error[0] )
    return strings.clone( string( compile_error[0:log_length-1] ) )
}

R_LinkShaderProgram :: proc( shaders: []u32 ) -> ( program_id: u32, ok: bool ) {
    program := gl.CreateProgram()
    for s in shaders {
        gl.AttachShader( program, s )
    }
    gl.LinkProgram( program )
    shader_compile_error : i32 = ---
    gl.GetProgramiv( program, gl.LINK_STATUS, &shader_compile_error )
    for s in shaders {
        gl.DetachShader( program, s )
    }
    return program, shader_compile_error != 0
}

R_CompileShader :: proc( src: string, type: ShaderType ) -> (shader_id: u32, ok: bool)  {
    shader := gl.CreateShader( u32( type ) )
    csrc := cstring( raw_data( src ) )
    src_length := i32( len( src ) )
    gl.ShaderSource( shader, 1, &csrc, &src_length )
    gl.CompileShader( shader )
    shader_compile_error : i32 = ---
    gl.GetShaderiv( shader, gl.COMPILE_STATUS, &shader_compile_error )
    return shader, shader_compile_error != 0
}