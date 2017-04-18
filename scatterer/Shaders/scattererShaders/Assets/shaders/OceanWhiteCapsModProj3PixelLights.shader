﻿
/*
 * Proland: a procedural landscape rendering library.
 * Copyright (c) 2008-2011 INRIA
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * Proland is distributed under a dual-license scheme.
 * You can obtain a specific license from Inria: proland-licensing@inria.fr.
 */

/*
 * Authors: Eric Bruneton, Antoine Begault, Guillaume Piolat.
 */

/**
 * Real-time Realistic Ocean Lighting using Seamless Transitions from Geometry to BRDF
 * Copyright (c) 2009 INRIA
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holders nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * Author: Eric Bruneton
 * Modified and ported to Unity by Justin Hawkins 2014
 */

Shader "Scatterer/OceanWhiteCapsPixelLights" 
{
	SubShader 
	{
		Tags { "Queue" = "Geometry+100" "RenderType"="" }
		
	
    	Pass   
    	{
			Tags { "LightMode" = "ForwardBase"}
    	
    		Blend SrcAlpha OneMinusSrcAlpha
    	
			CGPROGRAM
			#include "UnityCG.cginc"
			#pragma glsl
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag
//			#pragma multi_compile_fwdbase
			
			#pragma multi_compile SKY_REFLECTIONS_OFF SKY_REFLECTIONS_ON
			#pragma multi_compile PLANETSHINE_OFF PLANETSHINE_ON
			
//			#include "Utility.cginc"
//			#include "AtmosphereNew.cginc"
			#include "AtmosphereScatterer.cginc"
			#include "OceanBRDF.cginc"
			#include "OceanDisplacement3.cginc"
			
//			#include "Lighting.cginc"
//			#include "AutoLight.cginc"
//			#include "OceanLight.cginc"
			
			
			uniform float4x4 _Globals_ScreenToCamera;
			uniform float4x4 _Globals_CameraToWorld;
			uniform float4x4 _Globals_WorldToScreen;
			uniform float4x4 _Globals_CameraToScreen;
			uniform float3 _Globals_WorldCameraPos;
			
			uniform float4x4 _Globals_WorldToOcean;
			uniform float4x4 _Globals_OceanToWorld;
			
			uniform float3 _Scatterer_Origin;
			uniform float3 _Sun_WorldSunDir;
			
			uniform float2 _Ocean_MapSize;
			uniform float4 _Ocean_Choppyness;
			uniform float3 _Ocean_SunDir;
			uniform float3 _Ocean_Color;
			uniform float4 _Ocean_GridSizes;
			uniform float2 _Ocean_ScreenGridSize;
			uniform float _Ocean_WhiteCapStr;
			uniform float farWhiteCapStr;
			
			uniform sampler3D _Ocean_Variance;
			uniform sampler2D _Ocean_Map0;
			uniform sampler2D _Ocean_Map1;
			uniform sampler2D _Ocean_Map2;
			uniform sampler2D _Ocean_Map3;
			uniform sampler2D _Ocean_Map4;
			uniform sampler2D _Ocean_Foam0;
			uniform sampler2D _Ocean_Foam1;
			
			uniform float _OceanAlpha;
			uniform float _GlobalOceanAlpha;
			uniform float alphaRadius;
			
			uniform float2 _VarianceMax;
			
			//uniform sampler2D _Sky_Map;
			
#if defined (PLANETSHINE_ON)
			uniform float4x4 planetShineSources;
			uniform float4x4 planetShineRGB;
#endif
			
			struct v2f 
			{
    			float4  pos : SV_POSITION;
    			float2  oceanU : TEXCOORD0;
    			float3  oceanP : TEXCOORD1;
//    			float3  vertexPos : TEXCOORD2;
//    			LIGHTING_COORDS(3,4)
			};
		
			v2f vert(appdata_base v)
			{
				float t;
				float3 cameraDir, oceanDir;
				
				float4 vert = v.vertex;
				vert.xy *= 1.25;

				float2 u = OceanPos(vert, _Globals_ScreenToCamera, t, cameraDir, oceanDir);
			    float2 dux = OceanPos(vert + float4(_Ocean_ScreenGridSize.x, 0.0, 0.0, 0.0), _Globals_ScreenToCamera) - u;
			    float2 duy = OceanPos(vert + float4(0.0, _Ocean_ScreenGridSize.y, 0.0, 0.0), _Globals_ScreenToCamera) - u;


			    float3 dP = float3(0, 0, _Ocean_HeightOffset);
			    
			    if(duy.x != 0.0 || duy.y != 0.0) 
			    {
			    	float4 GRID_SIZES = _Ocean_GridSizes;
			    	float4 CHOPPYNESS = _Ocean_Choppyness;
			    	
			        dP.z += Tex2DGrad(_Ocean_Map0, u / GRID_SIZES.x, dux / GRID_SIZES.x, duy / GRID_SIZES.x, _Ocean_MapSize).x;	//it makes a difference but for testing it isn't an issue
			        dP.z += Tex2DGrad(_Ocean_Map0, u / GRID_SIZES.y, dux / GRID_SIZES.y, duy / GRID_SIZES.y, _Ocean_MapSize).y;
			        dP.z += Tex2DGrad(_Ocean_Map0, u / GRID_SIZES.z, dux / GRID_SIZES.z, duy / GRID_SIZES.z, _Ocean_MapSize).z;
			        dP.z += Tex2DGrad(_Ocean_Map0, u / GRID_SIZES.w, dux / GRID_SIZES.w, duy / GRID_SIZES.w, _Ocean_MapSize).w;

//			        dP.z += tex2Dlod(_Ocean_Map0, float4(u / GRID_SIZES.x,0,0)).x;
//			        dP.z += tex2Dlod(_Ocean_Map0, float4(u / GRID_SIZES.y,0,0)).y;
//			        dP.z += tex2Dlod(_Ocean_Map0, float4(u / GRID_SIZES.z,0,0)).z;
//			        dP.z += tex2Dlod(_Ocean_Map0, float4(u / GRID_SIZES.w,0,0)).w;
			        
			        dP.xy += CHOPPYNESS.x * Tex2DGrad(_Ocean_Map3, u / GRID_SIZES.x, dux / GRID_SIZES.x, duy / GRID_SIZES.x, _Ocean_MapSize).xy;
			        dP.xy += CHOPPYNESS.y * Tex2DGrad(_Ocean_Map3, u / GRID_SIZES.y, dux / GRID_SIZES.y, duy / GRID_SIZES.y, _Ocean_MapSize).zw;
			        dP.xy += CHOPPYNESS.z * Tex2DGrad(_Ocean_Map4, u / GRID_SIZES.z, dux / GRID_SIZES.z, duy / GRID_SIZES.z, _Ocean_MapSize).xy;
			        dP.xy += CHOPPYNESS.w * Tex2DGrad(_Ocean_Map4, u / GRID_SIZES.w, dux / GRID_SIZES.w, duy / GRID_SIZES.w, _Ocean_MapSize).zw;

//			        dP.xy += CHOPPYNESS.x * tex2Dlod(_Ocean_Map3, float4(u / GRID_SIZES.x,0,0)).xy;
//			        dP.xy += CHOPPYNESS.y * tex2Dlod(_Ocean_Map3, float4(u / GRID_SIZES.y,0,0)).zw;
//			        dP.xy += CHOPPYNESS.z * tex2Dlod(_Ocean_Map4, float4(u / GRID_SIZES.z,0,0)).xy;
//			        dP.xy += CHOPPYNESS.w * tex2Dlod(_Ocean_Map4, float4(u / GRID_SIZES.w,0,0)).zw;

			    }

				v2f OUT;
				
    			float3x3 otoc = _Ocean_OceanToCamera;
    			float4 screenP = float4(t * cameraDir + mul(otoc, dP), 1.0);
    			float3 oceanP = t * oceanDir + dP + float3(0.0, 0.0, _Ocean_CameraPos.z);

				OUT.pos = mul(_Globals_CameraToScreen, screenP);
								
			    OUT.oceanU = u;
			    OUT.oceanP = oceanP;
			   	
//			    float4 worldPos=mul(_Globals_CameraToWorld , screenP);
//			    OCEAN_TRANSFER_VERTEX_TO_FRAGMENT(OUT);
//			    OUT.vertexPos=worldPos.xyz;
			    
    			return OUT;
			}
			
			float3 reflectionAngle( float3 i, float3 n )
			{
  				return i - 2.0 * n * dot(n,i);
			}
			
			float3 ReflectedSky(float3 V, float3 N, float sigmaSq, float3 sunDir, float3 earthP) 
			{
    			float3 result = float3(0,0,0);

//    			float2 zeta0 = -N.xy / N.z;
//    			float2 tau0 = U(zeta0, V);
//
//    			const float n = 1.0 / 1.1;
//    			float2 JX = (U(zeta0 + float2(0.01, 0.0), V) - tau0) / 0.01 * n * sqrt(sigmaSq);
//    			float2 JY = (U(zeta0 + float2(0.0, 0.01), V) - tau0) / 0.01 * n * sqrt(sigmaSq);
//    
//    			result = tex2D(skymap, (tau0 * 0.5 / 1.1 + 0.5), JX, JY).rgb;

				float3 extinction = float3(0,0,0);

				float3 reflectedAngle=reflect(-V,N);
				reflectedAngle=float3(reflectedAngle.x,reflectedAngle.y,max(reflectedAngle.z,0.0)); //hack to avoid unsightly black pixels from downwards reflections
				result = SkyRadiance2(earthP,reflectedAngle, sunDir,extinction);

//    			result *= 0.02 + 0.98 * MeanFresnel(V, N, sigmaSq);
    			result *= MeanFresnel(V, N, sigmaSq);
//				result *= 0.02 + 0.98 * MeanFresnel(V, N, sigmaSq) * skyE / M_PI;
    			
				
    			return result;
			}
			
			float4 frag(v2f IN) : COLOR
			{

    			float3 L = _Ocean_SunDir;
    			float radius = _Ocean_Radius;
				float2 u = IN.oceanU;
				float3 oceanP = IN.oceanP;
				
				
				float3 earthCamera = float3(0.0, 0.0, _Ocean_CameraPos.z + radius);
				
    			float3 earthP = normalize(oceanP + float3(0.0, 0.0, radius)) * (radius + 10.0);
    			
    			float dist=length(earthP-earthCamera);
				
				float clampFactor= clamp(dist/alphaRadius,0.0,1.0);			
				
				float outAlpha=lerp(_OceanAlpha,1.0,clampFactor);
				float outWhiteCapStr=lerp(_Ocean_WhiteCapStr,farWhiteCapStr,clampFactor);
				
    			float3 oceanCamera = float3(0.0, 0.0, _Ocean_CameraPos.z);
    			float3 V = normalize(oceanCamera - oceanP);
			
				float2 slopes = float2(0,0);
			    slopes += tex2D(_Ocean_Map1, u / _Ocean_GridSizes.x).xy;
    			slopes += tex2D(_Ocean_Map1, u / _Ocean_GridSizes.y).zw;
    			slopes += tex2D(_Ocean_Map2, u / _Ocean_GridSizes.z).xy;
    			slopes += tex2D(_Ocean_Map2, u / _Ocean_GridSizes.w).zw;
    			
//    			if (radius > 0.0)
				{
			        slopes -= oceanP.xy / (radius + oceanP.z);
			    }
			    
			    float3 N = normalize(float3(-slopes.x, -slopes.y, 1.0));
			    
//			    if (dot(V, N) < 0.0) {
//			        N = reflect(N, V); // reflects backfacing normals
//			    }
			    
			    float Jxx = ddx(u.x);
			    float Jxy = ddy(u.x);
			    float Jyx = ddx(u.y);
			    float Jyy = ddy(u.y);
			    float A = Jxx * Jxx + Jyx * Jyx;
			    float B = Jxx * Jxy + Jyx * Jyy;
			    float C = Jxy * Jxy + Jyy * Jyy;
			    const float SCALE = 10.0;
			    float ua = pow(A / SCALE, 0.25);
			    float ub = 0.5 + 0.5 * B / sqrt(A * C);
			    float uc = pow(C / SCALE, 0.25);
//			    float sigmaSq = tex3D(_Ocean_Variance, float3(ua, ub, uc)).x;
			    float2 sigmaSq = tex3D(_Ocean_Variance, float3(ua, ub, uc)).xy * _VarianceMax;

			    sigmaSq = max(sigmaSq, 2e-5);
			    
				float3 sunL;
				float3 skyE;
				SunRadianceAndSkyIrradiance(earthP, N, L, sunL, skyE);
				
				float3 Lsky;
				
//				Lsky = ReflectedSkyRadiance(_Sky_Map, V, N, sigmaSq, L);   //flat world, sky_map

//				float atten=LIGHT_ATTENUATION(IN)*15;
				
#if defined (SKY_REFLECTIONS_ON)
				Lsky = ReflectedSky(V, N, sigmaSq, L, earthP);   //planet, accurate sky reflections
#else
				Lsky = MeanFresnel(V, N, sigmaSq) * skyE / M_PI; 		   //planet, sky irradiance only
#endif
				
						
				float3 Lsun = ReflectedSunRadiance(L, V, N, sigmaSq) * sunL * 100;
				float3 Lsea = RefractedSeaRadiance(V, N, sigmaSq) * _Ocean_Color * skyE / M_PI;
				
				// extract mean and variance of the jacobian matrix determinant
				float2 jm1 = tex2D(_Ocean_Foam0, u / _Ocean_GridSizes.x).xy;
				float2 jm2 = tex2D(_Ocean_Foam0, u / _Ocean_GridSizes.y).zw;
				float2 jm3 = tex2D(_Ocean_Foam1, u / _Ocean_GridSizes.z).xy;
				float2 jm4 = tex2D(_Ocean_Foam1, u / _Ocean_GridSizes.w).zw;
				float2 jm  = jm1+jm2+jm3+jm4;
				float jSigma2 = max(jm.y - (jm1.x*jm1.x + jm2.x*jm2.x + jm3.x*jm3.x + jm4.x*jm4.x), 0.0);

				// get coverage
				float W = WhitecapCoverage(outWhiteCapStr,jm.x,jSigma2);
				
				// compute and add whitecap radiance
				float3 l = (sunL * (max(dot(N, L), 0.0)) + skyE) / M_PI;
				float3 R_ftot = float3(W * l * 0.4);
				
				float3 surfaceColor = Lsun + Lsky + Lsea + R_ftot;
				
#if defined (PLANETSHINE_ON)
			    for (int i=0; i<4; ++i)
    			{
    				if (planetShineRGB[i].w == 0) break;
    				
    				L=normalize(planetShineSources[i].xyz);
					SunRadianceAndSkyIrradiance(earthP, N, L, sunL, skyE);
					
					#if defined (SKY_REFLECTIONS_ON)
						Lsky = ReflectedSky(V, N, sigmaSq, L, earthP);   //planet, accurate sky reflections
					#else
						Lsky = MeanFresnel(V, N, sigmaSq) * skyE / M_PI; 		   //planet, sky irradiance only
					#endif
				
					
					Lsun = ReflectedSunRadiance(L, V, N, sigmaSq) * sunL;
					Lsea = RefractedSeaRadiance(V, N, sigmaSq) * _Ocean_Color * skyE / M_PI;
					l = (sunL * (max(dot(N, L), 0.0)) + skyE) / M_PI;
					R_ftot = float3(W * l * 0.4);
					
					//if source is not a sun compute intensity of light from angle to light source
			   		float intensity=1;  
			   		if (planetShineSources[i].w != 1.0f)
					{
						intensity = 0.57f*max((0.75-dot(normalize(planetShineSources[i].xyz - earthP),_Sun_WorldSunDir)),0);
					}
					
					surfaceColor+= (Lsun + Lsky + Lsea + R_ftot)*planetShineRGB[i].xyz*planetShineRGB[i].w*intensity;
				}
	
#endif
				
//				float3 extinction=0;								
				// aerial perspective
//			    float3 inscatter = InScattering(earthCamera, earthP, L, extinction, 0.0);
			    float3 finalColor = surfaceColor;// + inscatter;

				return float4(hdr(finalColor), outAlpha*_GlobalOceanAlpha);
			}
			
			ENDCG
    	}
    	
    	
    	Pass   //forward Add
    	{
			Tags { "LightMode" = "ForwardAdd" } 
    	
    	
//    		Blend One One
			Blend One OneMinusSrcColor //"reverse" soft-additive
    	
			CGPROGRAM
			#include "UnityCG.cginc"
			#pragma glsl
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdadd
			
			#include "Utility.cginc"
			//#include "AtmosphereNew.cginc"
			#include "OceanBRDF.cginc"
			#include "OceanDisplacement3.cginc"
			
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#include "OceanLight.cginc"
			
			uniform float4x4 _Globals_ScreenToCamera;
			uniform float4x4 _Globals_CameraToWorld;
			uniform float4x4 _Globals_WorldToScreen;
			uniform float4x4 _Globals_CameraToScreen;
			uniform float4x4 _Globals_WorldToOcean;
			uniform float4x4 _Globals_OceanToWorld;
			uniform float3 _Globals_WorldCameraPos;
			
			uniform float2 _Ocean_MapSize;
			uniform float4 _Ocean_Choppyness;
			uniform float3 _Ocean_SunDir;
			uniform float3 _Ocean_Color;
			uniform float4 _Ocean_GridSizes;
			uniform float2 _Ocean_ScreenGridSize;
			uniform float _Ocean_WhiteCapStr;
			uniform float farWhiteCapStr;
			
			uniform sampler3D _Ocean_Variance;
			uniform sampler2D _Ocean_Map0;
			uniform sampler2D _Ocean_Map1;
			uniform sampler2D _Ocean_Map2;
			uniform sampler2D _Ocean_Map3;
			uniform sampler2D _Ocean_Map4;
			uniform sampler2D _Ocean_Foam0;
			uniform sampler2D _Ocean_Foam1;
			
			uniform float _OceanAlpha;
			uniform float _GlobalOceanAlpha;
			uniform float alphaRadius;
			
			uniform float2 _VarianceMax;
			
			uniform sampler2D _Sky_Map;
			
			struct v2f 
			{
    			float4  pos : SV_POSITION;
    			float2  oceanU : TEXCOORD0;
    			float3  oceanP : TEXCOORD1;
    			float3  vertexPos : TEXCOORD2;
    			LIGHTING_COORDS(3,4)
			};
		
			v2f vert(appdata_base v)
			{
				float t;
				float3 cameraDir, oceanDir;
				
				float4 vert = v.vertex;
				vert.xy *= 1.25;

				float2 u = OceanPos(vert, _Globals_ScreenToCamera, t, cameraDir, oceanDir);
			    float2 dux = OceanPos(vert + float4(_Ocean_ScreenGridSize.x, 0.0, 0.0, 0.0), _Globals_ScreenToCamera) - u;
			    float2 duy = OceanPos(vert + float4(0.0, _Ocean_ScreenGridSize.y, 0.0, 0.0), _Globals_ScreenToCamera) - u;


			    float3 dP = float3(0, 0, _Ocean_HeightOffset);
			    
			    if(duy.x != 0.0 || duy.y != 0.0) 
			    {
			    	float4 GRID_SIZES = _Ocean_GridSizes;
			    	float4 CHOPPYNESS = _Ocean_Choppyness;
			    	
			        dP.z += Tex2DGrad(_Ocean_Map0, u / GRID_SIZES.x, dux / GRID_SIZES.x, duy / GRID_SIZES.x, _Ocean_MapSize).x;
			        dP.z += Tex2DGrad(_Ocean_Map0, u / GRID_SIZES.y, dux / GRID_SIZES.y, duy / GRID_SIZES.y, _Ocean_MapSize).y;
			        dP.z += Tex2DGrad(_Ocean_Map0, u / GRID_SIZES.z, dux / GRID_SIZES.z, duy / GRID_SIZES.z, _Ocean_MapSize).z;
			        dP.z += Tex2DGrad(_Ocean_Map0, u / GRID_SIZES.w, dux / GRID_SIZES.w, duy / GRID_SIZES.w, _Ocean_MapSize).w;

			        dP.xy += CHOPPYNESS.x * Tex2DGrad(_Ocean_Map3, u / GRID_SIZES.x, dux / GRID_SIZES.x, duy / GRID_SIZES.x, _Ocean_MapSize).xy;
			        dP.xy += CHOPPYNESS.y * Tex2DGrad(_Ocean_Map3, u / GRID_SIZES.y, dux / GRID_SIZES.y, duy / GRID_SIZES.y, _Ocean_MapSize).zw;
			        dP.xy += CHOPPYNESS.z * Tex2DGrad(_Ocean_Map4, u / GRID_SIZES.z, dux / GRID_SIZES.z, duy / GRID_SIZES.z, _Ocean_MapSize).xy;
			        dP.xy += CHOPPYNESS.w * Tex2DGrad(_Ocean_Map4, u / GRID_SIZES.w, dux / GRID_SIZES.w, duy / GRID_SIZES.w, _Ocean_MapSize).zw;

			    }

				v2f OUT;
				
    			float3x3 otoc = _Ocean_OceanToCamera;
    			float4 screenP = float4(t * cameraDir + mul(otoc, dP), 1.0);
    			float3 oceanP = t * oceanDir + dP + float3(0.0, 0.0, _Ocean_CameraPos.z); 
    			
				float4 pos = mul(_Globals_CameraToScreen, screenP);
				

				OUT.pos = pos;				
			    OUT.oceanU = u;
			    OUT.oceanP = oceanP;
			    
			    float4 worldPos=mul(_Globals_CameraToWorld , screenP);
			    
			    OCEAN_TRANSFER_VERTEX_TO_FRAGMENT(OUT);
			    
			    OUT.vertexPos=worldPos.xyz;
			    
    			return OUT;
			}
			
			
			float4 frag(v2f IN) : COLOR
			{

    			float radius = _Ocean_Radius;
				float2 u = IN.oceanU;
				float3 oceanP = IN.oceanP;
				
				float3 earthCamera = float3(0.0, 0.0, _Ocean_CameraPos.z + radius); 
				
    			float3 earthP = normalize(oceanP + float3(0.0, 0.0, radius)) * (radius + 10.0); 
    			
    			float dist=length(earthP-earthCamera);
				
				float clampFactor= clamp(dist/alphaRadius,0.0,1.0);			
				
				float outAlpha=lerp(_OceanAlpha,1.0,clampFactor);
				float outWhiteCapStr=lerp(_Ocean_WhiteCapStr,farWhiteCapStr,clampFactor);
				
    			float3 oceanCamera = float3(0.0, 0.0, _Ocean_CameraPos.z);
    			float3 V = normalize(oceanCamera - oceanP);
			
				float2 slopes = float2(0,0);
			    slopes += tex2D(_Ocean_Map1, u / _Ocean_GridSizes.x).xy;
    			slopes += tex2D(_Ocean_Map1, u / _Ocean_GridSizes.y).zw;
    			slopes += tex2D(_Ocean_Map2, u / _Ocean_GridSizes.z).xy;
    			slopes += tex2D(_Ocean_Map2, u / _Ocean_GridSizes.w).zw;
    			

			    slopes -= oceanP.xy / (radius + oceanP.z);

			    
			    float3 N = normalize(float3(-slopes.x, -slopes.y, 1.0));
			    
			    if (dot(V, N) < 0.0) {
			        N = reflect(N, V); // reflects backfacing normals
			    }
			    
			    float Jxx = ddx(u.x);
			    float Jxy = ddy(u.x);
			    float Jyx = ddx(u.y);
			    float Jyy = ddy(u.y);
			    float A = Jxx * Jxx + Jyx * Jyx;
			    float B = Jxx * Jxy + Jyx * Jyy;
			    float C = Jxy * Jxy + Jyy * Jyy;
			    const float SCALE = 10.0;
			    float ua = pow(A / SCALE, 0.25);
			    float ub = 0.5 + 0.5 * B / sqrt(A * C);
			    float uc = pow(C / SCALE, 0.25);
//			    float sigmaSq = tex3D(_Ocean_Variance, float3(ua, ub, uc)).x;
			    float2 sigmaSq = tex3D(_Ocean_Variance, float3(ua, ub, uc)).xy * _VarianceMax;

			    sigmaSq = max(sigmaSq, 2e-5);
			    




//				float3 sunL;
//				float3 skyE;
//				SunRadianceAndSkyIrradiance(earthP, N, L, sunL, skyE);
				
				float atten=LIGHT_ATTENUATION(IN)*15;
				
				float3 Lsky;
				
//				Lsky = MeanFresnel(V, N, sigmaSq) * skyE / M_PI;

				Lsky = MeanFresnel(V, N, sigmaSq) * atten / M_PI;
				 
				
				
				float3 oceanL= mul(_Globals_WorldToOcean, _WorldSpaceLightPos0);
				float3 L = normalize(oceanL - oceanP); //light dir in ocean space, find it
//				float3 Lsun = ReflectedSunRadiance(L, V, N, sigmaSq) * sunL;
				float3 Lsun = ReflectedSunRadiance(L, V, N, sigmaSq) * atten;

//				float3 Lsea = RefractedSeaRadiance(V, N, sigmaSq) * _Ocean_Color * skyE / M_PI;
				float3 Lsea = RefractedSeaRadiance(V, N, sigmaSq) * _Ocean_Color * atten;
				
				// extract mean and variance of the jacobian matrix determinant
				float2 jm1 = tex2D(_Ocean_Foam0, u / _Ocean_GridSizes.x).xy;
				float2 jm2 = tex2D(_Ocean_Foam0, u / _Ocean_GridSizes.y).zw;
				float2 jm3 = tex2D(_Ocean_Foam1, u / _Ocean_GridSizes.z).xy;
				float2 jm4 = tex2D(_Ocean_Foam1, u / _Ocean_GridSizes.w).zw;
				float2 jm  = jm1+jm2+jm3+jm4;
				float jSigma2 = max(jm.y - (jm1.x*jm1.x + jm2.x*jm2.x + jm3.x*jm3.x + jm4.x*jm4.x), 0.0);

				// get coverage
				float W = WhitecapCoverage(outWhiteCapStr,jm.x,jSigma2);
				
				// compute and add whitecap radiance
//				float3 l = (sunL * (max(dot(N, L), 0.0)) + skyE) / M_PI;
				float3 l = (atten * (max(dot(N, L), 0.0))) / M_PI;
				float3 R_ftot = float3(W * l * 0.4);
				
				float3 surfaceColor = (Lsun + Lsky + Lsea + R_ftot) * _LightColor0.rgb;
//				float3 surfaceColor = Lsea + R_ftot + Lsky;
								
//				 aerial perspective
//			    float3 inscatter = InScattering(earthCamera, earthP, L, extinction, 0.0);
//			    float3 finalColor = surfaceColor;// + inscatter;
//			    
//			    float3 lightDir=normalize(IN.vertexPos-_WorldSpaceLightPos0.xyz);
			    
			    float3 finalColor= surfaceColor;
			    

//			    finalColor*=*atten;
			    
				return float4(hdr(finalColor), outAlpha*_GlobalOceanAlpha);
			}
			
			ENDCG
    	}
    	
    	
    	
	}
}

