#pragma once

#include <vector>
#include <unordered_set>
#include "LoadMesh.h"

namespace MeshDataGeometry
{

   typedef std::vector<std::unordered_set<uint32_t>> vertex_one_ring; //the ring of vertices surrounding each vertex
   typedef std::vector<std::unordered_set<uint32_t>> vertex_face_ring; //the ring of faces surrounding each vertex

   uint32_t ComputeNumVertices(MeshData& mesh_data);
   uint32_t ComputeNumIndices(MeshData& mesh_data);

   vertex_one_ring ComputeVertexOneRing(MeshData& mesh_data);
   vertex_face_ring ComputeVertexFaceRing(MeshData& mesh_data);
   
};
