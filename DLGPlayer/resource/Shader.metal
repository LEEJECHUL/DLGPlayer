//
//  YCbCr-Shader.metal
//  DLGPlayer
//
//  Created by KWANG HYOUN KIM on 20/08/2019.
//  Copyright © 2019 KWANG HYOUN KIM. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void YUVColorConversion(constant float *brightness [[buffer(0)]],
                               texture2d<uint, access::read> yTexture [[texture(0)]],
                               texture2d<uint, access::read> uTexture [[texture(1)]],
                               texture2d<uint, access::read> vTexture [[texture(2)]],
                               texture2d<float, access::write> outTexture [[texture(3)]],
                               uint2 gid [[thread_position_in_grid]])
{
    float3 colorOffset = float3(0, -0.5, -0.5);
    float3x3 colorMatrix = float3x3(
                                    float3(1, 1, 1),
                                    float3(0, -0.344, 1.770),
                                    float3(1.403, -0.714, 0)
                                    );
    
    uint2 uvCoords = uint2(gid.x / 2, gid.y / 2);
    
    float y = yTexture.read(gid).r / 255.0;
    float u = uTexture.read(uvCoords).r / 255.0;
    float v = vTexture.read(uvCoords).r / 255.0;
    
    float3 yuv = float3(y, u, v);
    float3 rgb = colorMatrix * (yuv + colorOffset);
    float3 black = float3(0, 0, 0);
    float3 mixed = mix(black, rgb, *brightness);
    
    outTexture.write(float4(mixed, 1.0), gid);
}

kernel void RGBColorConversion(constant float *brightness [[buffer(0)]],
                               texture2d<uint, access::read> texture [[texture(0)]],
                               texture2d<float, access::write> outTexture [[texture(3)]],
                               uint2 gid [[thread_position_in_grid]])
{
    float r = texture.read(gid).r / 255.0;
    float g = texture.read(gid).g / 255.0;
    float b = texture.read(gid).b / 255.0;
    float3 rgb = float3(r, g, b);
    float3 black = float3(0, 0, 0);
    float3 mixed = mix(black, rgb, *brightness);
    
    outTexture.write(float4(mixed, 1.0), gid);
}
