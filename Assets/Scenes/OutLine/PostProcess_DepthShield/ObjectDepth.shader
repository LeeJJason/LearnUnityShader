Shader "lcl/DepthShieldOutline/ObjectDepth"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float uv : TEXCOORD0;
                float depth01 : TEXCOORD1;
            };
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.depth01 = COMPUTE_DEPTH_01;
                return o;
            }
            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                float depth = i.depth01;
                // clip(col.a - 0.2);
                return fixed4(depth,depth,depth,1);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"

}