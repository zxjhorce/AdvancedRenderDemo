// Upgrade NOTE: upgraded instancing buffer 'InstanceProperties' to new syntax.

// Upgrade NOTE: replaced 'UNITY_PASS_TEXCUBE(unity_SpecCube1)' with 'UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1,unity_SpecCube0)'

#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED

#include "MyLightingInput.cginc"

#if !defined(ALBEDO_FUNCTION)
	#define ALBEDO_FUNCTION GetAlbedo
#endif

void ComputeVertexLightColor(inout InterpolatorsVertex i)
{
    #if defined(VERTEXLIGHT_ON)
        //float3 lightPos = float3(unity_4LightPosX0.x, unity_4LightPosY0.x, unity_4LightPosZ0.x);
        //float3 lightVec = lightPos - i.worldPos;
        //float3 lightDir = normalize(lightVec);
        //float ndotl = DotClamped(i.normal, lightDir);
        //float attenuation = 1 / (1 + dot(lightVec, lightVec) * unity_4LightAtten0);
        //i.vertexLightColor = unity_LightColor[0].rgb * ndotl * attenuation;
        i.vertexLightColor = Shade4PointLights(unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
            unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
            unity_4LightAtten0, i.worldPos.xyz, i.normal);
    #endif
}

float3 CreateBinormal(float3 normal, float3 tangent, float binormalSign)
{
    float3 binormal = cross(normal, tangent.xyz) * (binormalSign * unity_WorldTransformParams.w);
    return binormal;
}

float FadeShadows(Interpolators i, float attenuation)
{
    #if HANDLE_SHADOWS_BLENDING_IN_GI || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
        #if ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
            attenuation = SHADOW_ATTENUATION(i);
        #endif

        float viewZ = dot(_WorldSpaceCameraPos - i.worldPos, UNITY_MATRIX_V[2].xyz);
        float shadowFadeDistance = UnityComputeShadowFadeDistance(i.worldPos, viewZ);
        float shadowFade = UnityComputeShadowFade(shadowFadeDistance);
        float bakedAttenuation = UnitySampleBakedOcclusion(i.lightmapUV, i.worldPos);
        //attenuation = saturate(attenuation + shadowFade);
        attenuation = UnityMixRealtimeAndBakedShadows(attenuation, bakedAttenuation, shadowFade);
    #endif
    return attenuation;
}

InterpolatorsVertex MyVertexProgram(VertexData v)
{
    InterpolatorsVertex i;
    UNITY_INITIALIZE_OUTPUT(InterpolatorsVertex, i);
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, i);

    #if !defined(NO_DEFAULT_UV)
        i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
        i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);

        #if VERTEX_DISPLACEMENT
            float displacement = tex2Dlod(_DisplacementMap, float4(i.uv.xy, 0, 0)).g;
            displacement = (displacement - 0.5) * _DisplacementStrength;
            //v.vertex.y += displacement;
            v.normal = normalize(v.normal);
            v.vertex.xyz += v.normal * displacement;
        #endif
    #endif

    i.pos = UnityObjectToClipPos(v.vertex);
    i.worldPos.xyz = mul(unity_ObjectToWorld, v.vertex);
    #if FOG_DEPTH
        i.worldPos.w = i.pos.z;
    #endif
    //i.uv.xy = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
    //i.uv.zw = v.uv * _DetailTex_ST.xy + _DetailTex_ST.zw;

    //i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
    //i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);

    #if defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
        //不能用TRANSFORM_TEX 不是unity_Lightmap_ST,实际是unity_LightmapST
        i.lightmapUV = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
    #endif

    #if defined(DYNAMICLIGHTMAP_ON)
        i.dynamicLightmapUV = v.uv2 * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif

    //i.normal = mul(transpose((float3x3)unity_WorldToObject), v.normal);
    //i.normal = normalize(i.normal);
    i.normal = UnityObjectToWorldNormal(v.normal);

    #if REQUIRES_TANGENT_SPACE
        #if defined(BINORMAL_PER_FRAGMENT)
            i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
        #else
            i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
            i.binormal = CreateBinormal(i.normal, i.tangent, v.tangent.w);
        #endif
    #endif

    //#if defined(SHADOWS_SCREEN)
    //    //i.shadowCoordinates.xy = (float2(i.position.x, -i.position.y) + i.position.w) * 0.5;// / i.position.w;
    //    //i.shadowCoordinates.zw = i.position.zw;
    //    i.shadowCoordinates = ComputeScreenPos(i.position);
    //#endif
    //TRANSFER_SHADOW(i)
    UNITY_TRANSFER_SHADOW(i, v.uv1)

    ComputeVertexLightColor(i);

    #if defined(_PARALLAX_MAP)
        #if defined(PARALLAX_SUPPORT_SCALED_DYNAMIC_BATCHING)
            v.tangent.xyz = normalize(v.tangent.xyz);
            v.normal = normalize(v.normal);
        #endif
        float3x3 objectToTangent = float3x3(
            v.tangent.xyz,
            cross(v.normal, v.tangent.xyz) * v.tangent.w,
            v.normal
        );
        i.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.vertex));
    #endif

    return i;
}

