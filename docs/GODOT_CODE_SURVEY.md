# Godot Code Survey — Deep Dive of Everything Vendored

A 13-agent survey of every project under `third_party/`: what each one
demonstrates, its most instructive files, and what we can concretely reuse
for building a polished 2D arcade game — plus a full license audit.
Engine used for validation: Godot 4.7.1-stable (headless imports).

Generated 2026-08-07 from the vendored snapshots recorded in `THIRD_PARTY_LICENSES.md`.

## How to use this document

Skim the **Top picks** blockquote at the head of each section first — those
are the highest-leverage projects. Every path is relative to `third_party/`.

## godot-demo-projects/2d (a-l)

> **Top picks:** 1) dodge_the_creeps — the only complete arcade game loop in the batch: spawn timers + Path2D edge spawning, CanvasLayer HUD wired by signals, start/game-over flow, music/SFX; use it as the structural skeleton (but note CC-BY music and CC0/OFL assets if shipping its media). 2) finite_state_machine — state.gd + state_machine.gd are generic, drop-in FSM infrastructure for player/enemy/game-flow states, with a pushdown stack and a debug state display. 3) bullet_shower — the PhysicsServer2D RID + batched _draw() technique is the right way to do bullet-hell-scale projectile counts without node overhead. 4) glow — the WorldEnvironment 2D glow setup plus the CanvasLayer-to-exempt-HUD trick delivers the cheap 'polished neon arcade' look. 5) kinematic_character (with dynamic_tilemap_layers' identical controller) — the cleanest minimal movement core (accel/stop-force/clamp/jump, moving and one-way platforms) if the game has platforming.

### Bullet Shower

`godot-demo-projects/2d/bullet_shower`

- **Shows:** Managing 500 bullets without nodes via low-level PhysicsServer2D (body_create, shape RIDs, body_set_state transforms, collision mask 0) plus batch rendering of all bullets in one CanvasItem _draw()/draw_texture loop with queue_redraw. Player is an Area2D following the mouse, reacting to body_shape_entered/exited signals.
- **Key files:** `godot-demo-projects/2d/bullet_shower/bullets.gd`, `godot-demo-projects/2d/bullet_shower/player.gd`, `godot-demo-projects/2d/bullet_shower/shower.tscn`
- **Reuse for our game:** Directly reusable pattern for high-count bullet/projectile systems (bullet-hell waves, particles-with-collision) at arcade scale: RID-based PhysicsServer2D bodies + single-node batched drawing; also shows required _exit_tree RID cleanup and Input.set_mouse_mode(MOUSE_MODE_HIDDEN).

### Custom Drawing in 2D

`godot-demo-projects/2d/custom_drawing`

- **Shows:** CanvasItem _draw() API: draw_line/draw_dashed_line/draw_circle/draw_arc/draw_polygon/draw_texture/text/mesh drawing, draw_set_transform, per-call antialiasing vs viewport msaa_2d toggle, @tool scripts so drawing previews in editor, animated redraw via queue_redraw each frame gated on is_visible_in_tree.
- **Key files:** `godot-demo-projects/2d/custom_drawing/lines.gd`, `godot-demo-projects/2d/custom_drawing/animation.gd`, `godot-demo-projects/2d/custom_drawing/custom_drawing.gd`, `godot-demo-projects/2d/custom_drawing/polygons.gd`
- **Reuse for our game:** Reusable for procedural HUD elements (circular progress/cooldown arcs via draw_arc as in animation.gd), debug overlays, laser/trail lines, and the antialiasing width-compensation tricks; the MSAA-2D toggle snippet is useful for a graphics options menu.

### Dodge the Creeps

`godot-demo-projects/2d/dodge_the_creeps`

- **Shows:** Complete minimal arcade game loop: timer-driven enemy spawning at random points along a Path2D/PathFollow2D (progress_ratio = randf()), RigidBody2D mobs that queue_free on VisibleOnScreenNotifier2D screen_exited, Area2D player with input-action 8-way movement clamped to viewport, CanvasLayer HUD with score label/messages/start button and signals, game-over/restart flow, AudioStreamPlayer music + death sound, call_group to clear mobs, keyboard+gamepad input map.
- **Key files:** `godot-demo-projects/2d/dodge_the_creeps/main.gd`, `godot-demo-projects/2d/dodge_the_creeps/hud.gd`, `godot-demo-projects/2d/dodge_the_creeps/player.gd`, `godot-demo-projects/2d/dodge_the_creeps/mob.gd`
- **Reuse for our game:** Highest direct relevance: the whole architecture (main game controller + spawn timers + Path2D edge spawner + CanvasLayer HUD via signals + start/game-over state + music/SFX players + group-based cleanup + set_deferred on collision shapes) is a lift-and-adapt skeleton for an arcade game; input map includes joypad bindings. No high-score persistence though.
- **License notes:** Music 'House In a Forest Loop.ogg' CC-BY 3.0 (HorrorPen, opengameart); art from Kenney 'Abstract Platformer' CC0 1.0; Xolonium font SIL OFL 1.1 (fonts/LICENSE.txt); code MIT (KidsCanCode)

### Drawable Textures

`godot-demo-projects/2d/drawable_textures`

- **Shows:** DrawableTexture2D (Godot 4.x GPU-writable texture): setup(), blit_rect() painting with GradientTexture2D radial brushes and arbitrary Texture2D stamps, eraser as background-colored brush, same texture shared as TextureRect content and 3D StandardMaterial3D albedo; gui_input-driven mouse painting.
- **Key files:** `godot-demo-projects/2d/drawable_textures/main.gd`, `godot-demo-projects/2d/drawable_textures/main.tscn`
- **Reuse for our game:** Niche but usable for persistent decals/splatter/scorch marks or fog-of-war style reveal effects (blit_rect stamping into a shared texture); otherwise low relevance to core arcade mechanics.

### Dynamic TileMap Layers

`godot-demo-projects/2d/dynamic_tilemap_layers`

- **Shows:** TileMapLayer runtime tile modification: _use_tile_data_runtime_update/_tile_data_runtime_update to strip collision polygons (fake secret walls), Area2D detector toggling layer self_modulate alpha fade with move_toward in _process, set_process(false) idle optimization; plus a compact CharacterBody2D platformer controller (accel/friction/gravity/jump).
- **Key files:** `godot-demo-projects/2d/dynamic_tilemap_layers/level/tile_map.gd`, `godot-demo-projects/2d/dynamic_tilemap_layers/player/player.gd`
- **Reuse for our game:** The alpha-fade-on-trigger pattern (move_toward + self_modulate + process toggling) is reusable for reveal effects; player.gd is a solid minimal platformer controller; runtime tile-data update useful only if the arcade game is tile-based.

### Hierarchical Finite State Machine

`godot-demo-projects/2d/finite_state_machine`

- **Shows:** Node-based generic FSM: base state.gd interface (enter/exit/handle_input/update, finished signal), state_machine.gd delegating _physics_process/_unhandled_input to current state with a pushdown states_stack ('previous' pops), hierarchical states (motion/on_ground/in_air), subclass override of _change_state for interrupt states (attack/stagger), plus bullet spawner, sword hit, health, and a debug states-stack UI displayer.
- **Key files:** `godot-demo-projects/2d/finite_state_machine/state_machine/state_machine.gd`, `godot-demo-projects/2d/finite_state_machine/state_machine/state.gd`, `godot-demo-projects/2d/finite_state_machine/player/player_state_machine.gd`, `godot-demo-projects/2d/finite_state_machine/player/player_controller.gd`
- **Reuse for our game:** The two generic files (state.gd, state_machine.gd) are drop-in reusable for player/enemy/game-flow state machines (idle/move/dash/stagger/die, or menu/playing/paused/game-over); the debug states_stack_displayer.gd is a handy dev overlay.

### Glow for 2D

`godot-demo-projects/2d/glow`

- **Shows:** 2D glow/bloom via WorldEnvironment (environment.glow_*), runtime toggling of glow_map (lens dirt) and glow_intensity from script, keeping UI unaffected by placing the Label on a separate CanvasLayer, mouse-drag panning via InputEventMouseMotion.screen_relative.
- **Key files:** `godot-demo-projects/2d/glow/beach_cave.gd`, `godot-demo-projects/2d/glow/beach_cave.tscn`
- **Reuse for our game:** Direct recipe for neon/glow arcade aesthetics: WorldEnvironment glow settings for 2D (needs Forward+/Mobile renderer), runtime glow parameter tweaks for effects, and the CanvasLayer-excludes-HUD-from-glow trick.

### Hexagonal Game

`godot-demo-projects/2d/hexagonal_map`

- **Shows:** Hexagonal TileMap/TileSet configuration (tileset_edit.tscn) and a CharacterBody2D moved with Input.get_axis plus velocity friction, with the y-axis scaled by tan(30 deg) to match hex geometry.
- **Key files:** `godot-demo-projects/2d/hexagonal_map/troll.gd`, `godot-demo-projects/2d/hexagonal_map/map.tscn`, `godot-demo-projects/2d/hexagonal_map/tileset_edit.tscn`
- **Reuse for our game:** Low relevance unless the game uses hex grids; the friction-based velocity movement snippet is trivially small.

### Instancing Demo

`godot-demo-projects/2d/instancing`

- **Shows:** PackedScene instancing on click: @export PackedScene, instantiate(), set global_position, add_child; _unhandled_input mouse-button filtering with is_echo/is_pressed checks; RigidBody2D balls.
- **Key files:** `godot-demo-projects/2d/instancing/ball_factory.gd`, `godot-demo-projects/2d/instancing/scene_instancing.tscn`
- **Reuse for our game:** Low relevance beyond the baseline spawn(position) factory pattern, which any spawner/wave system already implies; dodge_the_creeps covers this better.

### Isometric Game

`godot-demo-projects/2d/isometric`

- **Shows:** Isometric TileMap with Y-sort depth sorting and vertical tile offsets, StaticBody2D/CollisionPolygon2D colliders at object bases, 8-direction animation selection from movement angle (angle bucketing into 45-degree slices, AnimatedSprite2D play + flip_h), PointLight2D real-time shadows mixed with baked Polygon2D shading and a blob shadow sprite.
- **Key files:** `godot-demo-projects/2d/isometric/player/goblin.gd`, `godot-demo-projects/2d/isometric/dungeon.tscn`, `godot-demo-projects/2d/isometric/tileset/tileset_edit.tscn`
- **Reuse for our game:** The 8-directional animation picker in goblin.gd (angle -> anim table) is reusable for any top-down arcade character; iso-specific depth-sort/tile setup is low relevance unless going isometric.

### Kinematic Character 2D

`godot-demo-projects/2d/kinematic_character`

- **Shows:** CharacterBody2D platformer controller: Input.get_axis, accelerate/clamp/move_toward stop force, gravity from ProjectSettings, move_and_slide, is_on_floor jump; world scene includes moving platforms (AnimationPlayer-driven) and one-way collision platforms; trivial win-trigger via Area2D body_entered showing a label.
- **Key files:** `godot-demo-projects/2d/kinematic_character/player/player.gd`, `godot-demo-projects/2d/kinematic_character/world.tscn`, `godot-demo-projects/2d/kinematic_character/level/princess.gd`
- **Reuse for our game:** player.gd is a clean, copyable arcade platformer movement core (acceleration, stop friction, clamped max speed, jump); world.tscn shows moving-platform and one-way-platform setup.

### 2D Lights as Mask

`godot-demo-projects/2d/light2d_as_mask`

- **Shows:** Scriptless scene: PointLight2D nodes used as masks over a sprite via CanvasItemMaterial light_mode = 2 (mask mode), with light positions animated by an AnimationPlayer value track (cubic-eased keys).
- **Key files:** `godot-demo-projects/2d/light2d_as_mask/lightmask.tscn`
- **Reuse for our game:** Useful trick for spotlight/reveal effects (flashlight vision, reveal-on-proximity, stencil-like transitions) using Light2D + CanvasItemMaterial mask mode; otherwise narrow.

### 2D Lights and Shadows

`godot-demo-projects/2d/lights_and_shadows`

- **Shows:** PointLight2D and DirectionalLight2D with LightOccluder2D shadows; runtime toggling of lights via node groups (get_nodes_in_group) and cycling shadow_filter quality (wrapi) from _input actions.
- **Key files:** `godot-demo-projects/2d/lights_and_shadows/light_shadows.gd`, `godot-demo-projects/2d/lights_and_shadows/light_shadows.tscn`
- **Reuse for our game:** Recipe for 2D dynamic lighting/mood (muzzle flashes, glow pickups) and a graphics-options pattern for cycling shadow quality; group-based bulk light toggling is reusable.

## godot-demo-projects/2d (m-z)

> **Top picks:** 1) platformer - the closest thing to a complete Godot 4 game skeleton: copy-ready pause menu with tween fades and paused-tree handling, HUD coin counter wired by signal, gun cooldown/bullet spawning, tuned CharacterBody2D feel (move_toward accel, jump-cut, double jump with pitch-shifted SFX), fullscreen toggle, and local-2P input via action suffixes. 2) tween - single-file cookbook of every Tween pattern needed for arcade juice (pop-ups, blinks, elastic scaling, path-following, countdowns, pause/kill lifecycle). 3) particles - GPUParticles2D + ParticleProcessMaterial recipes (explosion, trails, subemitters, turbulence, emission masks) plus the 2D glow WorldEnvironment setup for a neon look. 4) sprite_shaders + screen_space_shaders (pair) - small drop-in .gdshader files covering hit-flash/outline/dissolve on sprites and vignette/pixelize/old-film full-screen post effects; cheapest route to visual polish. 5) navigation_astar - the best pathfinding reference if the arcade game has grid-based chasing enemies (AStarGrid2D config plus steering smoothing). License caution: the 'Pompy' music in platformer and physics_platformer has attribution but no stated license - replace it; everything else is MIT (skeleton's art assets are MIT but require third-party copyright attribution).

### Navigation Polygon 2D

`godot-demo-projects/2d/navigation`

- **Shows:** Click-to-move pathfinding with NavigationRegion2D + NavigationPolygon and a CharacterBody2D driven by NavigationAgent2D (target_position, get_next_path_position, is_navigation_finished, path/target_desired_distance tuning, debug_enabled).
- **Key files:** `godot-demo-projects/2d/navigation/character.gd`, `godot-demo-projects/2d/navigation/navigation.tscn`
- **Reuse for our game:** Minimal NavigationAgent2D movement loop (direction_to next path point * speed, move_and_slide) usable for enemies that chase the player around obstacles; also shows custom 'click' input action via _unhandled_input.

### Grid-based Navigation with AStarGrid2D

`godot-demo-projects/2d/navigation_astar`

- **Shows:** AStarGrid2D pathfinding over a TileMapLayer (region, cell_size, Manhattan heuristics, diagonal_mode, set_point_solid from get_used_cells), plus steering-behavior smoothing (desired velocity - velocity / mass) and path debug via _draw()/queue_redraw.
- **Key files:** `godot-demo-projects/2d/navigation_astar/pathfind_astar.gd`, `godot-demo-projects/2d/navigation_astar/character.gd`
- **Reuse for our game:** Drop-in AStarGrid2D setup for grid/maze arcade games (Pac-Man-style enemy pathing); steering arrive behavior for smooth homing movement; is_point_walkable and local_to_map/map_to_local snapping patterns; simple IDLE/FOLLOW state enum.

### Navigation Mesh Chunks 2D

`godot-demo-projects/2d/navigation_mesh_chunks`

- **Shows:** Runtime navmesh baking with NavigationServer2D: parse_source_geometry_data from static colliders, chunked baking via NavigationPolygon.baking_rect/border_size, edge merging without edge-connection margins, vertex snapping, and comparing NavigationAgent2D path postprocessing modes.
- **Key files:** `godot-demo-projects/2d/navigation_mesh_chunks/navmesh_chunks_demo_2d.gd`
- **Reuse for our game:** Low relevance unless the game has large/streamed worlds; the NavigationServer2D runtime-baking API calls are a useful reference if navmeshes must be rebuilt at runtime.

### 2D Particles

`godot-demo-projects/2d/particles`

- **Shows:** GPUParticles2D + ParticleProcessMaterial catalog: fire, smoke, flipbook animation, magic trails (trail_enabled/trail_lifetime), explosion, emission masks, subemitters (end-of-life and collision), turbulence, particle collision with LightOccluder2D/SDF, path-following emitters, WorldEnvironment 2D glow; also SceneTree pause toggle and Compatibility-renderer feature fallbacks.
- **Key files:** `godot-demo-projects/2d/particles/particles.tscn`, `godot-demo-projects/2d/particles/pause.gd`
- **Reuse for our game:** High value: ready-made ParticleProcessMaterial recipes to copy for explosions, engine trails, sparks, and pickups; 2D glow WorldEnvironment setup for neon arcade look; get_tree().paused toggle; group-based bulk tweaking of particles via get_nodes_in_group.

### Physics Platformer

`godot-demo-projects/2d/physics_platformer`

- **Shows:** RigidBody2D character controllers written inside _integrate_forces (PhysicsDirectBodyState2D contacts, floor detection via contact normals, moving-platform velocity compensation, variable-height jump via stop force), RigidBody2D bullets with collision exceptions, enemy contact/raycast edge detection, seesaw and one-way platforms.
- **Key files:** `godot-demo-projects/2d/physics_platformer/player/player.gd`, `godot-demo-projects/2d/physics_platformer/enemy/enemy.gd`, `godot-demo-projects/2d/physics_platformer/player/bullet.gd`
- **Reuse for our game:** Reference for fully physics-driven actors (rarely needed; CharacterBody2D is simpler), but the contact-normal floor test, add_collision_exception_with for bullets, CPUParticles2D muzzle smoke restart(), and AudioStreamPlayer2D SFX-per-action pattern transfer directly.
- **License notes:** Music 'Pompy' by Hubert Lamontagne (madbr), soundcloud attribution in README; license terms not stated - do not reuse the music without checking

### 2D Physics Tests

`godot-demo-projects/2d/physics_tests`

- **Shows:** A test harness for the 2D physics engine: menu-driven scene loader, functional tests (shapes, stacks, character on slopes/tilemap/pixels, one-way collision, joints, raycasting) and performance tests (broadphase, contacts), plus utility scripts: FPS/engine-version labels, log scroller, option menus, mouse rigidbody picking, parameterized CharacterBody2D controller.
- **Key files:** `godot-demo-projects/2d/physics_tests/utils/characterbody_controller.gd`, `godot-demo-projects/2d/physics_tests/test.gd`, `godot-demo-projects/2d/physics_tests/tests.gd`, `godot-demo-projects/2d/physics_tests/utils/rigidbody_pick.gd`
- **Reuse for our game:** Mostly low relevance as engine QA, but utils/ has liftable snippets: label_fps.gd for a debug FPS counter, a scene-picker menu pattern (tests_menu.gd + option_menu.gd), and characterbody_controller.gd as a tunable movement testbed (snap, floor_max_angle, stop_on_slope flags).

### 2D Platformer

`godot-demo-projects/2d/platformer`

- **Shows:** Complete Godot 4 game structure: CharacterBody2D player (Input.get_axis, move_toward acceleration, variable jump cut, double jump with pitch-shifted SFX, terminal velocity, floor_stop_on_slope via RayCast2D), gun with cooldown Timer and top-level bullets, raycast-driven patrol enemy, Area2D coin with signal to HUD, tween-animated pause menu with get_tree().paused and focus grab, camera limits, parallax background, fullscreen toggle, split-screen via two SubViewports sharing world_2d, action_suffix input remapping for 2 players, music and per-action audio.
- **Key files:** `godot-demo-projects/2d/platformer/player/player.gd`, `godot-demo-projects/2d/platformer/gui/pause_menu.gd`, `godot-demo-projects/2d/platformer/game.gd`, `godot-demo-projects/2d/platformer/player/gun.gd`
- **Reuse for our game:** Highest value in scope: pause_menu.gd (tween fade in/out, paused flag, gamepad focus) and game.gd (toggle_pause/toggle_fullscreen handling) are copy-paste ready; gun cooldown + set_as_top_level bullet spawn; coin signal -> coins_counter.gd HUD update; jump-cut and move_toward feel tuning; action_suffix pattern for local multiplayer.
- **License notes:** Music 'Pompy' by Hubert Lamontagne (madbr), soundcloud attribution in README; license terms not stated - do not reuse the music without checking

### 2D Polygons and Lines

`godot-demo-projects/2d/polygons_lines`

- **Shows:** Polygon2D and Line2D rendering (solid and textured), Line2D antialiasing via a gradient-edge texture trick, runtime 2D MSAA switching (get_viewport().msaa_2d) with Compatibility-renderer fallback detection.
- **Key files:** `godot-demo-projects/2d/polygons_lines/polygons_lines.gd`, `godot-demo-projects/2d/polygons_lines/polygons_lines.tscn`
- **Reuse for our game:** The AA-texture Line2D trick and msaa_2d option are directly useful for a vector/neon-styled arcade game (trails, laser beams, geometry outlines); otherwise low code content.

### Pong with GDScript

`godot-demo-projects/2d/pong`

- **Shows:** Minimal arcade game entirely with Area2D nodes and signals: paddle input via Input.get_action_strength difference with clamped position, ball speed ramping in _process, area_entered signal handlers on paddles/walls to deflect or reset the ball, per-node input action names derived from node name.
- **Key files:** `godot-demo-projects/2d/pong/logic/ball.gd`, `godot-demo-projects/2d/pong/logic/paddle.gd`, `godot-demo-projects/2d/pong/logic/wall.gd`
- **Reuse for our game:** Template-sized reference for signal-driven arcade collisions and 2-player input maps; ball reset() and progressive speed-up patterns are standard arcade mechanics. No score/HUD/audio, so it needs augmentation.

### Role Playing Game

`godot-demo-projects/2d/role_playing_game`

- **Shows:** Grid-based movement using a TileMapLayer as the collision authority (request_move with local_to_map/set_cell bookkeeping), JSON-driven dialogue player with started/finished signals, turn-based combat queue using awaited signals (await active_combatant.turn_finished), scene composition of exploration/dialogue/combat modes.
- **Key files:** `godot-demo-projects/2d/role_playing_game/grid_movement/grid/grid.gd`, `godot-demo-projects/2d/role_playing_game/combat/turn_queue.gd`, `godot-demo-projects/2d/role_playing_game/dialogue/dialogue_player/dialogue_player.gd`, `godot-demo-projects/2d/role_playing_game/game.gd`
- **Reuse for our game:** Mostly low relevance for arcade; the grid request_move pattern could serve a tile-based arcade game, and FileAccess+JSON loading in dialogue_player.gd is the same pattern used for saving/loading high scores.

### Screen Space Shaders

`godot-demo-projects/2d/screen_space_shaders`

- **Shows:** Full-screen canvas_item shaders sampling hint_screen_texture (with filter_linear_mipmap for cheap blur via textureLod): vignette, whirl, pixelize, sepia, old film, mirage, BCS, blur, negative; plus a simple OptionButton-driven effect/picture switcher toggling ColorRect overlays.
- **Key files:** `godot-demo-projects/2d/screen_space_shaders/shaders/vignette.gdshader`, `godot-demo-projects/2d/screen_space_shaders/shaders/pixelize.gdshader`, `godot-demo-projects/2d/screen_space_shaders/shaders/old_film.gdshader`, `godot-demo-projects/2d/screen_space_shaders/screen_shaders.gd`
- **Reuse for our game:** High value for polish: vignette, CRT-adjacent old_film, pixelize, and whirl are ready-made post effects for damage flashes, pause blur, retro filters, and transitions - just put the shader on a full-screen ColorRect above the game.

### Skeleton2D

`godot-demo-projects/2d/skeleton`

- **Shows:** Bone-rigged 2D character with Skeleton2D + Polygon2D meshes, driven by an AnimationTree blend graph controlled from code (transition_request, OneShot ONE_SHOT_REQUEST_FIRE for jump/land, TimeScale scaling run/walk speed by velocity), CharacterBody2D controller with jump-cut, terminal-velocity hard-landing stun.
- **Key files:** `godot-demo-projects/2d/skeleton/player/player.gd`, `godot-demo-projects/2d/skeleton/player/player.tscn`
- **Reuse for our game:** AnimationTree parameter-driving code (state transitions, one-shots, timescale tied to speed) is the modern pattern for any animated player character; sprite-flip via scale and landing-stun timer also transfer. Skeleton rigging itself only matters if using cutout art.
- **License notes:** GBot character art (c) Andreas Esau, MIT; rigging/animation (c) 2020 RustyStriker, MIT - attribution required but still MIT, no CC assets

### Sprite Shaders

`godot-demo-projects/2d/sprite_shaders`

- **Shows:** Per-sprite canvas_item shaders using TEXTURE/TEXTURE_PIXEL_SIZE: alpha-based outline, glow, aura, gaussian-ish blur, drop/offset shadow, silhouette, disintegrate (noise dissolve), vertex-distortion 'fatty'.
- **Key files:** `godot-demo-projects/2d/sprite_shaders/shaders/outline.gdshader`, `godot-demo-projects/2d/sprite_shaders/shaders/dissintegrate.gdshader`, `godot-demo-projects/2d/sprite_shaders/shaders/dropshadow.gdshader`
- **Reuse for our game:** High value: outline for selection/hit highlight, silhouette (set to white) for damage-flash, disintegrate for enemy death effects, glow/aura for power-ups - all small self-contained .gdshader files that drop onto any Sprite2D material.

### Tween Interpolation

`godot-demo-projects/2d/tween`

- **Shows:** Godot 4 Tween API in depth: create_tween chaining, set_loops/set_speed_scale, per-Tweener ease/trans overrides, parallel(), as_relative(), tween_interval, tween_callback with bind(), tween_method (including moving along a Path2D curve via sample_baked), sub-tweens from lambdas, pause/play/kill lifecycle, live speed changes.
- **Key files:** `godot-demo-projects/2d/tween/main.gd`
- **Reuse for our game:** High value as a cookbook for all juice/animation code: menu slide-ins, score pop-ups, hit flashes (blink loop), death shrink/vanish (elastic scale + fade), path-following pickups, countdowns - every pattern needed for arcade polish is demonstrated in one file.

## godot-demo-projects/3d (a-l)

> **Top picks:** 1) graphics_settings — a near-complete, copyable options menu (UI scale, fullscreen, vsync, FPS cap, brightness/contrast/saturation, FPS counter with gradient coloring, OptionButton/Slider signal wiring); the single most reusable asset in this batch for a polished arcade game. 2) kinematic_character — the accel/decel/lerp movement-feel recipe and teleport + reset_physics_interpolation pattern port directly to CharacterBody2D for tight arcade controls. 3) ik (fps subfolder) — minimal projectile spawning with fire-rate cooldown and timed despawn (simple_bullet.gd), plus a clean scene-switch button for menus. 4) labels_and_texts — Font.get_string_size() fit-to-width font shrinking and text-based health/score display tricks for HUD work. 5) antialiasing — the cleanest example of the shared orbit-camera/tester-carousel + vsync/max_fps plumbing if a settings screen or mode-select carousel is needed. Remaining entries (csg, decals, global_illumination, lights_and_shadows) are rendering showcases with little 2D transfer beyond the click-to-spawn raycast pattern in decals.

