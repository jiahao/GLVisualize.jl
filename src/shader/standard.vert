{{GLSL_VERSION}}

in vec3 vertices;
in vec3 normals;

uniform vec3 light[4];
uniform vec4 color;
uniform mat4 projection, view, model;
void render(vec3 vertices, vec3 normals, vec4 color, mat4 viewmodel, mat4 projection, vec3 light[4]);

uniform uint objectid;
flat out uvec2 o_id;

void main()
{
	o_id = uvec2(objectid, gl_VertexID+1);
	render(vertices, normals, color, view*model, projection, light);
}


