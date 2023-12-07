Shader "Unlit/Explosion"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Noise ("Noise", 2D) = "white" {}
        _ColorMap ("SamplingPalette", 2D) = "white" {}
        _FloatPos ("_FloatPos", Range(0.0, 1.0)) = 0.5
        _NoiseFactor ("_NoiseFactor", Range(0.0, 1.0)) = 0.5
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent" "Queue" = "Transparent"
        }
        LOD 100

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        AlphaTest Greater 0.1

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"

            // Define instanced properties
            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float, _FloatPos)
                UNITY_DEFINE_INSTANCED_PROP(float, _NoiseFactor)
                UNITY_DEFINE_INSTANCED_PROP(float4, _Noise_ST)
            UNITY_INSTANCING_BUFFER_END(Props)

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float2 noiseuv : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float2 noiseuv : TEXCOORD1;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            sampler2D _MainTex;
            sampler2D _ColorMap;
            sampler2D _Noise;
            float4 _MainTex_ST;
            float4 _Noise_ST;

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.noiseuv = TRANSFORM_TEX(v.uv, _Noise);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                          UNITY_SETUP_INSTANCE_ID(i);
                float timepos = UNITY_ACCESS_INSTANCED_PROP(Props, _FloatPos);
                float noiseFac = UNITY_ACCESS_INSTANCED_PROP(Props, _NoiseFactor);
                
                //color of sampling
                fixed sampleArgument = tex2D(_MainTex, i.uv).r;
                clip(sampleArgument - 0.01);
                fixed noised = sampleArgument
                    +
                    lerp(
                        0,
                        (tex2D(_Noise, i.noiseuv).r - 0.5) * 2,
                        noiseFac);
                // sample the texture
                fixed4 col = tex2D(_ColorMap,fixed2(1 - noised, 1 - timepos));
                return col;
            }
            ENDCG
        }
    }
}