#include "AttriblessRendering.h"
#include <GL/glew.h>

/*
Be sure to bind an attribless vao before calling draw* functions.
*/

void bind_attribless_vao()
{
	static GLuint attribless_vao = -1;
	if(attribless_vao == -1)
	{
		glGenVertexArrays(1, &attribless_vao);
	}
	glBindVertexArray(attribless_vao);
}


/*
draw_attribless_cube

In vertex shader declare:

	const vec4 cube[8] = vec4[]( vec4(-1.0, -1.0, -1.0, 1.0),
								 vec4(-1.0, +1.0, -1.0, 1.0),
								 vec4(+1.0, +1.0, -1.0, 1.0),
								 vec4(+1.0, -1.0, -1.0, 1.0),
								 vec4(-1.0, -1.0, +1.0, 1.0),
								 vec4(-1.0, +1.0, +1.0, 1.0),
								 vec4(+1.0, +1.0, +1.0, 1.0),
								 vec4(+1.0, -1.0, +1.0, 1.0));

	const int index[14] = int[](1, 0, 2, 3, 7, 0, 4, 1, 5, 2, 6, 7, 5, 4);

In vertex shader main() use:

	int ix = index[gl_VertexID];
	vec4 v = cube[ix];
	gl_Position = PV*v;

*/
void draw_attribless_cube()
{
   glDrawArrays(GL_TRIANGLE_STRIP, 0, 14);
}


/*
draw_attribless_quad

In vertex shader declare:
const vec4 quad[4] = vec4[] (vec4(-1.0, 1.0, 0.0, 1.0), 
										vec4(-1.0, -1.0, 0.0, 1.0), 
										vec4( 1.0, 1.0, 0.0, 1.0), 
										vec4( 1.0, -1.0, 0.0, 1.0) );


In vertex shader main() use:

	gl_Position = quad[ gl_VertexID ]; //get clip space coords out of quad array

*/

void draw_attribless_quad()
{
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4); // draw quad
}


/*
draw_attribless_triangle_grid

layout (location=1000) uniform ivec2 nxy = ivec2(10, 10);
out vec2 tex_coord;

//The rectangle that gets covered by an nxy.x x nxy.y mesh of vertices
const vec4 rect[4] = vec4[](vec4(-1.0, -1.0, 0.0, 1.0), vec4(+1.0, -1.0, 0.0, 1.0),
							vec4(-1.0, +1.0, 0.0, 1.0), vec4( +1.0, +1.0, 0.0, 1.0));

const ivec2 offset[6] = ivec2[](ivec2(0,0), ivec2(1,0), ivec2(0, 1), ivec2(1, 0), ivec2(0, 1), ivec2(1,1));

//This is just generating a grid in attributeless fashion
void grid_vertex(out vec4 pos, out vec2 uv)
{
	ivec2 qxy = nxy - ivec2(1); //number of rows and columns of quads
	int q = gl_VertexID/6;	//1D quad index (two triangles)
	int v = gl_VertexID%6;	//vertex index within the quad
	ivec2 ij = ivec2(q%qxy.x, q/qxy.x); //2D quad index of current vertex
	ij += offset[v]; //2D grid index of each point
	uv = ij/vec2(qxy);
	pos = mix(mix(rect[0], rect[1], uv.s), mix(rect[2], rect[3], uv.s), uv.t);
}

void main(void)
{
	vec4 pos;
	vec2 uv;
	grid_vertex(pos, uv);
	float height = textureLod(diffuse_tex, uv, 0.0).r;
	pos.z = 4.0*height;
	gl_Position = PVM*pos;
	tex_coord = uv;
}

*/

void draw_attribless_triangle_grid(int nx, int ny)
{
	const int GRID_UNIFORM_LOCATION = 1000;
	if(nx <= 1 || ny <= 1) return;
	//nx,ny: number of rows and columns of vertices
	int n = (nx-1)*(ny-1)*6;
	glUniform2i(GRID_UNIFORM_LOCATION, nx, ny);
	glDrawArrays(GL_TRIANGLES, 0, n);
}


//Get positions out of Ssbo
void draw_attribless_particles(int n)
{
	glDrawArrays(GL_POINTS, 0, n);
}