UnityLight CreateLight(Interpolators i)
{
    UnityLight light;

    #if defined(DEFERRED_PASS) || SUBTRACTIVE_LIGHTING
        light.dir = float3(0, 1, 0);
        light.color = 0;
    #else
         #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
            float3 lightVec = _WorldSpaceLightPos0.xyz - i.worldPos.xyz;
            light.dir = normalize(lightVec);
        #else
            light.dir = _WorldSpaceLightPos0.xyz;
        #endif

        //#if defined(SHADOWS_SCREEN)
        //    //float attenuation = tex2D(_ShadowMapTexture, i.shadowCoordinates.xy / i.shadowCoordinates.w);
        //    float attenuation = SHADOW_ATTENUATION(i)
        //#else
            //float attenuation = 1 / (1 + dot(lightVec, lightVec));
            //UNITY_LIGHT_ATTENUATION(attenuation, 0, i.worldPos)
            UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz)
            attenuation = FadeShadows(i, attenuation);
        //#endif
        attenuation *= GetOcclusion(i);
        light.color = _LightColor0.rgb * attenuation;
    #endif
   
    //light.ndotl = DotClamped(i.normal, light.dir);
    return light;
}

float3 BoxProjection(float3 direction, float3 position, float4 cubemapPosition, float3 boxMin, float3 boxMax)
{
    //boxMin -= position;
    //boxMax -= position;
    //float x = (direction.x > 0 ? boxMax.x : boxMin.x) / direction.x;
    //float y = (direction.y > 0 ? boxMax.y : boxMin.y) / direction.y;
    //float z = (direction.z > 0 ? boxMax.z : boxMin.z) / direction.z;
    //float scalar = min(min(x, y), z);
    #if UNITY_SPECCUBE_BOX_PROJECTION
        UNITY_BRANCH
        if (cubemapPosition.w > 0)
        {
             float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
            float scalar = min(min(factors.x, factors.y), factors.z);
            direction = direction * scalar + (position - cubemapPosition);
        }
    #endif
    return direction;
}


void ApplySubtractiveLighting(Interpolators i, inout UnityIndirect indirectLight)
{
    #if SUBTRACTIVE_LIGHTING
        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz);
        attenuation = FadeShadows(i, attenuation);

        float ndotl = saturate(dot(i.normal, _WorldSpaceLightPos0.xyz));
        float3 shadowedLightEstimate = ndotl * (1 - attenuation) * _LightColor0.rgb;
        float3 subtractedLight = indirectLight.diffuse - shadowedLightEstimate;
        subtractedLight = max(subtractedLight, unity_ShadowColor.rgb);
        subtractedLight = lerp(subtractedLight, indirectLight.diffuse, _LightShadowData.x);
        //indirectLight.diffuse = subtractedLight;
        indirectLight.diffuse = min(subtractedLight, indirectLight.diffuse);
    #endif
}