### 3D Anti-Aliasing

`godot-demo-projects/3d/antialiasing`

- **Shows:** Runtime toggling of Viewport AA settings: msaa_3d, screen_space_aa (FXAA/SMAA), use_taa, scaling_3d_scale (SSAA via render scale), alpha antialiasing modes on materials. Also orbit-camera rig (CameraHolder/RotationX nodes driven by InputEventMouseMotion.screen_relative), gl_compatibility fallback detection via RenderingServer.get_current_rendering_method(), DisplayServer vsync control, Engine.max_fps limiting, FPS label.
- **Key files:** `antialiasing/anti_aliasing.gd`, `antialiasing/anti_aliasing.tscn`, `antialiasing/thin_lines.tscn`
- **Reuse for our game:** Graphics-options plumbing transfers directly: setting Viewport MSAA/FXAA/TAA from an options menu, DisplayServer.window_set_vsync_mode, Engine.max_fps cap, FPS counter label pattern, resolution-independent mouse input via screen_relative. The 3D AA specifics are low relevance for 2D.
- **License notes:** Repo MIT; checker.png CC0 1.0 (Kenney); paint.png/paint_normal.png CC BY 3.0 (johndn, opengameart.org)

### Constructive Solid Geometry (CSG)

`godot-demo-projects/3d/csg`

- **Shows:** CSGBox3D/CSGSphere3D/CSGCombiner3D etc. boolean operations (union/intersection/subtraction) for level prototyping, shown via a tester-scene carousel with orbit camera and prev/next UI cycling through child Node3Ds.
- **Key files:** `csg/csg.gd`, `csg/csg.tscn`
- **Reuse for our game:** Low relevance. Only the generic tester carousel pattern (cycling visible children with prev/next buttons + ui_left/ui_right actions) is mildly reusable, e.g. for a level/ship-select screen.
- **License notes:** Repo MIT; checker.png CC0 1.0 (Kenney)

### Decals

`godot-demo-projects/3d/decals`

- **Shows:** Decal node usage and per-project decal filter modes (nearest/linear/mipmaps/anisotropic via ProjectSettings). Click-to-place decals: Camera3D.project_position + PhysicsRayQueryParameters3D.create + direct_space_state.intersect_ray, then instantiating a decal scene at the hit position with modulate tint.
- **Key files:** `decals/tester.gd`, `decals/decal.tscn`, `decals/test.tscn`
- **Reuse for our game:** The screen-click -> world raycast -> spawn-scene-at-hit pattern maps to 2D (get_global_mouse_position + spawning bullet-hole/splat sprites with modulate). Decal node itself is 3D-only; in 2D you'd use Sprite2D. Moderate relevance for impact/splat VFX logic.
- **License notes:** Repo MIT; checker.png CC0 (Kenney); paint.png CC BY 3.0 (johndn); scifi_*.png CC0 (Yughues); paintedarrow*.png CC BY-SA 3.0 (Alex Foster)

### Global Illumination

`godot-demo-projects/3d/global_illumination`

- **Shows:** Switching between LightmapGI, VoxelGI, SDFGI, ReflectionProbe modes and SSAO/SSIL at runtime via Environment properties; enum-driven cycling of render modes with descriptive labels; free-fly Camera3D with mouse capture (Input.set_mouse_mode MOUSE_MODE_CAPTURED), Input.get_axis movement with velocity damping.
- **Key files:** `global_illumination/test.gd`, `global_illumination/camera.gd`, `global_illumination/test.tscn`
- **Reuse for our game:** The enum + parallel text-array pattern for cycling quality/game modes with on-screen labels is a clean reusable idiom; mouse-capture toggle handling too. GI systems themselves are low relevance for 2D.
- **License notes:** Repo MIT; zdm2.glb derived from Cube 2: Sauerbraten map, CC BY 4.0

### 3D Graphics Settings

`godot-demo-projects/3d/graphics_settings`

- **Shows:** A full graphics-settings menu (494-line settings.gd): UI scale via root.set_content_scale_size, Viewport scaling_3d_scale/scaling_3d_mode (FSR1/FSR2) + fsr_sharpness, DisplayServer vsync modes, Window.MODE_FULLSCREEN switching, Engine.max_fps, MSAA/TAA/FXAA/SMAA, shadow atlas sizing via RenderingServer, Environment toggles (SDFGI, glow, SSAO, SSR, SSIL, volumetric fog), brightness/contrast/saturation adjustments, FPS label colored by a Gradient stored in node metadata, resolution readout on viewport size_changed, gl_compatibility feature-gating.
- **Key files:** `graphics_settings/settings.gd`, `graphics_settings/control.tscn`, `graphics_settings/3d_scene.tscn`
- **Reuse for our game:** Highest-value entry in this batch: a template for an options menu. Directly liftable for 2D: UI scale slider (content_scale_size), fullscreen/windowed toggle, vsync selector, FPS limit, brightness/contrast/saturation via Environment adjustments, FPS counter with gradient coloring, OptionButton/HSlider signal wiring, unsupported-feature graying-out. Only the 3D effect toggles are irrelevant.

### 3D Inverse Kinematics

`godot-demo-projects/3d/ik`

- **Shows:** SkeletonIK3D node (start() in a runner script), custom FABRIK solver and look-at IK as an editor plugin (@tool scripts with setters on exported NodePaths), an FPS example with CharacterBody3D movement, sprint/lean via Path3D+PathFollow3D, RigidBody3D bullets with timed queue_free despawn, mouse-look, and a scene-switch button (change_scene_to_file).
- **Key files:** `ik/addons/sade/ik_fabrik.gd`, `ik/fps/example_player.gd`, `ik/fps/simple_bullet.gd`, `ik/skeleton_ik_runner.gd`
- **Reuse for our game:** simple_bullet.gd is the canonical projectile-despawn-timer pattern (works identically in 2D). Fire-rate cooldown timer and preload+instantiate bullet spawning in example_player.gd transfer directly to a 2D shooter. button_change_scene.gd shows minimal scene switching for menus. IK itself is low relevance.
- **License notes:** Repo MIT; ik/model contains Godot Battle Bot model (no separate license stated, part of MIT repo)

### Kinematic Character 3D

`godot-demo-projects/3d/kinematic_character`

- **Shows:** CharacterBody3D with move_and_slide(), gravity from ProjectSettings, camera-relative input direction, accel/decel via lerp of horizontal velocity toward target, jump gated on is_on_floor() after move_and_slide(), fall-off-world reset with reset_physics_interpolation(), and a top_level follow camera with min/max distance and height clamping (follow_camera.gd).
- **Key files:** `kinematic_character/player/cubio.gd`, `kinematic_character/player/follow_camera.gd`, `kinematic_character/level.tscn`
- **Reuse for our game:** The movement feel recipe transfers to CharacterBody2D almost line-for-line: Input.get_axis, normalize diagonals, separate accel vs decel based on dot(input, velocity), lerp toward target speed, jump-after-move_and_slide ordering, reset_physics_interpolation() after teleports. Follow-camera distance clamping maps to a 2D lerp camera.

### 3D Labels and Texts

`godot-demo-projects/3d/labels_and_texts`

- **Shows:** Label3D (billboard, MSDF vs rasterized fonts, outlines, icon fonts) vs TextMesh (PrimitiveMesh with depth); simulated layout via Label3D.offset; text-character health bar; auto-shrinking font size using Font.get_string_size() in a loop; a small vertex-displacement spatial shader (curvature.gdshader).
- **Key files:** `labels_and_texts/label_3d_layout.gd`, `labels_and_texts/3d_labels_and_texts.gd`, `labels_and_texts/curvature.gdshader`
- **Reuse for our game:** Font.get_string_size()-based fit-to-width font shrinking works identically for 2D Labels (score/name displays). The animated text health-bar and offset-based layout ideas adapt to floating damage numbers / enemy health tags in 2D. Label3D specifics are 3D-only.
- **License notes:** Repo MIT; checker.png CC0 (Kenney); textmesh_texture.png CC0 (bruvzg)

### 3D Lights and Shadows

`godot-demo-projects/3d/lights_and_shadows`

- **Shows:** DirectionalLight3D/OmniLight3D/SpotLight3D features: PCSS contact-hardening shadows, light projectors, area lights; PhysicalSkyMaterial with real-time radiance update; a 5-line day/night cycle (rotate_object_local on a DirectionalLight3D in _process); tester-carousel orbit camera identical to the other showcase demos.
- **Key files:** `lights_and_shadows/tester.gd`, `lights_and_shadows/day_night_cycle.gd`, `lights_and_shadows/test.tscn`
- **Reuse for our game:** Low relevance. 2D lighting uses PointLight2D/CanvasModulate, not these nodes. The day/night concept (slow modulate rotation/tween) is trivially reimplemented; nothing worth lifting directly.
- **License notes:** Repo MIT; checker.png CC0 1.0 (Kenney)

## godot-demo-projects/3d (m-z)

> **Top picks:** 1) squash_the_creeps — the single best full-game-loop template in scope: Timer+PathFollow random spawning, signal-driven score HUD, offscreen despawn, retry/reload; maps 1:1 onto 2D nodes (flag: CC-BY music, OFL font). 2) voxel — settings.gd is a drop-in JSON persistence AutoLoad singleton, exactly what a high-score/options system needs; also pause/settings menu structure. 3) truck_town — richest polish library: gamepad-focusable menus, AudioServer volume/mute UI, loading screen via frame_post_draw, speed-driven audio pitch, joypad rumble + handheld vibration on impact, gradient-tinted HUD readouts. 4) waypoints — complete off-screen indicator/edge-clamped marker math reusable verbatim for 2D arcade off-screen enemy arrows. 5) ragdoll_physics + physics_interpolation (tie) — slow-motion juice (Engine.time_scale + AudioServer.playback_speed_scale) and impact-speed SFX from ragdoll; smooth-motion physics interpolation, teleport reset, and Curve-driven projectile lifetime scaling from physics_interpolation.

### Material Testers

`godot-demo-projects/3d/material_testers`

- **Shows:** Showcase of complex BaseMaterial3D setups (subsurface, clearcoat, refraction, etc.) on sphere meshes; orbit-camera tester UI cycling scenes and HDR panorama backgrounds; runtime renderer detection (RenderingServer.get_current_rendering_method) to tweak Environment for gl_compatibility.
- **Key files:** `material_testers/tester.gd`, `material_testers/material_tester.tscn`
- **Reuse for our game:** Low relevance for 2D gameplay; the renderer-detection-and-adjust pattern and the smooth lerp camera/UI cycling pattern in tester.gd are mildly transferable.
- **License notes:** HDR backgrounds and some textures (wool/marble) contain CC metadata strings in binaries; no explicit non-MIT LICENSE files in this demo, but background HDRs likely third-party — verify before reuse.

### 3D Navigation

`godot-demo-projects/3d/navigation`

- **Shows:** NavigationAgent3D pathfinding on a baked NavigationRegion3D; move_toward polyline following; drawing the computed path with a custom ImmediateMesh Line3D class; click-to-set-target via camera ray projection.
- **Key files:** `navigation/character.gd`, `navigation/navmesh.gd`, `navigation/line3d.gd`
- **Reuse for our game:** Concept of NavigationAgent + get_next_path_position transfers directly to NavigationAgent2D for enemy AI pathfinding; otherwise low relevance.

### Navigation Mesh Chunks 3D

`godot-demo-projects/3d/navigation_mesh_chunks`

- **Shows:** Direct NavigationServer3D API use: chunked navmesh baking from parsed static colliders (NavigationMeshSourceGeometryData3D, map_set_cell_size, disabling edge connections), aligning chunk edges so regions merge by edge key; debug path drawing.
- **Key files:** `navigation_mesh_chunks/navmesh_chhunks_demo_3d.gd`
- **Reuse for our game:** low relevance

### Occlusion Culling and Mesh LOD

`godot-demo-projects/3d/occlusion_culling_mesh_lod`

- **Shows:** OccluderInstance3D-based occlusion culling over 1024 rooms, automatic mesh LOD via viewport mesh_lod_threshold, runtime toggles, Viewport.debug_draw cycling, vsync toggle, and a live perf HUD from RenderingServer.get_rendering_info (draw calls/primitives/objects).
- **Key files:** `occlusion_culling_mesh_lod/node_3d.gd`, `occlusion_culling_mesh_lod/camera.gd`
- **Reuse for our game:** The perf/FPS debug overlay pattern (Engine.get_frames_per_second + RenderingServer stats in a Label) is directly reusable as a debug HUD; rest is low relevance.

### 3D Particles

`godot-demo-projects/3d/particles`

