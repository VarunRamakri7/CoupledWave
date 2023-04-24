#include "MeshDataGeometry.h"
#include <glm/glm.hpp>
#include <cassert>

namespace MeshDataGeometry
{

   uint32_t ComputeNumVertices(MeshData& mesh_data)
   {
      uint32_t totalNumVerts = 0;
      for (int m = 0; m < mesh_data.mSubmesh.size(); m++)
      {
         totalNumVerts += mesh_data.mScene->mMeshes[m]->mNumVertices;
      }
      return totalNumVerts;
   }

   uint32_t ComputeNumIndices(MeshData& mesh_data)
   {
      int totalNumIndices = 0;
      for (int m = 0; m < mesh_data.mSubmesh.size(); m++)
      {
         totalNumIndices += mesh_data.mSubmesh[m].mNumIndices;
      }
      return totalNumIndices;
   }
   
   vertex_one_ring ComputeVertexOneRing(MeshData& mesh_data)
   {
      uint32_t nv = ComputeNumVertices(mesh_data);
      vertex_one_ring vring(nv);

      for (int m = 0; m < mesh_data.mSubmesh.size(); m++)
      {
         int meshFaces = mesh_data.mScene->mMeshes[m]->mNumFaces;
         for (unsigned int f = 0; f < meshFaces; ++f)
         {
            const aiFace* face = &mesh_data.mScene->mMeshes[m]->mFaces[f];
            assert(face->mNumIndices == 3); //this should be a triangle

            unsigned int* vx = face->mIndices;
            vring[vx[0]].insert(vx[1]);   vring[vx[0]].insert(vx[2]);
            vring[vx[1]].insert(vx[0]);   vring[vx[1]].insert(vx[2]);
            vring[vx[2]].insert(vx[0]);   vring[vx[2]].insert(vx[1]);
         }
      }

      return vring;
   }


   vertex_face_ring ComputeVertexFaceRing(MeshData& mesh_data)
   {
      uint32_t nv = ComputeNumVertices(mesh_data);
      vertex_face_ring fring(nv);

      uint32_t face_index = 0;
      for (int m = 0; m < mesh_data.mSubmesh.size(); m++)
      {
         int meshFaces = mesh_data.mScene->mMeshes[m]->mNumFaces;
         for (unsigned int f = 0; f < meshFaces; ++f)
         {
            const aiFace* face = &mesh_data.mScene->mMeshes[m]->mFaces[f];
            assert(face->mNumIndices==3); //this should be a triangle
            for (int ix = 0; ix < 3; ix++)
            {
               int v = face->mIndices[ix];
               fring[v].insert(face_index);
            }
            face_index++;
         }
      }

      return fring;
   }

};