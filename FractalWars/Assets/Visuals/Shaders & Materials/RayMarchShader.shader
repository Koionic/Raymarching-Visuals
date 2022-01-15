Shader "Ganon/RayMarchShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma target 3.0

            #include "UnityCG.cginc"
			#include "DistanceFunctions.cginc"

			sampler2D _MainTex;
			uniform sampler2D _CameraDepthTexture;
			uniform float4x4 _CamFrustum, _CamToWorld;
			uniform float _maxDistance;
			uniform float4 _sphere1, _box1;
			uniform float3 _modInterval;
			uniform float3 _LightDir;
			uniform fixed4 _mainColor;

            uniform float4 _sphereObj1;
            uniform float4 _sphereObj2;
            uniform float4 _sphereObj3;

            uniform bool addObjects = true;

            uniform int colourIndex = 0;

            uniform fixed4 _color1 = (1,0,0,1);
            uniform fixed4 _color2 = (0,1,0,1);
            uniform fixed4 _color3 = (0,0,1,1);
            uniform fixed4 _color4 = (1,0,0,1);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float3 ray : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
				half index = v.vertex.z;
				v.vertex.z = 0;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

				o.ray = _CamFrustum[(int)index].xyz;

				o.ray /= abs(o.ray.z);

				o.ray = mul(_CamToWorld, o.ray);

                return o;
            }

            float addSphere(float d, float3 p, float4 obj)
            {
            	float Sphere = sdSphere(p - obj.xyz, obj.w);
            	
            	d = opU(d, Sphere);

            	if (d < 0.01) //hit is detected
            	{
            		colourIndex++;
            	}

            	return d;
            }

            float distanceFieldObjs(float d, float3 p)
            {
            	d = addSphere(d, p, _sphereObj1);
            	//d = opU(d, _sphereObj2);
            	//d = opU(d, _sphereObj3);

            	return d;
            }


            
			//p = position
			//THIS IS WHERE YOU PUT THE SHAPES
			float distanceField(float3 p)
			{
				float3 originalP = p;
            	
				float modX = pMod1(p.x, _modInterval.x);
				float modY = pMod1(p.y, _modInterval.y);
				float modZ = pMod1(p.z, _modInterval.z);
				float Sphere1 = sdSphere(p - _sphere1.xyz, _sphere1.w);
				float Box1 = sdBox(p - _box1.xyz, _box1.www);

				float finalD = opS(Sphere1, Box1);

            	if (finalD < 0.01) //hit is detected
            	{
            		colourIndex = 0;
            	}
            	
            	return distanceFieldObjs(finalD, originalP);
			}

			//p = position
			float3 getNormal(float3 p)
			{
				const float2 offset = float2(0.1, 0.0);
				float3 n = float3(
					distanceField(p + offset.xyy) - distanceField(p - offset.xyy),
					distanceField(p + offset.yxy) - distanceField(p - offset.yxy),
					distanceField(p + offset.yyx) - distanceField(p - offset.yyx));
				return normalize(n);
			}

			//ro = ray origin, rd = ray direction
			fixed4 raymarching(float3 ro, float3 rd, float depth)
			{
				fixed4 result = fixed4(1, 1, 1, 1);
				const int max_iteration = 256;
				float t = 0; //distance travelled along the ray direction

				for (int i = 0; i < max_iteration; i++)
				{
					if (t > _maxDistance || t >= depth)
					{
						//Environment
						result = fixed4(rd,0);
						break;
					}

					float3 p = ro + rd * t;
					//check for hit in distancefield
					
					float d = distanceField(p);
					if (d < 0.01) //hit is detected
					{
						//shading
						float3 n = getNormal(p);
						float light = dot(-_LightDir, n);

						fixed4 col = (1,1,1,1);
						
						if (colourIndex == 0)
						{
							col = (0,1,1,1);
						}
						else if (colourIndex == 1)
						{
							col = fixed4(1,0,1,1);
						}
						else if (colourIndex == 2)
						{
							col = fixed4(0,0,1,1);
						}
						
						result = fixed4(col.rgb * n * light, 1);
						//result = fixed4(_mainColor.rgb * light, 1);
						break;
					}

					t += d;
				}


				return result;
			}

            fixed4 frag (v2f i) : SV_Target
            {
				float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
				depth += length(i.ray);
				fixed3 col = tex2D(_MainTex, i.uv);
				float3 rayDirection = normalize(i.ray.xyz);
				float3 rayOrigin = _WorldSpaceCameraPos;
				fixed4 result = raymarching(rayOrigin, rayDirection, depth);
				return fixed4(col * (1.0 - result.w) + result.xyz * result.w,1.0);
            }
            ENDCG
        }
    }
}
