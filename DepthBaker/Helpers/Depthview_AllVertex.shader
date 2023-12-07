Shader "Unlit/DepthFromTexView"
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
      //  Blend SrcAlpha OneMinusSrcAlpha
        ZWrite On
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
                float2 uv2 : TEXCOORD2;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float4 inDepth: TEXCOORD3;
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

            float smoothUnit(float a, float b, float x)
            {
                x=( (x - a) / (b - a));
                return x * x * (3 - 2 * x);
            }
            
            float steph(float nf, int steps)
            {
                float halfstep = nf / steps;
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
                
                float normDot = dot(normalize(_WorldSpaceCameraPos - mul(unity_ObjectToWorld, v.vertex)), v.normal);
                float lightDot = dot(normalize(_WorldSpaceCameraPos - mul(unity_ObjectToWorld, v.vertex)), ObjSpaceLightDir(v.vertex));

                camvec.w = dot(camvec.x, float3(0, 0, 1)); // for vertical dot is enough.
                
                float2 inPlaneVector = camvec.wy;
                inPlaneVector = (inPlaneVector + 1) * 0.5;
                float ha = hAng(camvec, _hsteps); //horizontal angle float stepped.

                float2 scale = (1 / (float)_vsteps, 1 / (float)_hsteps);
                //the fuck is here - steps are blending because of vertices...
                // make new shader.
                float pl_H_cent = steph(ha, _hsteps); //main plato offset
                float mainFracH = stephFrac(ha, _hsteps); //inf plato pos
                float secDirH = mainFracH > 0.5 ? 1.0 : -1.0; // neighbor to sample
                // since plato is a step in 0-1 range, we can loop around using frac.
                float pl_H_nex = (frac(pl_H_cent + secDirH / (float)_hsteps)); //next plato offset

                float pl_V_cent = stepv(inPlaneVector.y, _vsteps);
                float mainFracV = stepvFrac(inPlaneVector.y, _vsteps);
                float secDirV = mainFracV > 0.5 ? 1.0 : -1.0;
                // here we need to clamp it as verticals dont support blendovercenter.
                //float pl_V_nex = frac(clamp((pl_V_cent + secDirV / (float)_vsteps), 0, 1-scale.y));
                float pl_V_nex = frac(pl_V_cent + secDirV / (float)_vsteps);

                //mainOffsetV=0.4;

                float2 uvsample = v.uv1.xy * scale;
                
                float4 sampleZero = tex2Dlod(_DepthPerAngleGridmap, float4(uvsample + float2(pl_V_cent, pl_H_cent), 0, 1));
                float4 sampleH = tex2Dlod(_DepthPerAngleGridmap, float4(uvsample + float2(pl_V_cent, pl_H_nex), 0, 1));
                float4 sampleV = tex2Dlod(_DepthPerAngleGridmap, float4(uvsample + float2(pl_V_nex, pl_H_cent), 0, 1));
                float4 sampleHV = tex2Dlod(_DepthPerAngleGridmap, float4(uvsample + float2(pl_V_nex, pl_H_nex), 0, 1));

// calculate blend because on the inbetween in should be 0.5,
                
                float hLerpParam =  smoothstep(0,1,2 * abs(mainFracH - 0.5));
                float vLerpParam =  smoothstep(0,1,2 * abs(mainFracV - 0.5));
                //float hLerpParam =  2 * abs(mainFracH - 0.5);
                //float vLerpParam =  2 * abs(mainFracV - 0.5);
                //g is cumulative
                float2 finalLerp;
                float2 lerpH = lerp(sampleZero, sampleH, hLerpParam);
                //float2 lerpV = lerp(sampleZero, sampleV, vLerpParam);
                //float2 finalLerp = lerp(lerpH ,lerpV, 0.5);

                // for quadratic interpol, but works worse
                float2 lerpV2 = lerp(sampleV, sampleHV, hLerpParam);
                float2 lerpHV = lerp(lerpH,lerpV2, vLerpParam);
                finalLerp = lerpHV;

                // we need something like this, for edges because it gets interpolated to black on edge transition
                //if (finalLerp < 0.001)
                //    finalLerp=1;

                o.inDepth = float4(finalLerp.r, finalLerp.g, pl_V_cent, lightDot);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.uv2 = TRANSFORM_TEX(v.uv2, _MainTex);
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                return i.inDepth.b;
                // leave test shader as original.
                float d = i.inDepth.g;
                float l = i.inDepth.a;
                float dr = 1-clamp(d*4,0,1);
                float n = abs(i.inDepth.b);
                //d=clamp(d-0.5,0,1);
                
                return float4(d,d*d,0,0);
                return fixed4(d,d*d,pow(0.2,dr),1);
                fixed4 col = tex2D(_MainTex, i.uv);
                fixed4 dcol= fixed4(d,d*d,0,0);
                fixed4 sss = fixed4(1-pow(0.4,d),1-pow(0.2,d),0,0.2);
                return col+sss*0.2;
                //return i.uv2.x*_Factor;
                // sample the texture
                //fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}