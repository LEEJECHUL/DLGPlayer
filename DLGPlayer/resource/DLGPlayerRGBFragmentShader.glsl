varying highp vec2 v_texcoord;
uniform highp float f_brightness;
uniform sampler2D s_texture;

void main() {
    highp vec4 texture = texture2D(s_texture, v_texcoord);
    highp vec3 black = vec3(0, 0, 0);
    
    gl_FragColor = vec4(mix(black, texture.rgb, f_brightness), 1);
}
