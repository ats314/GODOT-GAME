# Renderers, rendering, and shaders in Godot 4.7

Which of the three renderers to ship, what each one costs, and the parts of the rendering stack an agent
gets wrong most often: `WorldEnvironment` and glow, HDR in 2D, `CanvasItem` materials vs
`ShaderMaterial`, the shading language and its uniform hints, 2D lights and normal maps, `SubViewport`,
texture filter/repeat, MSDF fonts, and anti-aliasing. Read this before choosing
`rendering/renderer/rendering_method`, before writing any `.gdshader`, and before proposing a
screen-reading effect.

Scope: **Godot 4.7.1 stable, desktop PC (Windows + Linux + Steam Deck), sold on Steam.** Every API name
in backticks was checked against `third_party/godot-class-reference/classes/*.xml`. Manual citations are
paths under `third_party/godot-docs/`. Sibling guides: `library/guides/performance.md` (frame budget,
servers API, pipeline stutter), `library/guides/api-changes-and-traps.md` (3.x → 4.x).

## 1. The renderer decision

Three renderers ship in 4.7. Source: `tutorials/rendering/renderers.rst`.

| | Compatibility | Mobile | Forward+ |
|---|---|---|---|
| `rendering_method` string | `gl_compatibility` | `mobile` | `forward_plus` |
| Driver | OpenGL 3.3 | Vulkan / D3D12 / Metal | Vulkan / D3D12 / Metal |
| Backend | — | RenderingDevice | RenderingDevice |
| Lighting | Forward single-pass, shadowed lights multi-pass | Forward single-pass | Clustered forward |
| Base cost / scaling cost | Low / high | Medium / medium | Highest / low |
| Colour precision | RGBA8 | RGB10A2 (RGBA16F if HDR 2D on) | RGBA16F |
| Depth | 24-bit, no reverse Z | 24-bit, reverse Z | 32-bit, reverse Z |

`rendering/renderer/rendering_method` defaults to `"forward_plus"` in `ProjectSettings`. The `.mobile`
and `.web` overrides exist in the engine defaults; we have no mobile or web export, so ignore both.

### What only Forward+ has

`VoxelGI`, SDFGI (`Environment.sdfgi_enabled`), SSIL (`ssil_enabled`), screen-space reflections
(`ssr_enabled`), volumetric fog (`volumetric_fog_enabled`), sub-surface scattering on `BaseMaterial3D`,
`hint_normal_roughness_texture`, PCSS soft shadows for `DirectionalLight3D`, TAA (`Viewport.use_taa`),
FSR2 (`Viewport.SCALING_3D_MODE_FSR2`), unlimited `ReflectionProbe` per mesh, 512 lights per cluster
instead of 8 per mesh.

### What Mobile still has (i.e. what Forward+ does *not* uniquely buy you)

Decals, `LightmapGI`, particle trails, particle SDF collision, DOF blur, debanding, variable rate
shading, MSAA 2D, FXAA, SMAA, glow with the full property set, HDR 2D, HDR output, `CompositorEffect`,
compute shaders, `RenderingDevice` access, PCSS for `OmniLight3D`/`SpotLight3D`, light projector
textures.

### What Compatibility loses that matters to us

No MSAA 2D, no FXAA, no SMAA, no TAA, no debanding, no HDR 2D, no HDR output, no `CompositorEffect`, no
compute shaders, no `RenderingDevice`, no decals, no DOF, and a cut-down glow implementation missing
**Levels, Normalized, Strength, Blend Mode, Mix, Map, Map Strength**. It also cannot use
ubershaders/pipeline precompilation, so it is back to the Godot-3-era "show every material for one frame
during loading" trick (`tutorials/performance/pipeline_compilations.rst`).

### Recommendation

**Ship Forward+ unless a Deck profile says otherwise; keep Mobile as the tested
fallback; do not ship Compatibility.**

Reasoning, tied to the table above:

- Forward+ has the *lowest scaling cost*. Its higher base cost is a fixed per-frame
  tax; on a scene with many lights or many materials it wins back more than it spends.
- Forward+ is where new features land first, and RGBA16F + 32-bit depth removes a whole
  class of banding and z-fighting bugs before they are written.
- The Deck is our weakest promised machine. Forward+ runs on it (RDNA2 is a Vulkan
  device), but the *fixed* base cost is the part a handheld power envelope punishes.
  If the art direction never uses SDFGI/VoxelGI/SSR/SSIL/volumetric fog, Mobile gives
  the same picture for a smaller constant, and Mobile's RGB10A2 buffer is upgraded to
  RGBA16F automatically once HDR 2D is enabled.
- Compatibility only makes sense for hardware without Vulkan/D3D12/Metal. Steam's
  hardware floor and the Deck are both well past that.

Decide once, write it in `project.godot`, and re-measure on Deck hardware before locking art direction —
the renderer changes what materials and environments are even available, so switching late is an
art-content migration, not a checkbox.

### Fallbacks and runtime detection

Since 4.4, Forward+/Mobile fall back Vulkan ⇄ D3D12, then to Compatibility if no RenderingDevice backend
works. Controlled by `rendering/rendering_device/fallback_to_vulkan`, `..._to_d3d12`, `..._to_opengl3`
(all `true` by default) and `rendering/gl_compatibility/fallback_to_angle`, `..._to_gles`,
`..._to_native`. **Fallback means the player may be running a renderer you never tested.** Detect it and
degrade deliberately:

