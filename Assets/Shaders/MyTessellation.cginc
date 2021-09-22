
#if !defined(TESSELLATION_INCLUDED)
#define TESSELLATION_INCLUDED

float _TessellationUniform;
float _TessellationEdgeLength;

struct TessellationFactors
{
	float edge[3] : SV_TessFactor;
	float inside : SV_InsideTessFactor;
};

struct TessellationControlPoint
{
	float4 vertex : INTERNALTESSPOS;
	float3 normal : NORMAL;
	#if TESSELLATION_TANGENT
		float4 tangent : TANGENT;
	#endif
	float2 uv : TEXCOORD0;
	#if TESSELLATION_UV1
		float2 uv1 : TEXCOORD1;
	#endif
	
	#if TESSELLATION_UV2
		float2 uv2 : TEXCOORD2;
	#endif
	
};

//float TessellationEdgeFactor(TessellationControlPoint cp0, TessellationControlPoint cp1)
float TessellationEdgeFactor(float3 p0, float3 p1)
{
	#if defined(_TESSELLATION_EDGE)
		//float3 p0 = mul(unity_ObjectToWorld, float4(cp0.vertex.xyz, 1)).xyz;
		//float3 p1 = mul(unity_ObjectToWorld, float4(cp1.vertex.xyz, 1)).xyz;
		//float edgeLength = distance(p0, p1);

		//屏幕空间细分
		//float4 p0 = UnityObjectToClipPos(cp0.vertex);
		//float4 p1 = UnityObjectToClipPos(cp1.vertex);
		//float edgeLength = distance(p0.xy / p0.w, p1.xy / p1.w);
		//return edgeLength * _ScreenParams.y / _TessellationEdgeLength;

		//世界空间细分，根据视距调整
		//float3 p0 = mul(unity_ObjectToWorld, float4(cp0.vertex.xyz, 1)).xyz;
		//float3 p1 = mul(unity_ObjectToWorld, float4(cp1.vertex.xyz, 1)).xyz;
		float edgeLength = distance(p0, p1);

		float3 edgeCenter = (p0 + p1) * 0.5;
		float viewDistance = distance(edgeCenter, _WorldSpaceCameraPos);

		return edgeLength * _ScreenParams.y / (_TessellationEdgeLength * viewDistance);
	#else
		return _TessellationUniform;
	#endif
}

TessellationControlPoint MyTessellationVertexProgram(VertexData v)
{
	TessellationControlPoint p;
	p.vertex = v.vertex;
	p.normal = v.normal;
	#if TESSELLATION_TANGENT
		p.tangent = v.tangent;
	#endif
	p.uv = v.uv;
	#if TESSELLATION_UV1
		p.uv1 = v.uv1;
	#endif
	#if TESSELLATION_UV2
		p.uv2 = v.uv2;
	#endif
	return p;
}

[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("fractional_odd")]
[UNITY_patchconstantfunc("MyPatchConstantFunction")]
TessellationControlPoint MyHullProgram(InputPatch<TessellationControlPoint, 3> patch, uint id : SV_OutputControlPointID)
{
	return patch[id];
}

bool TriangleIsBelowClipPlane(float3 p0, float3 p1, float3 p2, int planeIndex, float bias)
{
	//float4 plane = float4(1, 0, 0, 0);
	//左右下上近远
	float4 plane = unity_CameraWorldClipPlanes[planeIndex];
	
	return dot(float4(p0, 1), plane) < bias && 
	dot(float4(p1, 1), plane) < bias &&
	dot(float4(p2, 1), plane) < bias;
}

bool TriangleIsCulled(float3 p0, float3 p1, float3 p2, float bias)
{
	//近，不判断，距离很短，不比浪费计算
	//远，不判断，该距离不会发生细分
	//return p0.x < 0 && p1.x < 0 && p2.x < 0;
	return TriangleIsBelowClipPlane(p0, p1, p2, 0, bias)||
	TriangleIsBelowClipPlane(p0, p1, p2, 1, bias)||
	TriangleIsBelowClipPlane(p0, p1, p2, 2, bias)||
	TriangleIsBelowClipPlane(p0, p1, p2, 3, bias);
}

TessellationFactors MyPatchConstantFunction(InputPatch<TessellationControlPoint, 3> patch)
{
	float3 p0 = mul(unity_ObjectToWorld, float4(patch[0].vertex.xyz, 1)).xyz;
	float3 p1 = mul(unity_ObjectToWorld, float4(patch[1].vertex.xyz, 1)).xyz;
	float3 p2 = mul(unity_ObjectToWorld, float4(patch[2].vertex.xyz, 1)).xyz;

	TessellationFactors f;
	float bias = 0;
	#if VERTEX_DISPLACEMENT
		bias = -0.5 * _DisplacementStrength;
	#endif
	if (TriangleIsCulled(p0, p1, p2, bias))
	{
		f.edge[0] = f.edge[1] = f.edge[2] = f.inside = 0;
	}
	else
	{
		f.edge[0] = TessellationEdgeFactor(p1, p2);
		f.edge[1] = TessellationEdgeFactor(p2, p0);
		f.edge[2] = TessellationEdgeFactor(p0, p1);
		//f.inside = (f.edge[0] + f.edge[1] + f.edge[2]) * (1 / 3.0);
		//解决内部因子不正确得问题
		f.inside = (TessellationEdgeFactor(p1, p2) 
		+ TessellationEdgeFactor(p2, p0)
		+ TessellationEdgeFactor(p0, p1)) * (1 / 3.0);
	}
	
	return f;
}

[UNITY_domain("tri")]
InterpolatorsVertex MyDomainProgram(TessellationFactors factors, OutputPatch<TessellationControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
{
	VertexData data;
	//data.vertex = patch[0].vertex * barycentricCoordinates.x + patch[1].vertex * barycentricCoordinates.y + patch[2].vertex * barycentricCoordinates.z;
	#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName = \
		patch[0].fieldName * barycentricCoordinates.x + \
		patch[1].fieldName * barycentricCoordinates.y + \
		patch[2].fieldName * barycentricCoordinates.z;

	MY_DOMAIN_PROGRAM_INTERPOLATE(vertex)
	MY_DOMAIN_PROGRAM_INTERPOLATE(normal)
	#if TESSELLATION_TANGENT
		MY_DOMAIN_PROGRAM_INTERPOLATE(tangent)
	#endif
	MY_DOMAIN_PROGRAM_INTERPOLATE(uv)
	#if TESSELLATION_UV1
		MY_DOMAIN_PROGRAM_INTERPOLATE(uv1)
	#endif
	#if TESSELLATION_UV2
		MY_DOMAIN_PROGRAM_INTERPOLATE(uv2)
	#endif

	return MyVertexProgram(data);
}

#endif