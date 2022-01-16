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

			uniform int _MaxIterations;
            uniform float _Accuracy;
            
			uniform float _maxDistance;
			uniform float4 _sphere1, _box1;
			uniform float3 _modInterval;
			uniform float3 _LightDir;
            uniform float3 _LightCol;
			uniform float3 _mainColor;

			uniform float _LightIntensity;
			uniform float _ColorIntensity;
            
            uniform float4 _sphereObj1;
            uniform float4 _sphereObj2;
            uniform float4 _sphereObj3;

            uniform bool addObjects = true;

            uniform int colourIndex = 0;

            uniform sampler2D _envTex;

            uniform float3 _sphereColor1;
            uniform float3 _sphereColor2;
            uniform float3 _sphereColor3;

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

            float4 addSphere(float4 d, float3 p, float4 obj, fixed3 newCol)
            {
            	float4 Sphere;
            	Sphere.xyz = newCol;
            	Sphere.w = sdSphere(p - obj.xyz, obj.w);
            	
            	return opU(d, Sphere);
            }

            float4 distanceFieldObjs(float4 d, float3 p)
            {
            	float4 newD;
            	
            	newD = addSphere(d, p, _sphereObj1, _sphereColor1);
            	newD = addSphere(newD, p, _sphereObj2, _sphereColor2);
            	newD = addSphere(newD, p, _sphereObj3, _sphereColor3);
            	//d = opU(d, _sphereObj2);
            	//d = opU(d, _sphereObj3);

            	return newD;
            }


            
			//p = position
			//THIS IS WHERE YOU PUT THE SHAPES
			float4 distanceField(float3 p)
			{
				float3 originalP = p;
            	
				float modX = pMod1(p.x, _modInterval.x);
				float modY = pMod1(p.y, _modInterval.y);
            	float modZ = pMod1(p.z, _modInterval.z);
            	
				float Sphere1 = sdSphere(p - _sphere1.xyz, _sphere1.w);
				float Box1 = sdBox(p - _box1.xyz, _box1.www);

				float4 d;

            	d.xyz = _mainColor;
            	d.w = opS(Sphere1, Box1);

				d = distanceFieldObjs(d, originalP);

            	return d;
			}

			//p = position
			float3 getNormal(float3 p)
			{
				const float2 offset = float2(0.01, 0.0);
				float3 n = float3(
					distanceField(p + offset.xyy).w - distanceField(p - offset.xyy).w,
					distanceField(p + offset.yxy).w - distanceField(p - offset.yxy).w,
					distanceField(p + offset.yyx).w - distanceField(p - offset.yyx).w);
				return normalize(n);
			}

            float3 Shading(float3 p, float3 n, fixed3 c)
            {
	            float3 result;

            	//Diffuse Color
            	float3 color = c.rgb * _ColorIntensity;
            	//Directional Light
            	float3 light = (_LightCol * dot(-_LightDir, n) * 0.5 + 0.5) * _LightIntensity;

            	result = color * light;

            	return result;
            }

			//ro = ray origin, rd = ray direction
			bool raymarching(float3 ro, float3 rd, float depth, inout float3 p, inout fixed3 dColor)
			{
				bool hit = false;
            	
				//fixed4 result = fixed4(1, 1, 1, 1);
				float t = 0; //distance travelled along the ray direction

				for (int i = 0; i < _MaxIterations; i++)
				{
					if (t > _maxDistance || t >= depth)
					{
						//Environment
						hit = false;
						//result = fixed4(rd,0);
						break;
					}

					p = ro + rd * t;
					//check for hit in distancefield
					
					float4 d = distanceField(p);
					if (d.w < _Accuracy) //hit is detected
					{
						hit = true;
						dColor = d.xyz;
						//result = fixed4(_mainColor.rgb * light, 1);
						break;
					}
										

					t += d.w;
				}


				return hit;
			}

            fixed4 frag (v2f i) : SV_Target
            {
				float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
				depth += length(i.ray);
				fixed3 col = tex2D(_MainTex, i.uv);
				float3 rayDirection = normalize(i.ray.xyz);
				float3 rayOrigin = _WorldSpaceCameraPos;
				fixed4 result;
            	float3 hitPosition;
            	fixed3 dColor = _mainColor;

            	bool hit = raymarching(rayOrigin, rayDirection, depth, hitPosition, dColor);

            	if (hit)
            	{
            		float3 n = getNormal(hitPosition);
            		float3 s = Shading(hitPosition, n, dColor);

            		result = fixed4(s,1);
            	}
            	else
            	{
            		result = fixed4(0,0,0,0);
            	}

            	//return result;
				//fixed4 result = raymarching(rayOrigin, rayDirection, depth);
				return fixed4(col * (1.0 - result.w) + result.xyz * result.w,1.0);
            }
            ENDCG
        }
    }
}
