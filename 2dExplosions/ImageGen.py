from PIL import Image
import noise
import numpy as np

def generate_tiled_perlin_noise_toroid(x, y, width, height, scale=2, octaves=6, persistence=0.5, lacunarity=2.0):
    # Convert (x, y) to angles
    theta = 2.0 * np.pi * x / width
    phi = 2.0 * np.pi * y / height

    # Radius of the torus tube
    r = 0.5

    # Convert angles to 3D coordinates on the torus
    nx = (1 + r * np.cos(phi)) * np.cos(theta)
    ny = (1 + r * np.cos(phi)) * np.sin(theta)
    nz = r * np.sin(phi)

    # Sample 3D Perlin noise
    e = noise.pnoise3(nx * scale, ny * scale, nz * scale,
                      octaves=octaves, persistence=persistence,
                      lacunarity=lacunarity, base=0)
    return e

def generate_tiled_perlin_noise_v2(x, y, width, height, scale=3, octaves=6, persistence=0.5, lacunarity=2.0):
    # Adjust the coordinates for tiling
    dx = x / width
    dy = y / height

    # Use a combination of four samples to create tiling
    n0 = noise.pnoise3(dx * scale, dy * scale, 0, octaves=octaves, persistence=persistence, lacunarity=lacunarity, base=0)
    n1 = noise.pnoise3((dx + 1) * scale, dy * scale, 0, octaves=octaves, persistence=persistence, lacunarity=lacunarity, base=0)
    n2 = noise.pnoise3(dx * scale, (dy + 1) * scale, 0, octaves=octaves, persistence=persistence, lacunarity=lacunarity, base=0)
    n3 = noise.pnoise3((dx + 1) * scale, (dy + 1) * scale, 0, octaves=octaves, persistence=persistence, lacunarity=lacunarity, base=0)

    # Blend the four samples
    u = dx * np.pi * 2
    v = dy * np.pi * 2
    s = (np.cos(u) + 1) * 0.5
    t = (np.cos(v) + 1) * 0.5
    
    nx = n0 * (1 - s) * (1 - t) + n1 * s * (1 - t) + n2 * (1 - s) * t + n3 * s * t
    return nx

def generate_tiled_perlin_noise(x, y, width, height, scale=2, octaves=6, persistence=0.5, lacunarity=2.0):
    # Convert (x, y) to angles
    theta = 2.0 * np.pi * x / width
    phi = 2.0 * np.pi * y / height

    # Radius of the torus tube
    r = 0.5

    # Convert angles to 3D coordinates on the torus
    nx = (1 + r * np.cos(phi)) * np.cos(theta)
    ny = (1 + r * np.cos(phi)) * np.sin(theta)
    nz = r * np.sin(phi)

    # Sample 3D Perlin noise
    e = noise.pnoise3(nx * scale, ny * scale, nz * scale,
                      octaves=octaves, persistence=persistence,
                      lacunarity=lacunarity, base=0)
    return e


def f(x, y, width, height):
    return generate_tiled_perlin_noise(x,y,width, height)

def create_image(width, height):
    image = Image.new('RGBA', (width, height))
    pixels = image.load()

    for x in range(width):
        for y in range(height):
            val = int((f(x, y, width, height) + 1) * 128)  # Normalizing and scaling
            pixels[x, y] = (val, val, val,val)  # Gray  scale


    return image

# Parameters
width, height = 256, 256

# Generate and save the image
img = create_image(width, height)
img.save("tiled_perlin_noise.png")
