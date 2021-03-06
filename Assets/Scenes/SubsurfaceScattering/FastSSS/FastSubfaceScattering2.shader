/*
* @Descripttion: 次表面散射 - part2 多个pass渲染 ForwardAdd 渲染点光源
* @Author: lichanglong
* @Date: 2021-08-20 18:21:10
 * @FilePath: \LearnUnityShader\Assets\Scenes\SubsurfaceScattering\FastSSS\FastSubfaceScattering2.shader
*/
Shader "lcl/SubsurfaceScattering/FastSubfaceScattering2" {
	Properties{
		_MainTex ("Texture", 2D) = "white" {}
		_BaseColor("Base Color",Color) = (1,1,1,1)
		_Specular("_Specular Color",Color) = (1,1,1,1)
		[PowerSlider()]_Gloss("Gloss",Range(0,200)) = 10
		
		// fresnel
		// _RimPower("Rim Power", Range(0.0, 36)) = 0.1
		// _RimIntensity("Rim Intensity", Range(0, 1)) = 0.2
		
		[Header(SubsurfaceScattering)]
		[Main(frontFactor)] _group ("group", float) = 1
		[Sub(frontFactor)][HDR]_InteriorColor ("Interior Color", Color) = (1,1,1,1)
		[Sub(frontFactor)]_InteriorColorPower ("InteriorColorPower", Range(0,50)) = 0.0
		[Title(frontFactor, Back SSS Factor)]
		[Sub(frontFactor)]_DistortionBack ("Back Distortion", Range(0,1)) = 0.0
		[Sub(frontFactor)]_PowerBack ("Back Power", Range(0,10)) = 0.0
		[Sub(frontFactor)]_ScaleBack ("Back Scale", Range(0,1)) = 0.0
		[Title(frontFactor, Front SSS Factor)]
		[Sub(frontFactor)]_FrontSssIntensity ("Front SSS Intensity", Range(0,1)) = 0.2
		[Sub(frontFactor)]_DistortionFont ("Front Distortion", Range(0,1)) = 0.0
		[Sub(frontFactor)]_PowerFont ("Front Power", Range(0,10)) = 0.0
		[Sub(frontFactor)]_ScaleFont ("Front Scale", Range(0,1)) = 0.0
	}
	SubShader {
		Pass{
			Tags { "LightMode"="Forwardbase" }
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// #pragma multi_compile_fwdbase

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
            #pragma enable_d3d11_debug_symbols

			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _BaseColor;
			half _Gloss;
			float3 _Specular;
			float  _RimPower;
			float _RimIntensity;

			float4 _InteriorColor;
			float _InteriorColorPower;

			float _DistortionBack;
			float _PowerBack;
			float _ScaleBack;
			
			float _FrontSssIntensity;
			float _DistortionFont;
			float _PowerFont;
			float _ScaleFont;

			struct a2v {
				float4 vertex : POSITION;
				float3 normal: NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct v2f{
				float4 position:SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normalDir: TEXCOORD1;
				float3 worldPos: TEXCOORD2;
				float3 viewDir: TEXCOORD3;
				float3 lightDir: TEXCOORD4;
			};

			v2f vert(a2v v){
				v2f o;
				o.position = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.worldPos = mul (unity_ObjectToWorld, v.vertex);
				o.normalDir = UnityObjectToWorldNormal (v.normal);
				o.viewDir = UnityWorldSpaceViewDir(o.worldPos);
				o.lightDir = UnityWorldSpaceLightDir(o.worldPos);
				return o;
			};
			
			// 计算SSS
			inline float SubsurfaceScattering (float3 viewDir, float3 lightDir, float3 normalDir, float distortion,float power,float scale)
			{
				// float3 H = normalize(lightDir + normalDir * distortion);
				float3 H = (lightDir + normalDir * distortion);
				float I = pow(saturate(dot(viewDir, -H)), power) * scale;
				return I;
			}
			
			
			fixed4 frag(v2f i): SV_TARGET{
				fixed4 col = tex2D(_MainTex, i.uv) * _BaseColor;
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
				fixed3 normalDir = normalize(i.normalDir);
				fixed3 viewDir = normalize(i.viewDir);
				float3 lightDir = normalize(i.lightDir);
				// -------------Diffuse1-------------
				// fixed3 diffuse = _LightColor0.rgb * max(dot(normalDir,lightDir),0.3);
				// diffuse *= col * _InteriorColor;

				// -------------Diffuse2-------------
				fixed3 diffuse = _LightColor0.rgb * max(dot(normalDir,lightDir),0);
				fixed4 unlitCol = col * _InteriorColor * 0.5;
				diffuse = lerp(unlitCol, col, diffuse); 

				// -------------Specular - BlinnPhong-------------
				fixed3 halfDir = normalize(lightDir+viewDir);
				fixed3 specular = _LightColor0.rgb * pow(max(0,dot(normalDir,halfDir)),_Gloss) * _Specular;
				
				// ---------------次表面散射-----------
				// 背面
				float sssValueBack = SubsurfaceScattering(viewDir,lightDir,normalDir,_DistortionBack,_PowerBack,_ScaleBack);
				// 正面
				float sssValueFont = SubsurfaceScattering(viewDir,-lightDir,normalDir,_DistortionFont,_PowerFont,_ScaleFont);
				float sssValue = saturate(sssValueFont * _FrontSssIntensity + sssValueBack);
				fixed3 sssCol = lerp(_InteriorColor, _LightColor0, saturate(pow(sssValue, _InteriorColorPower))).rgb * sssValue;

				// ---------------Rim---------------
				// float rim = 1.0 - max(0, dot(normalDir, viewDir));
				// float rimValue = lerp(rim, 0, sssValue);
				// float3 rimCol = lerp(_InteriorColor, _LightColor0.rgb, rimValue) * pow(rimValue, _RimPower) * _RimIntensity;  
		
				fixed3 resCol = sssCol + diffuse.rgb + specular;
				return float4(resCol,1);
			};
			
			ENDCG
		}

		Pass{
			Tags { "LightMode"="ForwardAdd" }
			Blend One One
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdadd

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			struct a2v {
				float4 vertex : POSITION;
			};

			struct v2f{
				float4 position:SV_POSITION;
				float3 worldPos : TEXCOORD0;
			};

			v2f vert(a2v v){
				v2f o;
				o.position = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul (unity_ObjectToWorld, v.vertex);
				return o;
			};
			
			fixed4 frag(v2f i): SV_TARGET{
				// 衰减
				UNITY_LIGHT_ATTENUATION(atten, 0, i.worldPos);
				return float4(_LightColor0.rgb * atten,1);
			};
			
			ENDCG
		}
	}
	FallBack "Diffuse"
}