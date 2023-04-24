//https://www.shadertoy.com/view/NtjyWw

const uint k_hash = 1103515245U;  // GLIB C

vec3 uhash3( uvec3 x )  
{
    x = ((x>>8U)^x.yzx)*k_hash;
    x = ((x>>8U)^x.yzx)*k_hash;
    x = ((x>>8U)^x.yzx)*k_hash;
    
    return vec3(x)/float(0xffffffffU);
}

vec3 hash( vec3 f )      
{ 
    return uhash3( uvec3( floatBitsToUint(f.x),
                          floatBitsToUint(f.y),
                          floatBitsToUint(f.z) ) );
}