```gdscript
var method := RenderingServer.get_current_rendering_method()   # "forward_plus" | "mobile" | "gl_compatibility"
var driver := RenderingServer.get_current_rendering_driver_name()  # "vulkan" | "d3d12" | "metal" | "opengl3"
var gpu    := RenderingServer.get_video_adapter_name()
var info   := OS.get_video_adapter_driver_info()  # PackedStringArray: [name, version]
if method == "gl_compatibility":
    $WorldEnvironment.environment.glow_enabled = false
```

Engine default for `rendering/rendering_device/driver.windows` in the class reference is `"vulkan"`.
`tutorials/rendering/hdr_output.rst` states that projects *created* in 4.6+ have it set to `d3d12` in
their `project.godot`; that is a project-template value, not the engine default. HDR output on Windows
requires `d3d12`.

## 2. `WorldEnvironment`, glow, and tonemapping

`WorldEnvironment` is a node with three resource slots: `environment` (`Environment`),
`camera_attributes` (`CameraAttributes`), `compositor` (`Compositor`). One per viewport; a `Camera3D`'s
own `environment` overrides it.

### Glow properties (all on `Environment`, defaults from the 4.7.1 class reference)

| Property | Default | Note |
|---|---|---|
| `glow_enabled` | `false` | Invisible until threshold or bloom kicks in |
| `glow_intensity` | `0.3` | Overall scale |
| `glow_strength` | `1.0` | Gaussian kernel strength; prefer levels |
| `glow_bloom` | `0.0` | >0 sends the *whole* screen through glow |
| `glow_blend_mode` | `1` | `GLOW_BLEND_MODE_SCREEN`. See warning below |
| `glow_mix` | `0.05` | Only used with `GLOW_BLEND_MODE_MIX` |
| `glow_hdr_threshold` | `1.0` | Lower ⇒ more pixels bleed |
| `glow_hdr_scale` | `2.0` | Scales light above threshold |
| `glow_hdr_luminance_cap` | `12.0` | Set to `1.0` for the screen-blur trick |
| `glow_normalized` | `false` | Enable for uniform blur |
| `glow_levels/1` … `glow_levels/7` | `0.0, 0.8, 0.4, 0.1, 0.0, 0.0, 0.0` | Small index = tight glow |
| `glow_map`, `glow_map_strength` | `null`, `0.8` | Lens-dirt / gradient masking |

Also `set_glow_level(idx, intensity)` / `get_glow_level(idx)`.

Blend modes: `GLOW_BLEND_MODE_ADDITIVE` `0`, `_SCREEN` `1`, `_SOFTLIGHT` `2`, `_REPLACE` `3`, `_MIX`
`4`.

> **Doc/engine discrepancy.** `tutorials/3d/environment_and_post_processing.rst` says
> Softlight is the default blend mode. The 4.7.1 class reference says
> `glow_blend_mode = 1`, i.e. **Screen**. Trust the class reference and set the property
> explicitly rather than relying on either.

**Real cost.** Glow is a multi-level downsample/blur/upsample chain over the whole
frame. Its price scales with output resolution and with the number of non-zero `glow_levels`, not with
scene complexity — so it is a fixed per-frame tax exactly where a handheld is weakest.
`rendering/environment/glow/upscale_mode` defaults to `1` (bicubic) on desktop and `0` (bilinear) via
the `.mobile` override; bicubic looks better and costs more, and the manual explicitly calls that cost
"significant on integrated graphics". If the Deck is tight, dropping to bilinear and to a single
non-zero level is the first lever. The setting has no effect under Compatibility, which uses a different
glow implementation entirely.

Tonemapper enum: `TONE_MAPPER_LINEAR` `0`, `_REINHARDT` `1`, `_FILMIC` `2`, `_ACES` `3`, `_AGX` `4`,
with `tonemap_exposure`, `tonemap_white`, `tonemap_agx_contrast` (`1.25`), `tonemap_agx_white`
(`16.29`). Colour grading lives in `adjustment_enabled`, `adjustment_brightness/contrast/saturation`,
`adjustment_color_correction`.

### HDR in 2D

`rendering/viewport/hdr_2d` (project setting, `false` by default) and `Viewport.use_hdr_2d`
(per-viewport). Forward+ and Mobile only. Added in 4.2. Requires an editor restart.

What it buys: overbright `modulate` / `self_modulate` values (Intensity slider in the colour picker)
drive glow per-node, and 2D banding drops.

What it changes, and this is the trap: **the 2D renderer switches to linear colour space.**
Consequences:

- Every `sampler2D` uniform used as colour input in a `canvas_item` shader **must**
  carry `source_color`, or it renders washed out.
- Alpha blending changes. Low-opacity sprites become more visible and font antialiasing
  reads bolder.
- Under Mobile the viewport buffer is promoted RGB10A2 → RGBA16F, so the memory cost is
  real.

Without HDR 2D you can still get 2D glow: set `Environment.background_mode` to `BG_CANVAS` (`3`), lower
`glow_hdr_threshold`, and keep UI out of it by putting UI under a `CanvasLayer` above
`Environment.background_canvas_max_layer`.

### HDR *output* (HDR monitors) — desktop-relevant, not the same thing

