varying highp vec2 v_texcoord;
uniform highp float f_brightness;
uniform sampler2D s_texture_y;
uniform sampler2D s_texture_u;
uniform sampler2D s_texture_v;

void main() {
    highp float y = texture2D(s_texture_y, v_texcoord).r;
    highp float u = texture2D(s_texture_u, v_texcoord).r - 0.5;
    highp float v = texture2D(s_texture_v, v_texcoord).r - 0.5;
    
    highp float r = y + 1.402 * v;
    highp float g = y - 0.344 * u - 0.714 * v;
    highp float b = y + 1.772 * u;
    highp vec3 rgb = vec3(r, g, b);
    highp vec3 black = vec3(0, 0, 0);
    
    gl_FragColor = vec4(mix(black, rgb, f_brightness), 1);
}
