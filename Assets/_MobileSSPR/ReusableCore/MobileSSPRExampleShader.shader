﻿//just a simple shader to show how to use SSPR's result texture
Shader "MobileSSPR/ExampleShader"
{
    Properties
    {
        [MainColor] _BaseColor("BaseColor", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("BaseMap", 2D) = "white" {}

        _Roughness("_Roughness", range(0,1)) = 0.25 
        _SSPR_UVNoiseTex("_SSPR_UVNoiseTex", 2D) = "gray" {}
        _SSPR_NoiseIntensity("_SSPR_NoiseIntensity", range(-0.05,0.05)) = 0.02

        _UV_MoveSpeed("_UV_MoveSpeed (xy only)(for things like water flow)", Vector) = (0,0,0,0)

        _ReflectionAreaTex("_ReflectionArea", 2D) = "gray" {}
    }

    SubShader
    {
        Pass
        {
            //if "LightMode"="MobileSSPR", this shader will only draw if MobileSSPRRendererFeature is on
            Tags { "LightMode"="MobileSSPR" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 screenPos    : TEXCOORD1;
                float3 posWS        : TEXCOORD2;
                float4 positionHCS  : SV_POSITION;
            };

            //textures
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            
            TEXTURE2D(_MobileSSPR_ColorRT);
            sampler LinearClampSampler;

            sampler2D _SSPR_UVNoiseTex;
            sampler2D _ReflectionAreaTex;

            //cbuffer
            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            half _SSPR_NoiseIntensity;
            float2 _UV_MoveSpeed;
            half _Roughness;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap)+ _Time.y*_UV_MoveSpeed;
                OUT.screenPos = ComputeScreenPos(OUT.positionHCS);
                OUT.posWS = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            { 
                //base color
                half3 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;

                //sample scene's reflection probe
                half3 viewWS = (IN.posWS - _WorldSpaceCameraPos);
                viewWS = normalize(viewWS);

                half3 reflectDirWS = viewWS.y * half3(1,-1,1);//reflect at horizontal plane

                //call this function in Lighting.hlsl-> half3 GlossyEnvironmentReflection(half3 reflectVector, half perceptualRoughness, half occlusion)
                half3 reflectionProbeResult = GlossyEnvironmentReflection(reflectDirWS,_Roughness,1);               

                //our screen space reflection
                half2 noise = tex2D(_SSPR_UVNoiseTex, IN.uv);
                half2 screenUV = IN.screenPos.xy/IN.screenPos.w;
                half4 SSPRResult = SAMPLE_TEXTURE2D(_MobileSSPR_ColorRT,LinearClampSampler, screenUV + (noise*2-1)* _SSPR_NoiseIntensity); //use LinearClampSampler to make it blurry

                //final reflection
                half3 finalReflection = lerp(reflectionProbeResult,SSPRResult.rgb,SSPRResult.a);//combine reflection probe and SSPR
                
                //show reflection area
                half reflectionArea = tex2D(_ReflectionAreaTex,IN.uv);

                return half4(lerp(baseColor,finalReflection,reflectionArea),1);
            }

            ENDHLSL
        }
    }
}