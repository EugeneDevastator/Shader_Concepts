Shader "Unlit/AngleVisual"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _hsteps("hsteps", Integer) = 5
        _vsteps("vsteps", Integer) = 3
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
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
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float4 calcAngle : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            int _hsteps;
            int _vsteps;
            
            float hAng(float3 normalizedVector,int steps) {
                float angle = ((atan2(normalizedVector.z, normalizedVector.x)+(3.14159265/steps)) / (2 * 3.14159265));
                return frac(angle); // Ensures the result is in the 0-1 range
            }
            float steph(float nf, int steps)
            {
                float halfstep = nf/steps;
                return floor((nf)*steps)/steps;
            }
            float stepv(float nf, int steps)
            {
                return round(nf*steps)/steps;
            }
            
            v2f vert (appdata v)
            {
                v2f o;

                float4 camvec;
                camvec.xyz = normalize(ObjSpaceViewDir(v.vertex));
                camvec.w =dot(camvec.x,float3(0,0,1)); // for vertical dot is enough.
                float2 hvec = camvec.wy;
                hvec=(hvec+1)*0.5;
                float ha = hAng(camvec,_hsteps); //horizontal angle float stepped.
                o.calcAngle = float4(steph(ha,_hsteps),stepv(hvec.y,_vsteps-1),0,1);
                
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            
            fixed4 frag (v2f i) : SV_Target
            {

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return float4(i.calcAngle.xy,0,1);
            }
            ENDCG
        }
    }
}