UnityIndirect CreateIndirectLight(Interpolators i, float3 viewDir, SurfaceData surface)
{
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;

    #if defined(VERTEXLIGHT_ON)
        indirectLight.diffuse = i.vertexLightColor;
    #endif

    #if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
        #if defined(LIGHTMAP_ON)
            indirectLight.diffuse = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV));

            #if defined(DIRLIGHTMAP_COMBINED)
                float4 lightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, i.lightmapUV);
                indirectLight.diffuse = DecodeDirectionalLightmap(indirectLight.diffuse, lightmapDirection, i.normal);
            #endif

            ApplySubtractiveLighting(i, indirectLight);
        //#else
        //    indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
        #endif

        #if defined(DYNAMICLIGHTMAP_ON)
            float3 dynamicLightDiffuse = DecodeRealtimeLightmap(UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, i.dynamicLightmapUV));

            #if defined(DIRLIGHTMAP_COMBINED)
                float4 dynamicLightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, i.dynamicLightmapUV);
                indirectLight.diffuse += DecodeDirectionalLightmap(dynamicLightDiffuse, dynamicLightmapDirection, i.normal);
            #else
                indirectLight.diffuse += dynamicLightDiffuse;
            #endif

        #endif

        #if !defined(LIGHTMAP_ON) && !defined(DYNAMICLIGHTMAP_ON)
            #if UNITY_LIGHT_PROBE_PROXY_VOLUME
                if (unity_ProbeVolumeParams.x == 1)
                {
                    indirectLight.diffuse = SHEvalLinearL0L1_SampleProbeVolume(float4(i.normal, 1), i.worldPos);
                    indirectLight.diffuse = max(0, indirectLight.diffuse);
                    #if defined(UNITY_COLORSPACE_GAMMA)
                        indirectLight.diffuse = LinearToGammaSpace(indirectLight.diffuse);
                    #endif
                }
                else
                {
                    indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
                }
            #else
                indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
            #endif
        #endif

        float3 reflectionDir = reflect(-viewDir, i.normal);
        //float roughness = 1 - _Smoothness;
        //roughness *= 1.7 - 0.7 * roughness;
        //float4 envSample = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectionDir, roughness * UNITY_SPECCUBE_LOD_STEPS);
        //indirectLight.specular = DecodeHDR(envSample, unity_SpecCube0_HDR);
        Unity_GlossyEnvironmentData envData;
        envData.roughness = 1 - surface.smoothness;
        //envData.reflUVW = reflectionDir;
        envData.reflUVW = BoxProjection(reflectionDir, i.worldPos.xyz, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
        float3 probe0 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData);
        envData.reflUVW = BoxProjection(reflectionDir, i.worldPos.xyz, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
        #if UNITY_SPECCUBE_BLENDING
            float interpolator = unity_SpecCube0_BoxMin.w;
            UNITY_BRANCH
            if (interpolator < 0.99999)
            {
                float3 probe1 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1,unity_SpecCube0), unity_SpecCube1_HDR, envData);
                indirectLight.specular = lerp(probe1, probe0, interpolator);
            }
            else
            {
                indirectLight.specular = probe0;
            }
        #else
            indirectLight.specular = probe0;
        #endif
        
        float occlusion = surface.occlusion;
        indirectLight.diffuse *= occlusion;
        indirectLight.specular *= occlusion;

        #if defined(DEFERRED_PASS) && UNITY_ENABLE_REFLECTION_BUFFERS
            indirectLight.specular = 0;
        #endif
    #endif
    

    return indirectLight;
}


float3 GetTangentSpaceNormal (Interpolators i)
{
    float3 normal = float3(0, 0, 1);
    #if defined(_NORMAL_MAP)
        normal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
    #endif
    #if defined(_DETAIL_NORMAL_MAP)
        float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
        detailNormal = lerp(float3(0, 0, 1), detailNormal, GetDetailMask(i));
        normal = BlendNormals(normal, detailNormal);
    #endif
    
    return normal;
}

