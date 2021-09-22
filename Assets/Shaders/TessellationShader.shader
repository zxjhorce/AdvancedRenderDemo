// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/Tessellation"
{
    Properties
    {
        //_Tint("Tint", Color) = (1, 1, 1, 1)
        _Color("Tint", Color) = (1, 1, 1, 1)
        _MainTex("Albedo", 2D) = "white" {}

        [NoScaleOffset] _NormalMap("Normals", 2D) = "bump" {}
        _BumpScale("Bump Scale", Float) = 1

        [NoScaleOffset] _MetallicMap("Metallic", 2D) = "white" {}
        [Gamma] _Metallic("Metallic", Range(0, 1)) = 0
        _Smoothness("Smoothness", Range(0, 1)) = 0.5

        _DetailTex("Detail Albedo", 2D) = "gray" {}
        [NoScaleOffset] _DetailNormalMap("Detail Normals", 2D) = "bump" {}
        _DetailBumpScale("Detail Bump Scale", Float) = 1

        [NoScaleOffset] _EmissionMap("Emission", 2D) = "black" {}
        _Emission("Emission", Color) = (0, 0, 0)

        [NoScaleOffset] _ParallaxMap("Parallax", 2D) = "black" {}
        _ParallaxStrength("Parallax Strength", Range(0, 1)) = 0

        [NoScaleOffset] _OcclusionMap("Occlusion", 2D) = "white" {}
        _OcclusionStrength("Occlusion Strength", Range(0, 1)) = 1

        [NoScaleOffset] _DetailMask("Detail Mask", 2D) = "white" {}

        //_AlphaCutoff ("Alpha Cutoff", Range(0, 1)) = 0.5
        _Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.5

        [HideInInspector] _SrcBlend ("_SrcBlend", Float) = 1
        [HideInInspector] _DstBlend ("_DstBlend", Float) = 0
        [HideInInspector] _ZWrite ("_ZWrite", Float) = 1

        //_WireframeColor ("Wireframe Color", Color) = (0, 0, 0)
        //_WireframeSmoothing ("Wireframe Smoothness", Range(0, 10)) = 1
        //_WireframeThickness ("Wireframe Thickness", Range(0, 10)) = 1

        _TessellationUniform ("Tessellation Uniform", Range(1, 64)) = 1
        _TessellationEdgeLength ("Tessellation Edge Length", Range(5, 100)) = 50
    }

    CGINCLUDE

    #define BINORMAL_PER_FRAGMENT
    #define FOG_DISTANCE

    //#define PARALLAX_BIAS 0
    ////#define PARALLAX_OFFSET_LIMITING
    ////#define PARALLAX_RAYMARCHING_STEPS 100
    //#define PARALLAX_RAYMARCHING_INTERPOLATE
    //#define PARALLAX_RAYMARCHING_SEARCH_STEPS 3
    //#define PARALLAX_FUNCTION ParallaxRaymarching
    //#define PARALLAX_SUPPORT_SCALED_DYNAMIC_BATCHING

    #define VERTEX_DISPLACEMENT_INSTEAD_OF_PARALLAX

    ENDCG

    SubShader
    {
       
        Pass
        {
            Tags {
                "LightMode" = "ForwardBase"
            }
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

           CGPROGRAM

           #pragma target 4.6

           #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
           #pragma shader_feature _METALLIC_MAP
           #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
           #pragma shader_feature _NORMAL_MAP
           #pragma shader_feature _PARALLAX_MAP
           #pragma shader_feature _OCCLUSION_MAP
           #pragma shader_feature _EMISSION_MAP
           #pragma shader_feature _DETAIL_MASK
           #pragma shader_feature _DETAIL_ALBEDO_MAP
           #pragma shader_feature _DETAIL_NORMAL_MAP
           #pragma shader_feature _TESSELLATION_EDGE

           #pragma multi_compile _ UNITY_HDR_ON
           //#pragma multi_compile _ SHADOWS_SCREEN
           ////#pragma multi_compile _ VERTEXLIGHT_ON
           ////#pragma multi_compile _ LIGHTMAP_ON
           //#pragma multi_compile _ LIGHTMAP_ON VERTEXLIGHT_ON
           #pragma multi_compile_fwdbase
           #pragma multi_compile_fog
           //#pragma multi_compile_instancing
           //#pragma instancing_options lodfade
           #pragma multi_compile _ LOD_FADE_CROSSFADE

           #pragma vertex MyTessellationVertexProgram
           #pragma fragment MyFragmentProgram
           #pragma hull MyHullProgram
           #pragma domain MyDomainProgram
           //#pragma geometry MyGeometryProgram

           //#include "UnityStandardBRDF.cginc"
           //#include "UnityStandardUtils.cginc"
          
           #define FORWARD_BASE_PASS

           #include "MyLighting.cginc"
           //#include "MyFlatWireframe.cginc"
           #include "MyTessellation.cginc"

           ENDCG
        }

        Pass
        {
            Tags {
                "LightMode" = "ForwardAdd"
            }

            Blend [_SrcBlend] One
            ZWrite Off

           CGPROGRAM

           #pragma target 4.6

           #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
           #pragma shader_feature _METALLIC_MAP
           #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
           #pragma shader_feature _NORMAL_MAP
           #pragma shader_feature _PARALLAX_MAP
           #pragma shader_feature _DETAIL_MASK
           #pragma shader_feature _DETAIL_ALBEDO_MAP
           #pragma shader_feature _DETAIL_NORMAL_MAP
           #pragma shader_feature _TESSELLATION_EDGE

           #pragma multi_compile _ UNITY_HDR_ON
           #pragma multi_compile_fwdadd_fullshadows
           #pragma multi_compile_fog
           //#pragma instancing_options lodfade
           #pragma multi_compile _ LOD_FADE_CROSSFADE
           //#pragma multi_compile DIRECTIONAL POINT SPOT

           #pragma vertex MyTessellationVertexProgram
           #pragma fragment MyFragmentProgram
           #pragma hull MyHullProgram
           #pragma domain MyDomainProgram
           //#pragma geometry MyGeometryProgram

           //#include "UnityStandardBRDF.cginc"
           //#include "UnityStandardUtils.cginc"
          
           //#define POINT

           #include "MyLighting.cginc"
           //#include "MyFlatWireframe.cginc"
           #include "MyTessellation.cginc"

           ENDCG
        }

        Pass
        {
            Tags {
                "LightMode" = "Deferred"
            }

           CGPROGRAM

           #pragma target 4.6
           #pragma exclude_renderers nomrt

           #pragma shader_feature _ _RENDERING_CUTOUT
           #pragma shader_feature _METALLIC_MAP
           #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
           #pragma shader_feature _NORMAL_MAP
           #pragma shader_feature _PARALLAX_MAP
           #pragma shader_feature _OCCLUSION_MAP
           #pragma shader_feature _EMISSION_MAP
           #pragma shader_feature _DETAIL_MASK
           #pragma shader_feature _DETAIL_ALBEDO_MAP
           #pragma shader_feature _DETAIL_NORMAL_MAP
           #pragma shader_feature _TESSELLATION_EDGE

           //#pragma multi_compile _ UNITY_HDR_ON
           //#pragma multi_compile _ SHADOWS_SCREEN
           //#pragma multi_compile _ LIGHTMAP_ON
           #pragma multi_compile_prepassfinal
           //#pragma multi_compile_instancing
           //#pragma instancing_options lodfade
           #pragma multi_compile _ LOD_FADE_CROSSFADE

           #pragma vertex MyTessellationVertexProgram
           #pragma fragment MyFragmentProgram
           #pragma hull MyHullProgram
           #pragma domain MyDomainProgram
           //#pragma geometry MyGeometryProgram
          
           #define DEFERRED_PASS

           #include "MyLighting.cginc"
           //#include "MyFlatWireframe.cginc"
           #include "MyTessellation.cginc"

           ENDCG
        }

        Pass
        {
            Tags {
                "LightMode" = "ShadowCaster"
            }

          
           CGPROGRAM

           #pragma target 4.6

           #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
           #pragma shader_feature _SEMITRANSPARENT_SHADOWS 
           #pragma shader_feature _SMOOTHNESS_ALBEDO 
           #pragma shader_feature _PARALLAX_MAP
           #pragma shader_feature _TESSELLATION_EDGE
           #pragma multi_compile_shadowcaster
           #pragma multi_compile_instancing
           #pragma instancing_options lodfade
           #pragma multi_compile _ LOD_FADE_CROSSFADE

           //#pragma vertex MyShadowVertexProgram
           #pragma vertex MyTessellationVertexProgram
           #pragma fragment MyShadowFragmentProgram
           #pragma hull MyHullProgram
           #pragma domain MyDomainProgram

           #include "MyShadows.cginc"
           #include "MyTessellation.cginc"

           ENDCG
        }

        Pass
        {
            Tags {
                "LightMode" = "Meta"
            }

            Cull Off
          
           CGPROGRAM

           #pragma vertex MyLightmappingVertexProgram
           #pragma fragment MyLightmappingFragmentProgram

           #pragma shader_feature _METALLIC_MAP
           #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
           #pragma shader_feature _EMISSION_MAP
           #pragma shader_feature _DETAIL_MASK
           #pragma shader_feature _DETAIL_ALBEDO_MAP

           #include "MyLightmapping.cginc"

           ENDCG
        }
    }

    CustomEditor "MyLightingShaderGUI"
}
