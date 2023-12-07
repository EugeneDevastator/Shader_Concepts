Shader "Unlit/DepthFromTexViewV2"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DepthPerAngleGridmap("DepthPerAngleGridmap", 2D) = "white" { }
        _Factor("Factor", Float) = 0.0
        _Lerper("lerper", Range(0.0, 1.0)) = 0.0
        _hsteps("hsteps", Integer) = 5
        _vsteps("vsteps", Integer) = 5
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "Queue" = "Geometry"
        }
        LOD 100

        Cull Back
        //Blend SrcAlpha OneMinusSrcAlpha
        //ZWrite On
        //  AlphaTest Greater 0.1

        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv1: TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 depthData: TEXCOORD3;
                float4 depthSamples: TEXCOORD4;
            };

            sampler2D _MainTex;
            sampler2D _DepthPerAngleGridmap;
            float4 _MainTex_ST;
            float _Factor;
            float _Lerper;
            int _hsteps;
            int _vsteps;

            float hAng(float3 normalizedVector, int steps)
            {
                float angle = ((atan2(normalizedVector.z, normalizedVector.x) + (3.14159265 / steps)) / (2 *
                    3.14159265));
                return frac(angle); // Ensures the result is in the 0-1 range
            }

            float vAng(float vectorY, int steps)
            {
                float scale = (1.0 - acos(vectorY) / 3.14159265);
                return (scale);
            }

            float smoothUnit(float a, float b, float x)
            {
                x = ((x - a) / (b - a));
                return x * x * (3 - 2 * x);
            }

            float steph(float nf, int steps)
            {
                return floor((nf) * steps) / steps;
            }

            float stephFrac(float nf, int steps)
            {
                return frac(nf * steps);
            }

            float stepv(float nf, int steps)
            {
                return floor(nf * steps) / steps;
            }

            float stepvFrac(float nf, int steps)
            {
                return frac(nf * steps);
            }

            v2f vert(appdata v)
            {
                // uv1 stores location on sample texture.
                // sample the texture using uv1 from vertex
                v2f o;
                float4 camvec;
                //probably invert y axis wht the fuck.
                //cam ObjSpaceViewDir(v.vertex)
                //camvec.xyz = float3(1, 1, -1) * normalize(-_WorldSpaceCameraPos + mul(unity_ObjectToWorld, v.vertex));
                camvec.xyz = normalize(float3(-1, -1, 1) * ObjSpaceViewDir(v.vertex));
                //camvec.xyz = normalize(float3(1, 1, -1)*ObjSpaceLightDir(v.vertex));

                //float normDot = dot(normalize(_WorldSpaceCameraPos - mul(unity_ObjectToWorld, v.vertex)), v.normal);
                //float lightDot = dot(normalize(_WorldSpaceCameraPos - mul(unity_ObjectToWorld, v.vertex)), ObjSpaceLightDir(v.vertex));
                float vertAngle_f01 = vAng(camvec.y,_hsteps);
                float horizAngle_f01 = hAng(camvec, _hsteps); //horizontal angle float stepped.
                float2 scale = (1 / (float)_vsteps, 1 / (float)_hsteps);

                //the fuck is here - steps are blending because of vertices...
                // make new shader.
                float pl_H_cent = steph(horizAngle_f01, _hsteps); //main plato offset
                float mainFracH = stephFrac(horizAngle_f01, _hsteps); //inf plato pos
                float secDirH = mainFracH > 0.5 ? 1.0 : -1.0; // neighbor to sample
                // since plato is a step in 0-1 range, we can loop around using frac.
                float pl_H_nex = (frac(pl_H_cent + (secDirH / (float)_hsteps))); //next plato offset

                float pl_V_cent = stepv(vertAngle_f01, _vsteps);
                float mainFracV = stepvFrac(vertAngle_f01, _vsteps);
                float secDirV = mainFracV > 0.5 ? 1.0 : -1.0;
                // here we need to clamp it as verticals dont support blendovercenter.
                float pl_V_nex = frac(clamp((pl_V_cent + secDirV / (float)_vsteps), 0, 1 - scale.y));
                //float pl_V_nex = frac(pl_V_cent + secDirV / ((float)_vsteps));

                //mainOffsetV=0.4;

                float2 uvsample = v.uv1.xy * scale;

                float4 sampleZero = tex2Dlod(_DepthPerAngleGridmap,
                                                            float4(uvsample + float2(pl_V_cent, pl_H_cent), 0, 1));
                float4 sampleH = tex2Dlod(_DepthPerAngleGridmap, float4(uvsample + float2(pl_V_cent, pl_H_nex), 0, 1));
                float4 sampleV = tex2Dlod(_DepthPerAngleGridmap, float4(uvsample + float2(pl_V_nex, pl_H_cent), 0, 1));
                float4 sampleHV = tex2Dlod(_DepthPerAngleGridmap, float4(uvsample + float2(pl_V_nex, pl_H_nex), 0, 1));

                o.depthData = float4(vertAngle_f01, camvec.xyz);
                o.depthSamples = float4(sampleZero.g, sampleH.g, sampleV.g, sampleHV.g);


                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float vertAngle_f01 = i.depthData.x;

                float3 camvec = i.depthData.yzw;
                float horizAngle_f01 = hAng(camvec, _hsteps);
                float mainFracH = stephFrac(horizAngle_f01, _hsteps); //inf plato pos
                float mainFracV = stepvFrac(vertAngle_f01, _vsteps);
                float pl_H_cent = steph(horizAngle_f01, _hsteps);

                float pl_V_cent = stepv(vertAngle_f01, _vsteps);

                float secDirV = mainFracV > 0.5 ? 1.0 : -1.0;
                // here we need to clamp it as verticals dont support blendovercenter.
                //float pl_V_nex = frac(clamp((pl_V_cent + secDirV / (float)_vsteps), 0, 1 - scale.y));
                float pl_V_nex = frac(pl_V_cent + secDirV / ((float)_vsteps));

                float secDirH = mainFracH > 0.5 ? 1.0 : -1.0; // neighbor to sample
                // since plato is a step in 0-1 range, we can loop around using frac.
                float pl_H_nex = (frac(pl_H_cent + (secDirH / (float)_hsteps))); //next plato offset

                float sampleZero = i.depthSamples.x;
                // so current sample is interpolated which is good.
                //perhaps we need to gain next samples not from interpolation but manualy..
                float sampleH = i.depthSamples.y;
                float sampleV = i.depthSamples.z;
                float sampleHV = i.depthSamples.w;

                // calculate blend because on the inbetween in should be 0.5,

                //float hLerpParam = smoothstep(0, 1, abs(mainFracH-0.5));
                //float vLerpParam = smoothstep(0, 1, abs(mainFracV-0.5));
                float hLerpParam = abs(mainFracH - 0.5);
                float vLerpParam = abs(mainFracV - 0.5);

                float lerpH = lerp(sampleZero, sampleH, hLerpParam);
                float lerpV2 = lerp(sampleV, sampleHV, hLerpParam);
                float lerpHV = lerp(lerpH, lerpV2, vLerpParam);
                return lerpHV;
            }
            ENDCG
        }
    }
}