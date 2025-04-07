#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

void MainLight_float(float3 WorldPos, out float3 Direction, out float3 Color, out float ShadowAtten)
{
#if SHADERGRAPH_PREVIEW
    Direction = float3(0.5, 0.5, 0);
    Color = 1;
    ShadowAtten = 1;
#else
#if SHADOWS_SCREEN
    float4 clipPos = TransformWorldToHClip(WorldPos);
    float4 shadowCoord = ComputeScreenPos(clipPos);
#else
    float4 shadowCoord = TransformWorldToShadowCoord(WorldPos);
#endif
    Light mainLight = GetMainLight(shadowCoord);
    Direction = normalize(mainLight.direction);
    Color = mainLight.color;
    ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
    float shadowStrength = GetMainLightShadowStrength();
    float accumulation = 0;
    for (int i = -4; i <= 4; i++){
        for (int j = -4; j <= 4; j++){
            accumulation += SampleShadowmap(shadowCoord + float4(i*.0001,j*.0001,0,0), TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowSamplingData, shadowStrength, false);
        }
    }
    ShadowAtten = clamp(smoothstep(accumulation/64 > .6 ? 1 : 0, 0, .1f), 0, 1);
#endif
}

void MainLight_half(float3 WorldPos, out half3 Direction, out half3 Color, out half ShadowAtten)
{
#if SHADERGRAPH_PREVIEW
    Direction = half3(0.5, 0.5, 0);
    Color = 1;
    ShadowAtten = 1;
#else
#if SHADOWS_SCREEN
    half4 clipPos = TransformWorldToHClip(WorldPos);
    half4 shadowCoord = ComputeScreenPos(clipPos);
#else
    half4 shadowCoord = TransformWorldToShadowCoord(WorldPos);
#endif
    Light mainLight = GetMainLight(shadowCoord);
    Direction = normalize(mainLight.direction);
    Color = mainLight.color;
    ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
    half shadowStrength = GetMainLightShadowStrength();
    half accumulation = 0;
    for (int i = -4; i <= 4; i++){
        for (int j = -4; j <= 4; j++){
            accumulation += SampleShadowmap(shadowCoord + float4(i*.0001,j*.0001,0,0), TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowSamplingData, shadowStrength, false);
        }
    }
    ShadowAtten = clamp(smoothstep(accumulation/64 > .6 ? 1 : 0, 0, .1f), 0, 1);
#endif
}

void AdditionalLights_float(float3 SpecColor, float Smoothness, float3 WorldPosition, float3 WorldNormal, float3 WorldView, out float3 Diffuse, out float3 Specular)
{
    Diffuse = 0;
    Specular = 0;
    float3 diffuseColor = 0;
    float3 specularColor = 0;

#ifndef SHADERGRAPH_PREVIEW
    Smoothness = exp2(10 * Smoothness + 1);
    WorldNormal = normalize(WorldNormal);
    WorldView = SafeNormalize(WorldView);
    int pixelLightCount = GetAdditionalLightsCount();
    float intensity = 0;
    for (int i = 0; i < pixelLightCount; ++i)
    {
        Light light = GetAdditionalLight(i, WorldPosition);
        float3 lC = light.color;
        intensity = sqrt(lC.x * lC.x + lC.y * lC.y + lC.z * lC.z);
        float3 attenuatedLightColor = lC * saturate(light.distanceAttenuation * light.distanceAttenuation) * light.shadowAttenuation;
        //diffuseColor += LightingLambert(attenuatedLightColor, light.direction, WorldNormal);
        diffuseColor += LightingLambert(attenuatedLightColor, light.direction, WorldNormal);
        specularColor += LightingSpecular(attenuatedLightColor, light.direction, WorldNormal, WorldView, float4(SpecColor, 0), Smoothness);
    }
    float amount = sqrt(diffuseColor.x * diffuseColor.x + diffuseColor.y * diffuseColor.y + diffuseColor.z * diffuseColor.z);

    Diffuse = amount > intensity/2 ? diffuseColor : 0;
    Specular = specularColor;
#endif
}

void AdditionalLights_half(half3 SpecColor, half Smoothness, half3 WorldPosition, half3 WorldNormal, half3 WorldView, out half3 Diffuse, out half3 Specular)
{
    half3 diffuseColor = 0;
    half3 specularColor = 0;

#ifndef SHADERGRAPH_PREVIEW
    Smoothness = exp2(10 * Smoothness + 1);
    WorldNormal = normalize(WorldNormal);
    WorldView = SafeNormalize(WorldView);
    int pixelLightCount = GetAdditionalLightsCount();
    for (int i = 0; i < pixelLightCount; ++i)
    {
        Light light = GetAdditionalLight(i, WorldPosition);
        half3 attenuatedLightColor = light.color * saturate(light.distanceAttenuation * light.distanceAttenuation) * light.shadowAttenuation;
        diffuseColor += LightingLambert(attenuatedLightColor, light.direction, WorldNormal);
        specularColor += LightingSpecular(attenuatedLightColor, light.direction, WorldNormal, WorldView, half4(SpecColor, 0), Smoothness);
    }
    float amount = sqrt(diffuseColor.x * diffuseColor.x + diffuseColor.y * diffuseColor.y + diffuseColor.z * diffuseColor.z);


    Diffuse = amount > amount/1.5 ? diffuseColor : 0; 
    Specular = 0;
#endif
}



#endif




void SequentialTonemapping_half(half3 color, half acesStrength, half saturation, out half3 result) {

    const half a = 3 * acesStrength;
    const half b = 0.03;
    const half c = 2.43;
    const half d = 0.59;
    const half e = 0.14;

    half3 acesMapped = saturate((color * (a * color + b)) / (color * (c * color + d) + e));

    half3 gammaCorrected = acesMapped;

    half lum = gammaCorrected.r * 0.3 + gammaCorrected.g * 0.59 + gammaCorrected.b * 0.11;
    half3 bw = half3(lum, lum, lum);

    result = lerp(gammaCorrected, bw, 1.0 - saturation);
}

void SequentialTonemapping_float(float3 color, float acesStrength, float saturation, out float3 result) {

    const half a = 3 * acesStrength;
    const half b = 0.03;
    const half c = 2.43;
    const half d = 0.59;
    const half e = 0.14;

    half3 acesMapped = saturate((color * (a * color + b)) / (color * (c * color + d) + e));

    half3 gammaCorrected = acesMapped;

    float lum = gammaCorrected.r * 0.3 + gammaCorrected.g * 0.59 + gammaCorrected.b * 0.11;
    float3 bw = float3(lum, lum, lum);

    result = lerp(gammaCorrected, bw, 1.0 - saturation);
}
