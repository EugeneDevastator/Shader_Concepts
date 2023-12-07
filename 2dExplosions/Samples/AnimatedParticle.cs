using System;
using UnityEngine;
using Random = UnityEngine.Random;

public class AnimatedParticle : MonoBehaviour
{
    private static int order = 0;

    // Cached property IDs
    private static readonly int RandomFloatID = Shader.PropertyToID("_NoiseFactor");
    private static readonly int TextureScaleOffsetID = Shader.PropertyToID("_Noise_ST");
    private static readonly int TimeFloatID = Shader.PropertyToID("_FloatPos");
    public float animTime = 1f;
    private Renderer particleRenderer;
    private MaterialPropertyBlock props;
    private float timeFloat;

    private void Awake()
    {
        order++;
        props = new MaterialPropertyBlock();
        particleRenderer = GetComponent<Renderer>();
        particleRenderer.sortingOrder = Mathf.FloorToInt(Random.value*10000);
        props.SetFloat(TimeFloatID, 0f);
    }

    void Update()
    {
        if (timeFloat >= animTime)
        {
            Destroy(gameObject);
            return;
        }
        timeFloat += Time.deltaTime;
        props.SetFloat(TimeFloatID, timeFloat/animTime);
        particleRenderer.SetPropertyBlock(props);

    }

    public void Initialize(float randomFloat, Vector4 textureScaleOffset, float scale)
    {
        transform.localScale = Vector3.one *scale;
        props.SetFloat(RandomFloatID, randomFloat);
        props.SetVector(TextureScaleOffsetID, textureScaleOffset);
        particleRenderer.SetPropertyBlock(props);
    }
}