`tutorials/rendering/hdr_output.rst`. Supported on Windows and Linux/Wayland (not X11). Needs: Forward+
or Mobile; `d3d12` on Windows; `display/window/hdr/request_hdr_output` plus
`Window.hdr_output_requested`; HDR 2D on for every `SubViewport`/`Window` involved. Incompatible with
tonemap Filmic/ACES, `GLOW_BLEND_MODE_SOFTLIGHT`, and `adjustment_color_correction`. Working example
vendored at `third_party/godot-demo-projects/misc/hdr_output`.

## 3. `CanvasItemMaterial` vs `ShaderMaterial`

`CanvasItemMaterial` is the no-shader option for 2D. Two properties that matter:

- `blend_mode`: `BLEND_MODE_MIX` `0`, `_ADD` `1`, `_SUB` `2`, `_MUL` `3`,
  `_PREMULT_ALPHA` `4`.
- `light_mode`: `LIGHT_MODE_NORMAL` `0`, `_UNSHADED` `1`, `_LIGHT_ONLY` `2`.

Plus `particles_animation`, `particles_anim_h_frames`, `particles_anim_v_frames`, `particles_anim_loop`
for sprite-sheet particles.

Use it whenever additive/multiply blending or unshaded is all you need — a `CanvasItemMaterial` compiles
nothing extra, whereas each distinct `ShaderMaterial` program is a pipeline the driver has to build (see
§12). Additive `Sprite2D` + `CanvasItemMaterial` is also the documented cheap substitute for short-lived
`PointLight2D` effects such as muzzle flashes.

`ShaderMaterial` has exactly `shader`, `set_shader_parameter(param, value)`,
`get_shader_parameter(param)`. `CanvasItem.use_parent_material` lets children reuse the parent's
material instead of allocating their own.

```gdscript
var mat := ShaderMaterial.new()
mat.shader = preload("res://fx/dissolve.gdshader")
mat.set_shader_parameter("progress", 0.0)   # name must match the uniform EXACTLY
$Sprite2D.material = mat
```

## 4. The shading language

### `shader_type` values (all six, from `Shader.Mode`)

| `shader_type` | `Shader.Mode` | Processor functions |
|---|---|---|
| `canvas_item` | `MODE_CANVAS_ITEM` `1` | `vertex()`, `fragment()`, `light()` |
| `spatial` | `MODE_SPATIAL` `0` | `vertex()`, `fragment()`, `light()` |
| `particles` | `MODE_PARTICLES` `2` | `start()`, `process()` — **not** `vertex()` |
| `sky` | `MODE_SKY` `3` | `sky()` |
| `fog` | `MODE_FOG` `4` | `fog()` |
| `texture_blit` | `MODE_TEXTURE_BLIT` `5` | `blit()` |

`texture_blit` drives `DrawableTexture2D.blit_rect()` — see `tutorials/rendering/drawable_textures.rst`
and `tutorials/shaders/shader_reference/texture_blit_shader.rst`.

File extension is `.gdshader` (`.shader` was removed in 4.0). Includes are `ShaderInclude` resources,
conventionally `.gdshaderinc`, pulled in with `#include`.

### Global built-ins (every shader type, every function)

`TIME` (float, seconds since engine start, **rolls over every 3600 s** —
`rendering/limits/time/time_rollover_secs`; affected by `Engine.time_scale`, not by pause), `PI`, `TAU`,
`E`.

If you need a `TIME` that ignores `time_scale`, make a global uniform and drive it yourself.

### Uniform hints — the complete verified list

From `tutorials/shaders/shader_reference/shading_language.rst`. Nothing outside this table is a valid
hint in 4.7.

| Type | Hint |
|---|---|
| `vec3`, `vec4` | `source_color` |
| `int` | `hint_enum("A", "B")` or `hint_enum("Slow:30", "Fast:200")` |
| `int`, `float` | `hint_range(min, max[, step])` |
| `sampler2D` | `source_color` |
| `sampler2D` | `hint_normal` |
| `sampler2D` | `hint_default_white`, `hint_default_black`, `hint_default_transparent` |
| `sampler2D` | `hint_anisotropy` |
| `sampler2D` | `hint_roughness_r`/`_g`/`_b`/`_a`/`_normal`/`_gray` |
| `sampler2D` | `filter_nearest`, `filter_linear`, `filter_nearest_mipmap`, `filter_linear_mipmap`, `filter_nearest_mipmap_anisotropic`, `filter_linear_mipmap_anisotropic` |
| `sampler2D` | `repeat_enable`, `repeat_disable` |
| `sampler2D` | `hint_screen_texture` |
| `sampler2D` | `hint_depth_texture` |
| `sampler2D` | `hint_normal_roughness_texture` — **Forward+ only** |

Syntax: hint first, default value second — `uniform vec4 tint : source_color = vec4(1.0);`

`source_color` is **required** in Forward+ and Mobile, and in `canvas_item` shaders whenever HDR 2D is
on. It is optional under Compatibility and with HDR 2D off. Always write it: it is correct in every
configuration.

Grouping: `group_uniforms MyGroup;` … `group_uniforms;` (subgroups via `group_uniforms A.B;`).

### Global uniforms

Declared in **Project Settings → Shader Globals**, then referenced as `global uniform vec4 my_color;`.
The setting must exist before the shader is saved or compilation fails; an inline default in the shader
is ignored.

```gdscript
RenderingServer.global_shader_parameter_set("my_color", Color(0.3, 0.6, 1.0))
RenderingServer.global_shader_parameter_add("wind", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color.WHITE)
RenderingServer.global_shader_parameter_remove("wind")
```

