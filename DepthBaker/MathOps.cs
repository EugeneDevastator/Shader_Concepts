using System.Collections.Generic;
using UnityEngine;

public static class MathOps
{
    // generates angle going vertical then horizontal.
    public static IEnumerable<Vector3> GenerateAngles(int hCount, int vCount)
    {
        float halfHeightOffset_a = 90f / vCount;
        Vector3 basev = Vector3.right;
        for (int h = 0; h < hCount; h++)
        {
            for (int v = 0; v < vCount; v++)
            {
                yield return
                    Quaternion.AngleAxis(h * (360 / hCount), Vector3.up) //applies second because of inverse transformations..
                    * Quaternion.AngleAxis(-90 + v * (180f / vCount) + halfHeightOffset_a, Vector3.forward)

                    // * Quaternion.AngleAxis(i * (360 / hcount), Vector3.right)
                    * basev;
            }
        }
    }

    public static Vector2Int Wrapto2D(int d1, int xsize)
    {
        return new Vector2Int(d1 % xsize, d1 / xsize);
    }

    public static Vector2 Wrapto2Df(int d1, int xsize)
    {
        return new Vector2(d1 % xsize, d1 / (float)xsize);
    }

    public static bool RayIntersectsTriangle(
        Ray ray,
        Vector3 p0,
        Vector3 p1,
        Vector3 p2,
        out float distance)
    {
        distance = 0;

        Vector3 edge1 = p1 - p0;
        Vector3 edge2 = p2 - p0;
        Vector3 h = Vector3.Cross(ray.direction, edge2);
        float a = Vector3.Dot(edge1, h);

        if (a > -Mathf.Epsilon && a < Mathf.Epsilon)
            return false; // Ray is parallel to the triangle

        float f = 1.0f / a;
        Vector3 s = ray.origin - p0;
        float u = f * Vector3.Dot(s, h);

        if (u < 0.0 || u > 1.0)
            return false;

        Vector3 q = Vector3.Cross(s, edge1);
        float v = f * Vector3.Dot(ray.direction, q);

        if (v < 0.0 || u + v > 1.0)
            return false;

        // At this stage, we can compute t to find out where the intersection point is on the line
        float t = f * Vector3.Dot(edge2, q);

        if (t > Mathf.Epsilon) // Ray intersection
        {
            distance = t;
            return true;
        }
        else // No hit
            return false;
    }
}