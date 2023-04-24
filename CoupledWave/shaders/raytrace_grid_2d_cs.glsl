#version 450

layout(local_size_x = 32, local_size_y = 32) in;

layout(rgba32f, binding = 0) restrict uniform image2D uImage; 

void rasterize_ray(ivec2 ix);
void rasterize_ray_opt(ivec2 ix);

uniform vec2 ro = vec2(32.0, 32.0);
uniform vec2 rd = vec2(0.0, -0.7071);

void main()
{
	ivec2 gid = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(uImage);

	if(gid.x >= size.x) return;
	if(gid.y >= size.y) return;

	rasterize_ray_opt(gid);
}

vec2 boxIntersector( vec2 ro, vec2 rd ) 
{
    vec2 box_hw = 0.5*vec2(imageSize(uImage).xy);
	ro -= box_hw;
    vec2 m = 1.0/rd; // can precompute if traversing a set of aligned boxes
    vec2 n = m*ro;   // can precompute if traversing a set of aligned boxes
    vec2 k = abs(m)*box_hw;
    vec2 t1 = -n - k;
    vec2 t2 = -n + k;
    float tN = max( t1.x, t1.y );
    float tF = min( t2.x, t2.y );
    if( tN>tF || tF<0.0) return vec2(-1.0); // no intersection
    return vec2(tN, tF);
}

float planeIntersector( in vec2 ro, in vec2 rd, in vec3 p )
{
    return -(dot(ro, p.xy)+p.z)/dot(rd, p.xy);
}

void rasterize_ray(ivec2 ix)
{
	imageStore(uImage, ix, vec4(0.0, 0.0, 0.0, 1.0));

	const ivec2 min_cell = ivec2(0);
	const ivec2 max_cell = imageSize(uImage)-ivec2(1);
	const vec2 nx = vec2(1.0, 0.0);
	const vec2 ny = vec2(0.0, 1.0);

	ivec2 cell_step = ivec2(sign(rd));
	ivec2 side = ivec2(step(vec2(0.0), rd));

	vec2 tNF = boxIntersector(ro, rd);

	//Handle ro inside grid
	if(all(greaterThanEqual(ro, min_cell)) && all(lessThanEqual(ro, max_cell))) 
	{
		tNF[0] = 0.0;	
	}

	float t = tNF[0];

	if(t<0.0) //Box behind ray
	{	
		imageStore(uImage, ix, vec4(1.0, 0.0, 1.0, 1.0));
		return;
	}

	vec2 p = ro+t*rd;
	ivec2 cell = ivec2(floor(p));
	cell = clamp(cell, min_cell, max_cell);

	for(int i=0; i<4000; i++)
	{
		if(any(lessThan(cell, min_cell))) break;
		if(any(greaterThan(cell, max_cell))) break;

		imageStore(uImage, cell, vec4(1.0, 0.0, 0.0, 1.0));

		vec3 planex = vec3(nx, -(cell.x+side.x));
		vec3 planey = vec3(ny, -(cell.y+side.y));
		
		float tx = planeIntersector(ro, rd, planex);
		float ty = planeIntersector(ro, rd, planey);

		if(tx<ty && tx>=t)
		{
			cell.x += cell_step.x;
			t = tx;
		}
		else
		{
			cell.y += cell_step.y;
			t = ty;
		}
	}
}

void rasterize_ray_opt(ivec2 ix)
{
	imageStore(uImage, ix, vec4(0.0, 0.0, 0.0, 1.0));

	const ivec2 min_cell = ivec2(0);
	const ivec2 max_cell = imageSize(uImage)-ivec2(1);
	const vec2 nx = vec2(1.0, 0.0);
	const vec2 ny = vec2(0.0, 1.0);

	ivec2 cell_step = ivec2(sign(rd));
	ivec2 side = ivec2(step(vec2(0.0), rd));

	vec2 tNF = boxIntersector(ro, rd);

	//Handle ro inside grid
	if(all(greaterThanEqual(ro, min_cell)) && all(lessThanEqual(ro, max_cell))) 
	{
		tNF[0] = 0.0;	
	}

	float t = tNF[0];

	if(t<0.0) //Box behind ray
	{	
		imageStore(uImage, ix, vec4(1.0, 0.0, 1.0, 1.0));
		return;
	}

	vec2 p = ro+t*rd;
	ivec2 cell = ivec2(floor(p));
	cell = clamp(cell, min_cell, max_cell);
	vec2 m = 1.0/rd;
	//TODO set initial collision point (in case we are already colliding at t)
	for(int i=0; i<4000; i++)
	{
		if(any(lessThan(cell, min_cell))) break;
		if(any(greaterThan(cell, max_cell))) break;

		//if(is_solid(cell)) break;

		imageStore(uImage, cell, vec4(1.0, 0.0, 0.0, 1.0));
		
		vec2 pz = -cell-side;
		vec2 tp = -m*(ro+pz);

		if(tp.x<tp.y && tp.x>=t)
		{
			//collision normal = -cell_step*nx;
			cell.x += cell_step.x;
			t = tp.x;
		}
		else
		{
			//collision normal = -cell_step*ny;
			cell.y += cell_step.y;
			t = tp.y;
		}
	}
	/*
	collision pt = ro+t*rd;
	vec2 d = p-(cell+vec2(0.5))
	collision n = sign(d)*step(vec2(1.0-eps), abs(d));
	*/

}