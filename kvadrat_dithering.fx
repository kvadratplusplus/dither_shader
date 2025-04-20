#include "ReShade.fxh"

uniform float spread = 0.1;
uniform int color_count
<
    ui_type = "slider";
    ui_min = 2;
    ui_max = 16;
> = 8;
uniform int height = 360;
uniform int width = 640;
uniform int current_matrix
<
    ui_type = "slider";
    ui_min = 0;
    ui_max = 3;
> = 2;
uniform float multiplier = 0.03;

uniform float sharpness = 0;

uniform float timer < source = "timer"; >;

float get_bayer2(int x, int y)
{
    static int bayer2[4] =
    {
        0, 2,
        3, 1
    };
    return float(bayer2[(x % 2) + (y % 2) * 2]) * (1.0f / 4.0f) - 0.5f;
}

float get_bayer4(int x, int y)
{
    static int bayer4[16] =
    {
        0, 8, 2, 10,
        12, 4, 14, 6,
        3, 11, 1, 9,
        15, 7, 13, 5
    };
    return float(bayer4[(x % 4) + (y % 4) * 4]) * (1.0f / 16.0f) - 0.5f;
}

float get_bayer8(int x, int y)
{
    static int bayer8[8 * 8] =
    {
        0, 32, 8, 40, 2, 34, 10, 42,
        48, 16, 56, 24, 50, 18, 58, 26,  
        12, 44,  4, 36, 14, 46,  6, 38, 
        60, 28, 52, 20, 62, 30, 54, 22,  
        3, 35, 11, 43,  1, 33,  9, 41,  
        51, 19, 59, 27, 49, 17, 57, 25, 
        15, 47,  7, 39, 13, 45,  5, 37, 
        63, 31, 55, 23, 61, 29, 53, 21
    };
    return float(bayer8[(x % 8) + (y % 8) * 8]) * (1.0f / 64.0f) - 0.5f;
}

float get_bayer8_time(int x, int y)
{
    static int bayer8[8 * 8] =
    {
        0, 32, 8, 40, 2, 34, 10, 42,
        48, 16, 56, 24, 50, 18, 58, 26,  
        12, 44,  4, 36, 14, 46,  6, 38, 
        60, 28, 52, 20, 62, 30, 54, 22,  
        3, 35, 11, 43,  1, 33,  9, 41,  
        51, 19, 59, 27, 49, 17, 57, 25, 
        15, 47,  7, 39, 13, 45,  5, 37, 
        63, 31, 55, 23, 61, 29, 53, 21
    };
    x += timer * multiplier;
    y += timer * multiplier;
    return float(bayer8[(x % 8) + (y % 8) * 8]) * (1.0f / 64.0f) - 0.5f;
}

float3 apply_sharpness(float3 col, float2 coord)
{
    float4 centerPixel = tex2D(ReShade::BackBuffer, coord);
    
    float2 offset = float2(1.0 / BUFFER_WIDTH, 1.0 / BUFFER_HEIGHT);
    
    float4 topPixel = tex2D(ReShade::BackBuffer, coord + float2(0.0, offset.y));
    float4 bottomPixel = tex2D(ReShade::BackBuffer, coord - float2(0.0, offset.y));
    float4 leftPixel = tex2D(ReShade::BackBuffer, coord - float2(offset.x, 0.0));
    float4 rightPixel = tex2D(ReShade::BackBuffer, coord + float2(offset.x, 0.0));
    
    float4 difference = (centerPixel - ((topPixel + bottomPixel + leftPixel + rightPixel) * 0.25)) * sharpness;

    return clamp(centerPixel + difference, 0.0, 1.0).xyz;
}

float3 apply_dithering(float3 col, float2 coord)
{
    int x = coord.x * width;
    int y = coord.y * height;

    float bayers[4];
    bayers[0] = get_bayer2(x, y);
    bayers[1] = get_bayer4(x, y);
    bayers[2] = get_bayer8(x, y);
    bayers[3] = get_bayer8_time(x, y);
    float3 output = col + spread * bayers[current_matrix];

    output.r = floor((color_count - 1.0f) * output.r + 0.5) / (color_count - 1.0f);
    output.g = floor((color_count - 1.0f) * output.g + 0.5) / (color_count - 1.0f);
    output.b = floor((color_count - 1.0f) * output.b + 0.5) / (color_count - 1.0f);

    return output;
}

float3 dither_func(float2 texcoord : TexCoord) : SV_Target
{
    float2 coord;
    coord.x = floor(texcoord.x * width) / width;
    coord.y = floor(texcoord.y * height) / height;

    float3 result = tex2D(ReShade::BackBuffer, coord).rgb;

    result = apply_sharpness(result, coord);
    result = apply_dithering(result, coord);

    return result;
}

technique kvadrat_dither
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = dither_func;
	}
}