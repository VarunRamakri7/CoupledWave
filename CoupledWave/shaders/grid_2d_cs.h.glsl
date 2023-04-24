#line 1
layout(std140, binding = kGridUboBinding) uniform UniformGridInfo
{
	aabb2D mExtents;
	ivec2 mNumCells;
	vec2 mCellSize;
	int mMaxCellsPerElement;
};

ivec2 CellCoord(vec2 p)
{
   p = p-mExtents.mMin;
   ivec2 cell = ivec2(floor(p/mCellSize));
   cell = clamp(cell, ivec2(0), mNumCells-ivec2(1));
   return cell;
}

int Index(ivec2 coord)
{
	return coord.x*mNumCells.y + coord.y;
}

ivec2 ContentRange(ivec2 cell)
{
	int cell1 = Index(cell);
	int start = mStart[cell1];
	int count = mCount[cell1];
	return ivec2(start, start+count-1);
}