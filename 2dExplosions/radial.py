from PIL import Image
import noise
import numpy as np

def f(x, y, width, height):
    a = ((x-width*0.5)**2+(y-height*0.5)**2)**0.5;
    return 1 - min(1,a/(max(width,height)*0.5))

def create_image(width, height):
    image = Image.new('RGBA', (width, height))
    pixels = image.load()

    for x in range(width):
        for y in range(height):
            val = int(abs(f(x, y, width, height)) * 256)  # Normalizing and scaling
            pixels[x, y] = (val, val, val, val)  # Grayscale

    return image

# Parameters
width, height = 256, 256

# Generate and save the image
img = create_image(width, height)
img.save("tiled_perlin_noise.png")
