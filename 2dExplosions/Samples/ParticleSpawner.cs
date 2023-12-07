using UnityEngine;
using System.Collections.Generic;
using UnityEngine.Serialization;
using UnityEngine.UI; // For using List

public class ParticleSpawner : MonoBehaviour
{
    public GameObject particlePrefab;
    public int particlesPerFrame = 10;
    [SerializeField] private Text text;
    private System.Random _randomizer;

    private List<GameObject> activeParticles = new List<GameObject>(); // To track active particles
    private float spawnInterval;
    private float timer;

    public int CurrentParticlesCount => activeParticles.Count; // Public property to get current particles count

    void Start()
    {
        //get a randomizer
        _randomizer = new System.Random();

//get a random int seed

        if (particlePrefab == null)
        {
            Debug.LogError("Particle prefab is not assigned!");
            return;
        }

        spawnInterval = 1f / particlesPerFrame;
        timer = spawnInterval;
    }

    void Update()
    {
        for (int i = 0; i < particlesPerFrame; i++)
        {
            SpawnParticle();
        }

        // timer -= Time.deltaTime;
        // if (timer <= 0f)
        // {
//
        //     timer = spawnInterval;
        // }

        RemoveDestroyedParticles();
        text.text = activeParticles.Count.ToString();
    }

    void SpawnParticle()
    {
        int seed = _randomizer.Next(int.MinValue,int.MaxValue);
        Random.InitState(seed);
        GameObject particle = Instantiate(particlePrefab, RandomScreenPosition(), Quaternion.identity);
        AnimatedParticle animatedParticle = particle.GetComponent<AnimatedParticle>();
        float randomFloat = Random.value * 0.4f;
        Vector4 textureScaleOffset = new Vector4(
            Random.Range(0.01f, 2f), // Scale X
            Random.Range(0.01f, 2f), // Scale Y
            Random.Range(0f, 1f), // Offset X
            Random.Range(0f, 1f) // Offset Y
        );

        animatedParticle.Initialize(randomFloat, textureScaleOffset, Random.value * 3f + 0.3f);
        activeParticles.Add(particle); // Add the particle to the list
    }

    Vector3 RandomScreenPosition()
    {
        Vector3 screenPos = new Vector3(
            Random.Range(0, Screen.width),
            Random.Range(0, Screen.height),
            Camera.main.nearClipPlane
        );

        return Camera.main.ScreenToWorldPoint(screenPos);
    }

    void RemoveDestroyedParticles()
    {
        activeParticles.RemoveAll(item => item == null);
    }
}