Shader "Unlit/NewUnlitShader"
{
    Properties
    {
        _Col("Example color", Color) = (.25, .5, .5, 1)
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue" = "Geometry-1"}
        LOD 100
        ZWrite True
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
                float4 screenPos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Col;
           UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture); // Declare depth texture

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                o.screenPos = ComputeScreenPos(o.vertex);
                return o;
            }

            struct fragOutput {
                fixed4 color : SV_Target;
                float depth : SV_Depth;
            };

            fragOutput frag(v2f i)
            {
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float existingDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
                existingDepth = Linear01Depth(existingDepth);
                fragOutput o;
                o.color = float4(_Col.x,existingDepth,_Col.z, tex2D(_MainTex, i.uv).r);
                //o.depth = tex2D(_MainTex, i.uv).r; // Note: depth should be in 0-1 range

                float myDepth = tex2D(_MainTex, i.uv).r*_Col.b;
                
                // Only write if our depth is less than or equal
                o.depth = myDepth <= existingDepth ? myDepth : existingDepth;
                UNITY_APPLY_FOG(i.fogCoord, o.color);
                return o;
            }
            ENDCG
        }
    }
}