Setting is free (no CPU↔GPU sync). **`global_shader_parameter_get()` forces the rendering thread to
synchronise — never call it per frame.** Cache values in an autoload at the same time you set them.

### Per-instance uniforms

`instance uniform vec4 my_color : source_color = vec4(1.0);` — available in both `canvas_item` and
`spatial` shaders. Set at runtime with `GeometryInstance3D.set_instance_shader_parameter(name, value)`
or `CanvasItem.set_instance_shader_parameter(name, value)`.

Restrictions: no textures, no arrays; hard cap of **16 per shader**; with multi-material meshes the
first material's parameters win unless name, index and type all match — pin the slot with `instance
uniform vec4 c : source_color, instance_index(5);`.

### Varyings

`varying vec3 some_color;` written in `vertex()`, read in `fragment()`; also `fragment()` → `light()`.
Cannot be assigned inside a custom function or inside `light()`. `varying flat vec3 v;` disables
interpolation.

### Screen / depth textures — and how they changed in 4.x

Godot 3's magic `SCREEN_TEXTURE` and `DEPTH_TEXTURE` globals were **removed in 4.0**. The class
reference and shader reference both list them only as "Removed in Godot 4". Declare uniforms instead:

```glsl
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
    COLOR = textureLod(screen_texture, SCREEN_UV, 0.0);
}
```

- `textureLod(..., 0.0)` reads the sharp copy. To read a blurred mip you must *also*
  change the filter hint to one containing `mipmap` — otherwise a non-zero LOD silently
  looks identical to LOD 0.
- In 2D the back-buffer copy happens once, at the first node that uses
  `hint_screen_texture`. Two overlapping screen-reading nodes will both sample the same
  pre-copy image. Insert a `BackBufferCopy` node between them
  (`copy_mode`: `COPY_MODE_DISABLED` `0`, `COPY_MODE_RECT` `1`, `COPY_MODE_VIEWPORT` `2`).
- In 3D the copy happens after opaque and before transparent geometry, so transparent
  objects are never in the screen texture — and a material using `hint_screen_texture`
  is itself treated as transparent, so it never appears in another material's copy.

Full-screen post-processing: `CanvasLayer` → `ColorRect` anchored Full Rect with a `ShaderMaterial`.
Works on all three renderers. `CompositorEffect` (Forward+/Mobile only) is the lower-level alternative;
example at `third_party/godot-demo-projects/compute/post_shader`.

### `canvas_item` built-ins worth knowing

`vertex()`: `VERTEX` (inout, local pixel coords), `UV`, `COLOR`, `MODEL_MATRIX`, `CANVAS_MATRIX`,
`SCREEN_MATRIX`, `TEXTURE_PIXEL_SIZE`, `INSTANCE_ID`, `INSTANCE_CUSTOM`, `VERTEX_ID`, `POINT_SIZE`,
`CUSTOM0`, `CUSTOM1`.

`fragment()`: `COLOR` (in *and* out), `UV`, `SCREEN_UV`, `FRAGCOORD`, `SCREEN_PIXEL_SIZE`, `TEXTURE`,
`TEXTURE_PIXEL_SIZE`, `NORMAL`, `NORMAL_TEXTURE`, `NORMAL_MAP`, `NORMAL_MAP_DEPTH`,
`SPECULAR_SHININESS`, `SPECULAR_SHININESS_TEXTURE`, `VERTEX`, `LIGHT_VERTEX`, `SHADOW_VERTEX`,
`REGION_RECT`, `POINT_COORD`.

`light()`: `LIGHT` (out), `LIGHT_COLOR`, `LIGHT_ENERGY`, `LIGHT_POSITION`, `LIGHT_DIRECTION`,
`LIGHT_IS_DIRECTIONAL`, `LIGHT_VERTEX`, `SHADOW_MODULATE`, `NORMAL`, `COLOR`, `UV`, `SCREEN_UV`,
`TEXTURE`, `TEXTURE_PIXEL_SIZE`, `SPECULAR_SHININESS`, `FRAGCOORD`, `POINT_COORD`.

`AT_LIGHT_PASS` still exists but is **always `false`** in 4.x — in Godot 3 objects were redrawn per
light; in 4.x all lighting happens in the regular draw pass. Any remembered `if (AT_LIGHT_PASS)` branch
is dead code. Defining `light()` at all replaces the built-in lighting, even if the body is empty.
`render_mode unshaded;` skips it; `light_only;` draws only where light reaches.

Render modes (`canvas_item`): `blend_mix` (default), `blend_add`, `blend_sub`, `blend_mul`,
`blend_premul_alpha`, `blend_disabled`, `unshaded`, `light_only`, `skip_vertex_transform`,
`world_vertex_coords`.

SDF functions, usable in `fragment()` and `light()`, fed by `LightOccluder2D` nodes with `sdf_collision`
enabled: `texture_sdf(vec2)`, `texture_sdf_normal(vec2)`, `sdf_to_screen_uv(vec2)`,
`screen_uv_to_sdf(vec2)`.

### `spatial` built-ins worth knowing

Fragment outputs: `ALBEDO`, `ALPHA`, `ALPHA_SCISSOR_THRESHOLD`, `ALPHA_HASH_SCALE`,
`ALPHA_ANTIALIASING_EDGE`, `METALLIC`, `SPECULAR`, `ROUGHNESS`, `EMISSION`, `NORMAL`, `NORMAL_MAP`,
`NORMAL_MAP_DEPTH`, `BENT_NORMAL_MAP`, `AO`, `AO_LIGHT_AFFECT`, `RIM`, `RIM_TINT`, `CLEARCOAT`,
`CLEARCOAT_ROUGHNESS`, `ANISOTROPY`, `ANISOTROPY_FLOW`, `BACKLIGHT`, `SSS_STRENGTH`,
`SSS_TRANSMITTANCE_*`, `FOG`, `RADIANCE`, `IRRADIANCE`, `PREMUL_ALPHA_FACTOR`, `DEPTH`.

Matrices (renamed from Godot 3 — this is the single most common hallucination): `MODEL_MATRIX`,
`MODEL_NORMAL_MATRIX`, `VIEW_MATRIX`, `INV_VIEW_MATRIX`, `MAIN_CAM_INV_VIEW_MATRIX`,
`PROJECTION_MATRIX`, `INV_PROJECTION_MATRIX`, `MODELVIEW_MATRIX`. Godot 3's `WORLD_MATRIX`,
`INV_CAMERA_MATRIX` and `CAMERA_MATRIX` do not exist. Prefer `MODELVIEW_MATRIX` when objects sit far
from the world origin — splitting into `MODEL_MATRIX * VIEW_MATRIX` invites float precision loss.

### Godot 3 → 4 shader traps

| Godot 3 | Godot 4.7 |
|---|---|
| `.shader` | `.gdshader` |
| `hint_albedo`, `hint_color` | `source_color` |
| `SCREEN_TEXTURE` | `uniform sampler2D … : hint_screen_texture` |
| `DEPTH_TEXTURE` | `uniform sampler2D … : hint_depth_texture` |
| filter/repeat set on the imported texture | set per-uniform hint, or per-`CanvasItem` |
| `particles` used `vertex()` | `start()` and `process()` |
| NDC z-range `[-1, 1]` | `[0, 1]` in Forward+/Mobile. Reconstruct as `vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);` (Compatibility keeps the 3.x range) |
| forward depth buffer | reverse Z since 4.3 — breaks hand-rolled depth maths |

## 5. 2D lights, shadows, normal maps

Nodes: `CanvasModulate` (ambient/darkening base), `PointLight2D`, `DirectionalLight2D`,
`LightOccluder2D` (+ `OccluderPolygon2D`). `tutorials/2d/2d_lights_and_shadows.rst`.

Without a `CanvasModulate`, lights only brighten an already fully-lit scene.

`Light2D` (base of both lights): `enabled`, `editor_only`, `color`, `energy`, `blend_mode`
(`BLEND_MODE_ADD` `0`, `_SUB` `1`, `_MIX` `2`), `shadow_enabled`, `shadow_color`, `shadow_filter`
(`SHADOW_FILTER_NONE` `0`, `_PCF5` `1`, `_PCF13` `2`), `shadow_filter_smooth`, `shadow_item_cull_mask`,
`range_item_cull_mask`, `range_z_min` (`-1024`), `range_z_max` (`1024`), `range_layer_min`,
`range_layer_max`.

`PointLight2D` adds `texture`, `texture_scale`, `offset`, `height`. `DirectionalLight2D` adds `height`,
`max_distance`. `LightOccluder2D`: `occluder`, `occluder_light_mask`, `sdf_collision` (`true`).

Cost order: `SHADOW_FILTER_NONE` ≪ `PCF5` < `PCF13`. PCF13 is for a handful of lights, not a scene full
of them. Light cost scales with screen area covered, so `texture_scale` is a performance dial.

**Normal and specular maps in 2D go through `CanvasTexture`**, not through separate
node properties. Assign a `CanvasTexture` to the node's texture slot, then fill `diffuse_texture`,
`normal_texture`, `specular_texture`, `specular_color`, `specular_shininess`; it also carries its own
`texture_filter` / `texture_repeat` overrides. After enabling normal mapping, raise the light's `height`
— at the default `0.0` normal mapping is nearly invisible.

In a shader, a 3D-authored normal map must be assigned to `NORMAL_MAP`, not `NORMAL`; Godot converts and
overwrites `NORMAL` for you:

```glsl
NORMAL_MAP = texture(NORMAL_TEXTURE, UV).rgb;
```

**Pixel-art lighting.** Lighting is computed at *viewport pixel* resolution, not at the
sprite's texel resolution, so nearest filtering does nothing for blocky lights. Snap it in a shader:

```glsl
shader_type canvas_item;
uniform float pixel_size = 4.0;

