// ------------------ Geometry Shader --------------------------------
// This version of the line shader simply cuts off the corners and
// draws the line with no overdraw on neighboring segments at all
{{GLSL_VERSION}}
{{GLSL_EXTENSIONS}}

layout(lines_adjacency) in;
layout(triangle_strip, max_vertices = 9) out;

in vec4 g_color[];
in float g_lastlen[];
flat in uvec2 g_id[];
//in float g_thickness[];

out vec4 f_color;
out vec2 f_uv;

flat out uvec2 f_id;

uniform vec2 resolution;
uniform float maxlength;
uniform float thickness;
uniform bool dotted;
uniform int max_primitives;



#define MITER_LIMIT 0.75

vec2 screen_space(vec4 vertex)
{
    return vec2( vertex.xy / vertex.w ) * resolution;
}
void emit_vertex(vec2 position, vec2 uv, int index)
{
    f_uv          = uv;
    f_color       = g_color[index];
    gl_Position   = vec4(position / resolution, 0.0, 1.0 );
    f_id          = g_id[index];
    EmitVertex();
}
#define AA_THICKNESS 3.0

vec2 compute_miter(vec2 normal_a, vec2 normal_b)
{
    vec2 miter = normalize(normal_a + normal_b);
    if(miter.x < 0.000001 && miter.y < 0.000001)
    {
        return vec2(-normal_a.y, normal_a.x);
    }
    return miter;
}

uniform int max_primtives;

void main(void)
{
    // get the four vertices passed to the shader:
    vec2 p0 = screen_space( gl_in[0].gl_Position ); // start of previous segment
    vec2 p1 = screen_space( gl_in[1].gl_Position ); // end of previous segment, start of current segment
    vec2 p2 = screen_space( gl_in[2].gl_Position ); // end of current segment, start of next segment
    vec2 p3 = screen_space( gl_in[3].gl_Position ); // end of next segment

    float thickness_aa = thickness + 2;

    
    // perform naive culling
    //vec2 area = resolution * 1.2;
    //if( p1.x < -area.x || p1.x > area.x ) return;
    //if( p1.y < -area.y || p1.y > area.y ) return;
    //if( p2.x < -area.x || p2.x > area.x ) return;
    //if( p2.y < -area.y || p2.y > area.y ) return;

    // determine the direction of each of the 3 segments (previous, current, next)
    vec2 v0 = normalize(p1 - p0);
    vec2 v1 = normalize(p2 - p1);
    vec2 v2 = normalize(p3 - p2);

    // determine the normal of each of the 3 segments (previous, current, next)
    vec2 n0 = vec2(-v0.y, v0.x);
    vec2 n1 = vec2(-v1.y, v1.x);
    vec2 n2 = vec2(-v2.y, v2.x);

    // determine miter lines by averaging the normals of the 2 segments
    vec2 miter_a = normalize(n0 + n1);    // miter at start of current segment
    vec2 miter_b = normalize(n1 + n2);    // miter at end of current segment

    // determine the length of the miter by projecting it onto normal and then inverse it
    float length_a = thickness_aa / dot( miter_a, n1 );
    float length_b = thickness_aa / dot( miter_b, n1 );

    float start = 0.0 - (AA_THICKNESS/thickness_aa);
    float end   = 1.0 + (AA_THICKNESS/thickness_aa);
    float xstart, xend;
    if(!dotted){
        xstart  = 1;
        xend    = 1;
    }else{
        xstart  = (g_lastlen[1])/thickness_aa;
        xend    = (g_lastlen[2])/thickness_aa;
    }
    if(gl_PrimitiveIDIn == 0) //first primitive
    {
        emit_vertex(p0 + thickness_aa * n0, vec2(xstart, start), 1);
        emit_vertex(p0 - thickness_aa * n0, vec2(xstart, end), 1);
    }
    

    if( dot( v0, v1 ) < -MITER_LIMIT ) {
        miter_a = n1;
        length_a = thickness_aa;

        // close the gap
        if( dot( v0, n1 ) > 0 ) {
            emit_vertex(p1 + thickness_aa * n0, vec2(xstart, start), 1);
            emit_vertex(p1 + thickness_aa * n1, vec2(xstart, end), 1);
            emit_vertex(p1, vec2(xstart, end), 1);
            EndPrimitive();
        }
        else {
            emit_vertex(p1 - thickness_aa * n1, vec2(xstart, end), 1);
            emit_vertex(p1 - thickness_aa * n0, vec2(xstart, end), 1);
            emit_vertex(p1, vec2( 0, 0.5 ), 1);
            EndPrimitive();
        }
    }

    if( dot( v1, v2 ) < -MITER_LIMIT ) {
        miter_b = n1;
        length_b = thickness_aa;
    }

    // generate the triangle strip
    
    emit_vertex(p1 + length_a * miter_a, vec2( 0, 0 ), 1);
    emit_vertex(p1 - length_a * miter_a, vec2( 0, 1 ), 1);


    emit_vertex(p2 + length_b * miter_b, vec2( 0, 0 ), 2);
    emit_vertex(p2 - length_b * miter_b, vec2( 0, 1 ), 2);

    if(gl_PrimitiveIDIn == max_primitives) //last primtive
    {
        emit_vertex(p3 + thickness_aa * n2, vec2(xend, start), 1);
        emit_vertex(p3 - thickness_aa * n2, vec2(xend, end), 1);
    }
}


