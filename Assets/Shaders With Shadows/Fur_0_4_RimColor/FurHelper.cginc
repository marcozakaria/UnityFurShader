﻿#pragma target 3.0
#pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
#pragma multi_compile_fwdadd_fullshadows
#pragma multi_compile_shadowcaster

#include "Lighting.cginc"
#include "UnityCG.cginc"
#include "AutoLight.cginc"

struct v2f
{
      float4 pos: SV_POSITION;
    half4 uv: TEXCOORD0;
    SHADOW_COORDS(1)
    float3 worldNormal: TEXCOORD2;
    float3 worldPos: TEXCOORD3;
    float4 screenPos : TEXCOORD4;
};

fixed4 _Color;
fixed4 _Specular;
half _Shininess;

sampler2D _MainTex;
half4 _MainTex_ST;
sampler2D _FurTex;
half4 _FurTex_ST;

fixed _FurLength;
fixed _FurDensity;
fixed _FurThinness;
fixed _FurShading;

float4 _ForceGlobal;
float4 _ForceLocal;

fixed4 _RimColor;
half _RimPower;

v2f vert_surface(appdata_base v)
{
    v2f o;
    o.pos = UnityObjectToClipPos(v.vertex);
    o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.worldNormal = UnityObjectToWorldNormal(v.normal);
    o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
    TRANSFER_SHADOW(o);

    return o;
}

v2f vert_base(appdata_base v)
{
    v2f o;
    float3 P = v.vertex.xyz + v.normal * _FurLength * FURSTEP;
    P += clamp(mul(unity_WorldToObject, _ForceGlobal).xyz + _ForceLocal.xyz, -1, 1) * pow(FURSTEP, 3) * _FurLength;
    o.pos = UnityObjectToClipPos(float4(P, 1.0));
    o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.uv.zw = TRANSFORM_TEX(v.texcoord, _FurTex);
    o.worldNormal = UnityObjectToWorldNormal(v.normal);
    o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
    TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);

    return o;
}

fixed4 frag_surface(v2f i): SV_Target
{
    
    fixed3 worldNormal = normalize(i.worldNormal);
    fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
    fixed3 worldView = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
    fixed3 worldHalf = normalize(worldView + worldLight);
    
    fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color;
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
    fixed3 diffuse = _LightColor0.rgb * albedo * saturate(dot(worldNormal, worldLight));
    fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(worldNormal, worldHalf)), _Shininess);

    fixed3 color = ambient + diffuse + specular;
    fixed shadow = SHADOW_ATTENUATION(i);
    
    return fixed4(color * shadow, 1.0);
}

fixed4 frag_base(v2f i): SV_Target
{
    fixed3 worldNormal = normalize(i.worldNormal);
    fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
    fixed3 worldView = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
    fixed3 worldHalf = normalize(worldView + worldLight);

    fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color;
    albedo -= (pow(1 - FURSTEP, 3)) * _FurShading;
    half rim = 1.0 - saturate(dot(worldView, worldNormal));
    albedo += fixed4(_RimColor.rgb * pow(rim, _RimPower), 1.0);

    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
    fixed3 diffuse = _LightColor0.rgb * albedo * saturate(dot(worldNormal, worldLight));
    fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(worldNormal, worldHalf)), _Shininess);

    fixed3 color = ambient + diffuse + specular;
    fixed3 noise = tex2D(_FurTex, i.uv.zw * _FurThinness).rgb;
    fixed alpha = clamp(noise - (FURSTEP * FURSTEP) * _FurDensity, 0, 1);
    fixed shadow = SHADOW_ATTENUATION(i);
    
    return fixed4(color * shadow, alpha);
}