void fragment() {
    LIGHT_VERTEX.xy = floor(LIGHT_VERTEX.xy / pixel_size) * pixel_size;
    SHADOW_VERTEX  = floor(SHADOW_VERTEX  / pixel_size) * pixel_size;
    COLOR = texture(TEXTURE, UV);
}
```

## 6. Viewports and `SubViewport`

A `SubViewport` is a render target; `get_texture()` returns a `ViewportTexture`. Uses: 3D-in-2D,
2D-in-3D, procedural textures, split screen, render-to-texture UI.

Key `SubViewport` properties: `size` (`Vector2i(512, 512)`), `size_2d_override`,
`size_2d_override_stretch`, `render_target_update_mode` (`UPDATE_DISABLED` `0`, `UPDATE_ONCE` `1`,
`UPDATE_WHEN_VISIBLE` `2` = default, `UPDATE_WHEN_PARENT_VISIBLE` `3`, `UPDATE_ALWAYS` `4`),
`render_target_clear_mode` (`CLEAR_MODE_ALWAYS` `0`, `CLEAR_MODE_NEVER` `1`, `CLEAR_MODE_ONCE` `2`).

**`UPDATE_ALWAYS` on a `SubViewport` you only need occasionally is a silent frame-rate
sink** — it re-renders a whole scene every frame. `UPDATE_ONCE` for static bakes, `UPDATE_WHEN_VISIBLE`
otherwise.

`SubViewport`s do not receive input unless parented to a `SubViewportContainer` (`stretch`,
`stretch_shrink`, `mouse_target`). Per-viewport render settings live on `Viewport`: `msaa_2d`,
`msaa_3d`, `screen_space_aa`, `use_taa`, `use_debanding`, `use_hdr_2d`, `scaling_3d_mode`,
`scaling_3d_scale`, `fsr_sharpness`, `canvas_item_default_texture_filter`,
`canvas_item_default_texture_repeat`, `texture_mipmap_bias`, `anisotropic_filtering_level`,
`snap_2d_transforms_to_pixel`, `snap_2d_vertices_to_pixel`, `transparent_bg`, `debug_draw`,
`sdf_oversize`, `sdf_scale`.

Vendored examples: `third_party/godot-demo-projects/viewport/` — `2d_in_3d`, `3d_in_2d`, `3d_scaling`,
`gui_in_3d`, `dynamic_split_screen`, `split_screen_input`, `screen_capture`.

## 7. Texture filter / repeat, and pixel-art settings

Three levels, most specific wins: uniform hint in the shader → the `CanvasItem` (or `CanvasTexture`)
property → the project setting.

`CanvasItem.texture_filter`: `TEXTURE_FILTER_PARENT_NODE` `0` (default), `_NEAREST` `1`, `_LINEAR` `2`,
`_NEAREST_WITH_MIPMAPS` `3`, `_LINEAR_WITH_MIPMAPS` `4`, `_NEAREST_WITH_MIPMAPS_ANISOTROPIC` `5`,
`_LINEAR_WITH_MIPMAPS_ANISOTROPIC` `6`.

`CanvasItem.texture_repeat`: `TEXTURE_REPEAT_PARENT_NODE` `0` (default), `_DISABLED` `1`, `_ENABLED`
`2`, `_MIRROR` `3`.

Project defaults: `rendering/textures/canvas_textures/default_texture_filter` = `1` and
`rendering/textures/canvas_textures/default_texture_repeat` = `0`. **These use a different enum from
`CanvasItem`** — `Viewport.DefaultCanvasItemTextureFilter` orders it `NEAREST` `0`, `LINEAR` `1`,
`LINEAR_WITH_MIPMAPS` `2`, `NEAREST_WITH_MIPMAPS` `3`, `PARENT_NODE` `4`; and
`DefaultCanvasItemTextureRepeat` orders it `DISABLED` `0`, `ENABLED` `1`, `MIRROR` `2`, `PARENT_NODE`
`3`. So the shipped defaults are **Linear filtering, repeat disabled**, and the same numeric value means
different things on `CanvasItem.texture_filter` vs `Viewport.canvas_item_default_texture_filter`. Never
copy an integer between the two.

**Pixel art project settings** (`tutorials/rendering/multiple_resolutions.rst`):

- Base window size = the intended internal resolution. `640×360` is the recommended
  baseline (integer-scales to 720p/1080p/1440p/4K with no bars).
- `display/window/stretch/mode` = `"viewport"`.
- `display/window/stretch/aspect` = `"keep"` (single ratio, black bars) or `"expand"`.
- `display/window/stretch/scale_mode` = `"integer"` (default is `"fractional"`).
- Set `rendering/textures/canvas_textures/default_texture_filter` to `0` (Nearest).
- `rendering/2d/snap/snap_2d_transforms_to_pixel` and
  `rendering/2d/snap/snap_2d_vertices_to_pixel` (both `false` by default) — the class
  reference points at these directly from the texture-filter setting. Per-viewport
  equivalents: `Viewport.snap_2d_transforms_to_pixel`, `snap_2d_vertices_to_pixel`.
- Texture import: disable VRAM compression and mipmaps for pixel-art textures.
- Use `canvas_items` stretch mode instead if you want sub-pixel sprite motion or a
  high-resolution 3D viewport under a low-resolution UI.

Non-pixel-art desktop: base `1920×1080`, stretch mode `canvas_items`, aspect `expand`.

## 8. MSDF fonts

Multi-channel signed distance field rendering: crisp at any size, rasterised once instead of per size.

Enable per font in the Import dock: `ResourceImporterDynamicFont`'s `multichannel_signed_distance_field`
(`false`), `msdf_size` (`48`), `msdf_pixel_range` (`8`). At runtime the loaded resource exposes
`FontFile.multichannel_signed_distance_field`, `FontFile.msdf_size` (`48`), `FontFile.msdf_pixel_range`
(`16`). Project-wide default font: `gui/theme/default_font_multichannel_signed_distance_field`.

Trade-offs, per `tutorials/ui/gui_using_fonts.rst`: higher baseline render cost, worse clarity at
*small* sizes (no hinting), no LCD subpixel optimisation, no antialiasing control, and fonts with
self-intersecting outlines render wrong. Wins: no re-rasterise on size change, no stutter at large
sizes, one cache entry per font instead of per font-size.

Good fit for a scaling desktop/Deck UI where the same font is drawn at many sizes. Poor fit for a
pixel-art bitmap-style UI.

Related draw APIs: `CanvasItem.draw_msdf_texture_rect_region(texture, rect, src_rect, modulate, outline,
pixel_range, scale)`, and `BaseMaterial3D.albedo_texture_msdf` / `msdf_pixel_range` /
`msdf_outline_size` for MSDF textures on 3D quads.

## 9. Anti-aliasing

| Technique | Compatibility | Mobile | Forward+ | Setting |
|---|---|---|---|---|
| MSAA 3D | ✔ | ✔ | ✔ | `rendering/anti_aliasing/quality/msaa_3d`, `Viewport.msaa_3d` |
| MSAA 2D | ✘ | ✔ | ✔ | `.../msaa_2d`, `Viewport.msaa_2d` |
| FXAA | ✘ | ✔ | ✔ | `.../screen_space_aa` = `SCREEN_SPACE_AA_FXAA` `1` |
| SMAA 1x | ✘ | ✔ | ✔ | `.../screen_space_aa` = `SCREEN_SPACE_AA_SMAA` `2` |
| TAA | ✘ | ✘ | ✔ | `.../use_taa`, `Viewport.use_taa` |
| FSR2 | ✘ | ✘ | ✔ | `Viewport.scaling_3d_mode` = `SCALING_3D_MODE_FSR2` `2` |
| SSAA (supersampling) | ✔ | ✔ | ✔ | `scaling_3d_scale` > 1.0 |
| Debanding | ✘ | ✔ | ✔ | `.../use_debanding` |

`MSAA` levels: `MSAA_DISABLED` `0`, `MSAA_2X` `1`, `MSAA_4X` `2`, `MSAA_8X` `3`. 2× or 4× recommended;
8× is called "not worth the cost" by the manual. `smaa_edge_detection_threshold` defaults to `0.05`.

MSAA touches geometry edges only. It does **not** help with: aliasing inside nearest-filtered pixel art,
aliasing produced by custom 2D shaders, `Light2D` specular aliasing, font antialiasing, alpha-scissor
transparency, or specular aliasing in 3D.

Cheapest 2D antialiasing is not MSAA at all: `Line2D.antialiased`, and the `antialiased: bool = false`
parameter on `draw_line`, `draw_polyline`, `draw_arc`, `draw_circle`, `draw_rect`, `draw_multiline`.
These generate extra geometry instead of paying a permanent buffer cost. `Polygon2D` and
`TextureProgressBar` have no such parameter — those need MSAA 2D.

**Resolution scaling** (`Viewport.scaling_3d_mode` / `rendering/scaling_3d/mode`):
`SCALING_3D_MODE_BILINEAR` `0`, `_FSR` `1`, `_FSR2` `2`, `_METALFX_SPATIAL` `3`, `_METALFX_TEMPORAL`
`4`, `_NEAREST` `5`. This is the lever to expose in the options menu for the Deck: it scales 3D
rendering while leaving the UI at native resolution. FSR2 supplies its own temporal AA and **overrides
`use_taa`**. FSR1 wants a separate AA alongside it. On weak GPUs the cost of FSR1/FSR2 itself can exceed
what bilinear saves — measure, do not assume.

**4.7 behaviour change:** `CanvasItem` no longer adds the antialiasing feather when
drawing lines (GH-105122). Lines that looked correct in 4.6 will render thinner; fix by increasing
`width`, not by re-adding the feather.

## 10. `RenderingServer` direct draws and `_draw()`

### Custom `_draw()`

`_draw()` runs once when the item enters the tree, then only when `CanvasItem.queue_redraw()` is called.
Never call `_draw()` yourself; never redraw every frame unless the content actually changes. Coordinates
are local to the item; use `draw_set_transform()` / `draw_set_transform_matrix()` to change that.

Available: `draw_line`, `draw_dashed_line`, `draw_multiline`, `draw_multiline_colors`, `draw_polyline`,
`draw_polyline_colors`, `draw_rect`, `draw_circle`, `draw_ellipse`, `draw_arc`, `draw_ellipse_arc`,
`draw_polygon`, `draw_colored_polygon`, `draw_primitive`, `draw_texture`, `draw_texture_rect`,
`draw_texture_rect_region`, `draw_msdf_texture_rect_region`, `draw_lcd_texture_rect_region`,
`draw_style_box`, `draw_mesh`, `draw_multimesh`, `draw_string`, `draw_string_outline`,
`draw_multiline_string`, `draw_char`, `draw_char_outline`, `draw_animation_slice`, `draw_end_animation`.

Note the width convention: `width = -1.0` (the default) means a fast single-pixel line; any explicit
width builds a quad and costs more.

### `RenderingServer` canvas items

For thousands of static sprites, skipping `Node2D` entirely is the documented win
(`tutorials/performance/using_servers.rst`; see also `library/guides/performance.md` §7).

```gdscript
extends Node2D

