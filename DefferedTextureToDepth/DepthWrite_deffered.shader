Shader "Unlit/DepthWriterDefferred"
{
    Properties
    {
        _Col("Example color", Color) = (.25, .5, .5, 1)
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { 
            "RenderType"="Opaque" 
            "Queue" = "Geometry-1"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 100
        ZWrite On

        Pass
        {
            Name "GBuffer"
            Tags { "LightMode" = "UniversalGBuffer" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };
            struct FragmentOutputMy
            {
                half4 GBuffer0 : SV_Target0;
                half4 GBuffer1 : SV_Target1;
                half4 GBuffer2 : SV_Target2;
                half4 GBuffer3 : SV_Target3; // Camera color attachment
                float Depth : SV_Depth; // depth

                #ifdef GBUFFER_OPTIONAL_SLOT_1
                GBUFFER_OPTIONAL_SLOT_1_TYPE GBuffer4 : SV_Target4;
                #endif
                #ifdef GBUFFER_OPTIONAL_SLOT_2
                half4 GBuffer5 : SV_Target5;
                #endif
                #ifdef GBUFFER_OPTIONAL_SLOT_3
                half4 GBuffer6 : SV_Target6;
                #endif
            };
            
            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _Col;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.screenPos = ComputeScreenPos(output.positionCS);
                return output;
            }

            FragmentOutputMy frag(Varyings input)
            {
                float2 screenUV = input.screenPos.xy / input.screenPos.w;
                float existingDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
                existingDepth = Linear01Depth(existingDepth, _ZBufferParams);

                float myDepth = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).r * _Col.b;
                
                // Setup surface data
                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = float3(_Col.x, existingDepth, _Col.z);
                surfaceData.smoothness = 0.5;
                surfaceData.metallic = 0;
                surfaceData.normalTS = float3(0, 0, 1);

                // Setup input data
                InputData inputData = (InputData)0;
                inputData.normalWS = normalize(input.normalWS);
                inputData.positionWS = float3(0, 0, 0); // You might want to compute this if needed
                inputData.viewDirectionWS = float3(0, 0, 1); // You might want to compute this if needed

                // Output to GBuffer
                FragmentOutputMy output;
                FragmentOutput uout = SurfaceDataToGbuffer(surfaceData, inputData, float3(0,0,0), 0);
                output.GBuffer0 = uout.GBuffer0;   // albedo          albedo          albedo          materialFlags   (sRGB rendertarget)
                output.GBuffer1 = uout.GBuffer1;            // specular        specular        specular        occlusion
                output.GBuffer2 = uout.GBuffer2;                     // encoded-normal  encoded-normal  encoded-normal  smoothness
                output.GBuffer3 = uout.GBuffer3; 
                // Handle depth
                if(myDepth <= existingDepth)
                {
                    output.Depth = myDepth;
                }
                else
                {
                    output.Depth = existingDepth;
                }

                return output;
            }
            ENDHLSL
        }
    }
}
