#ifndef DAVE_BAKED_DEPTH_INCLUDED
#define DAVE_BAKED_DEPTH_INCLUDED
#define PI            3.14159265359f
// returns angle in horizontal plane of a vector mapped to 0-1
float GetYawRatio(float3 normalizedVector, int steps)
{
    float angle = ((atan2(normalizedVector.z, normalizedVector.x) + (PI / steps)) / (2 *
        PI));
    return frac(angle); // Ensures the result is in the 0-1 range
}

// returns angle in vertical plane mapped from 0-1 0 being v.down and 1 v.up
float GetPitchRatio(float vectorY, int steps)
{
    float scale = (1.0 - acos(vectorY) / PI);
    return (scale);
}

//gets a smooth for known normalized range. doesnt work outside 0-1
float smoothUnit(float a, float b, float x)
{
    x = ((x - a) / (b - a));
    return x * x * (3 - 2 * x);
}


// stepping function that returns "stair" function in range 0-1 for ex. for 2 steps it will return values: 0, 0.5
float NormalizedSteps(float nf, int steps)
{
    return floor((nf) * steps) / steps;
}

// returns fraction inside each "stair step" again from 0-1
float NormalizedStepFraction(float nf, int steps)
{
    return frac(nf * steps);
}

// verticals turned out to be the same, however if we are to bake polar tops we would need to change it specifically for verticals.

float stepv(float nf, int steps)
{
    return floor(nf * steps) / steps;
}

float stepvFrac(float nf, int steps)
{
    return frac(nf * steps);
}

// returns stepped ratio coords: float4(pl_V_cent, pl_H_cent, pl_V_nex, pl_H_nex);
float4 GetQuadSamples(float YawRatio, float PitchRatio, int _hSteps, int _vSteps)
{
    float vstep = (1 / (float)_vSteps);
    float pl_H_cent = NormalizedSteps(YawRatio, _hSteps); //main plato offset
    float mainFracH = NormalizedStepFraction(YawRatio, _hSteps); //inf plato pos
    float secDirH = mainFracH > 0.5 ? 1.0 : -1.0; // neighbor to sample
    // since plato is a step in 0-1 range, we can loop around using frac.
    float pl_H_nex = (frac(pl_H_cent + (secDirH / (float)_hSteps))); //next plato offset

    float pl_V_cent = NormalizedSteps(PitchRatio, _vSteps);
    float mainFracV = NormalizedStepFraction(PitchRatio, _vSteps);
    float secDirV = mainFracV > 0.5 ? 1.0 : -1.0;
    // here we need to clamp it as verticals dont support blendovercenter.
    float pl_V_nex = frac(clamp((pl_V_cent + secDirV / (float)_vSteps), 0, 1 - vstep));
    return float4(pl_V_cent, pl_H_cent, pl_V_nex, pl_H_nex);
}

#endif
