Shader "Custom/PlayerGoo" {

	Properties{
		_MainTex("Texture", 2D) = "white" {}
		_Fade("Dissolve Scale", Range(0.0, 1.0)) = 1.0
		_DissolveTex("Dissolve Texture", 2D) = "white" {}
		_DissolveStart("Dissolve Start Point", Vector) = (1, 1, 0, 0)
		_DissolveEnd("Dissolve End Point", Vector) = (0, 0, 0, 0)
		_DissolveBand("Dissolve Band Size", Float) = 0.25
		_GlowColor("Glow Color", Color) = (1, 1, 1, 1)
	}

	SubShader{
		Cull Off
		Blend SrcAlpha OneMinusSrcAlpha

		Pass{
			CGPROGRAM

			#pragma vertex vertexFunc
			#pragma fragment fragmentFunc
			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float3 _DissolveStart;
			float3 _DissolveEnd;
			half _Fade;
			half _DissolveBand;
			fixed4 _GlowColor;

			struct v2f {
				float4 pos : SV_POSITION;
				half2 uv : TEXCOORD0;
			};

			//Precompute dissolve direction.
			static float2 dDir = normalize(_DissolveStart - _DissolveEnd);

			//Precompute reciprocal of band size.
			static float dBandFactor = 1.0f / _DissolveBand;

			//Precompute gradient start position.
			static float2 dissolveEndConverted = _DissolveEnd - _DissolveBand * dDir;

			//Calculate geometry-based dissolve coefficient.
			//Compute top of dissolution gradient according to dissolve progression.
			static float2 dPoint = lerp(dissolveEndConverted, _DissolveStart, _Fade);

			v2f vertexFunc(appdata_base v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;
				return o;
			}

			fixed4 _Color;
			float4 _MainTex_TexelSize;
			sampler2D _DissolveTex;

			fixed4 fragmentFunc(v2f i) : COLOR {
				
				//Project vector between current vertex and top of gradient onto dissolve direction.
				//Scale coefficient by band (gradient) size.
				float dGeometry = dot(i.uv - dPoint, dDir) * dBandFactor;

				//Convert dissolve progression to -1 to 1 scale.
				half dBase = -2.0f * _Fade + 1.0f;

				//Read from noise texture.
				fixed4 dTex = tex2D(_DissolveTex, i.uv);
				fixed4 o = tex2D(_MainTex, i.uv);
				//Convert dissolve texture sample based on dissolve progression.
				half dTexRead = dTex.r + dBase;

				//Combine texture factor with geometry coefficient from vertex shader.
				half dFinal = dTexRead + dGeometry;

				float3 intensity = dot(o.rgb, float3(0.299, 0.587, 0.114));

				half progress = 1.0f - clamp(dFinal, 0.0f, 1.0f);

				half saturation = step(progress, 0.5f) * lerp(intensity, o.rgb, progress * 2.0f);

				float3 glow = step(0.5f, progress) * lerp(_GlowColor, o, progress * 2.0f - 1.0f);
				// step(x, y) is y >= x
				o.rgb = saturation + glow;// + step(0.5f, saturation) * o.rgb;

				//half glow = step(progress, 0.5f) * lerp(o.rgb, _GlowColor, progress * 2);

				//o.rgb = saturation;
				return o;
			}

			ENDCG
		}
	}
}