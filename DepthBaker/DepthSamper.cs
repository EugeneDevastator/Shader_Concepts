using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Unity.Mathematics;
using UnityEditor;
using UnityEngine;

[RequireComponent(typeof(MeshCollider))]
[RequireComponent(typeof(MeshFilter))]
public class DepthSampler : MonoBehaviour
{
    public int _cellCount = 4;
    public int vertexPackingSideCount = 40;
    [SerializeField] MeshFilter _meshFilter;
    [SerializeField] private RenderTexture _writeTexture;
    [SerializeField] private Texture2D _bakeDepthTexture;
    [SerializeField] private float DepthMul;
    private Mesh _collmesh;
    private Texture2D _memTex;
    private Mesh mesh;
    private MeshCollider meshCollider;

    void Start()
    {
        MeshFilter meshFilter = GetComponent<MeshFilter>();

        // Clone and modify the mesh
        mesh = Instantiate(meshFilter.sharedMesh);
        meshFilter.mesh = mesh;
        _collmesh = Instantiate(meshFilter.sharedMesh);
        MeshOps.InvertMesh(_collmesh);

        // Set the modified mesh to both MeshFilter and MeshCollider
        meshCollider = GetComponent<MeshCollider>();
        meshCollider.sharedMesh = _collmesh;
        meshCollider.convex = false;
    }

    /// <summary>
    /// Uses inverted collider and rays, not bad, but inprecise. fast.
    /// </summary>
    /// <param name="vertexPosition"></param>
    /// <param name="direction"></param>
    /// <returns></returns>
    public float SampleDepthCollider(Vector3 vertexPosition, Vector3 direction)
    {
        RaycastHit hit;
        float depth = 0.0f;

        // Cast the ray
        Ray ray = new Ray(vertexPosition, direction);
        if (meshCollider.Raycast(ray, out hit, 1000))
        {
            depth = hit.distance;
            Debug.Log(depth);
        }
        Debug.DrawRay(vertexPosition, direction.normalized * 1000, Color.red, 2.0f);

        return depth;
    }

    [ContextMenu("show bounds")]
    void bounds()
    {
        Debug.Log(_meshFilter.sharedMesh.bounds);
        Debug.Log("suggested:" + 1f / Mathf.Max(_meshFilter.sharedMesh.bounds.extents.x, mesh.bounds.extents.y, mesh.bounds.extents.z));
        Debug.Log(Mathf.Sqrt((float)_meshFilter.sharedMesh.vertices.Count()));
    }

    [ContextMenu("bakeuv1")]
    void Bakeuv1()
    {
        MeshOps.BakeIndicesToUv1(_meshFilter.sharedMesh, vertexPackingSideCount);
    }

    [ContextMenu("test angles")]
    public void GenAngles()
    {
        var directionVectors = MathOps.GenerateAngles(5, 3).ToArray();
        foreach (var a in directionVectors)
        {
            Debug.DrawLine(Vector3.zero, a.normalized, Color.green, 7);
        }
    }

    private void CreateTexture()
    {
        var texSize = _cellCount * vertexPackingSideCount;
        _memTex = new Texture2D(texSize, texSize, TextureFormat.RGBA32, false);

        // tex.ReadPixels(new Rect(0, 0, _writeTexture.width, _writeTexture.height), 0, 0);
    }

    [ContextMenu("Generate FULLY")]
    void MakeDepthFull()
    {
        //mesh.RecalculateNormals();
        //var texSize = _cellCount * vertexPackingSideCount;
//
        //// Resize render texture to be texSize x texSize
        //if (_writeTexture == null || _writeTexture.width != texSize || _writeTexture.height != texSize)
        //{
        //    if (_writeTexture != null)
        //    {
        //        // Release the existing texture if it exists
        //        _writeTexture.Release(); 
        //    }
//
        //    // Create a new RenderTexture with the desired size
        //    RenderTexture newTexture = new RenderTexture(texSize, texSize, 24)
        //    {
        //        enableRandomWrite = true
        //    };
        //    newTexture.Create();
//
        //    // Assign the new texture to _writeTexture
        //    _writeTexture = newTexture;
        //}
//
        //RenderTexture currentRT = RenderTexture.active;
        //RenderTexture.active = _writeTexture;
//
        //// Clear the RenderTexture with black color
        //GL.Clear(true, true, Color.black);
//
        //// Additional operations on _writeTexture may follow here
//
        //// Restore the original RenderTexture.active if necessary
        //RenderTexture.active = currentRT;
        
        vertexPackingSideCount = Mathf.CeilToInt(Mathf.Sqrt((float)_meshFilter.sharedMesh.vertices.Count()));
        mesh = _meshFilter.sharedMesh;
        CreateTexture();

        //sample into texture
        var angles = MathOps.GenerateAngles(_cellCount, _cellCount).ToArray();
        for (var i = 0; i < angles.Length; i++)
        {
            Debug.Log($"angle {i}/{angles.Length}");
            WriteAndSampleDirection(angles[i], i);
        }
        Bakeuv1();
        SaveTexture(_memTex);
        Debug.Log("Generated: " + _cellCount + "time:" + Time.realtimeSinceStartup);
    }