var texture: Texture2D  # RenderingServer needs you to keep the reference alive

func _ready() -> void:
    var ci := RenderingServer.canvas_item_create()
    RenderingServer.canvas_item_set_parent(ci, get_canvas_item())
    texture = load("res://sprite.png")
    RenderingServer.canvas_item_add_texture_rect(ci, Rect2(-texture.get_size() / 2, texture.get_size()), texture)
    RenderingServer.canvas_item_set_transform(ci, Transform2D().rotated(deg_to_rad(45)).translated(Vector2(20, 30)))
    RenderingServer.canvas_item_reset_physics_interpolation(ci)  # or it teleports in on frame 1
```

RIDs are not reference-counted. Free them with `RenderingServer.free_rid()` in `_exit_tree()` or they
leak for the process lifetime.

Other useful entry points: `canvas_item_set_material`, `canvas_item_set_modulate`,
`canvas_item_set_z_index`, `canvas_item_set_canvas_group_mode`, `canvas_item_set_copy_to_backbuffer`,
`canvas_item_add_multimesh`, `canvas_item_add_particles`, `RenderingServer.set_default_clear_color()`,
`RenderingServer.get_rendering_device()`.

## 11. What is already vendored — do not rewrite it

`library/code/shaders.tsv` indexes **55** shaders (path, `shader_type`, line count, uniform names). Grep
it before writing anything.

| Where | What |
|---|---|
| `third_party/godot-demo-projects/2d/screen_space_shaders/shaders/` | 11 `canvas_item` screen-space effects: `BCS`, `blur`, `contrasted`, `mirage`, `negative`, `normalized`, `old_film`, `pixelize`, `sepia`, `vignette`, `whirl` |
| `third_party/godot-demo-projects/2d/sprite_shaders/shaders/` | 10 sprite effects: `aura`, `blur`, `dissintegrate`, `dropshadow`, `fatty`, `glow`, `offsetshadow`, `outline`, `silouette` |
| `third_party/godot-demo-projects/3d/sky_shaders/` | volumetric cloud `sky` shader |
| `third_party/godot-demo-projects/3d/tonemap_color_correction/` | tonemapping + colour-correction reference scene |
| `third_party/godot-demo-projects/compute/post_shader/` | `CompositorEffect` post-processing (Forward+ only) |
| `third_party/godot-demo-projects/compute/texture/` | compute-driven water `spatial` shader |
| `third_party/godot-demo-projects/misc/hdr_output/` | HDR output settings UI to copy |
| `third_party/godot-demo-projects/2d/lights_and_shadows/`, `2d/light2d_as_mask/` | 2D lighting and light-as-mask |
| `third_party/godot-demo-projects/3d/variable_rate_shading/` | VRS density texture shader |
| `third_party/Terrain3D/project/addons/terrain_3d/extras/shaders/` | large production `spatial` terrain shaders (`lightweight` 455 lines, `minimum` 260, `ocean_shader`) |

**ShaderV** (`third_party/ShaderV/addons/shaderV/`) is a VisualShader node pack: **93
`VisualShaderNodeCustom` scripts** across `rgba/`, `uv/`, `tools/` — blurs, glows, noises (perlin
2D/3D/4D + fractal variants), shape generators, chromatic aberration, lens distortion, posterise,
pixelate, gradient mapping, emboss, colour-space helpers. Examples in
`third_party/ShaderV/addons/shaderV/examples/basic_examples.tscn`. Its `project.godot` declares feature
level **4.2**, not 4.7 — the custom-node API is unchanged as far as the class reference shows, but
nothing in this repo proves it loads clean in 4.7. Test before depending on it.

## 12. Shader/pipeline compilation stutter (Steam-facing)

Since 4.4, Forward+ and Mobile use **ubershaders + pipeline precompilation**: one general pipeline is
compiled at load time via specialisation constants, and optimised variants compile in background threads
during play. Compatibility has neither — it needs the old "display everything for one frame during
loading" workaround.

Precompilation only covers what the `RenderingServer` has *seen* by load time. Loading a mesh or shader
mid-game, or toggling MSAA / instancing a `VoxelGI` at runtime, forces new pipeline compilations — i.e.
a hitch on a first playthrough on the player's machine. Watch the pipeline-compilation monitors in the
debugger; you will not feel these hitches yourself once your driver cache is warm. Detail in
`tutorials/performance/pipeline_compilations.rst` and `library/guides/performance.md` §19.

## 13. What I could not verify offline

- **Steam Deck specifics.** No vendored Godot doc mentions the Steam Deck, its GPU, or a
  15 W envelope. The recommendation in §1 is derived from documented renderer cost
  characteristics ("Forward+: highest base cost, low scaling cost") applied to a
  handheld, plus `docs/PLATFORM_TARGETS.md`. Treat the Deck framing as engineering
  judgement, not a cited fact, and settle it by profiling on the device.
- **Absolute cost figures.** The manual gives no ms/frame numbers for glow, PCF13 2D
  shadows, MSAA levels, FSR1 vs FSR2, or MSDF vs rasterised fonts. Every "cost" claim
  here is directional.
- **Version each feature landed.** Verified from the vendored docs: HDR 2D in 4.2,
  FSR2 in 4.2, reverse Z in 4.3, ubershaders/pipeline precompilation and the renderer
  fallback chain in 4.4. Not verified: when SMAA, `hint_enum`, `instance_index`,
  `DrawableTexture2D`/`texture_blit`, `draw_ellipse`/`draw_ellipse_arc`, and
  `CanvasItem.set_instance_shader_parameter` were introduced — all exist in 4.7.1, but
  the vendored docs do not date them.
- **`Environment.glow_blend_mode` default.** Class reference says `1` (Screen); the
  manual page says Softlight. Not resolvable offline; set it explicitly.
- **ShaderV under 4.7.** Declares feature level 4.2; not run here.