void InitializeFragmentNormal(inout Interpolators i)
{
    //float h = tex2D(_HeigthMap, i.uv);
    //i.normal = float3(0, h, 0);
    //有限差分
    //float2 delta = float2(_HeightMap_TexelSize.x, 0);
    //float h1 = tex2D(_HeigthMap, i.uv);
    //float h2 = tex2D(_HeigthMap, i.uv + delta);

    ////中心差分
    //float2 du = float2(_HeightMap_TexelSize.x * 0.5, 0);
    //float u1 = tex2D(_HeigthMap, i.uv - du);
    //float u2 = tex2D(_HeigthMap, i.uv + du);
    ////i.normal = float3(delta.x, (h2 - h1), 0);
    //float3 tu = float3(1, (u1 - u2), 0);

    //float2 dv = float2(0, _HeightMap_TexelSize.y * 0.5);
    //float v1 = tex2D(_HeigthMap, i.uv - dv);
    //float v2 = tex2D(_HeigthMap, i.uv + dv);
    //float3 tv = float3(0, (v1 - v2), 1);
    
    ////i.normal = cross(tv, tu);
    //i.normal = float3(u1 - u2, 1, v1 - v2);

    //i.normal.xy = tex2D(_NormalMap, i.uv).wy * 2 - 1;
    //i.normal.xy *= _BumpScale;
    //i.normal.z = sqrt(1 - saturate(dot(i.normal.xy, i.normal.xy)));
    //float3 mainNormal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
    //float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
    //detailNormal = lerp(float3(0, 0, 1), detailNormal, GetDetailMask(i));
    ////i.normal = (mainNormal + detailNormal) * 0.5;
    ////i.normal = float3(mainNormal.xy / mainNormal.z + detailNormal.xy /detailNormal.z, 1);
    ////泛白混合
    ////i.normal = float3(mainNormal.xy  + detailNormal.xy , mainNormal.z * detailNormal.z);
    //float3 tangentSpaceNormal = BlendNormals(mainNormal, detailNormal);

    //float3 dpdx = ddx(i.worldPos);
    //float3 dpdy = ddy(i.worldPos);
    //i.normal = normalize(cross(dpdy, dpdx));
    #if REQUIRES_TANGENT_SPACE
        float3 tangentSpaceNormal = GetTangentSpaceNormal(i);

        //tangentSpaceNormal = tangentSpaceNormal.xzy;
        #if defined(BINORMAL_PER_FRAGMENT)
            float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);
        #else
            float3 binormal = i.binormal;
        #endif
   
        //i.normal = normalize(tangentSpaceNormal.x * i.tangent + tangentSpaceNormal.y * i.normal + tangentSpaceNormal.z * binormal);
        i.normal = normalize(tangentSpaceNormal.x * i.tangent + tangentSpaceNormal.y * binormal + tangentSpaceNormal.z * i.normal);
        //i.normal = i.normal.xzy;
    #else
        i.normal = normalize(i.normal);
    #endif
}

struct FragmentOutput
{
    #if defined(DEFERRED_PASS)
        float4 gBuffer0 : SV_Target0;
        float4 gBuffer1 : SV_Target1;
        float4 gBuffer2 : SV_Target2;
        float4 gBuffer3 : SV_Target3;

        #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
            float4 gBuffer4 : SV_Target4;
        #endif
    #else
        float4 color : SV_TARGET;
    #endif
};

float4 ApplyFog(float4 color, Interpolators i)
{
    #if FOG_ON
        float viewDistance = length(_WorldSpaceCameraPos - i.worldPos.xyz);
        #if FOG_DEPTH
            viewDistance = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.worldPos.w);
        #endif
        UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
        float3 fogColor = 0;
        #if defined(FORWARD_BASE_PASS)
            fogColor = unity_FogColor.rgb;
        #endif
        color.rgb = lerp(fogColor, color.rgb, saturate(unityFogFactor));
    #endif
    return color;
}

