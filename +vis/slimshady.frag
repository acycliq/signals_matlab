#version 330

/*in vec3 fragmentColor;*/

in vec2 UV;

out vec4 color;

uniform vec4 maxColor;
uniform vec4 minColor;
uniform sampler2D myTextureSampler;

void main() 
{
    /*color = vec4(1.0f, 1.0f, 1.0f, 1.0f);*/
    /*color = fragmentColor;*/
    /*color = vec4(1.0f, 1.0f, 1.0f, 1.0f);*/
    /*vec2 scale;
    scale.x = 360/size.x;
    scale.y = 180/size.y;*/
    color = texture(myTextureSampler, UV).rgba;
    color = color*(maxColor - minColor) + minColor;
}