    private void WriteAndSampleDirection(Vector3 look_v3_w, int number)
    {
        Vector3[] vertices = mesh.vertices;
        Vector2[] depthValues = new Vector2[vertices.Length];
        float y = 1; //is in
        int[] triangles = mesh.triangles;
        Parallel.For(0, vertices.Length, i =>
        {
            var depths = MeshOps.SampleDepthBruteCumulative(i, vertices[i], look_v3_w, triangles, vertices);
            // Ensure thread-safe assignment if necessary
                depthValues[i].x = depths.dsingle;
                depthValues[i].y = depths.dcumul;
        });
        
        //for (int i = 0; i < vertices.Length; i++)
        //{
        //    var depths = MeshOps.SampleDepthBruteCumulative(i, vertices[i],look_v3_w, mesh, vertices);
        //    depthValues[i].x = depths.dsingle;
        //    depthValues[i].y = depths.dcumul;
        //}
        Debug.Log("total verts: " + vertices.Length + "sqrt: " + Mathf.Sqrt(vertices.Length));

        //mesh.SetUVs(2,depthValues); dont really need it anymore
        var cellOffset = MathOps.Wrapto2D(number, _cellCount);

        //write generated values to texture as well.
        ModifyTexture(depthValues.Select(u => (u.x, u.y)).ToArray(), vertexPackingSideCount, cellOffset);
    }

    [ContextMenu("Generate test")]
    void MakeDepth()
    {
        Debug.LogError("DEPRECATED");
        return;

        // abbreviations
        // f01 - float from 0 to 1
        // f11 float from -1 to 1
        // v3 - vector 3
        // _w - world space
        // sc - scalar
        Vector3 look_v3_w = Vector3.up;
        float MinThroughDepth_f01 = 0.2f;

        Vector3[] vertices = mesh.vertices;
        Vector3[] normals = mesh.normals;
        Vector2[] uv2 = new Vector2[vertices.Length];
        float y = 1; //is in
        for (int i = 0; i < vertices.Length; i++)
        {
            float depth = MeshOps.SampleDepthBrute((vertices[i]), look_v3_w, mesh);
            float sss = 0;
            var lookOnNormal_f11 = Vector3.Dot(look_v3_w, mesh.normals[i].normalized);

            //Update for sss so that surfaces that are facing also have some underlying scattering.
            if (depth <= Mathf.Epsilon) //is outside
            {
                sss = (1 - lookOnNormal_f11)
                      * MinThroughDepth_f01;
                y = 0;
            }
            else
            {
                sss = MinThroughDepth_f01 + depth; //this is for sss. on edges there will be some of the depth.

                //depth = depth * Mathf.Abs(drillOnNomral);
                y = 1;
            }

            //Debug.Log(lookOnNormal_f11);

            uv2[i] = new Vector2(depth, y);
        }

        Debug.Log("total verts: " + vertices.Length + "sqrt: " + Mathf.Sqrt(vertices.Length));
        mesh.uv2 = uv2;

        //ModifyTexture(uv2.Select(u => u.x).ToArray(), 80, new Vector2Int(2, 2));
    }

    private void ModifyTexture((float, float)[] indexValues, int suqarePixelCount, Vector2Int cellOffset)
    {
        // Set pixel at (3, 3) to yellow with transparency
        Color yellowTransparent = new Color(1, 1, 0, 0.5f); // RGBA for yellow with 50% alpha
        Color c = new Color(1, 1, 0, 0.5f);

        for (var i = 0; i < indexValues.Length; i++)
        {
            var col = new Color(indexValues[i].Item1, indexValues[i].Item2, 0, 1);
            ;
            col *= DepthMul;
            var offset_px = cellOffset * suqarePixelCount;
            var pxPos = MathOps.Wrapto2D(i, suqarePixelCount) + offset_px;
            _memTex.SetPixel(pxPos.x, pxPos.y, col);
        }
        _memTex.Apply(); // Use DestroyImmediate in editor scripts
    }

    private void SaveTexture(Texture2D tex)
    {
        // Convert the texture to a byte array
        byte[] pngData = tex.EncodeToPNG();
        string path = AssetDatabase.GetAssetPath(_bakeDepthTexture);

        // Write the data to the existing asset
        if (pngData != null)
        {
            System.IO.File.WriteAllBytes(path, pngData);
            AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceUpdate);
        }

        // Reassign the updated asset to the textureAsset variable
        _bakeDepthTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
        DestroyImmediate(_memTex);
    }
}