float GetParallaxHeight(float2 uv)
{
    return tex2D(_ParallaxMap, uv).g;
}

float2 ParallaxOffset(float2 uv, float2 viewDir)
{
    float height = GetParallaxHeight(uv);
    height -= 0.5;
    height *= _ParallaxStrength;
    return viewDir * height;
}

float2 ParallaxRaymarching(float2 uv, float2 viewDir)
{
    #if !defined(PARALLAX_RAYMARCHING_STEPS)
        #define PARALLAX_RAYMARCHING_STEPS 10
    #endif
    float2 uvOffset = 0;
    float stepSize = 1.0 / PARALLAX_RAYMARCHING_STEPS;
    float2 uvDelta = viewDir * (stepSize * _ParallaxStrength);

    float stepHeight = 1;
    float surfaceHeight = GetParallaxHeight(uv);

    float2 prevUVOffset = uvOffset;
    float prevStepHeight = stepHeight;
    float prevSurfaceHeight = surfaceHeight;

    for (int i = 1; i < PARALLAX_RAYMARCHING_STEPS && stepHeight > surfaceHeight; i++)
    {
        prevUVOffset = uvOffset;
        prevStepHeight = stepHeight;
        prevSurfaceHeight = surfaceHeight;

        uvOffset -= uvDelta;
        stepHeight -= stepSize;
        surfaceHeight = GetParallaxHeight(uv + uvOffset);
    }

    #if !defined(PARALLAX_RAYMARCHING_SEARCH_STEPS)
        #define PARALLAX_RAYMARCHING_SEARCH_STEPS 0
    #endif
    #if PARALLAX_RAYMARCHING_SEARCH_STEPS > 0 
        for (int i = 0; i < PARALLAX_RAYMARCHING_SEARCH_STEPS; i++)
        {
            uvDelta *= 0.5;
            stepSize *= 0.5;

            if (stepHeight < surfaceHeight)
            {
                uvOffset += uvDelta;
                stepHeight += stepSize;
            }
            else
            {
                uvOffset -= uvDelta;
                stepHeight -= stepSize;
            }
            
            surfaceHeight = GetParallaxHeight(uv + uvOffset);
        }
    #elif defined(PARALLAX_RAYMARCHING_INTERPOLATE)
        float prevDifference = prevStepHeight - prevSurfaceHeight;
        float difference = surfaceHeight - stepHeight;
        float t = prevDifference / (prevDifference + difference);
        //uvOffset = lerp(prevUVOffset, uvOffset, t);
        //下面方法效率更高
        uvOffset = prevUVOffset - uvDelta * t;
    #endif

    return uvOffset;
}

void ApplyParallax(inout Interpolators i)
{
    #if defined(_PARALLAX_MAP) && !defined(NO_DEFAULT_UV)
        i.tangentViewDir = normalize(i.tangentViewDir);
        #if !defined(PARALLAX_OFFSET_LIMITING)
            #if !defined(PARALLAX_BIAS)
                #define PARALLAX_BIAS 0.42
            #endif
            i.tangentViewDir.xy /= (i.tangentViewDir.z + PARALLAX_BIAS);
        #endif
        
        #if !defined(PARALLAX_FUNCTION)
            #define PARALLAX_FUNCTION ParallaxOffset
        #endif
        float2 uvOffset = PARALLAX_FUNCTION(i.uv.xy, i.tangentViewDir.xy);
        i.uv.xy += uvOffset;
        i.uv.zw += uvOffset * (_DetailTex_ST.xy / _MainTex_ST.xy);
    #endif
}

