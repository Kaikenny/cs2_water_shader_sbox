HEADER
{
    Description = "CS2-Style Water Shader"; // hope you enjoy this mess of a shader, alot is very useless and don't work like the color stuff cus i was to lazy to set up everytin properly
}

FEATURES
{
	#include "common/features.hlsl"
	Feature( F_CAUSTICS, 0..1, "Caustics" );
	Feature( F_FLOW_NORMALS, 0..1, "Flow Normals" );
	Feature( F_FLOW_COLOR, 0..1, "Flow Color" );
	Feature( F_ANIMATED_NORMALS, 0..1, "Animated Normals" );
	Feature( F_DISABLE_REFRACTION, 0..1, "Disable Refraction" );
	Feature( F_FRESNEL, 0..1, "Fresnel Effect" );
	Feature( F_FOAM, 0..1, "Edge Foam" );
	Feature( F_VERTEX_DISPLACEMENT, 0..1, "Vertex Displacement" );
	Feature( F_CS2_FOG, 0..1, "CS2 Fog System" );
}

MODES
{
	Forward();
	Depth();
	ToolsShadingComplexity( "tools_shading_complexity.shader" );
}

COMMON
{
	#ifndef S_ALPHA_TEST
	#define S_ALPHA_TEST 0
	#endif
	#ifndef S_TRANSLUCENT
	#define S_TRANSLUCENT 1
	#endif
	
	#define S_SPECULAR 1
	#include "common/shared.hlsl"
	#include "procedural.hlsl"
}

struct VertexInput
{
	#include "common/vertexinput.hlsl"
};

struct PixelInput
{
	#include "common/pixelinput.hlsl" // i hope sam actually makes the hl:a bottle shader that would be great 
};

VS
{
	#include "common/vertex.hlsl"
	
	float g_flWaveAmplitude < UiGroup( "Waves,0/,0/0" ); Default1( 2.0 ); Range1( 0, 10 ); >;
	float g_flWaveFrequency < UiGroup( "Waves,0/,0/0" ); Default1( 0.5 ); Range1( 0.01, 5 ); >;
	float g_flWaveSpeed < UiGroup( "Waves,0/,0/0" ); Default1( 1.0 ); Range1( 0, 5 ); >;
	float g_flWaveSteepness < UiGroup( "Waves,0/,0/0" ); Default1( 0.2 ); Range1( 0, 2 ); >;
	
	PixelInput MainVs( VertexInput v )
	{
		PixelInput i = ProcessVertex( v );
		
		#if F_VERTEX_DISPLACEMENT
		{
			float3 worldPos = i.vPositionWs.xyz;
			float2 worldUV = worldPos.xy;
			float time = g_flTime * g_flWaveSpeed;
			
			float heightZ = 0.0;
			float2 horizontalOffset = float2(0, 0);
			
			{
				float2 direction = float2(0.857, 0.515);
				float frequency = g_flWaveFrequency * 0.3;
				float amplitude = g_flWaveAmplitude;
				float phase = dot(direction, worldUV) * frequency + time * 1.2;
				
				heightZ += amplitude * sin(phase);
				horizontalOffset += g_flWaveSteepness * amplitude * direction * cos(phase);
			}
			
			{
				float2 direction = float2(-0.514, 0.858);
				float frequency = g_flWaveFrequency * 0.6;
				float amplitude = g_flWaveAmplitude * 0.6;
				float phase = dot(direction, worldUV) * frequency - time * 1.5;
				
				heightZ += amplitude * sin(phase);
				horizontalOffset += g_flWaveSteepness * amplitude * direction * cos(phase);
			}
			
			i.vPositionWs.xy += horizontalOffset;
			i.vPositionWs.z += heightZ;
			
			i.vPositionPs.xyzw = Position3WsToPs( i.vPositionWs.xyz );
		}
		#endif
		
		return FinalizeVertex( i );
	}
}