- **Shows:** GPUParticles3D vs CPUParticles3D feature tour: collision (SDF baked collision), attractors, trails, subemitters; a reusable tester scene with orbit/zoom mouse camera and prev/next scene cycling via _unhandled_input.
- **Key files:** `particles/tester.gd`, `particles/test.tscn`
- **Reuse for our game:** Particle concepts (process material params, subemitters for explosions, trails) map closely to GPUParticles2D for arcade juice; tester.gd's screen_relative mouse handling is a good input-handling reference.
- **License notes:** checker.png: CC0 by Kenney (particles/checker.LICENSE.md); kenney smoke sprites CC0.

### Physical Light and Camera Units

`godot-demo-projects/3d/physical_light_camera_units`

- **Shows:** Physical light units (lumen/lux/Kelvin) and CameraAttributesPhysical (shutter/aperture/ISO); GDScript port of the engine's Kelvin-to-Color conversion; options UI wiring sliders to light/environment properties.
- **Key files:** `physical_light_camera_units/options.gd`, `physical_light_camera_units/test.tscn`
- **Reuse for our game:** low relevance

### Physics Interpolation

`godot-demo-projects/3d/physics_interpolation`

- **Shows:** Fixed-timestep physics interpolation toggling at runtime, reset_physics_interpolation() after teleports, FPS/TPS/fixed camera modes with captured mouse, bullet spawning as RigidBody3D with deferred collision enable and Curve-sampled scale-over-lifetime.
- **Key files:** `physics_interpolation/player.gd`, `physics_interpolation/bullet.gd`
- **Reuse for our game:** Physics interpolation + reset_physics_interpolation on teleport is directly relevant to smooth 2D arcade movement at high refresh rates; bullet.gd's Curve-driven scale-over-lifetime and one-tick collision delay are reusable projectile patterns.

### 3D Physics Tests

`godot-demo-projects/3d/physics_tests`

- **Shows:** Test harness for the 3D physics engine: menu-driven scene loading from a Dictionary registry (tests.gd), plus a utils/ library of small drop-in nodes — FPS/pause/version labels, time_scale control, camera orbit, rigidbody mouse picking, scrolling on-screen log, option menus.
- **Key files:** `physics_tests/tests.gd`, `physics_tests/utils/camera_orbit.gd`, `physics_tests/utils/rigidbody_pick.gd`, `physics_tests/utils/scroll_log.gd`
- **Reuse for our game:** utils/ scripts (fps label, pause label, time_scale, scroll log, option menu) are engine-dimension-agnostic debug/UI helpers worth lifting; the scene-registry + dynamic loading pattern suits a level/test select menu.
- **License notes:** Robot head model by James Redmond (fracteed) — free-use note in physics_tests/assets/robot_head/readme.txt, not MIT-labeled.

### Platformer 3D

`godot-demo-projects/3d/platformer`

- **Shows:** Full CharacterBody3D platformer: camera-relative movement with accel/deaccel and sharp-turn handling, AnimationTree blending, coin pickup via Area3D body_entered, RigidBody3D enemy using _integrate_forces with RayCast3D floor/wall sensing and contact-based death, follow camera, CanvasLayer touch UI shown only when DisplayServer.is_touchscreen_available(), third-party virtual joystick addon, sky shader.
- **Key files:** `platformer/player/player.gd`, `platformer/enemy/enemy.gd`, `platformer/coin/coin.gd`, `platformer/touch_screen_ui.gd`
- **Reuse for our game:** Accel/deaccel movement tuning, Input.get_vector usage, Area3D pickup pattern (identical in Area2D), enemy edge/wall detection via raycasts, and conditional touch-screen UI are all directly portable to 2D arcade design.
- **License notes:** Uses 'Virtual joystick' addon by Marco F (MIT, godotengine asset 1787) — attribution noted in README.

### Procedural Materials

`godot-demo-projects/3d/procedural_materials`

- **Shows:** Three procedural texture techniques: NoiseTexture2D (async C++ noise), CPU Image/ImageTexture generation via script, and real-time shader-on-ColorRect rendered to a SubViewport with ViewportTexture applied to a material; also a minimal loading/staging scene using change_scene_to_packed after 2 awaited frames.
- **Key files:** `procedural_materials/loading.gd`, `procedural_materials/scripts/grid.gd`, `procedural_materials/shaders/plasma.gdshader`
- **Reuse for our game:** loading.gd is a clean loading-screen pattern; NoiseTexture2D and animated 2D shaders (plasma etc.) are directly usable for arcade backgrounds/effects.

### Ragdoll Physics

`godot-demo-projects/3d/ragdoll_physics`

- **Shows:** PhysicalBone3D ragdolls with initial impulse, spawn-at-cursor via PhysicsRayQueryParameters3D raycast, slow motion via Engine.time_scale + AudioServer.playback_speed_scale pitch, impact sounds scaled by collision speed, stencil-mode outlines, CSG-baked static geometry with LightmapGI.
- **Key files:** `ragdoll_physics/ragdoll_physics.gd`, `ragdoll_physics/characters/mannequiny_ragdoll.gd`
- **Reuse for our game:** Slow-motion combo (Engine.time_scale + AudioServer.playback_speed_scale) is a great arcade hit-stop/slowmo effect; impact-speed-scaled SFX is reusable audio polish. Ragdoll itself low relevance.
- **License notes:** mannequiny.glb: CC BY 4.0 (GDQuest); impact_big.wav/impact_small.wav: CC0 (freesound); checker.png: CC0 Kenney.

### RigidBody Character 3D

`godot-demo-projects/3d/rigidbody_character`

- **Shows:** Player as RigidBody3D moved with apply_central_impulse in _physics_process; ShapeCast3D ground check (vs infinitely-thin RayCast3D); camera-basis-relative input; reset with reset_physics_interpolation; periodic RigidBody cube spawning from level script.
- **Key files:** `rigidbody_character/player/cubio.gd`, `rigidbody_character/level.gd`
- **Reuse for our game:** ShapeCast ground-check idea and impulse-based movement translate to RigidBody2D arcade physics (e.g. ball/physics games); modest relevance otherwise.

### 3D Sky Shaders

`godot-demo-projects/3d/sky_shaders`

- **Shows:** shader_type sky with raymarched volumetric clouds (Horizon Zero Dawn technique) over converted PhysicalSkyMaterial; day/night cycle driven by AnimationPlayer animating shader parameters; set_shader_parameter from _process; smooth FOV lerp with exp decay.
- **Key files:** `sky_shaders/sky_volumetric_clouds.gdshader`, `sky_shaders/main.gd`
- **Reuse for our game:** AnimationPlayer-drives-shader-uniforms pattern and framerate-independent lerp (1.0 - exp(-delta*k)) are reusable for 2D shader effects; sky shader itself low relevance.
- **License notes:** Cloud raymarching credited to A. Schneider SIGGRAPH 2015 technique (comment attribution only); noise textures unattributed — verify.

### 3D Soft Body Physics

`godot-demo-projects/3d/soft_body_physics`

- **Shows:** SoftBody3D cloth/boxes/spheres with pinned points, per-point impulses (wind), attaching nodes to soft-body points, spawn-at-cursor with a capped FIFO of max 10 user objects, simulation reset by re-instancing scenes.
- **Key files:** `soft_body_physics/tester.gd`, `soft_body_physics/cloth.tscn`
- **Reuse for our game:** The capped-object-pool spawn pattern (oldest removed beyond N) is a useful arcade spawning idiom; soft bodies themselves low relevance.
- **License notes:** checker.png: CC0 Kenney.

### 3D Sprites and Animated Sprites

`godot-demo-projects/3d/sprites`

- **Shows:** Sprite3D and AnimatedSprite3D (SpriteFrames) in 3D with billboard mode; 8-direction character sprite selection; custom spatial shaders on sprites (paper wobble, outline, negative, emission).
- **Key files:** `sprites/scripts/3d_sprites.gd`, `sprites/scripts/player.gd`, `sprites/shaders/paper.gdshader`
- **Reuse for our game:** The gdshader effects (paper wobble, negative, emission/outline) port almost directly to canvas_item shaders for 2D sprite juice; AnimatedSprite3D usage mirrors AnimatedSprite2D/SpriteFrames workflow.
- **License notes:** Small-8-Direction-Characters by AxulArt: CC BY 4.0 (sprites/textures/small_8_direction_characters.LICENSE.md); checker.png: CC0 Kenney.

### Squash the Creeps 3D

`godot-demo-projects/3d/squash_the_creeps`

- **Shows:** Complete minimal game loop: timer-driven enemy spawning at random points on a Path3D/PathFollow3D (progress_ratio = randf()), mob initialize(start, target) with randomized heading/speed, squashed signal wired to a score label, VisibleOnScreenNotifier3D despawn, retry overlay + scene reload on ui_accept, music player, lose condition.
- **Key files:** `squash_the_creeps/Main.gd`, `squash_the_creeps/Mob.gd`, `squash_the_creeps/Player.gd`, `squash_the_creeps/ScoreLabel.gd`
- **Reuse for our game:** Highest-value template in scope: the spawn-on-Timer + PathFollow random spawn point + signal-to-HUD score + offscreen-notifier cleanup + retry/reload loop is exactly the skeleton of a 2D arcade game (identical nodes exist in 2D: Path2D/PathFollow2D, VisibleOnScreenNotifier2D).
- **License notes:** Music 'House In a Forest Loop.ogg' CC-BY 3.0 (HorrorPen, opengameart); Montserrat font SIL OFL 1.1.

### Tonemapping and Color Correction

`godot-demo-projects/3d/tonemap_color_correction`

- **Shows:** Environment tonemap operators (Linear/Reinhard/Filmic/ACES/AgX) and adjustment_color_correction with 1D and 3D LUT textures; script-generated neutral 3D LUTs; carrying Environment settings across scene swaps; gradient/hue test-pattern shaders.
- **Key files:** `tonemap_color_correction/options.gd`, `tonemap_color_correction/gradients/gradient_bars.gd`, `tonemap_color_correction/test_scene.gd`
- **Reuse for our game:** Color-correction LUTs and Environment adjustments apply to a 2D game via WorldEnvironment/CanvasLayer for global grading; options.gd shows the UI-to-Environment wiring.

### Truck Town

`godot-demo-projects/3d/truck_town`

- **Shows:** VehicleBody3D driving with steering lerp, engine sound pitch scaled by speed, collision detection via sudden velocity change triggering impact SFX + Input.vibrate_handheld/start_joy_vibration haptics, ConeTwistJoint3D/PinJoint3D trailer chains, car select menu with gamepad focus (grab_focus), loading screen awaiting RenderingServer.frame_post_draw, AudioServer bus volume/mute UI, mood/time-of-day switching, speedometer Button with Gradient-tinted text.
- **Key files:** `truck_town/vehicles/vehicle.gd`, `truck_town/car_select/car_select.gd`, `truck_town/speedometer.gd`
- **Reuse for our game:** Rich menu/audio polish patterns: gamepad-focusable menus, volume slider + mute via AudioServer, loading screen frame_post_draw trick, speed-scaled audio pitch, controller rumble + mobile vibration on impact, gradient-tinted HUD text — all directly portable.
- **License notes:** Kenney audio icons CC0 (car_select/icon_license.txt); lamp and tree models from Sketchfab CC-BY-4.0 requiring credit (town/lamp/license.txt, town/tree/license.txt).

### Variable Rate Shading

`godot-demo-projects/3d/variable_rate_shading`

- **Shows:** Viewport VRS modes (texture-based and XR) with a density-mask gdshader, MobileVRInterface initialization via XRServer, and on-screen performance metrics.
- **Key files:** `variable_rate_shading/vrs.gd`, `variable_rate_shading/vrs_texture.gdshader`
- **Reuse for our game:** low relevance

### Visibility Ranges (HLOD)

`godot-demo-projects/3d/visibility_ranges`

- **Shows:** Hierarchical LOD via GeometryInstance3D visibility_range_begin/end with transparency-fade vs hysteresis modes; 2000 procedurally placed clusters with seeded RNG; loading screen shown for 2 awaited frames before heavy instancing; FPS label.
- **Key files:** `visibility_ranges/tree_clusters.gd`, `visibility_ranges/tree_cluster.tscn`, `visibility_ranges/fps_label.gd`
- **Reuse for our game:** Seeded random placement and the await-2-frames-then-instantiate loading pattern are reusable; LOD itself low relevance for 2D.

### Volumetric Fog

`godot-demo-projects/3d/volumetric_fog`

- **Shows:** FogVolume nodes (box/ellipsoid, positive/negative density, height falloff, 3D-texture density), Environment volumetric fog settings with temporal reprojection, custom fog shader with real-time 3D noise; free-fly camera with velocity damping.
- **Key files:** `volumetric_fog/volumetric_fog.tscn`, `volumetric_fog/camera.gd`
- **Reuse for our game:** low relevance
- **License notes:** Embedded fog noise shader carries an MIT header (from godotshaders.com, author alghost per README) — MIT but third-party attribution embedded in volumetric_fog.tscn.

### Voxel Game

`godot-demo-projects/3d/voxel`