FragmentOutput MyFragmentProgram(Interpolators i) 
{
    UNITY_SETUP_INSTANCE_ID(i);
    #if defined(LOD_FADE_CROSSFADE)
        UnityApplyDitherCrossFade(i.vpos);
    #endif

    ApplyParallax(i);

    InitializeFragmentNormal(i);

    SurfaceData surface;
    #if defined(SURFACE_FUNCTION)
        surface.normal = i.normal;
        surface.albedo = 1;
        surface.alpha = 1;
        surface.emission = 0;
        surface.metallic = 0;
        surface.occlusion = 1;
        surface.smoothness = 0.5;

        SurfaceParameters sp;
        sp.normal = i.normal;
        sp.position = i.worldPos.xyz;
        sp.uv = UV_FUNCTION(i);

        SURFACE_FUNCTION(surface, sp);
    #else
        surface.normal = i.normal;
        surface.albedo = ALBEDO_FUNCTION(i);
        surface.alpha = GetAlpha(i);
        surface.emission = GetEmission(i);
        surface.metallic = GetMetallic(i);
        surface.occlusion = GetOcclusion(i);
        surface.smoothness = GetSmoothness(i);
    #endif
    i.normal = surface.normal;

    float alpha = surface.alpha;
    #if defined(_RENDERING_CUTOUT)
        clip(alpha - _Cutoff);
    #endif

    //InitializeFragmentNormal(i);
    //float3 lightDir = _WorldSpaceLightPos0.xyz;
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);
    //float3 lightColor = _LightColor0.rgb;
    //float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;
    //albedo *= tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
    //albedo *= tex2D(_HeigthMap, i.uv);
               
    // albedo *= 1 - max(_SpecularTint.r, max(_SpecularTint.g, _SpecularTint.b));
    float3 specularTint;// = albedo * _Metallic;
    float oneMinusReflectivity;// = 1 - _Metallic;
    //albedo = EnergyConservationBetweenDiffuseAndSpecular(albedo, _SpecularTint.rgb, oneMinusReflectivity);
    //albedo *= oneMinusReflectivity;
    float3 albedo = DiffuseAndSpecularFromMetallic(surface.albedo, surface.metallic, specularTint, oneMinusReflectivity);
     #if defined(_RENDERING_TRANSPARENT)
        albedo *= alpha;
        alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
    #endif

    //float3 diffuse = albedo * lightColor * DotClamped(lightDir, i.normal);
    //float3 reflectionDir = reflect(-lightDir, i.normal);
    //float3 halfVector = normalize(lightDir + viewDir);
    //float3 specular = specularTint * lightColor * pow(DotClamped(halfVector, i.normal), _Smoothness * 100);
               
    //return float4(diffuse + specular, 1);

    //UnityLight light;
    //light.color = lightColor;
    //light.dir = lightDir;
    //light.ndotl = DotClamped(i.normal, lightDir);

    //UnityIndirect indirectLight;
    //indirectLight.diffuse = 0;
    //indirectLight.specular = 0;

    //float3 shColor = ShadeSH9(float4(i.normal, 1));
    //return float4(shColor, 1);

    float4 color = UNITY_BRDF_PBS(albedo, specularTint, oneMinusReflectivity, surface.smoothness, i.normal, viewDir, CreateLight(i), CreateIndirectLight(i, viewDir, surface));
    color.rgb += surface.emission;
    #if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
        color.a = alpha;
    #endif

    FragmentOutput output;
    #if defined(DEFERRED_PASS)
        #if !defined(UNITY_HDR_ON)
            color.rgb = exp2(-color.rgb);
        #endif

        output.gBuffer0.rgb = albedo;
        output.gBuffer0.a = surface.occlusion;
        output.gBuffer1.rgb = specularTint;
        output.gBuffer1.a = surface.smoothness;
        output.gBuffer2 = float4(i.normal * 0.5 + 0.5, 1);
        output.gBuffer3 = color;

        #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
            float2 shadowUV = 0;
            #if defined(LIGHTMAP_ON)
                shadowUV = i.lightmapUV;
            #endif
            output.gBuffer4 = UnityGetRawBakedOcclusions(shadowUV, i.worldPos.xyz);
        #endif
    #else
        output.color = ApplyFog(color, i);
    #endif

    return output;
}

#endif