PS
{
	StaticCombo( S_CAUSTICS, F_CAUSTICS, Sys( ALL ) );
	StaticCombo( S_FLOW_NORMALS, F_FLOW_NORMALS, Sys( ALL ) );
	StaticCombo( S_FLOW_COLOR, F_FLOW_COLOR, Sys( ALL ) );
	StaticCombo( S_ANIMATED_NORMALS, F_ANIMATED_NORMALS, Sys( ALL ) );
	StaticCombo( S_DISABLE_REFRACTION, F_DISABLE_REFRACTION, Sys( ALL ) );
	StaticCombo( S_FRESNEL, F_FRESNEL, Sys( ALL ) );
	StaticCombo( S_FOAM, F_FOAM, Sys( ALL ) );
	StaticCombo( S_CS2_FOG, F_CS2_FOG, Sys( ALL ) );
	
	#include "common/pixel.hlsl"
	#include "sbox_pixel.fxc"
	
	SamplerState g_sSampler < Filter( ANISOTROPIC ); AddressU( WRAP ); AddressV( WRAP ); MaxAniso( 8 ); >;
	SamplerState g_sClampSampler < Filter( LINEAR ); AddressU( CLAMP ); AddressV( CLAMP ); >;
	
	CreateInputTexture2D( NormalMapA, Linear, 8, "NormalizeNormals", "_normal", "Normals,0/,0/0", Default4( 0.5, 0.5, 1.0, 1.0 ) );
	CreateInputTexture2D( NormalMapB, Linear, 8, "NormalizeNormals", "_normal", "Normals,0/,0/0", Default4( 0.5, 0.5, 1.0, 1.0 ) );
	CreateInputTexture2D( FoamTexture, Srgb, 8, "None", "_mask", "Foam,0/,0/0", Default4( 1.0, 1.0, 1.0, 1.0 ) );
	CreateInputTexture2D( CausticsTexture, Linear, 8, "None", "_caustics", "Caustics,0/,0/0", Default4( 1.0, 1.0, 1.0, 1.0 ) );
	CreateInputTexture2D( FlowMap, Linear, 8, "None", "_flow", "Flow,0/,0/0", Default4( 0.5, 0.5, 0.0, 0.0 ) );
	CreateInputTexture2D( NoiseTexture, Linear, 8, "None", "_noise", "Flow,0/,0/0", Default4( 0.5, 0.5, 0.5, 0.0 ) );
	CreateInputTexture2D( ColorTexture, Srgb, 8, "None", "_color", "Color,0/,0/0", Default4( 1.0, 1.0, 1.0, 1.0 ) ); // ignore this is broken and does ABSOLUTELY nothing 
	
	Texture2D g_tNormalMapA < Channel( RGBA, Box( NormalMapA ), Linear ); OutputFormat( BC7 ); SrgbRead( False ); >;
	Texture2D g_tNormalMapB < Channel( RGBA, Box( NormalMapB ), Linear ); OutputFormat( BC7 ); SrgbRead( False ); >;
	Texture2D g_tFoamTexture < Channel( RGBA, Box( FoamTexture ), Srgb ); OutputFormat( BC7 ); SrgbRead( True ); >;
	Texture2D g_tCausticsTexture < Channel( RGBA, Box( CausticsTexture ), Linear ); OutputFormat( BC7 ); SrgbRead( False ); >;
	Texture2D g_tFlowMap < Channel( RGBA, Box( FlowMap ), Linear ); OutputFormat( BC7 ); SrgbRead( False ); >;
    Texture2D g_tNoiseTexture < Channel(RGBA, Box(NoiseTexture), Linear); OutputFormat(BC7); SrgbRead(False); > ;
    Texture2D g_tColorTexture < Channel(RGBA, Box(ColorTexture), Srgb); OutputFormat(BC7); SrgbRead(True); > ; // // claude told me to add ts or else ima bad boy bru
	
	BoolAttribute( bWantsFBCopyTexture, true );
	CreateTexture2D( g_tFrameBufferCopyTexture ) < Attribute("FrameBufferCopyTexture"); SrgbRead( true ); Filter(MIN_MAG_MIP_LINEAR); AddressU( CLAMP ); AddressV( CLAMP ); >;
	
	float3 g_vColorTint < UiType( Color ); UiGroup( "Color,0/,0/0" ); Default3( 1, 1, 1 ); >;
	float g_flModelTintAmount < UiGroup( "Color,0/,0/0" ); Default1( 1.0 ); Range1( 0, 1 ); >;
	float g_flColorScale < UiGroup( "Color,0/,0/0" ); Default1( 100.0 ); Range1( 10, 500 ); >;
	float g_flColorSpeed < UiGroup( "Color,0/,0/0" ); Default1( 0.2 ); Range1( 0, 2 ); >;
	float g_flNormalScale < UiGroup( "Surface,0/,0/0" ); Default1( 200.0 ); Range1( 10, 1000 ); >;
	float g_flNormalSpeed < UiGroup( "Surface,0/,0/0" ); Default1( 0.3 ); Range1( 0, 2 ); >;
	float g_flNormalStrength < UiGroup( "Surface,0/,0/0" ); Default1( 1.0 ); Range1( 0, 3 ); >;
	float g_flGlossiness < UiGroup( "Surface,0/,0/0" ); Default1( 0.98 ); Range1( 0, 1 ); >;
	float g_flMetalness < UiGroup( "Surface,0/,0/0" ); Default1( 0.85 ); Range1( 0, 1 ); >;
	
	float g_flNormalMapAnimationTimePerFrame < UiGroup( "Surface,0/,0/0" ); Default1( 0.1 ); Range1( 0, 10 ); >;
	float g_flNormalMapAnimationTimeOffset < UiGroup( "Surface,0/,0/0" ); Default1( 0.0 ); Range1( 0, 1000 ); >;
	
	float g_flFlowSpeed < UiGroup( "Flow,0/,0/0" ); Default1( 1.0 ); Range1( 0, 10 ); >;
	float g_flFlowStrength < UiGroup( "Flow,0/,0/0" ); Default1( 0.25 ); Range1( 0, 1 ); >;
	float g_flFlowCycle < UiGroup( "Flow,0/,0/0" ); Default1( 0.4 ); Range1( 0.1, 3 ); >;
	float g_flFlowMapScale < UiGroup( "Flow,0/,0/0" ); Default1( 500.0 ); Range1( 10, 2000 ); >;
	float g_flFlowLerpExp < UiGroup( "Flow,0/,0/0" ); Default1( 1.0 ); Range1( 0, 2 ); >;
	float g_flNoiseStrength < UiGroup( "Flow,0/,0/0" ); Default1( 0.1 ); Range1( 0, 2 ); >;
	float g_flNoiseScale < UiGroup( "Flow,0/,0/0" ); Default1( 200.0 ); Range1( 10, 1000 ); >;
	
	float g_flWorldUvScale < UiGroup( "Flow,0/,0/0" ); Default1( 0.1 ); Range1( 0.01, 10 ); >;
	float g_flNormalUvScale < UiGroup( "Flow,0/,0/0" ); Default1( 1.0 ); Range1( 0.01, 10 ); >;
	
	float g_flFoamDepth < UiGroup( "Foam,0/,0/0" ); Default1( 20.0 ); Range1( 1, 200 ); >;
	float g_flFoamSharpness < UiGroup( "Foam,0/,0/0" ); Default1( 3.0 ); Range1( 0.1, 10 ); >;
	float g_flFoamScale < UiGroup( "Foam,0/,0/0" ); Default1( 50.0 ); Range1( 10, 300 ); >;
	float g_flFoamSpeed < UiGroup( "Foam,0/,0/0" ); Default1( 0.5 ); Range1( 0, 2 ); >;
	float4 g_vFoamColor < UiType( Color ); UiGroup( "Foam,0/,0/0" ); Default4( 0.95, 0.95, 0.95, 1.0 ); >;
	float g_flFoamContrast < UiGroup( "Foam,0/,0/0" ); Default1( 1.5 ); Range1( 0.1, 5 ); >;
	
	float g_flCS2FogDensity < UiGroup( "CS2 Fog,0/,0/0" ); Default1( 0.5 ); Range1( 0, 2 ); >;
	float g_flCS2FogHeight < UiGroup( "CS2 Fog,0/,0/0" ); Default1( 100.0 ); Range1( 0, 500 ); >;
	float g_flCS2FogPower < UiGroup( "CS2 Fog,0/,0/0" ); Default1( 2.0 ); Range1( 0.1, 10 ); >;
	float4 g_vCS2FogColor < UiType( Color ); UiGroup( "CS2 Fog,0/,0/0" ); Default4( 0.2, 0.4, 0.6, 1.0 ); >;
	
	float g_flWaterDepth < UiGroup( "Water Fog,0/,0/0" ); Default1( 200.0 ); Range1( 10, 1000 ); >;
	float g_flWaterStart < UiGroup( "Water Fog,0/,0/0" ); Default1( 0.0 ); Range1( 0, 100 ); >;
	float4 g_vRefractionTint < UiType( Color ); UiGroup( "Water Fog,0/,0/0" ); Default4( 0.4, 0.7, 0.8, 1.0 ); >;
	float4 g_vWaterFogColor < UiType( Color ); UiGroup( "Water Fog,0/,0/0" ); Default4( 0.0, 0.3, 0.5, 1.0 ); >;
	
	float g_flRefractionAmount < UiGroup( "Refraction,0/,0/0" ); Default1( 0.1 ); Range1( 0, 1 ); >;
	float g_flRefractionClipPlaneAdjust < UiGroup( "Refraction,0/,0/0" ); Default1( 0.0 ); Range1( -100, 100 ); >;
	
	float g_flReflectance < UiGroup( "Reflection,0/,0/0" ); Default1( 0.3 ); Range1( 0, 1 ); >;
	
	float3 g_vReflectionDir < UiGroup( "Specular,0/,0/0" ); Default3( 0.707, 0.707, 0.0 ); Range3( -1, -1, -1, 1, 1, 1 ); >;
	float g_flReflectionPower < UiGroup( "Specular,0/,0/0" ); Default1( 50.0 ); Range1( 1, 200 ); >;
	float3 g_vReflectionColor < UiType( Color ); UiGroup( "Specular,0/,0/0" ); Default3( 1, 1, 1 ); >;
	
	float g_flCausticsScale < UiGroup( "Caustics,0/,0/0" ); Default1( 100.0 ); Range1( 10, 500 ); >;
	float g_flCausticsStrength < UiGroup( "Caustics,0/,0/0" ); Default1( 1.0 ); Range1( 0, 4 ); >;
	float g_flCausticsSpeed < UiGroup( "Caustics,0/,0/0" ); Default1( 0.5 ); Range1( 0, 2 ); >;
	
	int GetSunLightIndex()
	{
		for ( uint nLightIdx = 0; nLightIdx < NumDynamicLights; nLightIdx++ )
		{
			BinnedLight light = BinnedLightBuffer[ nLightIdx ];
			if ( length( light.GetPosition() ) < 10000.0f ) 
				continue;
			return nLightIdx;
		}
		return 0;
	}
	
	float SampleLightDirect( int nSunLightIdx, float3 vPosWs )
	{
		if (NumDynamicLights == 0) return 1.0;
		
		float lightContribution = 1.0;
		BinnedLight sun = BinnedLightBuffer[ nSunLightIdx ];
		
		for ( uint nFrustaIdx = 0; nFrustaIdx < sun.NumShadowFrusta(); nFrustaIdx++ )
		{
			lightContribution *= ComputeShadow( vPosWs, sun.WorldToShadow[ nFrustaIdx ], sun.ShadowBounds[ nFrustaIdx ] );
		}
		
		return lightContribution;
	}
	
	RenderState( CullMode, F_RENDER_BACKFACES ? NONE : DEFAULT );
	
	float4 MainPs( PixelInput i ) : SV_Target0
	{
		float3 worldPos = i.vPositionWithOffsetWs.xyz + g_vHighPrecisionLightingOffsetWs.xyz;
		float time = g_flTime * g_flNormalSpeed;
		
		#if S_ANIMATED_NORMALS
			float animTime = (g_flTime + g_flNormalMapAnimationTimeOffset) / g_flNormalMapAnimationTimePerFrame;
			float frame = floor(animTime);
		#endif
		
		float2 flowVector = float2(0, 0);
		float noiseValue = 0.5;
		
		#if S_FLOW_NORMALS
		{
			float2 worldUV = worldPos.xy * g_flWorldUvScale;
			flowVector = g_tFlowMap.Sample(g_sSampler, worldUV).rg * 2.0 - 1.0;
			flowVector *= g_flFlowStrength;
			
			noiseValue = g_tNoiseTexture.Sample(g_sSampler, worldPos.xy / g_flNoiseScale).r;
			flowVector *= (1.0 + noiseValue * g_flNoiseStrength);
		}
		#endif
		
		float flowTime = g_flTime * g_flFlowSpeed;
		float phase0 = frac(flowTime / g_flFlowCycle);
		float phase1 = frac(flowTime / g_flFlowCycle + 0.5);
		
		float flowLerp = abs((phase0 - 0.5) * 2.0);
		flowLerp = pow(flowLerp, g_flFlowLerpExp);
		
		float2 baseUV1 = worldPos.xy / g_flNormalScale * g_flNormalUvScale;
		float2 baseUV2 = worldPos.xy / g_flNormalScale * g_flNormalUvScale;
		float2 baseUV3 = worldPos.xy / (g_flNormalScale * 0.7) * g_flNormalUvScale;
		
		float3 blendedNormal;
		
		#if S_FLOW_NORMALS
		{
			float2 uv1a = baseUV1 + float2(time * 0.5, time * 0.3) + flowVector * phase0;
			float2 uv1b = baseUV1 + float2(time * 0.5, time * 0.3) + flowVector * phase1;
			float3 normal1a = g_tNormalMapA.Sample(g_sSampler, uv1a).xyz * 2.0 - 1.0;
			float3 normal1b = g_tNormalMapA.Sample(g_sSampler, uv1b).xyz * 2.0 - 1.0;
			float3 normal1 = lerp(normal1a, normal1b, flowLerp);
			
			float2 uv2a = baseUV2 + float2(-time * 0.4, time * 0.6) + flowVector * phase0;
			float2 uv2b = baseUV2 + float2(-time * 0.4, time * 0.6) + flowVector * phase1;
			float3 normal2a = g_tNormalMapB.Sample(g_sSampler, uv2a).xyz * 2.0 - 1.0;
			float3 normal2b = g_tNormalMapB.Sample(g_sSampler, uv2b).xyz * 2.0 - 1.0;
			float3 normal2 = lerp(normal2a, normal2b, flowLerp);
			
			float2 uv3a = baseUV3 + float2(time * 0.3, -time * 0.5) + flowVector * phase0;
			float2 uv3b = baseUV3 + float2(time * 0.3, -time * 0.5) + flowVector * phase1;
			float3 normal3a = g_tNormalMapA.Sample(g_sSampler, uv3a).xyz * 2.0 - 1.0;
			float3 normal3b = g_tNormalMapA.Sample(g_sSampler, uv3b).xyz * 2.0 - 1.0;
			float3 normal3 = lerp(normal3a, normal3b, flowLerp);
			
			blendedNormal = normalize((normal1 + normal2 + normal3) * 0.33);
		}
		#else
		{
			float2 uv1 = baseUV1 + float2(time * 0.5, time * 0.3);
			float2 uv2 = baseUV2 + float2(-time * 0.4, time * 0.6);
			float2 uv3 = baseUV3 + float2(time * 0.3, -time * 0.5);
			
			float3 normal1 = g_tNormalMapA.Sample(g_sSampler, uv1).xyz * 2.0 - 1.0;
			float3 normal2 = g_tNormalMapB.Sample(g_sSampler, uv2).xyz * 2.0 - 1.0;
			float3 normal3 = g_tNormalMapA.Sample(g_sSampler, uv3).xyz * 2.0 - 1.0;
			
			blendedNormal = normalize((normal1 + normal2 + normal3) * 0.33);
		}
		#endif
		
		blendedNormal.xy *= g_flNormalStrength;
		blendedNormal = normalize(blendedNormal);
		
		float3 worldNormal = TransformNormal(blendedNormal, i.vNormalWs, i.vTangentUWs, i.vTangentVWs);
		
		#if F_RENDER_BACKFACES
			if (!i.bIsFrontFace)
				worldNormal = -worldNormal;
		#endif
		
		float2 screenUv = i.vPositionSs.xy * g_vInvViewportSize;
		float sceneDepth = Depth::GetLinear( i.vPositionSs.xy );
		float waterDepth = i.vPositionSs.w;
		
		float3 viewDir = normalize(worldPos - g_vCameraPositionWs);
		
		float3 sceneWorldPos = Depth::GetWorldPosition( i.vPositionSs.xy );
		
		float3 viewVector = normalize(sceneWorldPos - g_vCameraPositionWs);
		float viewDist = 1.0 / max(0.001, dot(float3(0, 0, 1), viewVector));
		float adjustedWaterZ = worldPos.z - g_flRefractionClipPlaneAdjust;
		float actualDepth = (sceneDepth - waterDepth) * g_flViewportMaxZ * viewDist;
		
		float depthRange = 1.0 / max(0.001, g_flWaterDepth - g_flWaterStart);
		float depthFactor = saturate(((adjustedWaterZ - g_flWaterStart) - sceneWorldPos.z) * depthRange);
		
		float2 refractionUv = screenUv;
		
		#if !S_DISABLE_REFRACTION
		{
			refractionUv = screenUv - (worldNormal.xy * g_flRefractionAmount * depthFactor);
			
			float refractionDepth = Depth::Get( refractionUv * g_vViewportSize.xy );
			bool depthTest = refractionDepth < i.vPositionSs.z;
			refractionUv = depthTest ? screenUv : refractionUv;
			refractionUv = clamp(refractionUv, 0.0, 1.0);
		}
		#endif
		
		float3 refractedColor = g_tFrameBufferCopyTexture.Sample(g_sClampSampler, refractionUv).rgb;
		
		#if S_FLOW_COLOR
		{
			float2 colorUV1 = worldPos.xy / g_flColorScale + flowVector * phase0;
			float2 colorUV2 = worldPos.xy / g_flColorScale + flowVector * phase1;
			
			float3 color1 = g_tColorTexture.Sample(g_sSampler, colorUV1).rgb;
			float3 color2 = g_tColorTexture.Sample(g_sSampler, colorUV2).rgb;
			float3 baseColor = lerp(color1, color2, flowLerp);
			
			baseColor = lerp(float3(1, 1, 1), baseColor * g_vColorTint, g_flModelTintAmount);
			refractedColor *= baseColor;
		}
		#else
		{
			float2 colorUV = worldPos.xy / g_flColorScale + float2(time * g_flColorSpeed * 0.3, -time * g_flColorSpeed * 0.2);
			float3 baseColor = g_tColorTexture.Sample(g_sSampler, colorUV).rgb;
			baseColor = lerp(float3(1, 1, 1), baseColor * g_vColorTint, g_flModelTintAmount);
			refractedColor *= baseColor;
		}
		#endif
		
		float tintFactor = saturate(3.5 * depthFactor);
		float3 tintedRefraction = lerp(refractedColor, refractedColor * g_vRefractionTint.rgb, tintFactor);
		float3 waterColor = lerp(tintedRefraction, g_vWaterFogColor.rgb, depthFactor);
		
		#if S_CAUSTICS
		if (NumDynamicLights > 0 && sceneWorldPos.z < worldPos.z)
		{
			int sunIdx = GetSunLightIndex();
			float sunLight = SampleLightDirect(sunIdx, sceneWorldPos);
			
			float2 causticsUV = sceneWorldPos.xy / g_flCausticsScale + time * g_flCausticsSpeed * 0.5;
			float caustics = g_tCausticsTexture.Sample( g_sSampler, causticsUV ).r;
			
			waterColor += caustics * sunLight * g_flCausticsStrength * saturate(2.0 * depthFactor);
		}
		#endif
		
		float3 reflectDir = reflect(viewDir, worldNormal);
		float3 envReflection = EnvMap::From( worldPos, i.vPositionSs.xy, worldNormal, 0 );
		
		float2 reflectionUv = screenUv + worldNormal.xy * 0.03;
		reflectionUv = clamp(reflectionUv, 0.0, 1.0);
		float3 screenReflection = g_tFrameBufferCopyTexture.Sample(g_sClampSampler, reflectionUv).rgb;
		
		float3 finalReflection = lerp(envReflection, screenReflection, 0.5);
		
		float IOR = 1.333;
		float F0 = pow((1.0 - IOR) / (1.0 + IOR), 2.0);
		float cosTheta = saturate(dot(-viewDir, worldNormal));
		float fresnel = F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
		
		#if !S_FRESNEL
			fresnel = 1.0;
		#endif
		
		float reflectionStrength = g_flReflectance * saturate((depthFactor - 0.05) * 20.0);
		
		#if S_FRESNEL
			reflectionStrength *= fresnel;
		#endif
		
		waterColor = waterColor + (finalReflection * saturate(2.0 * depthFactor)) * reflectionStrength;
		
		#if S_FRESNEL
		{
			float3 reflectViewDir = reflect(-viewDir, worldNormal);
			float3 normalizedReflDir = normalize(g_vReflectionDir);
			float specular = pow(saturate(dot(normalizedReflDir, reflectViewDir)), g_flReflectionPower);
			waterColor += g_vReflectionColor * specular * fresnel;
		}
		#endif
		
		float foam = 0.0;
		
		#if S_FOAM
		{
			float depthDiff = abs(sceneDepth - waterDepth);
			float foamMask = saturate(1.0 - (depthDiff / g_flFoamDepth));
			foamMask = pow(foamMask, g_flFoamSharpness);
			
			float2 foamUV = worldPos.xy / g_flFoamScale + float2(time * g_flFoamSpeed, time * g_flFoamSpeed * 0.7);
			float foamTex = g_tFoamTexture.Sample( g_sSampler, foamUV ).r;
			
			foamTex = saturate((foamTex - 0.5) * g_flFoamContrast + 0.5);
			
			foam = foamMask * foamTex;
		}
		#else
		{
			foam = 0.0;
		}
		#endif
		
		#if S_FOAM
		{
			waterColor = lerp(waterColor, g_vFoamColor.rgb, foam);
		}
		#endif
		
		#if S_CS2_FOG
		{
			float3 fogViewVector = worldPos - g_vCameraPositionWs;
			float viewDist = length(fogViewVector);
			
			float fogFactor = saturate(viewDist / g_flCS2FogHeight);
			fogFactor = pow(fogFactor, g_flCS2FogPower);
			fogFactor *= g_flCS2FogDensity;
			
			waterColor = lerp(waterColor, g_vCS2FogColor.rgb, saturate(fogFactor));
		}
		#endif
		
		Material m = Material::Init();
		m.Albedo = waterColor;
		m.Normal = worldNormal;
		
		#if S_FOAM
		{
			m.Roughness = lerp(max(0.01, 1.0 - g_flGlossiness), 0.8, foam);
			m.Metalness = lerp(g_flMetalness, 0.0, foam);
		}
		#else
		{
			m.Roughness = max(0.01, 1.0 - g_flGlossiness);
			m.Metalness = g_flMetalness;
		}
		#endif
		
		m.AmbientOcclusion = 1;	// why u readin this part 
		m.Opacity = 1;
		m.Emission = float3(0, 0, 0);
		m.WorldTangentU = i.vTangentUWs;
		m.WorldTangentV = i.vTangentVWs;
		m.TextureCoords = i.vTextureCoords.xy;
		
		if(DepthNormals::WantsDepthNormals())
			return DepthNormals::Output(m.Normal, m.Roughness, 1);
		
		float4 outCol = ShadingModelStandard::Shade(i, m);
		outCol.rgb = Fog::Apply(worldPos, i.vPositionSs.xy, outCol.rgb);
		
		return outCol;
	}
}