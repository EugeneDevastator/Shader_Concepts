using System.Collections.Generic;
using System.Linq;
using UnityEngine;

public static class MeshOps
{
    public static void BakeIndicesToUv1(Mesh mesh, int vertsPerSide)
    {
        Vector3[] vertices = mesh.vertices;
        var totalVerts = vertices.Length;
        if (Mathf.Ceil(Mathf.Sqrt(totalVerts)) > vertsPerSide)
        {
            Debug.LogError("CANT FIT ALL INTO SQUARE!");
            return;
        }

        Vector2[] uv1 = new Vector2[vertices.Length];

        //   Vector2[] uv2 = mesh.uv2;
        float pxUvSize = 1f / (float)vertsPerSide;
        float halfPxUvSize = pxUvSize * 0.5f;

        Vector2 offset = new Vector2(halfPxUvSize, halfPxUvSize);

        for (int i = 0; i < vertices.Length; i++)
        {
            var intvec = MathOps.Wrapto2D(i, vertsPerSide);
            uv1[i] = offset + (Vector2)intvec * pxUvSize;
            Debug.Log(uv1[i]);
        }

        Debug.Log("total verts: " + vertices.Length + "sqrt: " + Mathf.Sqrt(vertices.Length));
        mesh.SetUVs(1, uv1);

        //    mesh.SetUVs(2, uv2);
    }

    public static void InvertMesh(Mesh mesh)
    {
        Vector3[] normals = mesh.normals;
        for (int i = 0; i < normals.Length; i++)
        {
            normals[i] = -normals[i];
        }
        mesh.normals = normals;

        for (int m = 0; m < mesh.subMeshCount; m++)
        {
            int[] triangles = mesh.GetTriangles(m);
            for (int i = 0; i < triangles.Length; i += 3)
            {
                // Swap order of triangle vertices to invert normals
                int temp = triangles[i + 0];
                triangles[i + 0] = triangles[i + 1];
                triangles[i + 1] = temp;
            }
            mesh.SetTriangles(triangles, m);
        }
    }

    public static float SampleDepthBrute(Vector3 vertexPosition, Vector3 direction, Mesh mesh)
    {
        Vector3[] vertices = mesh.vertices;
        int[] triangles = mesh.triangles;

        bool IsOutside = true;

        float closestDistance = Mathf.Infinity;
        Ray ray = new Ray(vertexPosition + direction * 0.01f, direction);

        for (int i = 0; i < triangles.Length; i += 3)
        {
            Vector3 p0 = vertices[triangles[i]];
            Vector3 p1 = vertices[triangles[i + 1]];
            Vector3 p2 = vertices[triangles[i + 2]];

            if (MathOps.RayIntersectsTriangle(ray, p0, p1, p2, out float distance))
            {
                IsOutside = !IsOutside; // check if ray was cast inside. by calculating passed faces.
                if (distance < closestDistance)
                {
                    closestDistance = distance;
                }
            }
        }

        return float.IsPositiveInfinity(closestDistance) || IsOutside
            ? 0
            : closestDistance;
    }

    public static (float dsingle, float dcumul) SampleDepthBruteCumulative(
        int vertexId, Vector3 vertexPosition, Vector3 direction, int[] triangles, Vector3[] vertices)
    {
        List<(float distance, Vector3 normal)> intersections = new List<(float, Vector3)>();
        Ray ray = new Ray(vertexPosition + direction, direction);
        float dsingle = 0;
        float closestDistance = Mathf.Infinity;
        bool IsOutside = true;
        Stack<float> depthStack = new Stack<float>();

        // Collect all intersection distances and normals
        for (int i = 0; i < triangles.Length; i += 3)
        {
            if (triangles[i] == vertexId || triangles[i + 1] == vertexId || triangles[i + 2] == vertexId)
                continue; // Skip the face if it contains the current vertex

            Vector3 p0 = vertices[triangles[i]];
            Vector3 p1 = vertices[triangles[i + 1]];
            Vector3 p2 = vertices[triangles[i + 2]];

            if (MathOps.RayIntersectsTriangle(ray, p0, p1, p2, out float distance))
            {
                Vector3 faceNormal = Vector3.Cross(p1 - p0, p2 - p0).normalized;
                intersections.Add((distance, faceNormal));
            }
        }
        
        // Sort the distances
        intersections.Sort((a, b) => a.distance.CompareTo(b.distance));
        
        float totalDistanceInside = 0f;
        float lastEntryDistance = 0f;
        
        if (intersections.Count < 1)
            return (0,0);
        
        bool currentlyInside = !(Vector3.Dot(intersections[0].normal, direction) < 0);
        dsingle = 999999;
        // Calculate the total distance inside
        foreach (var (distance, normal) in intersections)
        {
            bool entering = Vector3.Dot(normal, direction) < 0;

            if (entering)
            {
                // Entering the object
                if (!currentlyInside)
                {
                    currentlyInside = true;
                    lastEntryDistance = distance;
                }
            }
            else
            {
                // Exiting the object
                if (currentlyInside)
                {
                    currentlyInside = false;
                    totalDistanceInside += distance - lastEntryDistance;
                    dsingle = Mathf.Min(dsingle,totalDistanceInside);
                }
            }
        }

        return (dsingle, totalDistanceInside);
    }
}