- **Shows:** Minecraft-like chunked voxel world: SurfaceTool mesh generation in Threads, Dictionary chunk storage keyed by Vector3i, RayCast3D block place/break, AutoLoad settings singleton persisted as JSON via FileAccess (user://settings.json), pause/settings menu, distance fog toggle.
- **Key files:** `voxel/world/voxel_world.gd`, `voxel/world/chunk.gd`, `voxel/settings.gd`, `voxel/player/player.gd`
- **Reuse for our game:** settings.gd is a clean, minimal JSON save/load AutoLoad singleton — the exact pattern needed for persisting high scores and options in an arcade game; menu/debug scripts also useful.
- **License notes:** Textures from Minetest Game: mix of CC BY-SA 3.0 and CC0 (detailed per-file in README); TinyUnicode font CC-BY (DuffsDevice).

### 3D Waypoints

`godot-demo-projects/3d/waypoints`

- **Shows:** Projecting 3D world positions to screen-space Control positions with Camera3D.unproject_position (no viewports/Sprite3D), behind-camera detection via basis.z dot product, clamping markers to screen edges with rotation for off-screen indicators, distance-based fade via modulate.a and remap(), content_scale_size-aware viewport sizing.
- **Key files:** `waypoints/waypoint.gd`, `waypoints/main.gd`
- **Reuse for our game:** The sticky off-screen indicator math (edge clamping, arrow rotation, distance fade) is directly reusable for 2D off-screen enemy/pickup indicators — just skip the unprojection step.

## AI and camera addons (beehave, phantom-camera)

> **Top picks:** Both entries are high-value and complementary. (1) phantom-camera is the single biggest camera-juice win: priority-tweened virtual cameras, damped/dead-zone follow, arena limits, and built-in layered screen shake (PhantomCameraNoiseEmitter2D) replace hand-rolled camera+shake code entirely; its 2d_trigger_area.gd / 2d_room_limit_tween.gd examples are copy-paste zone-camera patterns. (2) beehave is the enemy-AI backbone: scene-tree behavior trees with reactive selectors, cooldown/limiter decorators, and a Blackboard, plus a runtime debugger and per-tree perf monitors — ideal for wave enemies and boss phases with configurable tick_rate for crowds; SetModulateColor.gd is the template for tween-driven RUNNING actions (hit flash, telegraphs). Caveats: beehave ships gdUnit4 (MIT, fine, also a free test harness); phantom-camera's examples/ contain an OpenGameArt spritesheet and Nunito fonts (OFL) — exclude or attribute if shipping.

### Beehave (behavior-tree AI addon, v2.9.3-dev, bitbrain)

`beehave`

- **Shows:** Behavior trees built as ordinary scene-tree nodes: BeehaveTree root (extends Node, ticks children in _physics_process/_process/manual at configurable tick_rate, exposes actor + Blackboard, SUCCESS/FAILURE/RUNNING enum) with composites (Selector/Sequence plus Reactive/Random/Star variants, SimpleParallel), decorators (Cooldown, Delayer, Inverter, Limiter, Repeater, TimeLimiter, UntilFail, Failer, Succeeder), and leaves (ActionLeaf/ConditionLeaf subclasses overriding tick(actor, blackboard), BlackboardSet/Get/Compare/Erase leaves). Also an in-editor runtime debugger panel and Performance.add_custom_monitor per-tree metrics via two autoloads (BeehaveGlobalMetrics, BeehaveGlobalDebugger). Bundles gdUnit4 test framework and a full test suite under test/. Integration: copy addons/beehave into project addons/, enable plugin (plugin auto-registers the two autoloads), optionally copy script_templates/BeehaveNode/default.gd for new-leaf boilerplate. Examples: beehave_test_scene.tscn (keyboard-moved sprite whose tree picks modulate color via HasPositivePosition/HasNegativePosition conditions + tween-based SetModulateColor RUNNING action, plus labels reading tree.get_last_condition()/get_running_action()), and random_tree_example (procedurally generates large random trees to stress the debugger).
- **Key files:** `beehave/addons/beehave/nodes/beehave_tree.gd`, `beehave/addons/beehave/nodes/leaves/action.gd`, `beehave/examples/actions/SetModulateColor.gd`, `beehave/examples/beehave_test_scene.gd`
- **Reuse for our game:** Directly reusable for enemy AI: drop addons/beehave into addons/, enable plugin, then per-enemy attach a BeehaveTree under each enemy scene with actor = enemy body. Arcade-enemy patterns map cleanly: SelectorReactive [Sequence(IsPlayerInRange -> ChaseAction) , WanderAction], Cooldown decorator for attack rate limiting, Blackboard for sharing player ref/target position between leaves, tick_rate>1 to cheapen many simultaneous enemies, tree.enabled=false on pause/death. SetModulateColor.gd is the canonical template for a long-running RUNNING action driven by a Tween (hit-flash, telegraphs). The gdUnit4 bundle also gives a ready test harness if we want AI unit tests. Debug panel + custom performance monitors are useful during tuning. No player input/HUD/spawning code worth lifting beyond trivial Input.is_action_pressed movement in the example.
- **License notes:** clean (root LICENSE, addons/beehave/LICENSE, and bundled addons/gdUnit4/LICENSE are all MIT; README credits logo/icon designers but no non-MIT assets found)

### Phantom Camera (Camera2D/3D control addon, v0.11.0.3, Marcus Skov)

`phantom-camera`

- **Shows:** Cinemachine-style virtual cameras for Godot 4.4+: PhantomCamera2D/3D nodes (extends Node2D/3D) that drive the scene's real Camera2D/Camera3D via a PhantomCameraHost child of the camera; a plugin-registered autoload PhantomCameraManager (add_autoload_singleton in plugin.gd) tracks all pcams/hosts. Priority-based camera switching with tween transitions (PhantomCameraTween Resource: duration/TransitionType/EaseType). 2D follow modes: GLUED, SIMPLE (damped + offset), GROUP (multi-target auto-zoom reframing), PATH (confined to Path2D), FRAMED (dead zones, dead_zone_reached signal), plus lookahead velocity limits, zoom control, and Camera2D limit_left/top/right/bottom mirroring with editor limit drawing. Camera shake via PhantomCameraNoiseEmitter2D + PhantomCameraNoise2D resources (growth_time/duration/decay_time, render-layer-style noise_emitter_layer masking, noise_emitted signal). Editor viewfinder bottom panel with dead-zone preview. Full C# wrapper classes (.cs) alongside GDScript. Example scenes under addons/phantom_camera/examples (2d_example_scene, follow_framed/group/path, 2d_limit, 2d_noise, 2d_tweening) with a CharacterBody2D platformer player, Area2D camera-trigger zones that raise a pcam's priority on enter, and room-based camera handoff (2d_room_limit_tween.gd). dev_scenes/2d has a minimal priority-swap/teleport test scene. Note: no project.godot in this vendored copy — it is addon-only, examples must be opened from a host project.
- **Key files:** `phantom-camera/addons/phantom_camera/scripts/phantom_camera/phantom_camera_2d.gd`, `phantom-camera/addons/phantom_camera/scripts/phantom_camera/phantom_camera_noise_emitter_2d.gd`, `phantom-camera/addons/phantom_camera/examples/scripts/2D/2d_room_limit_tween.gd`, `phantom-camera/addons/phantom_camera/examples/scripts/2D/2d_trigger_area.gd`
- **Reuse for our game:** Directly reusable for camera juice: install addons/phantom_camera, enable plugin (autoload added automatically), add PhantomCameraHost under the Camera2D, then one PhantomCamera2D per shot. For an arcade game: SIMPLE/FRAMED follow with damping for the player ship/character; GROUP follow with auto-zoom for boss intros or two-player; screen shake for free via PhantomCameraNoiseEmitter2D.emit() on hit/explosion (tunable duration/decay, layer-masked so only gameplay cam shakes); priority+PhantomCameraTween for menu->gameplay->game-over camera transitions and zoom punches; limit_* mirroring to clamp the camera to the arena. 2d_trigger_area.gd (Area2D raises pcam priority on player enter) and 2d_room_limit_tween.gd (per-room camera handoff with follow_target swap) are copy-paste patterns for zone-based cameras. The example player_character_body_2d.gd is a serviceable CharacterBody2D platformer controller reference (input remap dictionary, jump/gravity) but is tied to the demo UI; treat as reference only.
- **License notes:** Addon code MIT (root LICENSE + addons/phantom_camera/LICENSE). NOT plain MIT inside examples/: addons/phantom_camera/examples/credits.txt credits level_spritesheet to opengameart.org 'A platformer in the forest' by Buch (OpenGameArt asset, verify its CC terms before shipping); addons/phantom_camera/fonts/ bundles Nunito-Regular/Black.ttf (Google Fonts Nunito = SIL Open Font License, no license file included). Strip examples/ and fonts/ or keep attribution if shipped.

## Kenney Godot 4 starter kits (3D Platformer, FPS, City Builder)

> **Top picks:** All three ship the same core keeper: the Audio autoload (pooled AudioStreamPlayers, queue, random pitch) — take the City Builder version (scripts/audio.gd) since it adds per-call volume_db and random sound-variation selection. (1) Starter-Kit-FPS is the top pick overall: scripts/weapon.gd's Resource-driven weapon definitions (cooldown/damage/spread/shot_count/knockback/crosshair) plus objects/impact.gd's self-freeing hit effect and the duck-typed has_method(\"damage\") interface are a ready-made architecture for 2D arcade shooting, powerups, and hit feedback. (2) Starter-Kit-City-Builder's data_map.gd/data_structure.gd + ResourceSaver/ResourceLoader save-load flow is the cleanest reusable pattern for high-score/settings persistence. (3) Starter-Kit-3D-Platformer's player.gd is the best 'game feel' reference: squash-and-stretch via scale lerps, velocity lerp smoothing, speed-scaled footstep pitch and particle trails — all translate directly to 2D juice. All are MIT code / CC0 assets; only caveat is the shared Lilita One font (SIL OFL 1.1) which needs its license file kept if redistributed.

### Starter Kit 3D Platformer

`Starter-Kit-3D-Platformer`

- **Shows:** Godot 4.6 3D platformer: CharacterBody3D with manual gravity accumulator, double jump, velocity lerp smoothing, squash-and-stretch juice via model.scale lerp, lerp_angle facing rotation; orbit camera rig (Node3D + Camera lerp follow, clamp on pitch/zoom); autoloaded pooled AudioStreamPlayer manager (12 players, queue, random pitch_scale) adapted from KidsCanCode; Area3D coin pickup with signal -> HUD label; falling platform (body_entered triggers accelerating fall + queue_free); keyboard+gamepad input map with Input.get_axis; canvas_items stretch mode; Jolt physics + physics interpolation; renderer-detection fallback for gl_compatibility in main.gd.
- **Key files:** `scripts/player.gd`, `scripts/view.gd`, `scripts/audio.gd`, `objects/coin.gd`
- **Reuse for our game:** Directly liftable: audio.gd autoload (pooled SFX with random pitch, engine-agnostic re: 2D/3D); squash-and-stretch scale-lerp juice pattern for jumps/landings; signal-based pickup -> HUD counter pattern (coin_collected.emit -> hud.gd); dual keyboard/gamepad input map layout in project.godot with Input.get_axis/get_vector; velocity lerp smoothing for snappy-but-smooth movement; sine-bob + rotate idle animation for pickups (coin.gd).
- **License notes:** Code MIT (LICENSE.md, Kenney). All sprites/3D models/sounds CC0 per README. fonts/lilita_one_regular.ttf is SIL Open Font License 1.1 (Copyright 2011 Juan Montoreano, Reserved Font Name Lilita) — see fonts/license.txt; OFL requires bundling that license text if the font is redistributed.

### Starter Kit FPS

`Starter-Kit-FPS`

- **Shows:** Godot 4.6 FPS: CharacterBody3D FPS controller with mouse capture (MOUSE_MODE_CAPTURED), mouse+gamepad look (lerp_angle smoothing for controller), multi-jump; data-driven weapons as custom Resource subclass (class_name Weapon: cooldown, damage, spread, shot_count, knockback ranges, crosshair texture, sound path); hitscan shooting via RayCast3D with randomized spread and force_raycast_update; SubViewport/SubViewportContainer second camera on render layer 2 for first-person weapon model; Tween-based weapon-switch animation; duck-typed damage (collider.has_method("damage")); AnimatedSprite3D muzzle flash and self-freeing impact effect; enemy with look_at, sine hover, raycast attack on Timer; camera/weapon knockback recoil; CanvasLayer HUD via signal.
- **Key files:** `objects/player.gd`, `scripts/weapon.gd`, `objects/enemy.gd`, `objects/impact.gd`
- **Reuse for our game:** Best of the three for arcade mechanics: weapon.gd Resource-per-weapon pattern maps 1:1 to 2D arcade weapon/powerup definitions (cooldown Timer gate, spread, shot_count, knockback, per-weapon crosshair/sound); audio.gd here adds random-choice from comma-separated sound list (sound variation); recoil/knockback-to-camera pattern adapts to 2D screen kick; impact.gd (play animation, queue_free on animation_finished) is the standard 2D hit-spark pattern; enemy.gd shows Timer-driven attacks and has_method duck-typed damage interface; health signal -> HUD.
- **License notes:** Code MIT (LICENSE.md, Kenney). Sprites/3D models/sounds CC0 per README. fonts/lilita_one_regular.ttf is SIL OFL 1.1 (fonts/license.txt), not MIT/CC0.

### Starter Kit City Builder

`Starter-Kit-City-Builder`

- **Shows:** Godot 4.6 grid placement game: GridMap with MeshLibrary built at runtime from PackedScenes (extracting Mesh via SceneState property walk); mouse-to-grid picking via Plane.intersects_ray + Camera3D.project_ray_origin/normal; place/demolish/rotate cells (set_cell_item, get_orthogonal_index_from_basis); save/load via custom Resource classes (DataMap holding Array[DataStructure]) with ResourceSaver.save to user://map.res and ResourceLoader.load, plus loading a bundled res:// sample map; ghost-preview cursor (selector) with lerped snap; pan/rotate/zoom RTS camera (middle-mouse drag in _input, edge-free WASD pan); Audio autoload variant with per-call volume_db.
- **Key files:** `scripts/builder.gd`, `scripts/data_map.gd`, `scripts/view.gd`, `scripts/audio.gd`
- **Reuse for our game:** Main lift is persistence: DataMap/DataStructure custom-Resource + ResourceSaver/ResourceLoader to user:// is exactly the pattern for saving high scores/settings in a 2D arcade game (typed, @export-serialized, no JSON plumbing); audio.gd here is the most evolved of the three (pooled players + random pitch + per-sound volume_db) — take this version; cash counter -> Label HUD update pattern. Grid/GridMap picking itself is low relevance for arcade play.
- **License notes:** Code MIT (LICENSE.md, Kenney). Sprites/3D models/sounds CC0 per README. fonts/lilita_one_regular.ttf is SIL OFL 1.1 (fonts/license.txt), not MIT/CC0. scenes/ contains stray editor temp files (mai*.tmp) — ignorable cruft, not a license issue.

## game-scaffolding template (Maaack's Godot Game Template, Godot 4.7 / 4.3+ compatible, MIT)

> **Top picks:** 1) addons/maaacks_game_template/base — the highest-value lift in the whole survey scope: production-grade autoloads for threaded scene loading, persistent settings, input rebinding, music crossfading, and auto UI SFX; adopting it wholesale saves days of shell work for the arcade game. 2) Project root wiring (project.godot + scenes/game/game.tscn) — shows exactly how to compose the autoloads, PauseMenuController, LevelLoader/LevelManager, and win/lose windows into a running game; our game should replicate this composition and only swap the level scenes. 3) examples/scripts/game_state.gd + base GlobalState — the ready-made Resource-based save system to clone for high scores and unlocks. 4) extras/win_lose_manager.gd — minimal game-over/retry flow that fits an arcade loop better than the full level chain. Caveat: template is menus/infrastructure only (no gameplay, particles, screen shake, HUD); license is MIT with only peripheral CC-BY logo images (droppable) and CC0 Kenney input icons.

### maaacks_game_template addon - base/ (core app shell)

`Godot-Game-Template/addons/maaacks_game_template/base`

