uniform sampler2D texture;
// Pattern scrolling inside the silhouette of the creature
uniform sampler2D patternTexture;
// Size of the pattern in pixels
uniform vec2 patternSize;
// Size of the creature in pixels
uniform vec2 spriteSize;
// Scrolling offset of the pattern in pixels
uniform vec2 patternOrigin;
// How much of the pattern shows over the creature
uniform float patternOpacity;
#ifdef GL_ES
varying vec2 v_factor_npot;
#else
const vec2 v_factor_npot = vec2(1.0, 1.0);
#endif

void main() {
  // The layer shares the texture of the creature it dresses, so that alpha is the silhouette
  float silhouette = texture2D(texture, gl_TexCoord[0].xy).a;
  // Tile the pattern over the creature, the way the engine plane shader tiles its own
  vec2 spriteCoord = gl_TexCoord[0].xy * v_factor_npot * spriteSize;
  vec2 patternCoord = mod(patternOrigin + spriteCoord, patternSize) / patternSize;
  vec4 frag = vec4(texture2D(patternTexture, patternCoord).rgb, silhouette * patternOpacity);
  gl_FragColor = frag;
}