- **Shows:** The complete menu/settings/persistence backbone as 4 autoloads (project.godot: AppConfig, SceneLoader, ProjectMusicController, ProjectUISoundController) plus reusable UI scenes. SceneLoader wraps ResourceLoader.load_threaded_request/get_status for background or loading-screen scene changes; AppSettings (static class) applies input remaps, AudioServer bus volumes/mute, fullscreen/resolution/vsync from a ConfigFile (PlayerConfig, user://player_config.cfg); GlobalState saves a custom Resource to user://global_state.tres via ResourceSaver with per-key sub-state resources; MusicController hooks SceneTree.node_added to detect autoplay AudioStreamPlayers on the Music bus, reparents them and crossfades via Tween + a runtime-created blend bus; UISoundController auto-connects hover/focus/pressed sounds to every Button/Slider/TabBar/LineEdit/ItemList/Tree in the tree; OverlaidWindow handles pause (get_tree().paused), focus capture/restore, and modal exclusivity; input options menu does full key/joypad rebinding UI with InputMap + icon mapping; credits_label.gd converts ATTRIBUTION.md markdown to BBCode via RegEx; loading_screen.gd shows threaded-load progress with stall detection and web-specific messaging; opening.gd is a tweened logo-fade splash that background-loads the next scene.
- **Key files:** `addons/maaacks_game_template/base/nodes/autoloads/scene_loader/scene_loader.gd`, `addons/maaacks_game_template/base/nodes/config/app_settings.gd`, `addons/maaacks_game_template/base/nodes/autoloads/music_controller/music_controller.gd`, `addons/maaacks_game_template/base/nodes/windows/overlaid_window.gd`
- **Reuse for our game:** This is the game shell to lift wholesale: copy the 4 autoload scenes + base/ nodes and get main menu (play/options/credits/exit with web-export handling), tabbed options (audio buses, fullscreen/resolution/vsync, full input rebinding with gamepad icons), pause-aware overlaid windows, threaded scene loading with progress bar, persistent settings (ConfigFile) and save data (Resource) with zero extra code. UISoundController gives instant menu SFX polish; MusicController gives cross-scene music with crossfade blending. GlobalState.get_or_create_state() is the ready-made slot for a high-score Resource.
- **License notes:** Addon code is MIT. Bundled non-MIT assets: Kenney Input Prompts icons CC0 at addons/maaacks_game_template/assets/input-icons/License.txt (installer can download the full Kenney set); Godot Engine logo CC BY 4.0 (assets/godot_engine_logo); Git logo CC BY 3.0 (assets/git_logo). ATTRIBUTION.md also credits Git (GPL-2 tool, not shipped).

### maaacks_game_template addon - extras/ (level flow managers)

`Godot-Game-Template/addons/maaacks_game_template/extras`

- **Shows:** Level orchestration decoupled from menus: LevelLoader (@tool) loads level scenes through SceneLoader into a container node with level_load_started/level_loaded/level_ready signals; LevelManager connects to duck-typed level signals (level_won/level_lost/level_changed), traverses a SceneLister file list linearly or follows explicit next-level paths, tracks checkpoint_level_path, and instantiates optional win/lose/level-won overlay scenes wiring their continue_pressed/restart_pressed/main_menu_pressed signals; WinLoseManager is the single-scene variant; scene_lister.gd enumerates .tscn files in a directory; capture_mouse.gd handles mouse capture.
- **Key files:** `addons/maaacks_game_template/extras/scripts/level_manager.gd`, `addons/maaacks_game_template/extras/scripts/level_loader.gd`, `addons/maaacks_game_template/extras/scripts/win_lose_manager.gd`, `addons/maaacks_game_template/extras/scripts/scene_lister.gd`
- **Reuse for our game:** WinLoseManager maps directly onto an arcade game-over/victory flow (emit game_won/game_lost, get retry/main-menu overlays free). LevelManager+LevelLoader+SceneLister give wave/stage progression with checkpoints if the game has discrete stages; the signal-contract pattern (level node emits level_won, manager handles transitions) is the clean architecture to copy.

### maaacks_game_template addon - examples/ (inherited reference implementations)

`Godot-Game-Template/addons/maaacks_game_template/examples`

- **Shows:** How to extend the base: GameStateExample/LevelStateExample are custom Resources stored via GlobalState (static accessors, per-level dictionary of states, play-time counters) — the canonical save-game pattern; level_and_state_manager.gd subclasses LevelManager to persist current/checkpoint level into GameState; pause_menu.gd extends OverlaidWindow with options sub-window, restart/main-menu/exit confirmations; master_options_menu_with_tabs.gd, mini_options_menu, game_options_menu with reset-save control; main_menu_with_animations.gd adds AnimationPlayer intro + continue/level-select buttons; end_credits, scrolling_credits (auto-scroll ATTRIBUTION.md), game_timer.gd (pause-aware play-time vs wall-time Timers persisted on _exit_tree), tutorial_manager, loading_screen_with_shader_caching.
- **Key files:** `addons/maaacks_game_template/examples/scripts/game_state.gd`, `addons/maaacks_game_template/examples/scenes/windows/pause_menu.gd`, `addons/maaacks_game_template/examples/scenes/menus/options_menu/master_options_menu_with_tabs.gd`, `addons/maaacks_game_template/examples/scenes/game/scripts/game_timer.gd`
- **Reuse for our game:** GameStateExample is the template to clone for high-score/unlock persistence (rename fields to best_score, games_played; it already does versioned open/save). pause_menu.gd + pause_menu_layer are drop-in arcade pause menus. game_timer.gd pattern (PROCESS_MODE_PAUSABLE vs ALWAYS timers) is directly reusable for tracked play time. scrolling_credits gives an end-credits screen from a markdown file.
- **License notes:** examples/ATTRIBUTION.md + bundled logos: Godot Engine logo CC BY 4.0, Git logo CC BY 3.0 (addons/maaacks_game_template/examples/assets/*/LICENSE.txt); code MIT.

### Godot-Game-Template project root (copied working game: scenes/, scripts/, resources/)

`Godot-Game-Template`

- **Shows:** A runnable wired-together instance of the addon (what the setup wizard copies out of addons/): project.godot registers the 4 autoloads, main_scene=scenes/opening/opening.tscn, gl_compatibility renderer, 1280x720, move_up/down/left/right + interact actions with key+joypad bindings, en/fr menu translations. Flow: opening (logo fade, background-loads menu) -> main_menu (options/credits/level-select sub-menus) -> game.tscn which composes BackgroundMusicPlayer, game_timer.gd, PauseMenuController (pause_menu_layer), LevelLoader + level_and_state_manager.gd (LevelManager subclass) + SceneLister over scenes/game/levels/level_[1-3].tscn, win/lose windows, per-level LevelLoadingScreen, and a TutorialManager. level.gd shows the level signal contract (level_won/level_lost) plus per-level persisted state (color, tutorial_read). resources/themes/ has 6 ready Theme .tres files (expedition, gravity, grow, lab, lore, steal_this_theme).
- **Key files:** `project.godot`, `scenes/game/game.tscn`, `scenes/game/levels/level.gd`, `scripts/level_and_state_manager.gd`
- **Reuse for our game:** Use this root project as the literal starting shell: keep project.godot autoload block, opening->main_menu->game scene flow, pause_menu_layer, loading screens, options menus, and the input action set (WASD+joypad axes already mapped); replace scenes/game/levels/* with arcade gameplay scenes that emit level_won/level_lost (or swap LevelManager for WinLoseManager for a single endless scene). Pick one of resources/themes/*.tres for instant coherent UI styling. Note: contains zero gameplay mechanics — no spawning, particles, screen shake, or HUD; those must come from other repos.
- **License notes:** Root ATTRIBUTION.md: Godot Engine logo CC BY 4.0 (assets/godot_engine_logo), Git logo CC BY 3.0 (assets/git_logo); everything else MIT (LICENSE.txt, Marek Belski).

## godot-demo-projects: gui + audio

> **Top picks:** 1) gui/input_mapping — a complete, drop-in key-rebinding menu plus the user:// FileAccess.store_var persistence pattern that generalizes to high-score/settings saving. 2) audio/rhythm_game — the best-engineered code in scope: Conductor + 1-Euro-filter beat clock for music-synced gameplay, the canonical pause pattern (PROCESS_MODE_ALWAYS handler toggling get_tree().paused), timed spawning with hit windows, and signal-driven stats->HUD wiring that maps directly onto an arcade score/combo system. 3) gui/multiple_resolutions — the definitive recipe (code + README) for HUD/menus that survive any resolution/aspect ratio, including AspectRatioContainer clamping and a UI-scale setting. 4) audio/generator + audio/audio_effects — together cover 'generated sound': push_frame() procedural synthesis for retro SFX, per-bus effect toggling for audio polish (note the CC-BY music in audio_effects must not be shipped uncredited). 5) gui/custom_splash_screen + gui/theming_override — small but immediately liftable polish: seamless boot flow with proper load-vs-preload scene change, and the runtime StyleBox/theme-override recipe for menu styling.

### Audio Effects

`godot-demo-projects/audio/audio_effects`

- **Shows:** Toggling per-bus AudioEffects at runtime via AudioServer.set_bus_effect_enabled(bus, effect_idx, bool); a bus layout preloaded with Amplify, BandLimit, BandPass, Chorus, Compressor, Delay, Distortion, EQ, Reverb, etc., plus multiple AudioStreamPlayer SFX nodes.
- **Key files:** `audio_effects.gd`, `audio_effects.tscn`, `default_bus_layout (in .tscn/project)`
- **Reuse for our game:** Direct pattern for an audio options/SFX polish layer: put music and SFX on separate buses, toggle reverb/distortion for underwater/hit-stun states, one AudioStreamPlayer per SFX. The set_bus_effect_enabled pattern is exactly how you'd do a 'muffle audio on pause' effect.
- **License notes:** Music 'Monkeys Spinning Monkeys' by Kevin MacLeod is CC-BY 3.0 (attribution required); all SFX are Freesound CC0; icon CC0. Do not ship the music without credit.

### Audio BPM Sync

`godot-demo-projects/audio/bpm_sync`

- **Shows:** Two ways to get an accurate song-time clock: system clock (Time.get_ticks_usec compensated by AudioServer.get_time_to_next_mix + get_output_latency) vs sound clock (get_playback_position + get_time_since_last_mix - output_latency), converting time to beat number.
- **Key files:** `bpm_sync.gd`
- **Reuse for our game:** The ~50-line latency-compensation math is copy-pasteable for anything beat-synced: pulsing HUD/background to music, beat-timed enemy spawns, music-synced attract mode.
- **License notes:** Bundled music the_comeback2.ogg and lcd.ttf font have no license/credit text in the repo; treat as demo-only assets.

### Audio Device Changer

`godot-demo-projects/audio/device_changer`

- **Shows:** AudioServer.get_output_device_list()/get_output_device()/set_output_device() and get_speaker_mode(), listed in an ItemList.
- **Key files:** `Changer.gd`
- **Reuse for our game:** Low relevance except as an optional 'output device' dropdown in a settings menu; the 43-line script is the whole implementation if wanted.

### Audio Generator

`godot-demo-projects/audio/generator`

- **Shows:** Procedural audio from GDScript: AudioStreamGenerator + AudioStreamGeneratorPlayback.push_frame() filling a buffer with a sine wave each _process; setting mix_rate before play(); linear_to_db() for perceptual volume sliders.
- **Key files:** `generator_demo.gd`, `generator.tscn`
- **Reuse for our game:** HIGH for 'generated sound': the exact buffer-fill loop needed for retro synthesized SFX (blips, lasers, explosions) without shipping audio files — swap the sine for square/noise/envelope. Also the linear_to_db volume-slider idiom for the options menu.

### Mic Record

`godot-demo-projects/audio/mic_record`

- **Shows:** AudioEffectRecord on a 'Record' bus with an AudioStreamPlayer whose stream is AudioStreamMicrophone; get_recording() returns AudioStreamWAV, played back or saved via save_to_wav(); setting format/mix_rate/stereo.
- **Key files:** `MicRecord.gd`, `default_bus_layout.tres`
- **Reuse for our game:** low relevance (unless mic gimmick); the AudioStreamWAV save_to_wav pattern could serve replay/clip export but that's a stretch.
- **License notes:** Intro.ogg music has no credit text in the demo; treat as demo-only.

### MIDI Piano

`godot-demo-projects/audio/midi_piano`

- **Shows:** InputEventMIDI handling (OS.open_midi_inputs, MIDI_MESSAGE_NOTE_ON), procedurally instancing keyboard UI from two PackedScenes into HBoxContainers, and pitch-shifting one A440.wav sample via AudioStreamPlayer.pitch_scale = 2^((n-69)/12).
- **Key files:** `piano.gd`, `piano_keys/piano_key.gd`
- **Reuse for our game:** The pitch_scale = pow(2, semitones/12.0) trick is very reusable: play one SFX sample at varying pitches for combo escalation / pickup arpeggios (classic arcade polish) instead of authoring many samples.

### Rhythm Game

`godot-demo-projects/audio/rhythm_game`

- **Shows:** Production-quality beat clock: Conductor node blending jittery audio-thread time with stable system time via a 1-Euro filter (in _physics_process), PROCESS_MODE_ALWAYS + get_tree().paused pause handling, note spawning from chart data arrays, hit windows (perfect/good/miss) with input-latency setting, signals for stats/HUD updates, Tween-based judgment popups, metronome slaved to the conductor.
- **Key files:** `game_state/conductor.gd`, `globals/one_euro_filter.gd`, `game_state/note_manager.gd`, `scenes/main/pause_handler.gd`
- **Reuse for our game:** HIGH: Conductor + OneEuroFilter are drop-in for any music-synced gameplay; pause_handler.gd is the canonical 8-line SceneTree pause pattern; note_manager shows timed spawning + hit-window scoring + signal-driven HUD (PlayStats emitting 'changed') — the same architecture as an arcade score/combo system; global_settings.gd shows an autoload settings singleton.
- **License notes:** Metronome WAV is CC0 (Ludwig Peter Mueller). one_euro_filter.gd is MIT but carries a third-party copyright header (Patryk Kalinowski) that must be retained. Song the_comeback2.ogg has no explicit credit.

### Audio Spectrum

`godot-demo-projects/audio/spectrum`

- **Shows:** AudioEffectSpectrumAnalyzer on the master bus, read via AudioServer.get_bus_effect_instance() -> get_magnitude_for_frequency_range(), converted to dB energy and drawn as animated VU bars with _draw()/queue_redraw(), lerp-smoothed peaks and a reflection effect.
- **Key files:** `show_spectrum.gd`
- **Reuse for our game:** Good for juice: music-reactive menu/background visualizer or an equalizer bar in the HUD; also a clean example of custom _draw() rendering for lightweight HUD widgets.
- **License notes:** Bundled music track has no credit text; treat as demo-only.

### Text-to-Speech

`godot-demo-projects/audio/text_to_speech`

- **Shows:** DisplayServer.tts_get_voices/tts_speak/tts_pause/tts_stop with utterance callbacks (STARTED/ENDED/CANCELED/BOUNDARY), voice list in a Tree control, rate/pitch/volume/interrupt options.
- **Key files:** `voice_list.gd`
- **Reuse for our game:** low relevance (possible accessibility option for menu narration, but OS TTS quality varies).

### UI Accessibility

`godot-demo-projects/gui/accessibility`

- **Shows:** Godot 4.x accessibility API: queue_accessibility_update(), accessibility element RIDs for sub-items of a custom Control, accessibility actions (inc/dec/focus), live-region labels, and grab_focus() discipline for keyboard-driven UI.
- **Key files:** `custom_control.gd`, `controls.gd`, `controls.tscn`
- **Reuse for our game:** Moderate: the keyboard-focus conventions (grab_focus on menu open, full keyboard navigability) are worth copying for menus; full accessibility-RID work is optional polish.

### BiDi and Font Features

`godot-demo-projects/gui/bidi_and_font_features`

- **Shows:** BiDi text/structured-text overrides, line breaking and justification flags, OpenType font features and variable-font axes via FontVariation, loading system fonts, custom structured-text parser (custom_st_parser.gd).
- **Key files:** `bidi.gd`, `custom_st_parser.gd`
- **Reuse for our game:** low relevance unless shipping RTL locales; FontVariation axis tweaking could style a logo/title.
- **License notes:** Noto fonts under SIL OFL 1.1; Linux Libertine under its own OFL/GPL dual license (LICENSE files bundled).

### Control Gallery

`godot-demo-projects/gui/control_gallery`

- **Shows:** One scene exhibiting nearly every Control: Buttons, sliders, SpinBox, ProgressBar, ItemList, Tree (with scripted TreeItems + item buttons), TabContainer, HSplitContainer/VSplitContainer layout; almost no code.
- **Key files:** `control_gallery.tscn`, `tree.gd`
- **Reuse for our game:** Useful as a visual reference/palette when building settings menus and HUD, and as a theme test-bed (drop your Theme resource on it to preview every widget at once).

### Custom Splash Screen

`godot-demo-projects/gui/custom_splash_screen`

- **Shows:** Seamless custom boot splash: disable boot-splash image, match BG color to first frame, main scene = splash.tscn with autoplay AnimationPlayer, animation_finished -> change_scene_to_packed(load(...)) (deliberately load not preload), OS.set_restart_on_exit for a restart button, release feature-tag trick for skipping splash in dev.
- **Key files:** `splash.gd`, `splash.tscn`, `main.gd`
- **Reuse for our game:** Directly liftable for a polished boot flow (studio logo -> title screen); the load-vs-preload scene-change pattern and restart-on-exit trick apply to any game.

### Drag and Drop (GUI)

`godot-demo-projects/gui/drag_and_drop`

- **Shows:** Control drag-and-drop trio: _get_drag_data() with set_drag_preview(), _can_drop_data() type check, _drop_data(), demonstrated with ColorPickerButtons.
- **Key files:** `drag_drop_script.gd`
- **Reuse for our game:** low relevance for pure arcade; the 33-line pattern is the reference if you ever add inventory/loadout drag UI.

### GD Paint

`godot-demo-projects/gui/gd_paint`

- **Shows:** A small paint app: custom _draw() rendering of stroke lists (pen/eraser/rect/circle brushes), mouse capture inside a drawing area, undo of strokes/shapes, saving the viewport to PNG (get_viewport().get_texture().get_image().save_png).
- **Key files:** `paint_control.gd`, `tools_panel.gd`
- **Reuse for our game:** Mostly low relevance; the viewport-to-PNG screenshot snippet is handy for a 'share score screenshot' feature, and _draw()-based dynamic rendering informs trail/telemetry effects.

### GUI Input Mapping

`godot-demo-projects/gui/input_mapping`

- **Shows:** Full key-rebinding screen: toggle Button enters listen mode, _unhandled_key_input captures the key, InputMap.action_erase_events/action_add_event remaps, autoload KeyPersistence saves/loads the keymap dictionary to user:// with FileAccess.store_var/get_var, validating saved actions against current InputMap.
- **Key files:** `ActionRemapButton.gd`, `KeyPersistence.gd`, `InputRemapMenu.tscn`
- **Reuse for our game:** HIGH: drop-in controls-remapping menu; KeyPersistence.gd doubles as the template for any user:// save file (also directly applicable to high-score/settings persistence). Comment notes how to extend to gamepads via _input().

### MSDF Font

`godot-demo-projects/gui/msdf_font`

- **Shows:** Multichannel signed distance field font import vs traditional rasterization, runtime font swap via add_theme_font_override, outline_size theme constant override, crispness under scale/rotation.
- **Key files:** `sdf_font_demo.gd`, `sdf_font_demo.tscn`
- **Reuse for our game:** Import setting worth copying for HUD/score fonts that zoom or rotate (e.g. popping score numbers): enable MSDF on the font import and text stays crisp at any scale.
- **License notes:** Montserrat SemiBold TTF bundled with no license file in the demo (Montserrat is SIL OFL upstream — carry attribution if shipped).

### Multiple Resolutions and Aspect Ratios

`godot-demo-projects/gui/multiple_resolutions`

- **Shows:** canvas_items stretch mode + expand aspect, runtime changes to window.content_scale_mode/aspect/factor, AspectRatioContainer to clamp HUD width on ultrawide, GUI margin for TV overscan, MSDF font for scale-independent text; README is a mini-tutorial on base-window-size choice.
- **Key files:** `main.gd`, `main.tscn`, `README.md`
- **Reuse for our game:** HIGH: this is the checklist for making the arcade game's HUD/menus survive any window size; the AspectRatioContainer + gui_margin technique and the content_scale_factor 'UI scale' options-menu setting are directly liftable.

### Pseudolocalization

`godot-demo-projects/gui/pseudolocalization`

- **Shows:** TranslationServer.pseudolocalization_enabled and the internationalization/pseudolocalization/* project settings (accents, fake bidi, double vowels, expansion ratio) toggled at runtime with reload_pseudolocalization().
- **Key files:** `Pseudolocalization.gd`
- **Reuse for our game:** low relevance unless localizing; then it's a cheap way to catch UI text overflow in menus.

### RegEx

`godot-demo-projects/gui/regex`

- **Shows:** RegEx.compile/is_valid/search_all with capture groups, results rendered into a dynamic list of Labels.
- **Key files:** `regex.gd`
- **Reuse for our game:** low relevance (maybe name-entry validation for high-score initials).

### Rich Text Label with BBCode

`godot-demo-projects/gui/rich_text_bbcode`

- **Shows:** RichTextLabel BBCode: colors, wave/shake/rainbow text effects, tables, images, clickable [url] via meta_clicked -> OS.shell_open, print_rich(), plus get_tree().paused toggle showing animations halt when the tree pauses.
- **Key files:** `rich_text_bbcode.gd`, `rich_text_bbcode.tscn`
- **Reuse for our game:** Good for juicy HUD/text: [shake]/[wave]/[rainbow] BBCode is a free way to animate 'NEW HIGH SCORE!' or combo text; meta_clicked handles credits-screen links.

### GUI Theming Override

`godot-demo-projects/gui/theming_override`

- **Shows:** Runtime theme overrides: get_theme_stylebox().duplicate(), mutate StyleBoxFlat (border_color), add_theme_stylebox_override for normal/hover/pressed together, add_theme_color_override, remove_theme_*_override to reset; grab_focus for controller-friendly menus.
- **Key files:** `test.gd`
- **Reuse for our game:** The exact API recipe for restyling buttons/panels at runtime (selected-item highlights, unlock states, team colors) without authoring multiple Theme resources.

### GUI Translation

`godot-demo-projects/gui/translation`

- **Shows:** i18n via both CSV and gettext PO translations, TranslationServer.set_locale(), tr() keys, resource remapping per locale (localized audio), bundled multi-script fallback fonts.
- **Key files:** `translation_csv.gd`, `translation_po.gd`, `translations/ (csv + po folders)`
- **Reuse for our game:** Moderate: the CSV translation pipeline is the lowest-effort way to localize menu/HUD strings if desired; otherwise low relevance.
- **License notes:** Droid Sans font family under Apache License 2.0 (LICENSE.DroidSans.txt bundled).

### UI Mirroring

`godot-demo-projects/gui/ui_mirroring`

- **Shows:** Automatic RTL layout mirroring of Control hierarchies when TranslationServer.set_locale('ar') is active; layout_direction inheritance.
- **Key files:** `ui_mirroring.gd`, `ui_mirroring.tscn`
- **Reuse for our game:** low relevance unless shipping RTL locales.
- **License notes:** Noto fonts under SIL OFL 1.1 (LICENSE.Noto.txt bundled).

## godot-demo-projects: loading, compute, plugins, mono, xr

> **Top picks:** 1) mono/dodge_the_creeps — the single most relevant reference: a complete Godot 4 2D arcade loop (Timer-driven mob spawning along Path2D/PathFollow2D, screen-clamped input, AnimatedSprite2D, CanvasLayer HUD with signals and timed messages, music/SFX, restart flow); patterns port directly to GDScript. 2) loading/serialization — ready-made ConfigFile and JSON save/load templates to user://, exactly what's needed for high scores and settings persistence, including entity respawn on load. 3) loading/autoload — the SceneManager-autoload pattern (deferred scene swaps) that should underpin menu/game/game-over flow and any global score/audio singleton. 4) loading/load_threaded — ResourceLoader.load_threaded_request/get for hitch-free preloading behind menus/loading screens, cheap polish. 5) mono/pong — compact demonstration of signal-driven Area2D arcade collisions, Input.GetActionStrength analog input, and time-based difficulty ramping. Everything in xr/ and compute/ is low relevance for this build; plugins/ matters only if we later want a custom wave/level editor dock. Watch asset licensing in dodge/squash_the_creeps (CC-BY music, CC0 Kenney art, OFL fonts) if any assets are lifted rather than just code.

### Compute Shader Heightmap

`godot-demo-projects/compute/heightmap`

- **Shows:** RenderingDevice compute pipeline from GDScript: loading a .glsl compute shader, creating texture/sampler uniforms and uniform sets, dispatching, and reading results back into Image/ImageTexture. Compares CPU (FastNoiseLite loop) vs GPU generation of an island heightmap with GradientTexture1D overlay and timing readouts.
- **Key files:** `compute/heightmap/main.gd`, `compute/heightmap/compute_shader.glsl`
- **Reuse for our game:** low relevance (GPU compute for procedural texture generation is overkill for a 2D arcade game; FastNoiseLite usage in main.gd is a handy reference for procedural noise though)

### Compositor Effects (Post-Processing)

`godot-demo-projects/compute/post_shader`

- **Shows:** CompositorEffect resource subclass (@tool) with _render_callback submitting a compute dispatch for full-screen post-processing (grayscale + template shader with runtime-injected user code, push constants, color/depth image access). Forward+ only, attached via Compositor on WorldEnvironment/Camera3D.
- **Key files:** `compute/post_shader/post_process_shader.gd`, `compute/post_shader/post_process_grayscale.gd`, `compute/post_shader/post_process_grayscale.glsl`
- **Reuse for our game:** low relevance (CompositorEffect applies to 3D rendering in RD renderers; full-screen FX for a 2D game are better done with a CanvasLayer + ColorRect canvas_item shader)

### Compute Texture (water ripples)

`godot-demo-projects/compute/texture`

- **Shows:** Compute shader writing a height texture consumed by a material shader via Texture2DRD; RenderingServer.call_on_render_thread for render-thread init/dispatch; RID cycling of three textures for frame history; mouse-driven wave input on an Area3D plane.
- **Key files:** `compute/texture/water_plane/water_plane.gd`, `compute/texture/water_plane/water_compute.glsl`, `compute/texture/water_plane/water_shader.gdshader`
- **Reuse for our game:** low relevance (advanced GPU technique; a 2D ripple/distortion effect is simpler as a canvas shader)
- **License notes:** polyhaven/ sky assets CC0 1.0 (Poly Haven), noted in README

### Autoload (singleton scene switcher)

`godot-demo-projects/loading/autoload`

- **Shows:** Autoload singleton (project.godot [autoload]) implementing manual scene changes: call_deferred to avoid freeing the running scene mid-callback, free current_scene, ResourceLoader.load + instantiate, add to root, reassign get_tree().current_scene.
- **Key files:** `loading/autoload/global.gd`, `loading/autoload/scene_a.gd`
- **Reuse for our game:** Directly reusable: a global SceneManager autoload is the standard backbone for menu->game->game-over flow; same autoload pattern serves global score/audio managers

### Threaded Loading (ResourceLoader)

`godot-demo-projects/loading/load_threaded`

- **Shows:** ResourceLoader.load_threaded_request() to queue background loads and load_threaded_get() to retrieve finished resources (textures) without blocking the main thread.
- **Key files:** `loading/load_threaded/load_threaded.gd`
- **Reuse for our game:** Reusable for polish: preload heavy scenes/audio during the title screen or a loading screen so level start is hitch-free; pair with load_threaded_get_status for a progress bar

### Run-time File Saving and Loading

`godot-demo-projects/loading/runtime_save_load`

- **Shows:** Loading/saving files bypassing the import system: Image.load_from_file + ImageTexture, AudioStreamOggVorbis/MP3/WAV runtime loading, GLTFDocument import/export, FontFile dynamic fonts, ZIPReader/ZIPPacker, FileAccess, FileDialog UI wiring.
- **Key files:** `loading/runtime_save_load/runtime_save_load.gd`, `loading/runtime_save_load/runtime_save_load.tscn`
- **Reuse for our game:** Marginal: useful only if supporting user-generated content or saving screenshots; the FileDialog + error-handling patterns are a decent reference
- **License notes:** examples/fonts Inter (SIL OFL 1.1); examples/3d_scenes/gltf CC0 (Poly Haven); examples/audio CC BY-SA 4.0 (Red Eclipse)

### Scene Changer

`godot-demo-projects/loading/scene_changer`

- **Shows:** Minimal get_tree().change_scene_to_file() switching between two scenes from button signals.
- **Key files:** `loading/scene_changer/scene_a.gd`
- **Reuse for our game:** Reusable one-liner pattern for menu/game/game-over screen transitions when no persistent state manager is needed

### Saving and Loading (Serialization)

`godot-demo-projects/loading/serialization`

- **Shows:** Save/load of game state (player position/health/rotation, enemy list) in two formats: ConfigFile (stores Variants natively to user://) and JSON (var_to_str/str_to_var round-tripping, JSON.stringify/parse). Uses node groups + call_group to clear/respawn enemies on load.
- **Key files:** `loading/serialization/save_load_config_file.gd`, `loading/serialization/save_load_json.gd`, `loading/serialization/enemy.gd`, `loading/serialization/player.gd`
- **Reuse for our game:** Directly reusable: exact template for persisting high scores/settings to user:// via ConfigFile, and for full game-state save/restore including respawning entities

### Loading with Threads

`godot-demo-projects/loading/threads`

- **Shows:** Manual Thread API: Thread.new(), start(callable.bind(arg)), call_deferred back to main thread for node access, wait_to_finish() for return value, and _exit_tree cleanup discipline.
- **Key files:** `loading/threads/thread.gd`
- **Reuse for our game:** Reusable pattern for any background work (procedural generation, leaderboard I/O) without frame hitches; load_threaded API is usually simpler for pure resource loading

### 2.5D with C#

`godot-demo-projects/mono/2.5d`

- **Shows:** C# editor plugin adding custom node types ([Tool] Node25D driving a Node2D from a 3D child's position via custom Basis25D/Transform25D math structs), YSort25D depth sorting, ShadowMath25D downward-cast shadows, multiple projection modes (isometric, oblique, 45deg); 3D physics bodies used purely for math with 2D sprites for display.
- **Key files:** `mono/2.5d/addons/node25d-cs/Node25D.cs`, `mono/2.5d/addons/node25d-cs/Basis25D.cs`, `mono/2.5d/assets/player/PlayerMath25D.cs`, `mono/2.5d/addons/node25d-cs/YSort25D.cs`
- **Reuse for our game:** low relevance unless the game wants an isometric/2.5D look; the 3D-physics-with-2D-sprites trick and Y-sorting logic are the only transferable ideas
- **License notes:** assets/mr_mrs_robot.ogg CC-BY (Juan Linietsky), noted in README

### Android IAP with C#

`godot-demo-projects/mono/android_iap`

- **Shows:** C# wrapper (GooglePlayBilling.cs) around the Android GodotGooglePlayBilling plugin singleton: Engine singleton access, Connect with Callable.From for typed signal callbacks, purchase/consume/acknowledge flow, SKU query parsing into C# records.
- **Key files:** `mono/android_iap/Main.cs`, `mono/android_iap/GodotGooglePlayBilling/GooglePlayBilling.cs`
- **Reuse for our game:** low relevance (only if shipping paid Android IAP; requires Google Play upload to test)

### Dodge the Creeps with C#

`godot-demo-projects/mono/dodge_the_creeps`

- **Shows:** Complete minimal 2D arcade game: Area2D player with Input.IsActionPressed 8-way movement clamped to viewport, AnimatedSprite2D animation switching/flipping, mob spawning on Timer along Path2D/PathFollow2D with random direction/speed, VisibleOnScreenNotifier2D auto-despawn, CanvasLayer HUD (score label, timed messages, start button, custom signals), game-over flow with async/await ToSignal, music + death AudioStreamPlayer, group-based CallGroup(QueueFree) cleanup.
- **Key files:** `mono/dodge_the_creeps/Main.cs`, `mono/dodge_the_creeps/Player.cs`, `mono/dodge_the_creeps/HUD.cs`, `mono/dodge_the_creeps/Mob.cs`
- **Reuse for our game:** Highly reusable: the whole game loop (Timer-driven spawning/waves, PathFollow2D edge spawning, HUD with signals, restart flow, SFX/music wiring, screen-clamped input) maps 1:1 to a GDScript Godot 4 arcade game
- **License notes:** art music CC-BY 3.0 (HorrorPen); Kenney 'Abstract Platformer' art CC0; Xolonium font SIL OFL 1.1 (fonts/LICENSE.txt)

### Pong Multiplayer with C#

`godot-demo-projects/mono/multiplayer_pong`

- **Shows:** ENetMultiplayerPeer host/join lobby in C#: connecting multiplayer signals (peer_connected, connection_failed, server_disconnected) via Callable, deferred signal connections, spawning the game scene on connect, authority-split paddle input.
- **Key files:** `mono/multiplayer_pong/logic/Lobby.cs`, `mono/multiplayer_pong/logic/Pong.cs`, `mono/multiplayer_pong/logic/Paddle.cs`
- **Reuse for our game:** Reusable only if adding local/LAN multiplayer; the Lobby host/join UI + ENet setup is a compact template, otherwise low relevance

### Pong with C#

`godot-demo-projects/mono/pong`

- **Shows:** Area2D-based arcade physics without physics bodies: ball/paddles/walls as Area2D with area_entered signals mutating ball direction, Input.GetActionStrength for analog-friendly paddle input, per-node input action names derived from node Name, ball speed ramping over time.
- **Key files:** `mono/pong/Logic/Ball.cs`, `mono/pong/Logic/Paddle.cs`, `mono/pong/Logic/CeilingFloor.cs`
- **Reuse for our game:** Reusable patterns: signal-driven Area2D collisions for lightweight arcade objects, GetActionStrength input, difficulty ramp via speed accumulation

### Squash the Creeps (3D, C#)

`godot-demo-projects/mono/squash_the_creeps`

- **Shows:** 3D beginner game: CharacterBody3D movement/jump/squash mechanic, mob spawning on Timer at random PathFollow3D.ProgressRatio along a Path3D, [Signal] Squashed wired to a score label, GetTree().ReloadCurrentScene() restart, AnimationPlayer character animation, music player scene.
- **Key files:** `mono/squash_the_creeps/Main.cs`, `mono/squash_the_creeps/Player.cs`, `mono/squash_the_creeps/Mob.cs`, `mono/squash_the_creeps/ScoreLabel.cs`
- **Reuse for our game:** Moderate: spawn-along-path with random ProgressRatio, signal-to-scorelabel wiring, and ReloadCurrentScene restart all translate directly to 2D; movement code is 3D-specific
- **License notes:** art music CC-BY 3.0 (HorrorPen); Montserrat font SIL OFL 1.1 (fonts/LICENSE.txt)

### Plugin Demos (4 editor plugins in one project)

`godot-demo-projects/plugins`

- **Shows:** EditorPlugin APIs: add_custom_type for a custom node (custom_node), _has_main_screen/_make_visible main-screen tab (main_screen), dock via add_control_to_dock plus custom Resource with ResourceFormatLoader/ResourceFormatSaver and EditorImportPlugin import/export round-trips (material_creator), and a minimal EditorImportPlugin for a custom *.mtxt file type (simple_import_plugin).
- **Key files:** `plugins/addons/custom_node/heart_plugin.gd`, `plugins/addons/main_screen/main_screen_plugin.gd`, `plugins/addons/material_creator/material_plugin.gd`, `plugins/addons/simple_import_plugin/import.gd`
- **Reuse for our game:** low relevance to gameplay; useful only if building custom editor tooling (e.g., a level/wave editor dock) for the project

### Mobile VR Interface Demo

`godot-demo-projects/xr/mobile_vr_interface_demo`

- **Shows:** Enabling the built-in MobileVRInterface: XRServer.find_interface + initialize, viewport.use_xr, Viewport.VRS_XR variable rate shading, simple keyboard movement for desktop stereo-rendering testing.
- **Key files:** `xr/mobile_vr_interface_demo/main.gd`
- **Reuse for our game:** low relevance

### OpenXR Binding Modifier Demo

`godot-demo-projects/xr/openxr_binding_modifier_demo`

- **Shows:** OpenXR action map binding modifiers (analog threshold, dpad emulation) configured in a minimal custom action map; controller state display UI; local-floor reference space; standard start_vr.gd OpenXR session bootstrap (session signals, VRS, vsync off).
- **Key files:** `xr/openxr_binding_modifier_demo/start_vr.gd`, `xr/openxr_binding_modifier_demo/controller_state.gd`
- **Reuse for our game:** low relevance

### OpenXR Character-Centric Movement

`godot-demo-projects/xr/openxr_character_centric_movement`

- **Shows:** Room-scale XR locomotion with CharacterBody3D as root: physical player movement reconciled against the body via XROrigin3D offsetting, recenter math using XRServer.center_on_hmd and head tracker XRPose.get_adjusted_transform, screen blackout shader when the body can't follow.
- **Key files:** `xr/openxr_character_centric_movement/player.gd`, `xr/openxr_character_centric_movement/start_vr.gd`, `xr/openxr_character_centric_movement/objects/black_out.gd`
- **Reuse for our game:** low relevance

### OpenXR Composition Layers

`godot-demo-projects/xr/openxr_composition_layers`

- **Shows:** OpenXRCompositionLayer (equirect curved screen) presenting a SubViewport-rendered 2D UI at native quality outside lens distortion, with controller ray pointer interaction into the layer's UI (intersects_ray, pointer shaders).
- **Key files:** `xr/openxr_composition_layers/main.gd`, `xr/openxr_composition_layers/handle_pointers.gd`, `xr/openxr_composition_layers/ui.gd`
- **Reuse for our game:** low relevance

### OpenXR Hand Tracking Demo

`godot-demo-projects/xr/openxr_hand_tracking_demo`

- **Shows:** Unified hand tracking: XRHandModifier3D-driven hand mesh from controller or optical tracking, custom fallback SkeletonModifier3D, action-map-driven pickup/grab logic on RigidBody3D objects, per-hand tracking-source info display.
- **Key files:** `xr/openxr_hand_tracking_demo/hand_controller.gd`, `xr/openxr_hand_tracking_demo/pickup/pickup_handler.gd`, `xr/openxr_hand_tracking_demo/xr_hand_fallback_modifier_3d.gd`
- **Reuse for our game:** low relevance

### OpenXR Origin-Centric Movement

`godot-demo-projects/xr/openxr_origin_centric_movement`

- **Shows:** Room-scale XR locomotion with XROrigin3D as root node: moving the origin to drive virtual movement, companion/contrast demo to the character-centric approach; same blackout-on-collision and recenter logic.
- **Key files:** `xr/openxr_origin_centric_movement/player.gd`, `xr/openxr_origin_centric_movement/start_vr.gd`
- **Reuse for our game:** low relevance

### OpenXR Passthrough

`godot-demo-projects/xr/openxr_passthrough`

- **Shows:** AR passthrough: XRInterface.environment_blend_mode (alpha blend/additive/opaque) switching, viewport.transparent_bg + transparent Environment background color, shadow_to_opacity 'holepunch' shader cutting a real-world window into the scene, fading 3D message label.
- **Key files:** `xr/openxr_passthrough/main.gd`, `xr/openxr_passthrough/holepunch.gdshader`, `xr/openxr_passthrough/fade_message.gd`
- **Reuse for our game:** low relevance
- **License notes:** clean (requires external OpenXR Vendor plugin not included in repo)

### OpenXR Render Models

`godot-demo-projects/xr/openxr_render_models`

- **Shows:** OpenXRRenderModelManager node showing runtime-provided controller 3D models per XRController3D, plus physics-based 'collision hands' that follow tracked controllers.
- **Key files:** `xr/openxr_render_models/collision_hands.gd`, `xr/openxr_render_models/start_vr.gd`
- **Reuse for our game:** low relevance

### OpenXR Spectator View

`godot-demo-projects/xr/openxr_spectator_view`

- **Shows:** Different desktop vs headset views: main game inside a SubViewport whose output feeds the HMD, desktop window shows a 3rd-person/stabilized camera or raw per-eye output (Texture2DRD, compatibility renderer), visual layer masks to show/hide the player head per camera, per-platform main scene via export feature tags.
- **Key files:** `xr/openxr_spectator_view/spectator.gd`, `xr/openxr_spectator_view/main.gd`, `xr/openxr_spectator_view/cameras/stabilized_camera.gd`
- **Reuse for our game:** low relevance (the SubViewport + visual-layer-mask multi-camera technique is a general trick, e.g. for minimaps or replay views, but overkill for a 2D arcade game)

### WebXR Demo

`godot-demo-projects/xr/webxr`

- **Shows:** WebXRInterface: async session lifecycle via signals (session_supported/started/ended/failed), select/squeeze input signals, session_mode and requested_reference_space_types fallback chain, entering VR from an HTML5 button, polyfill head-include for web export.
- **Key files:** `xr/webxr/main.gd`, `xr/webxr/README.md`
- **Reuse for our game:** low relevance
- **License notes:** clean (README instructs embedding CDN-hosted WebXR polyfills in web export)

## godot-demo-projects: misc + viewport

> **Top picks:** 1) misc/pause — the canonical Godot 4 pause implementation (tree pause + PROCESS_MODE_ALWAYS UI), lift verbatim for a pause menu. 2) misc/joypads — deadzone axis handling, hot-plug signals, and a complete in-game controller remap wizard producing SDL mapping strings; the hardest gamepad-support work already done. 3) viewport/split_screen_input — device-ID input routing and shared-World2D split screen for local-multiplayer arcade modes. 4) misc/hdr_output's in_game_hdr_settings.gd — clean ConfigFile-persisted in-game settings panel pattern, the template for an options menu that saves to user://. 5) viewport/dynamic_split_screen — the SubViewport-textures-into-one-fullscreen-shader compositing architecture, reusable for 2D post-FX, transitions, and co-op views. Note: the requested 'saving' and 'shaders' demos do not exist under misc/ in this checkout; the closest equivalents in scope are the ConfigFile pattern (hdr_output) and the gdshader usage in noise_viewer/dynamic_split_screen.

### 2.5D Demo (GDScript)

`godot-demo-projects/misc/2.5d`

- **Shows:** Mixing 3D physics (CharacterBody3D/StaticBody3D) with 2D rendering via a custom Node25D that projects Vector3 positions to 2D with a 3-Vector2 basis matrix (isometric, 45deg, oblique, top-down view modes). Includes an EditorPlugin with a custom main-screen 2.5D viewport, a YSort25D child sorter, and ShadowMath25D drop-shadow casting.
- **Key files:** `addons/node25d/node_25d.gd`, `addons/node25d/y_sort_25d.gd`, `assets/player/player_math_25d.gd`, `addons/node25d/node25d_plugin.gd`
- **Reuse for our game:** Player movement patterns (Input.get_vector, move_and_slide, position-reset on fall) and manual y-sorting logic are liftable; the basis-projection trick is useful only if the arcade game wants a fake-isometric look. Otherwise moderate-low relevance.
- **License notes:** assets/mr_mrs_robot.ogg is CC-BY (Copyright circa 2008 Juan Linietsky) — attribution required; rest MIT

### Custom Logging

`godot-demo-projects/misc/custom_logging`

- **Shows:** Godot 4 Logger class subclassing (_log_message/_log_error with error types and ScriptBacktrace), registering it alongside built-in file logging, thread-safe UI updates via call_deferred, and an in-game BBCode console in a RichTextLabel; also OS.crash() and reading logging project settings.
- **Key files:** `custom_logger_ui.gd`, `main.gd`, `custom_logger_ui.tscn`
- **Reuse for our game:** Drop-in in-game debug console/error overlay for development builds; the thread-safe Logger-to-RichTextLabel pattern is directly reusable for a debug HUD.
- **License notes:** Bundles JetBrains Mono woff2 fonts with no license text in the demo (JetBrains Mono is OFL-1.1 upstream — attribution/license file needed if shipped)

### Graphics Tablet Input

`godot-demo-projects/misc/graphics_tablet_input`

- **Shows:** Pen pressure/tilt/inversion via InputEventMouseMotion, Input.use_accumulated_input = false for low-latency input, drawing with Line2D plus a continuously rebuilt width Curve, splitting Line2D strokes at 1024 points for performance, toggling V-Sync at runtime, 2D MSAA.
- **Key files:** `graphics_tablet_input.gd`, `project.godot`
- **Reuse for our game:** Line2D trail/stroke technique (with width curve and point-count splitting) works for bullet trails or drawing mechanics; the input-accumulation and V-Sync latency notes matter for responsive arcade feel. Moderate relevance.

### HDR Output

`godot-demo-projects/misc/hdr_output`

- **Shows:** Window.hdr_output_requested, DisplayServer HDR reference/max luminance APIs, capability detection, tonemap comparison scenes, and an in-game graphics settings panel persisted with ConfigFile to user://hdr_settings.cfg (with process_mode toggling on visibility).
- **Key files:** `in_game_hdr_settings/in_game_hdr_settings.gd`, `main/developer_settings.gd`, `color_sweep/color_sweep.gdshader`
- **Reuse for our game:** The ConfigFile save/load settings-panel pattern (in_game_hdr_settings.gd) is a solid template for an options menu that persists graphics/audio settings; HDR itself is low relevance. The CC0 Super Mountain Dusk parallax art is freely reusable.
- **License notes:** output_max_linear_value/Super Mountain Dusk/ art pack is CC0 by Luis Zuno (ansimuz) per bundled public-license.txt — no attribution required; rest MIT

### Joypads Demo

`godot-demo-projects/misc/joypads`

- **Shows:** Full joypad API: Input.joy_connection_changed, get_connected_joypads, get_joy_name/guid, get_joy_axis polling with deadzone handling, per-button/axis UI highlighting, vibration, and a step-by-step controller remap wizard that builds SDL mapping strings (Input.add_joy_mapping) in a SubViewport diagram.
- **Key files:** `joypads.gd`, `remap/remap_wizard.gd`, `remap/joy_mapping.gd`
- **Reuse for our game:** High value: deadzone-scaled axis handling, hot-plug connection signals, and a complete in-game controller remapping UI are directly liftable for arcade gamepad support and a rebind menu.
- **License notes:** joypads.gd header: MIT with author credit 'Dana Olson <dana@shineuponthee.com>' — MIT but keep the notice

### Large World Coordinates

`godot-demo-projects/misc/large_world_coordinates`

- **Shows:** Float precision jitter far from origin, OS.has_feature("double") detection for custom precision=double engine builds, plus a simple orbit camera (mouse-drag rotate, wheel zoom, clampf).
- **Key files:** `controls.gd`, `test.tscn`
- **Reuse for our game:** low relevance (orbit-camera snippet aside; a screen-sized arcade game never hits precision limits)

### Matrix Transform

`godot-demo-projects/misc/matrix_transform`

- **Shows:** Editor-only (@tool) visualization of Transform2D/Transform3D basis and origin vectors using Line2D gizmo markers; teaches transform composition, and the PackedVector2Array copy-on-write gotcha when mutating Line2D.points.
- **Key files:** `marker/AxisMarker2D.gd`, `marker/AxisMarker3D.gd`
- **Reuse for our game:** low relevance (educational playground, not runnable gameplay; the Line2D.points mutation gotcha is the one useful takeaway)

### Multiple Windows

`godot-demo-projects/misc/multiple_windows`

- **Shows:** Window class family: embedding/unembedding subwindows (Viewport.gui_embed_subwindows), transient/transparent/draggable windows, all Dialog types (AcceptDialog, ConfirmationDialog, FileDialog), Popup/PopupMenu/PopupPanel usage, and StatusIndicator (system tray icon).
- **Key files:** `scenes/main_scene.gd`, `scenes/draggable_window`, `scenes/popup_menu`
- **Reuse for our game:** Mostly low relevance for arcade gameplay; ConfirmationDialog/AcceptDialog wiring is handy for quit-confirm dialogs, otherwise skip.

### Noise Viewer

`godot-demo-projects/misc/noise_viewer`

- **Shows:** FastNoiseLite + NoiseTexture2D live parameter tweaking (seed, frequency, fractal octaves/gain/lacunarity, cellular params) from SpinBox/OptionButton UI, and passing min/max range into a canvas_item shader via set_shader_parameter.
- **Key files:** `noise_viewer.gd`, `noise_viewer.gdshader`, `noise_viewer.tscn`
- **Reuse for our game:** FastNoiseLite recipe reusable for procedural backgrounds, screen-shake noise sources, or dissolve/static shader effects; UI-to-shader-uniform plumbing is a good reference.

### OS Test

`godot-demo-projects/misc/os_test`

- **Shows:** OS/DisplayServer API grab-bag: clipboard, environment vars, executable path, locale, date/time, screen DPI/orientation, executing external binaries, plus optional C# preprocessor-define detection (CSharpTest.cs) in a GDScript project.
- **Key files:** `os_test.gd`, `actions.gd`
- **Reuse for our game:** low relevance (useful only as an API reference sheet, e.g. OS.get_user_data_dir for save paths)

### Pause Demo

`godot-demo-projects/misc/pause`

- **Shows:** SceneTree pausing: get_tree().paused, Node.PROCESS_MODE_ALWAYS on the pause button so it keeps processing while paused, and interactively switching a node's process_mode (Inherit/Pausable/WhenPaused/Always/Disabled) to show each mode's effect on an AnimationPlayer.
- **Key files:** `pause_button.gd`, `process_mode.gd`, `spinpause.tscn`
- **Reuse for our game:** Directly reusable: this is the canonical Godot 4 pause-menu pattern (pause the tree, mark the pause UI PROCESS_MODE_ALWAYS). Fifteen lines to lift verbatim.

### Window Management

`godot-demo-projects/misc/window_management`

- **Shows:** DisplayServer window control: fullscreen/windowed/minimized/maximized modes, resize/move, always-on-top, per-pixel transparency, mouse modes (captured/confined/hidden), screen count/DPI/refresh-rate queries, and Web-platform feature gating via OS.has_feature("web").
- **Key files:** `control.gd`, `observer/observer.gd`
- **Reuse for our game:** The fullscreen-toggle and screen-info snippets belong in any options menu; mouse-capture modes useful if the arcade game hides the cursor. Cherry-pick a few functions.

### 2D in 3D

`godot-demo-projects/viewport/2d_in_3d`

- **Shows:** Rendering a 2D game (self-contained Pong: Rect2.has_point paddle collision, speed-up on hit, randomized bounce) into a SubViewport, then mapping viewport.get_texture() onto a 3D quad's albedo; CLEAR_MODE_ONCE and a sine-based camera idle sway.
- **Key files:** `2d_in_3d.gd`, `pong.gd`
- **Reuse for our game:** pong.gd is a minimal arcade-loop reference (ball physics without physics engine, speed ramping); the SubViewport-to-texture trick enables CRT-cabinet or picture-in-picture presentation of the game.

### 3D in 2D

`godot-demo-projects/viewport/3d_in_2d`

- **Shows:** Rendering a 3D scene (animated GLB robot) into a SubViewport shown as a Sprite2D texture, plus resolution-independent handling: reacting to root Viewport.size_changed and rescaling the viewport/sprite to keep quality on window resize.
- **Key files:** `3d_in_2d.gd`, `robot_3d.gd`
- **Reuse for our game:** The size_changed resize-compensation pattern is useful for any resolution-independent 2D game; embedding a 3D character preview in a 2D menu (character select screen) is the concrete use.

### 3D Resolution Scaling

`godot-demo-projects/viewport/3d_scaling`

- **Shows:** Viewport.scaling_3d_scale and scaling_3d_mode (bilinear/FSR/FSR2) at runtime to downscale 3D rendering without blurring 2D UI; ClassDB enum introspection for label text; _unhandled_input action handling.
- **Key files:** `hud.gd`, `cubes.tscn`
- **Reuse for our game:** low relevance for pure 2D (scaling_3d_* does not affect 2D); only the input-action-cycling HUD snippet is generically reusable.
- **License notes:** Bundles noto_sans_ui_regular.ttf with no license text in the demo (Noto fonts are OFL/Apache upstream — needs license file if shipped)

### Dynamic Split Screen

`godot-demo-projects/viewport/dynamic_split_screen`

- **Shows:** Voronoi/Lego-style split screen: two Camera3Ds in two SubViewports, both textures fed as uniforms into one canvas_item shader on a fullscreen TextureRect; GDScript computes camera midpoint/separation and per-frame shader params (split line angle, thickness, activation) via set_shader_parameter.
- **Key files:** `camera_controller.gd`, `split_screen.gdshader`, `player.gd`
- **Reuse for our game:** The fullscreen-TextureRect + shader-uniform compositing pipeline is the reusable core — same architecture drives 2D co-op split screen, transitions, or fullscreen post-FX driven from GDScript.

### GUI in 3D

`godot-demo-projects/viewport/gui_in_3d`

- **Shows:** Interactive GUI on a 3D quad: SubViewport renders a Control scene, Area3D input_event physics picking converts 3D hit position to viewport 2D coords (affine_inverse), forwards synthesized mouse/touch events via Viewport.push_input, NOTIFICATION_VP_MOUSE_ENTER/EXIT, billboard handling.
- **Key files:** `gui_3d.gd`, `gui_panel_3d.tscn`
- **Reuse for our game:** low relevance for a 2D game (3D-specific input forwarding), unless doing a 3D cabinet/diegetic menu gimmick.

### Screen Capture

`godot-demo-projects/viewport/screen_capture`

- **Shows:** get_viewport().get_texture().get_image() to grab a screenshot, ImageTexture.create_from_image to redisplay it, Button.grab_focus for keyboard/gamepad UI navigation, Color.from_hsv randomized modulate.
- **Key files:** `screen_capture.gd`
- **Reuse for our game:** Ten-line screenshot recipe — reusable for share/screenshot features, save-slot thumbnails, or freeze-frame/death-screen effects; img.save_png is one call away.

### Split Screen Input

`godot-demo-projects/viewport/split_screen_input`

- **Shows:** Local multiplayer input routing: 4 SubViewportContainers sharing one World2D, a custom SubViewportContainer overriding _propagate_input_event to filter events per screen by keyboard key set or joypad device ID, runtime keybinding selection via OptionButton, per-player modulate colors.
- **Key files:** `root.gd`, `sub_viewport_container.gd`, `split_screen.gd`, `player.gd`
- **Reuse for our game:** High value for local-multiplayer arcade: device-ID-based joypad routing and _propagate_input_event filtering solve 'which controller drives which player'; the shared-World2D setup gives cheap same-arena split screen.

## godot-demo-projects: networking + mobile

> **Top picks:** 1) multiplayer_bomber — even ignoring networking, it is the best single source in this batch for arcade-game scaffolding: complete input map (keyboard+gamepad) in project.godot, lobby/menu flow with error handling, code-built score HUD with themed Labels, spawn-cooldown and AnimationPlayer-driven explosion lifecycle, and the autoload-gamestate-with-signals architecture we should copy for game flow. 2) multiplayer_pong — logic/lobby.gd is the cleanest menu/status-UI template, and ball.gd/paddle.gd give ready-made arcade ball mechanics (speed ramp on bounce, viewport-bounds clamping, score-to-win end state) plus integer-scale pixel-perfect display settings. 3) multitouch_cubes' gesture_area.gd — the only serious gesture recognizer in the repo; worth lifting if the arcade game targets touch (pinch-zoom camera, drag controls). 4) websocket_chat's websocket/WebSocketClient.gd + WebSocketServer.gd — clean class_name'd, signal-driven WebSocket wrappers to keep on the shelf for an online leaderboard later. Everything else in this batch (webrtc_*, websocket_minimal/multiplayer, android_iap, sensors, multitouch_view) is infrastructure- or platform-specific with little to lift for a polished local 2D arcade game.

### Multiplayer Bomber

`godot-demo-projects/networking/multiplayer_bomber`

- **Shows:** Full ENet high-level multiplayer game: ENetMultiplayerPeer host/join, autoload gamestate singleton with multiplayer.peer_connected/disconnected signals, @rpc functions (any_peer/call_local), MultiplayerSpawner with custom spawn_function for players and bombs, MultiplayerSynchronizer authority per-player (InputsSync), lobby UI, TileMap arena, Area2D bomb with PhysicsRayQueryParameters2D line-of-sight check, per-player score HUD built from code.
- **Key files:** `gamestate.gd`, `player.gd`, `bomb_spawner.gd`, `lobby.gd`
- **Reuse for our game:** High. gamestate.gd is a clean template for a lobby/game-state autoload with signals; lobby.gd shows menu flow with error dialogs and disabled-button states; project.godot has a complete WASD+arrows+gamepad input map plus canvas_items stretch and 2D pixel-snap settings; score.gd shows building a HUD scoreboard with font/outline theme overrides in code; get_player_color (HSV from name hash) is a nice per-player tint trick; bomb spawn cooldown pattern and AnimationPlayer-driven explode/despawn are directly liftable even for single-player.
- **License notes:** montserrat.otf font bundled with no license file in the demo (Montserrat is SIL OFL upstream; needs attribution if reused); rest is repo MIT

### Pong Multiplayer

`godot-demo-projects/networking/multiplayer_pong`

- **Shows:** Minimal 2-peer ENet game: create_server(port, 1)/create_client, ENet range-coder compression, per-node set_multiplayer_authority for the remote paddle, @rpc("unreliable") position sync, authority-split scoring (each peer judges its own side), Input.get_axis paddle control, Area2D ball bounce with rpc'd randomized direction.
- **Key files:** `logic/lobby.gd`, `logic/ball.gd`, `logic/paddle.gd`, `logic/pong.gd`
- **Reuse for our game:** Medium. lobby.gd is the tidiest host/join menu in the repo (status labels, disabled buttons, clean _end_game teardown with CONNECT_DEFERRED note); ball.gd/paddle.gd show simple arcade ball physics with speed ramp-up (speed *= 1.1 on bounce), screen-bounds clamping via get_viewport_rect(), and score-to-win + winner-label + exit-button flow in pong.gd; project.godot shows integer-scale pixel-perfect stretch (stretch/scale_mode=integer, texture filter nearest).

### WebRTC Minimal

`godot-demo-projects/networking/webrtc_minimal`

- **Shows:** WebRTCPeerConnection + create_data_channel basics with both peers in one process: session_description_created/ice_candidate_created signal wiring, offer/answer exchange, per-frame poll(), plus a toy in-process autoload 'Signaling' server variant.
- **Key files:** `minimal.gd`, `chat.gd`, `Signaling.gd`
- **Reuse for our game:** low relevance

### WebRTC Signaling (WebSocket signaling server/client)

`godot-demo-projects/networking/webrtc_signaling`

- **Shows:** Production-shaped WebRTC lobby stack: WebSocketPeer JSON protocol (JOIN/ID/OFFER/ANSWER/CANDIDATE/SEAL), WebRTCMultiplayerPeer in mesh or client-server mode with STUN config, a GDScript TCPServer+WebSocketPeer signaling server with lobby/timeout/seal logic, an equivalent Node.js server, and per-branch MultiplayerAPI via SceneTree.set_multiplayer to run several clients in one scene.
- **Key files:** `client/multiplayer_client.gd`, `client/ws_webrtc_client.gd`, `server/ws_webrtc_server.gd`, `server_node/server.js`
- **Reuse for our game:** low relevance for a local arcade game; only useful if browser-to-browser multiplayer is ever added.
- **License notes:** clean (requires external webrtc-native GDExtension, not vendored)

### WebSocket Chat

`godot-demo-projects/networking/websocket_chat`

- **Shows:** Reusable class_name WebSocketClient/WebSocketServer wrappers around WebSocketPeer + TCPServer: state-change signal emission from poll(), broadcast/exclude send semantics (peer_id 0/negative), pending-peer handshake timeout, TLS options, RichTextLabel log UI.
- **Key files:** `websocket/WebSocketClient.gd`, `websocket/WebSocketServer.gd`, `client.gd`, `server.gd`
- **Reuse for our game:** low relevance (the two websocket/*.gd wrapper classes are good drop-in utilities if online leaderboards/chat over WebSocket are ever wanted, but nothing arcade-specific).

### WebSocket Minimal

`godot-demo-projects/networking/websocket_minimal`

- **Shows:** Smallest possible WebSocketPeer client + TCPServer/accept_stream server pair in one scene, ping/pong buttons, BBCode-timestamped log labels.
- **Key files:** `client.gd`, `server.gd`
- **Reuse for our game:** low relevance

### WebSocket Multiplayer

`godot-demo-projects/networking/websocket_multiplayer`

- **Shows:** WebSocketMultiplayerPeer with the high-level Multiplayer API: create_server/create_client over ws://, @rpc turn-based game loop with server-side validation of requested actions (anti-cheat check on sender vs current turn), ItemList player roster with turn crown icon, per-branch MultiplayerAPI (set_multiplayer) to host server+two clients in one window.
- **Key files:** `script/main.gd`, `script/game.gd`, `script/combo.gd`
- **Reuse for our game:** Low-medium. The server-validates-client-requests RPC pattern in game.gd (request_action -> authority check -> broadcast result) is the right template if the arcade game ever gets online score submission or co-op; main.gd shows connect/disconnect UI state management with AcceptDialog error popups. Otherwise low relevance.

### Android IAP (Google Play Billing)

`godot-demo-projects/mobile/android_iap`

- **Shows:** Google Play Billing plugin usage: BillingClient signals (connected, query_product_details_response, on_purchase_updated), purchase/acknowledge/consume flow with await on response signals, JNISingleton, plus a small dynamic store UI (PanelContainer item cards instantiated from a PackedScene with configure() + custom signals).
- **Key files:** `store.gd`, `item.gd`, `item.tscn`
- **Reuse for our game:** Low unless shipping paid content on Android. The item.gd/item.tscn card pattern (PackedScene instanced per entry, configure() setter, buy_pressed signal bubbling) is a decent generic pattern for shop/level-select grids; the CC0 Kenney item icons are freely reusable placeholder art.
- **License notes:** Kenney 'Scribble Platformer' art under CC0 with credit-appreciated note (assets/kenney_scribble-platformer/License.txt); Android-only plugin dependency not vendored

### Multitouch Cubes

`godot-demo-projects/mobile/multitouch_cubes`

- **Shows:** Gesture recognition from raw InputEventScreenTouch/InputEventScreenDrag in a Control's _gui_input: finger-count state machine (1 finger = rotate, 2 fingers = pinch-zoom + twist), base-state snapshot to avoid drift accumulation, pixel-to-unit normalization, applied to a 3D cube transform.
- **Key files:** `gesture_area.gd`, `main.tscn`
- **Reuse for our game:** Medium if targeting touch: gesture_area.gd is a self-contained pinch/rotate/drag recognizer whose finger-state-machine and base_state snapshot technique port directly to 2D camera zoom or touch controls; otherwise low relevance for keyboard-only desktop arcade.

### Multitouch View

`godot-demo-projects/mobile/multitouch_view`

- **Shows:** Multitouch debug overlay: autoload TouchHelper tracking InputEventScreenTouch/Drag into a Dictionary[int, Vector2] via _unhandled_input + set_input_as_handled, and a Node2D drawing per-finger circles with _draw()/queue_redraw() and a bit-trick per-index color.
- **Key files:** `touch_helper.gd`, `main.gd`
- **Reuse for our game:** Low-medium: touch_helper.gd is a 25-line drop-in singleton if touch controls are added; main.gd is a minimal example of custom _draw() debug overlays (useful pattern for hitbox/debug rendering). Otherwise low relevance.

### Mobile Sensors

`godot-demo-projects/mobile/sensors`

- **Shows:** Input.get_accelerometer/get_gravity/get_gyroscope/get_magnetometer with hand-rolled orientation math: building a Basis from a direction vector, tilt-compensated compass north (cross products), gyro integration with gravity drift correction. 3D visualization, Mobile renderer.
- **Key files:** `main.gd`
- **Reuse for our game:** low relevance (only if tilt controls on mobile were desired; the README itself notes sensor reading applies to 2D too, but nothing else transfers).

## godot-open-rpg (GDQuest turn-based RPG demo, Godot 4.6)

> **Top picks:** 1) src/common — ScreenTransition (awaitable Tween fade CanvasLayer), MusicPlayer (crossfade autoload), and the Inventory Resource save/restore to user:// are three directly liftable pieces for an arcade game's transitions, audio, and high-score persistence; the signal-bus autoload pattern (FieldEvents/CombatEvents) is the project's best architectural takeaway for decoupling HUD/spawner/game-state. 2) src/combat/ui — UIDamageLabel floating text, life/energy bars, and the signal-driven menu->cursor UI flow are ready-made HUD/juice components. 3) src/combat actions — BattlerAction-as-Resource with coroutine execute() is a clean data-driven template for weapons/power-ups. 4) src/field/gamepieces/controllers/player_controller.gd — last-pressed-key directional input plus unified keyboard/gamepad/mouse handling solves a real arcade input problem. 5) src/field/gameboard — the AStar2D Vector2i wrapper with occupancy flags if the arcade game is grid-based. Caveats: whole project is MIT with CC0 assets, but the vendored Dialogic addon bundles Apache-2.0 fonts and CC BY-SA 4.0 sound effects in its Example Assets.

### OpenRPG turn-based combat system

`godot-open-rpg/src/combat`

- **Shows:** JRPG round-based combat run as a CanvasLayer game-state overlaid on the field: Combat autoload-driven setup/teardown via signal buses (CombatEvents/FieldEvents), CombatArena as PackedScene with per-arena AudioStream, Battler (Node2D) composing BattlerStats (Resource with setter-driven stat recalculation and health_changed/health_depleted signals), abstract BattlerAction Resources (attack/heal/modify-stats/projectile) executed as await-based coroutines using Tweens for movement animation, BattlerHit hit/miss resolution with hit_chance vs evasion, elemental affinities (elements.gd), random-choice enemy AI (combat_ai_random.gd), and a signal-driven combat UI (battler list -> action menu -> target cursor) with floating damage labels.
- **Key files:** `src/combat/combat.gd`, `src/combat/battlers/battler.gd`, `src/combat/actions/battler_action.gd`, `src/combat/ui/ui_combat.gd`
- **Reuse for our game:** Action-as-Resource pattern (exported icon/name/description/cost + execute() coroutine) is a clean data-driven template for arcade power-ups/weapons; UIDamageLabel (Marker2D + Tween rise-and-fade floating score/damage text) and ui_life_bar/ui_energy_bar are directly liftable HUD juice; Tween-based lunge/return attack animation in battler_action_projectile.gd is a good hit-feedback recipe; the CanvasLayer game-state swap (field hidden under combat, restored after) is a reusable pause/overlay-state pattern.
- **License notes:** clean (project MIT; battler sprites are CC0 Kenney Tiny Dungeon derivatives per CREDITS.md)

### OpenRPG gameboard grid + gamepiece movement

`godot-open-rpg/src/field/gameboard`

- **Shows:** Grid abstraction as an autoload (gameboard.gd): cell<->pixel<->unique-index conversion over a Rect2i extents, GameboardProperties Resource, Pathfinder extending AStar2D keyed by cell indices that auto-disables points as gamepieces move (via GamepieceRegistry.gamepiece_moved signal) with occupancy flags for source/target cells; GameboardLayer syncs TileMap layers into the pathfinder and emits pathfinder_changed only on real passability changes; debug overlay scripts draw boundaries and the pathfind graph.
- **Key files:** `src/field/gameboard/gameboard.gd`, `src/field/gameboard/pathfinder.gd`, `src/field/gameboard/gameboard_layer.gd`, `src/field/gamepieces/gamepiece.gd`
- **Reuse for our game:** AStar2D wrapper with Vector2i cells and occupancy-aware pathing transfers to any grid arcade game (Pac-Man-likes, tower defense enemy routing, puzzle games); cell_to_index/cell_to_pixel math and the autoload-singleton board pattern are drop-in; Gamepiece as Path2D with a PathFollow2D 'traveller' plus decoupled visual follower is a neat smooth-motion-on-a-grid technique.

### OpenRPG field controllers, cutscenes, interactions and triggers

`godot-open-rpg/src/field`

- **Shows:** Composition-based character control: GamepieceController subclassed into PlayerController (merges WASD/arrow keys, gamepad, and mouse click-to-move via FieldCursor; tracks most-recent-key for intuitive input; Area2D interaction searcher + trigger collision on layered 2D physics) and path_loop_ai_controller for NPC patrol; a Cutscene/Interaction/Trigger class hierarchy (@tool scripts with editor warnings) with reusable templates: area transitions, doors, pickups, treasure chests, combat triggers (incl. roaming encounters), and Dialogic-driven conversation templates; interaction popups (bouncing '!' markers); FieldCamera (Camera2D) with limits computed from board extents and viewport size_changed, following the player via RemoteTransform2D.
- **Key files:** `src/field/gamepieces/controllers/player_controller.gd`, `src/field/cutscenes/interaction.gd`, `src/field/cutscenes/templates/combat/combat_trigger.gd`, `src/field/field_camera.gd`
- **Reuse for our game:** PlayerController's last-pressed-key direction resolution is the correct fix for mushy 4-way keyboard input in arcade games; the project.godot input map (keyboard+gamepad button+analog axis per action) is a ready-made binding set; FieldCamera's viewport-resize-aware limit clamping is reusable for any bounded arena camera; the Trigger/Area2D + physics-layer-naming scheme is a tidy pattern for pickups and hazard zones.

### OpenRPG common services (transitions, music, inventory/save, signal buses)

`godot-open-rpg/src/common`

- **Shows:** Autoload architecture: FieldEvents/CombatEvents as pure signal-bus Nodes decoupling distant scenes; ScreenTransition autoload (CanvasLayer + ColorRect, Tween-driven cover()/clear() coroutines awaitable via a finished signal, reordered below all autoloads to draw on top); MusicPlayer autoload with AnimationPlayer-scaled fade-in/out crossfade between AudioStreams; Inventory as a custom Resource with static restore() loading from user://inventory.tres (create-if-missing) and item_changed signals feeding the inventory UI; Player autoload holding the controlled gamepiece; collision_finder.gd (direct_space_state point queries) and directions.gd (4-way direction enum/vector helpers).
- **Key files:** `src/common/screen_transitions/screen_transition.gd`, `src/common/music/music_player.gd`, `src/common/inventory.gd`, `src/combat/combat_events.gd`
- **Reuse for our game:** Highest-value directory: ScreenTransition is a drop-in fade for level/menu/game-over transitions; MusicPlayer gives instant music crossfade between menu/gameplay/boss tracks; the Inventory Resource-saved-to-user:// pattern is exactly the mechanism for persisting high scores/unlocks (Resource + static restore() + save()); the signal-bus autoload pattern cleanly wires HUD, spawner, and game-state without node coupling; CC0 Kenney interface/impact SFX and Zane Little music tracks in assets/ are usable as placeholder or shipping audio.
- **License notes:** clean (music/SFX referenced are CC0: Kenney audio packs, Zane Little Music — listed in CREDITS.md)

### Dialogic 2 addon (vendored, 2.0-Alpha-20)

`godot-open-rpg/addons/dialogic`

- **Shows:** Full third-party dialog framework: timeline (.dtl) and character (.dch) resources, editor plugin, layered dialog layouts, choices, variables, autoadvance/skip settings (see [dialogic] block in project.godot); OpenRPG integrates it via conversation_template.gd cutscenes and per-map timelines under overworld/maps (quest-state variables like TokenQuestStatus driving branching).
- **Key files:** `addons/dialogic/plugin.cfg`, `src/field/cutscenes/templates/conversations/conversation_template.gd`, `overworld/maps/town/fan_of_four.dtl`, `src/field/ui/dialogue_window.gd`
- **Reuse for our game:** low relevance (dialog trees are overkill for an arcade game), though the alpha-version pin (requires Godot 4.4+/project pins 4.6.2) is a caution against vendoring it casually.
- **License notes:** Dialogic itself MIT, but bundled 'Example Assets' carry non-MIT licenses: Fonts under Apache License 2.0 (addons/dialogic/Example Assets/Fonts/LICENSE.txt) and typing sound effects by Tim Krief under CC BY-SA 4.0 (addons/dialogic/Example Assets/sound-effects/LICENSE.txt) — CC BY-SA is share-alike, strip or replace if shipping

### OpenRPG overworld maps and scripted encounters

`godot-open-rpg/overworld`

- **Shows:** Content layer built on the src/ framework: town/forest/house maps assembled from Kenney Tiny Town/Dungeon tilesets, per-map interaction scripts (wand pedestal, door unlock, strange tree, gang-of-four multi-NPC conversation choreography), an opening cutscene script, roaming enemy encounters that trigger combat, and a game-end trigger; character gfx scenes (gobot, knight, monk, etc.) plugged into the Gamepiece animation_scene slot.
- **Key files:** `overworld/maps/opening_cutscene.gd`, `overworld/maps/town/gang_of_four_conversation.gd`, `overworld/maps/town/conversation_encounter.gd`, `overworld/maps/forest/game_end_trigger.gd`
- **Reuse for our game:** low relevance as content, but opening_cutscene.gd shows sequencing an intro with awaited coroutines + ScreenTransition (usable for arcade attract/intro sequences), and the Kenney CC0 tilesets/character sheets are free art for prototyping.
- **License notes:** art/audio CC0 (Kenney Tiny Town/Tiny Dungeon, Emotes Pack; Zane Little Music; food_please animated-character derivatives) per CREDITS.md — attribution not required but CREDITS.md worth keeping

## License audit (full tree)

All 8 vendored projects (Godot-Game-Template, Starter-Kit-3D-Platformer, Starter-Kit-City-Builder, Starter-Kit-FPS, beehave, godot-demo-projects, godot-open-rpg, phantom-camera) carry top-level MIT licenses, so the code is commercially safe. The single commercial blocker is Maaack's Game Template plugin logo, present in 3 copies under CC BY-NC-ND 4.0 (noncommercial, no derivatives) — it must be removed or replaced before any commercial release. Numerous assets require attribution if shipped: OFL 1.1 fonts (Lilita One x3 kits, Xolonium, Montserrat, Linux Libertine, Noto x2, Inter, plus phantom-camera's Nunito TTFs which are missing their OFL license file), Apache-2.0 fonts (Droid Sans, Roboto), CC-BY logos/textures/models/music across godot-demo-projects, and several CC BY-SA items (Minetest voxel textures, Red Eclipse audio, paintedarrow decal, Dialogic typing sounds) whose ShareAlike terms additionally bind modified versions. Everything else is CC0/public-domain (Kenney packs, Poly Haven, Freesound) or restated MIT; no GPL/LGPL code exists anywhere in the tree — the only GPL mentions are references to Git as a development tool in attribution docs.

> The single blocker below (Maaack plugin logo, CC BY-NC-ND) was **fixed in
> commit `4164455`**: the logo was replaced with an original CC0 placeholder
> in all three locations. Recorded in `THIRD_PARTY_LICENSES.md`.

### Blockers (all resolved) — 3

- `/home/user/GODOT-GAME/third_party/Godot-Game-Template/assets/plugin_logo/LICENSE.txt` — CC BY-NC-ND 4.0: Maaack's Game Template logo (logo.png) is NonCommercial + NoDerivatives. Cannot ship in a commercial game; remove or replace the plugin_logo assets.
- `/home/user/GODOT-GAME/third_party/Godot-Game-Template/addons/maaacks_game_template/assets/plugin_logo/LICENSE.txt` — CC BY-NC-ND 4.0: Duplicate copy of the NonCommercial/NoDerivatives plugin logo inside the addon. Same removal requirement.
- `/home/user/GODOT-GAME/third_party/Godot-Game-Template/addons/maaacks_game_template/examples/assets/plugin_logo/LICENSE.txt` — CC BY-NC-ND 4.0: Third copy of the NonCommercial/NoDerivatives plugin logo in the addon examples. Same removal requirement.

### Attribution required if shipped — 39

- `/home/user/GODOT-GAME/third_party/Godot-Game-Template/assets/godot_engine_logo/LICENSE.txt` — CC BY 4.0: Godot Engine logo by Andrea Calabro. Must credit if the logo ships in the game.
- `/home/user/GODOT-GAME/third_party/Godot-Game-Template/addons/maaacks_game_template/assets/godot_engine_logo/LICENSE.txt` — CC BY 4.0: Duplicate Godot Engine logo copy inside the addon; credit required if shipped.
- `/home/user/GODOT-GAME/third_party/Godot-Game-Template/addons/maaacks_game_template/examples/assets/godot_engine_logo/LICENSE.txt` — CC BY 4.0: Third Godot Engine logo copy in addon examples; credit required if shipped.
- `/home/user/GODOT-GAME/third_party/Godot-Game-Template/assets/git_logo/LICENSE.txt` — CC BY 3.0: Git logo by Jason Long. Must credit if shipped; also subject to Git trademark usage rules.
- `/home/user/GODOT-GAME/third_party/Godot-Game-Template/addons/maaacks_game_template/assets/git_logo/LICENSE.txt` — CC BY 3.0: Duplicate Git logo copy inside the addon; credit required if shipped.
- `/home/user/GODOT-GAME/third_party/Godot-Game-Template/addons/maaacks_game_template/examples/assets/git_logo/LICENSE.txt` — CC BY 3.0: Third Git logo copy in addon examples; credit required if shipped.
- `/home/user/GODOT-GAME/third_party/Starter-Kit-3D-Platformer/fonts/license.txt` — SIL OFL 1.1: Lilita One font (Juan Montoreano, Reserved Font Name Lilita). Keep OFL license text with the font; cannot sell the font standalone.
- `/home/user/GODOT-GAME/third_party/Starter-Kit-City-Builder/fonts/license.txt` — SIL OFL 1.1: Lilita One font, same OFL terms; keep license file with the font.
- `/home/user/GODOT-GAME/third_party/Starter-Kit-FPS/fonts/license.txt` — SIL OFL 1.1: Lilita One font, same OFL terms; keep license file with the font.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/2d/dodge_the_creeps/fonts/LICENSE.txt` — SIL OFL 1.1: Xolonium font by Severin Meyer (Reserved Font Name Xolonium). Keep OFL text and FONTLOG.txt with the font.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/mono/dodge_the_creeps/fonts/LICENSE.txt` — SIL OFL 1.1: Duplicate Xolonium font copy in the C# variant; same OFL terms.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/squash_the_creeps/fonts/LICENSE.txt` — SIL OFL 1.1: Montserrat Medium font (The Montserrat Project Authors). Keep OFL text with the font.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/mono/squash_the_creeps/fonts/LICENSE.txt` — SIL OFL 1.1: Duplicate Montserrat font copy in the C# variant; same OFL terms.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/2d/dodge_the_creeps/README.md` — CC BY 3.0: art/House In a Forest Loop.ogg by HorrorPen (opengameart.org) is CC-BY 3.0; must credit. Kenney sprites in same demo are CC0.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/mono/dodge_the_creeps/README.md` — CC BY 3.0: Same HorrorPen CC-BY 3.0 music in the C# variant; must credit.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/squash_the_creeps/README.md` — CC BY 3.0: art/House In a Forest Loop.ogg by HorrorPen is CC-BY 3.0; must credit.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/mono/squash_the_creeps/README.md` — CC BY 3.0: Same HorrorPen CC-BY 3.0 music in the C# variant; must credit.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/misc/2.5d/README.md` — CC BY: assets/mr_mrs_robot.ogg by Juan Linietsky is CC-BY (version unstated); must credit.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/mono/2.5d/README.md` — CC BY: Same Juan Linietsky CC-BY music in the C# variant; must credit.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/voxel/README.md` — CC BY-SA 3.0 / CC0 / CC BY (mixed): Minetest Game textures: most CC BY-SA 3.0 (attribution AND ShareAlike — modified versions must stay BY-SA), some CC0. TinyUnicode font by DuffsDevice is CC-BY. README lists per-file authorship; must credit and honor SA on derivatives.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/global_illumination/README.md` — CC BY 4.0: zdm2.glb derived from Cube 2: Sauerbraten map zdm2, CC BY 4.0; must credit.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/audio/audio_effects/README.md` — CC BY 3.0 (music) / CC0 (SFX, icon): Music 'Monkeys Spinning Monkeys' by Kevin MacLeod (incompetech.com) is CC BY 3.0 — credit required in exactly this form per MacLeod's terms. All Freesound SFX and the equalizer icon are CC0.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/loading/runtime_save_load/README.md` — CC BY-SA 4.0 (audio) / CC0 (glTF): examples/audio/ files are copyright Red Eclipse under CC BY-SA 4.0 — attribution plus ShareAlike on adaptations. Poly Haven glTF chair files are CC0.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/antialiasing/textures/paint.LICENSE.md` — CC BY 3.0: paint.png / paint_normal.png by johndn (opengameart.org splatter-pack); must credit.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/decals/textures/paint.LICENSE.md` — CC BY 3.0: Duplicate of the johndn splatter textures in the decals demo; must credit.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/decals/textures/paintedarrow.LICENSE.md` — CC BY-SA 3.0: paintedarrow.png / paintedarrow_normal.png by Alex Foster (Red Eclipse decals). Attribution plus ShareAlike — modified versions must remain BY-SA 3.0.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/ragdoll_physics/characters/mannequiny.LICENSE.md` — CC BY 4.0: mannequiny.glb by GDQuest and contributors; must credit.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/sprites/textures/small_8_direction_characters.LICENSE.md` — CC BY 4.0: Small 8-Direction Characters sprite sheet by AxulArt (itch.io); must credit.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/physics_tests/assets/robot_head/readme.txt` — CC BY (version unstated): Robot Head model by James Redmond (fracteed), CC-BY; must credit. No CC version specified in file.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/truck_town/town/lamp/license.txt` — CC BY 4.0: 'Lowpoly lamp' by RitiWox (Sketchfab). License file includes the exact credit line that must be copied wherever the work is shared.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/truck_town/town/tree/license.txt` — CC BY 4.0: 'tree low-poly' by Ricardo Sanchez (Sketchfab). License file includes the exact credit line that must be copied wherever the work is shared.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/gui/bidi_and_font_features/LICENSE.LinLibertine.txt` — SIL OFL 1.1: Linux Libertine / Biolinum fonts by Philipp H. Poll (Reserved Font Names). Keep OFL text with the fonts.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/gui/bidi_and_font_features/LICENSE.Noto.txt` — SIL OFL 1.1: Noto fonts (Google). Keep OFL text with the fonts.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/gui/ui_mirroring/LICENSE.Noto.txt` — SIL OFL 1.1: Noto fonts (Google) in ui_mirroring demo. Keep OFL text with the fonts.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/loading/runtime_save_load/examples/fonts/LICENSE.txt` — SIL OFL 1.1: Inter font (The Inter Project Authors, trademark of Rasmus Andersson). Keep OFL text with the font.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/gui/translation/fonts/LICENSE.DroidSans.txt` — Apache-2.0: Droid Sans font (Android Open Source Project). Apache 2.0 requires retaining the license/notice text when redistributing.
- `/home/user/GODOT-GAME/third_party/godot-open-rpg/addons/dialogic/Example Assets/sound-effects/LICENSE.txt` — CC BY-SA 4.0: Typing sound effects by Tim Krief. Attribution plus ShareAlike — adaptations must remain BY-SA 4.0.
- `/home/user/GODOT-GAME/third_party/godot-open-rpg/addons/dialogic/Example Assets/Fonts/LICENSE.txt` — Apache-2.0: Roboto Regular/Bold/Italic fonts (Google). Apache 2.0 requires retaining the license text when redistributing.
- `/home/user/GODOT-GAME/third_party/phantom-camera/addons/phantom_camera/fonts/Nunito-Regular.ttf` — SIL OFL 1.1 (upstream; no license file vendored): Nunito-Regular.ttf and Nunito-Black.ttf are bundled with NO license file in the repo. Nunito is OFL 1.1 upstream (Google Fonts); add the OFL license text alongside the fonts to comply.

### Informational (CC0 / public domain / MIT restated) — 29

- `/home/user/GODOT-GAME/third_party/Godot-Game-Template/LICENSE.txt` — MIT: Top-level project license present: MIT, Copyright (c) 2022-present Marek Belski. Addon copy at addons/maaacks_game_template/LICENSE.txt restates it.
- `/home/user/GODOT-GAME/third_party/Starter-Kit-3D-Platformer/LICENSE.md` — MIT: Top-level project license present: MIT, Copyright (c) 2023 Kenney.
- `/home/user/GODOT-GAME/third_party/Starter-Kit-City-Builder/LICENSE.md` — MIT: Top-level project license present: MIT, Copyright (c) 2025 Kenney.
- `/home/user/GODOT-GAME/third_party/Starter-Kit-FPS/LICENSE.md` — MIT: Top-level project license present: MIT, Copyright (c) 2025 Kenney.
- `/home/user/GODOT-GAME/third_party/beehave/LICENSE` — MIT: Top-level project license present: MIT, Copyright (c) 2023 bitbrain. Restated at addons/beehave/LICENSE.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/LICENSE.md` — MIT: Top-level project license present: MIT, Godot Engine contributors / Juan Linietsky, Ariel Manzur. Covers code only — many per-demo assets carry their own licenses (see other findings).
- `/home/user/GODOT-GAME/third_party/godot-open-rpg/LICENSE` — MIT: Top-level project license present: MIT, Copyright (c) 2018 GDquest.
- `/home/user/GODOT-GAME/third_party/phantom-camera/LICENSE` — MIT: Top-level project license present: MIT, Copyright (c) 2022 Marcus Skov. Restated at addons/phantom_camera/LICENSE.
- `/home/user/GODOT-GAME/third_party/beehave/addons/gdUnit4/LICENSE` — MIT: Vendored gdUnit4 test framework inside beehave, MIT, Copyright (c) 2023 Mike Schulze. Distinct third-party project but permissive; typically stripped from shipped builds anyway.
- `/home/user/GODOT-GAME/third_party/Godot-Game-Template/ATTRIBUTION.md` — mixed (index): Attribution index listing MIT template code, CC BY 4.0 Godot logo, CC BY 3.0 Git logo. GPL-2.0 mention refers only to Git as a development tool, NOT to vendored content — no GPL code in the tree. Duplicated at addons/maaacks_game_template/ATTRIBUTION.md and examples/ATTRIBUTION.md.
- `/home/user/GODOT-GAME/third_party/Godot-Game-Template/addons/maaacks_game_template/assets/input-icons/License.txt` — CC0 1.0: Kenney Input Prompts 1.1b, CC0; commercial use explicitly allowed, credit optional.
- `/home/user/GODOT-GAME/third_party/Godot-Game-Template/addons/maaacks_game_template/base/assets/remapping_input_icons/LICENSE.txt` — CC0 1.0: Remapping input icons by Marek Belski, CC0.
- `/home/user/GODOT-GAME/third_party/Starter-Kit-3D-Platformer/README.md` — CC0 1.0 (assets): README states all included 2D sprites, 3D models and sound effects are CC0.
- `/home/user/GODOT-GAME/third_party/Starter-Kit-City-Builder/README.md` — CC0 1.0 (assets): README states all included sprites, 3D models and sound effects are CC0.
- `/home/user/GODOT-GAME/third_party/Starter-Kit-FPS/README.md` — CC0 1.0 (assets): README states all included sprites, 3D models and sound effects are CC0.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/antialiasing/textures/checker.LICENSE.md` — CC0 1.0: checker.png by Kenney (prototype-textures), CC0. Identical CC0 checker.png declarations also at: 3d/csg/textures/, 3d/decals/textures/, 3d/labels_and_texts/textures/, 3d/lights_and_shadows/, 3d/particles/, 3d/ragdoll_physics/textures/, 3d/soft_body_physics/textures/, 3d/sprites/textures/ (each has its own checker.LICENSE.md).
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/decals/textures/scifi.LICENSE.md` — CC0 1.0: scifi_*.png decals by Yughues (opengameart.org), CC0.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/labels_and_texts/textures/textmesh_texture.LICENSE.md` — CC0 1.0: textmesh_texture.png by bruvzg, CC0.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/ragdoll_physics/sounds/impact_big.LICENSE.md` — CC0 1.0: impact_big.wav by FFeller (freesound.org), CC0. impact_small.wav (dorian.mastin) in same folder is also CC0 per impact_small.LICENSE.md.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/truck_town/car_select/icon_license.txt` — CC0 1.0: audio_on.png / audio_off.png from Kenney Game Icons, CC0.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/3d/antialiasing/README.md` — CC0 1.0 (polyhaven assets): polyhaven/ folder (dutch_ship_medium) downloaded from polyhaven.com, CC0.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/compute/texture/README.md` — CC0 1.0 (polyhaven assets): polyhaven/ folder (industrial_sunset_puresky) from polyhaven.com, CC0.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/audio/rhythm_game/README.md` — CC0 1.0: Metronome recording by Ludwig Peter Mueller, CC0.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/misc/hdr_output/output_max_linear_value/Super Mountain Dusk/public-license.txt` — CC0 1.0: 'Super Mountain Dusk' background pack, CC0; free for commercial use without attribution.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/mobile/android_iap/assets/kenney_scribble-platformer/License.txt` — CC0 1.0: Kenney Scribble Platformer pack, CC0.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/2d/skeleton/README.md` — MIT (assets): GBot character (Andreas Esau) and rigging/animation (RustyStriker) both stated MIT.
- `/home/user/GODOT-GAME/third_party/godot-demo-projects/2d/dodge_the_creeps/LICENSE` — MIT: Additional per-demo MIT license, Copyright (c) 2017 KidsCanCode (tutorial origin of the demo).
- `/home/user/GODOT-GAME/third_party/godot-open-rpg/CREDITS.md` — CC0 1.0 (all listed assets): All external assets (Zane Little Music tracks, Kenney packs, food_please characters) are CC0. Note the Dialogic addon inside this project has separate Apache-2.0 fonts and CC BY-SA 4.0 sounds (reported separately).
- `/home/user/GODOT-GAME/third_party/phantom-camera/addons/phantom_camera/examples/credits.txt` — CC0 1.0 (verified externally; not stated in file): Example level_spritesheet credited to Buch (opengameart.org 'A platformer in the forest') with no license stated in the file. Verified on OpenGameArt: CC0, attribution appreciated but not required. Example assets are typically stripped from shipped builds.
