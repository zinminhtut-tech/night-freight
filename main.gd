extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var bench: Node2D = $Bench
@onready var lever: Node2D = $Lever
@onready var lever_back: Node2D = $Lever2 # carriage 2+: the back door's own lever (director)
@onready var hud: CanvasLayer = $HUD
@onready var door_shape: CollisionShape2D = $Door/DoorShape
@onready var door_slab: Sprite2D = $Door/DoorSlab
@onready var chochin: CharacterBody2D = $Chochin

var bump_count := 0
var _bump_t := 9.0 # time since the last random pothole bump (>= 1 = inactive)
var _bump_timer := 3.0 # countdown to the next one
var _door_tween: Tween
var _back_tween: Tween

var chochin_scene: PackedScene = preload("res://chochin.tscn")
const ENEMY_HOME := Vector2(880, 430)
# --- Scrolling level (director's brief 2026-10-31): the carriage is now a
# continuous side-scrolling level, WORLD_W wide (about 3.4 screens). The
# original one-screen painting stays as the start section; reusable slices
# of the same paintings extend it. All layout lives in LAYOUTS below so
# the level can grow by editing data, not code.
const WORLD_W := 5760.0
const VIEW_W := 1680.0 # world units visible at zoom 0.686 (1152 / 0.686)
# Per-carriage layout data. sections: [src_x, src_w, flip] slices of the
# carriage painting (full height), placed back to back from paint_right.
# platforms: [center_x, center_y, wide] (wide = the 336px ledge, else 240).
# homes: chochin-obake posts; the LAST home is the Elder's post.
const LAYOUTS := {
    1: {
        "tex": "res://assets/bg/carriage_body.png", "scale": 0.7483,
        "paint_right": 1720.0, "bench": Vector2(150, 592),
        "sections": [[907, 448, false], [11, 448, true], [1355, 448, false], [459, 448, true], [1803, 448, false], [907, 448, true], [11, 448, false], [1355, 448, true], [459, 448, false], [1803, 448, true], [907, 448, false], [1700, 552, false]],
        "platforms": [[620, 472.5, true], [1080, 382.5, false], [1900, 472.5, false], [2450, 382.5, true], [3100, 472.5, false], [3650, 362.5, true], [4250, 472.5, false], [4800, 382.5, true], [5350, 472.5, false]],
        "homes": [Vector2(880, 430), Vector2(640, 300), Vector2(1180, 320), Vector2(1380, 450), Vector2(2100, 340), Vector2(2900, 300), Vector2(3700, 420), Vector2(4500, 330), Vector2(5400, 400)],
    },
    2: {
        "tex": "res://assets/bg/dining_body.png", "scale": 0.6863,
        "paint_right": 1680.0, "bench": Vector2(380, 592), "name": "Carriage 2 - Dining Car",
        "sections": [[790, 430, false], [60, 440, true], [1520, 440, false], [430, 430, true], [1150, 430, false], [790, 430, true], [1520, 440, true], [430, 430, false], [60, 440, false], [1150, 430, true], [790, 430, false], [1520, 440, false], [1980, 468, false], [0, 354, false]],
        "platforms": [[540, 490, true], [1230, 490, false], [1830, 490, false], [2430, 490, true], [3030, 490, false], [3630, 490, true], [4230, 490, false], [4830, 490, true], [5430, 490, false]],
        "homes": [Vector2(480, 330), Vector2(820, 290), Vector2(1100, 350), Vector2(1330, 400), Vector2(2000, 320), Vector2(2700, 290), Vector2(3400, 400), Vector2(4200, 310), Vector2(5350, 400)],
    },
    # Carriages 3-7 (director: "finish the rest of the game on the exact
    # same parameters", 2026-10-31): same scrolling template, own
    # generated paintings, scale/paint_right 0 = auto-cover in _build_world.
    3: {
        "tex": "res://assets/bg/festival_body.png", "scale": 0.0,
        "paint_right": 0.0, "bench": Vector2(380, 592), "name": "Carriage 3 - Lantern Festival",
        "tint": Color(1.0, 0.92, 0.8),
        "sections": [[582, 522, false], [1626, 522, true], [60, 522, false], [1104, 522, true], [582, 522, true], [1626, 522, false], [60, 522, true], [1104, 522, false]],
        "platforms": [[200, 490, false], [970, 490, true], [1650, 490, false], [2300, 490, true], [2900, 490, false], [3500, 490, true], [4100, 490, false], [4700, 490, true], [5300, 490, false]],
        "homes": [Vector2(480, 330), Vector2(820, 290), Vector2(1100, 350), Vector2(1330, 400), Vector2(2000, 320), Vector2(2700, 290), Vector2(3400, 400), Vector2(4200, 310), Vector2(5350, 400)],
    },
    4: {
        "tex": "res://assets/bg/cargo_body.png", "scale": 0.0,
        "paint_right": 0.0, "bench": Vector2(380, 592), "name": "Carriage 4 - Cargo Hold",
        "tint": Color(0.92, 0.88, 0.78),
        "sections": [[446, 446, false], [223, 669, false], [1338, 446, true], [0, 446, false], [892, 669, true], [892, 446, false], [1784, 448, true], [446, 446, true], [1338, 446, false]],
        "platforms": [[620, 472.5, true], [1080, 382.5, false], [1900, 472.5, false], [2450, 382.5, true], [3100, 472.5, false], [3650, 362.5, true], [4250, 472.5, false], [4800, 382.5, true], [5350, 472.5, false]],
        "homes": [Vector2(880, 430), Vector2(640, 300), Vector2(1180, 320), Vector2(1380, 450), Vector2(2100, 340), Vector2(2900, 300), Vector2(3700, 420), Vector2(4500, 330), Vector2(5400, 400)],
    },
    5: {
        "tex": "res://assets/bg/bathhouse_body.png", "scale": 0.0,
        "paint_right": 0.0, "bench": Vector2(380, 592), "name": "Carriage 5 - Bathhouse",
        "tint": Color(0.88, 0.95, 1.0),
        "sections": [[618, 588, false], [1794, 558, true], [30, 588, false], [1206, 588, true], [618, 588, true], [30, 588, false], [1206, 588, false], [0, 300, false]],
        "platforms": [[540, 490, true], [1230, 490, false], [1830, 490, false], [2430, 490, true], [3030, 490, false], [3630, 490, true], [4230, 490, false], [4830, 490, true], [5430, 490, false]],
        "homes": [Vector2(480, 330), Vector2(820, 290), Vector2(1100, 350), Vector2(1330, 400), Vector2(2000, 320), Vector2(2700, 290), Vector2(3400, 400), Vector2(4200, 310), Vector2(5350, 400)],
    },
    6: {
        "tex": "res://assets/bg/shrine_body.png", "scale": 0.0,
        "paint_right": 0.0, "bench": Vector2(380, 592), "name": "Carriage 6 - Shrine",
        "tint": Color(1.0, 0.9, 0.85),
        "elder_hp": 10, "elder_scale": 3.3, "elder_tint": Color(1.0, 0.72, 0.66), # the Nurikabe
        "sections": [[952, 456, false], [40, 456, true], [1864, 456, false], [496, 456, true], [1408, 456, false], [2320, 416, true], [40, 456, false], [952, 456, true]],
        "platforms": [[620, 472.5, true], [1080, 382.5, false], [1900, 472.5, false], [2450, 382.5, true], [3100, 472.5, false], [3650, 362.5, true], [4250, 472.5, false], [4800, 382.5, true], [5350, 472.5, false]],
        "homes": [Vector2(880, 430), Vector2(640, 300), Vector2(1180, 320), Vector2(1380, 450), Vector2(2100, 340), Vector2(2900, 300), Vector2(3700, 420), Vector2(4500, 330), Vector2(5400, 400)],
    },
    7: {
        "tex": "res://assets/bg/loco_body.png", "scale": 0.0,
        "paint_right": 0.0, "bench": Vector2(380, 592), "name": "Carriage 7 - Locomotive",
        "tint": Color(1.0, 0.8, 0.72),
        "elder_hp": 12, "elder_scale": 3.6, "elder_tint": Color(1.0, 0.6, 0.5), # the Oni Lord
        "sections": [[470, 470, false], [1410, 470, true], [0, 470, false], [940, 470, true], [1782, 470, false], [470, 470, true], [1410, 470, false], [0, 470, true], [940, 470, false]],
        "platforms": [[620, 472.5, true], [1080, 382.5, false], [1900, 472.5, false], [2450, 382.5, true], [3100, 472.5, false], [3650, 362.5, true], [4250, 472.5, false], [4800, 382.5, true], [5350, 472.5, false]],
        "homes": [Vector2(880, 430), Vector2(640, 300), Vector2(1180, 320), Vector2(1380, 450), Vector2(2100, 340), Vector2(2900, 300), Vector2(3700, 420), Vector2(4500, 330), Vector2(5400, 400)],
    },
}
var enemy_homes: Array[Vector2] = [] # filled from LAYOUTS in _ready
var _platforms: Array = [] # built platform node pairs {col, vis}
@onready var exit_glow: ColorRect = $ExitGlow
@onready var backdrop_root: CanvasLayer = $Backdrop
@onready var back_door: StaticBody2D = $BackDoor
@onready var back_slab: Sprite2D = $BackDoor/BackSlab
@onready var back_door_shape: CollisionShape2D = $BackDoor/BackDoorShape
@onready var back_exit_glow: ColorRect = $BackExitGlow

var interact_buffer_timer := 0.0
var playtime := 0.0

# --- Two-layer background + train life (director's overhaul 2026-10-31) ---
# Layer 1 (behind): a scrolling night backdrop seen THROUGH the windows.
# Layer 2: the carriage body itself, its window glass cut out.
# The camera carries a constant realistic train shake.
static var carriage_no := 1 # persists across the door-transfer scene reload
static var just_transferred := false
static var entry_side := "left" # where she appears after a transfer: forward trips land left, back trips land right
var transitioning := false
var _scroll := 0.0
var _shake_t := 0.0
var _fade: ColorRect
@onready var camera: Camera2D = $Camera2D
@onready var backdrop_a: Sprite2D = $Backdrop/BackdropA
@onready var backdrop_b: Sprite2D = $Backdrop/BackdropB
const BACKDROP_TILE_W := 4410.0 # 4704px mirrored-seamless texture at 0.9375 scale
const BACKDROP_SPEED := 75.0

var sfx_chime: AudioStreamPlayer
var sfx_door: AudioStreamPlayer
var sfx_bump: AudioStreamPlayer
var _back_active := false # the back door exists only in carriage 2 and beyond

func _ready() -> void:
    sfx_chime = AudioStreamPlayer.new()
    sfx_chime.stream = load("res://assets/sfx/bench_chime.wav")
    sfx_chime.bus = "SFX"
    add_child(sfx_chime)
    sfx_door = AudioStreamPlayer.new()
    sfx_door.stream = load("res://assets/sfx/door.wav")
    sfx_door.bus = "SFX"
    sfx_bump = AudioStreamPlayer.new()
    sfx_bump.stream = load("res://assets/sfx/bump.wav")
    sfx_bump.bus = "SFX"
    sfx_bump.volume_db = -9.0
    add_child(sfx_bump)
    add_child(sfx_door)
    # BGM: ghostly music-box loop (director's pick 2026-10-31), mixed
    # well UNDER the SFX so it never masks them (-13 dB, quiet source).
    var bgm := AudioStreamPlayer.new()
    bgm.name = "BGM"
    bgm.bus = "BGM"
    var bgm_stream := load("res://assets/music/bgm_carriage1.wav") as AudioStreamWAV
    if bgm_stream != null:
        bgm_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        bgm_stream.loop_begin = 0
        bgm_stream.loop_end = int(bgm_stream.get_length() * bgm_stream.mix_rate)
        bgm.stream = bgm_stream
    bgm.volume_db = -13.0
    add_child(bgm)
    bgm.play()
    # Environmental train ambience (director, 2026-10-31): rolling rumble
    # and rail clacks on the SFX bus, kept well under the action sounds.
    var amb := AudioStreamPlayer.new()
    amb.name = "Ambience"
    amb.bus = "SFX"
    var amb_stream := load("res://assets/sfx/train_ambience.wav") as AudioStreamWAV
    if amb_stream != null:
        amb_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        amb_stream.loop_begin = 0
        amb_stream.loop_end = int(amb_stream.get_length() * amb_stream.mix_rate)
        amb.stream = amb_stream
    amb.volume_db = -13.0 # raised from -20: at -20 the director could not hear it under the BGM (2026-10-31)
    add_child(amb)
    amb.play()
    _build_world()
    player.health_changed.connect(hud.set_health)
    hud.set_health(player.health)
    $ExitArea.body_entered.connect(_on_exit_area_body_entered)
    $BackExitArea.body_entered.connect(_on_back_exit_area_body_entered)
    lever.state_changed.connect(_on_lever_state_changed)
    lever_back.state_changed.connect(_on_back_lever_state_changed)
    apply_door()
    # Full-screen fade for the door transfer, owned by the HUD layer.
    _fade = ColorRect.new()
    _fade.color = Color(0, 0, 0, 0)
    _fade.set_anchors_preset(Control.PRESET_FULL_RECT)
    _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(_fade)
    if just_transferred:
        just_transferred = false
        var entry_x := 200.0 if entry_side == "left" else WORLD_W - 200.0
        if entry_side == "left" and carriage_no > 1:
            entry_x = 260.0 # carriage 2+: land clear of the back door's blocker
        player.global_position = Vector2(entry_x, 500)
        _fade.color = Color(0, 0, 0, 1)
        var fade_in := create_tween()
        fade_in.tween_property(_fade, "color", Color(0, 0, 0, 0), 0.5)
    _snap_camera()
    # Continue from the bench save if one exists. Deferred one frame so
    # get_tree().current_scene is settled when SaveSystem looks it up.
    if SaveSystem.has_save(0):
        SaveSystem.load_game.call_deferred(0)
        _snap_camera.call_deferred() # land the camera on the respawn point, no pan

func _process(delta: float) -> void:
    playtime += delta
    # Camera follows the player horizontally (smoothing + limits set in
    # _build_world); vertical framing is unchanged.
    camera.position.x = player.global_position.x
    # Scrolling backdrop: the world outside the windows streams past.
    # The backdrop lives in a CanvasLayer now (screen space), so it can
    # never shake with the train and never runs out along the level:
    # its offset is the train scroll plus a gentle travel parallax.
    _scroll = fmod(_scroll + BACKDROP_SPEED * delta, BACKDROP_TILE_W)
    var tile_screen := BACKDROP_TILE_W * 0.686 # tile width on screen at zoom 0.686
    var off := fmod(_scroll * 0.686 + camera.get_screen_center_position().x * 0.25 * 0.686, tile_screen)
    backdrop_a.position = Vector2(-off + tile_screen * 0.5, 324)
    backdrop_b.position = Vector2(-off + tile_screen * 1.5, 324)
    # Train shake: a low constant vibration + slow sway + a rail-joint
    # jolt every 1.25 seconds (matches the dududada ambience rhythm).
    _shake_t += delta
    var jolt_phase := fmod(_shake_t, 1.25)
    var jolt := 0.0
    if jolt_phase < 0.35:
        jolt = 3.0 * exp(-9.0 * jolt_phase) * sin(55.0 * jolt_phase)
    # Random pothole bumps (director, 2026-10-31): every 2.5-6 seconds
    # the carriage drops over a bad joint and shudders once.
    _bump_timer -= delta
    if _bump_timer <= 0.0:
        trigger_bump()
        _bump_timer = randf_range(2.5, 6.0)
    _bump_t += delta
    var bump := Vector2.ZERO
    if _bump_t < 0.6:
        var decay := exp(-7.0 * _bump_t)
        bump = Vector2(5.0 * decay * sin(51.0 * _bump_t), 12.0 * decay * sin(38.0 * _bump_t))
    camera.offset = Vector2(
        1.4 * sin(_shake_t * 1.9) + 0.7 * sin(_shake_t * 12.3),
        1.1 * sin(_shake_t * 2.6 + 1.0) + 0.6 * sin(_shake_t * 15.7) + jolt) + bump
    # The world outside does NOT shake with the train (director,
    # 2026-10-31): the backdrop is in a CanvasLayer, structurally
    # outside the camera's offset, so the mountains hold still while
    # the carriage rattles around them.

func trigger_bump() -> void:
    _bump_t = 0.0
    bump_count += 1
    if sfx_bump != null:
        sfx_bump.play() # the bump has a sound now (director, 2026-10-31)

# --- SaveSystem adapter (contract: player/respawn/room_id/playtime_seconds) ---
# Door state rides inside room_id so the verified module stays unmodified.
# Mechanism-state encoding lives in these two helpers only.
static func make_room_id(car_no: int, door_open: bool, back_open := false) -> String:
    var id := "carriage_%d" % car_no
    if back_open:
        id += "_back_open" # before the door suffix: room_door_open uses ends_with
    if door_open:
        id += "_door_open"
    return id

static func room_door_open(room_id: String) -> bool:
    return room_id.ends_with("door_open")

static func room_back_open(room_id: String) -> bool:
    return "_back_open" in room_id

var _restoring := false # true while a save is being applied (lever signal muted)

# The lever is a pure switch; main owns every effect of its state change.
func _on_lever_state_changed(open: bool) -> void:
    if _restoring:
        return
    apply_forward_door(true)
    sfx_door.play()
    hud.show_message("The carriage door grinds open" if open else "The carriage door slides shut")

func _on_back_lever_state_changed(open: bool) -> void:
    if _restoring:
        return
    apply_back_door(true)
    sfx_door.play()
    hud.show_message("The back door grinds open" if open else "The back door slides shut")

func get_save_state() -> Dictionary:
    var room := make_room_id(carriage_no, lever.is_open, lever_back.is_open if _back_active else false)
    return {
        "player": {"hp": player.health, "max_hp": player.MAX_HEALTH},
        "respawn": {"x": player.respawn_point.x, "y": player.respawn_point.y},
        "room_id": room,
        "playtime_seconds": playtime,
    }

func apply_save_state(state: Dictionary) -> void:
    var p: Dictionary = state["player"]
    player.health = int(p["hp"])
    var r: Dictionary = state["respawn"]
    player.respawn_point = Vector2(float(r["x"]), float(r["y"]))
    player.global_position = player.respawn_point
    _restoring = true
    lever.set_open(room_door_open(str(state["room_id"])))
    if _back_active:
        lever_back.set_open(room_back_open(str(state["room_id"])))
    _restoring = false
    apply_door()
    playtime = float(state["playtime_seconds"])
    hud.set_health(player.health)

# Director's rule (2026-10-31): resting at a bench resets every enemy in
# the carriage — a living enemy returns home at full health, a dead one
# is respawned fresh. Covers all four scattered chochin-obake.
func reset_all_enemies() -> void:
    var alive := {}
    for e in get_tree().get_nodes_in_group("enemy"):
        if is_instance_valid(e) and not e.is_queued_for_deletion():
            alive[e.home] = e
    for home_pos in enemy_homes:
        if alive.has(home_pos):
            alive[home_pos].reset_enemy()
        else:
            var e = chochin_scene.instantiate()
            e.position = home_pos
            add_child(e)
            _apply_tint(e)
            if home_pos == enemy_homes[enemy_homes.size() - 1]:
                _make_elder(e)
            if home_pos == enemy_homes[0]:
                chochin = e

# The Elder Chochin: the carriage's principal fight, posted at the
# LAST enemy home near the exit lever. Stats come from the layout:
# most carriages get 6 HP at 2.7x; the Shrine's Nurikabe and the
# Locomotive's Oni Lord are bigger and tougher (director, 2026-10-31).
func _make_elder(e: Node) -> void:
    var lay: Dictionary = LAYOUTS[carriage_no]
    e.max_health = int(lay.get("elder_hp", 6))
    e.health = e.max_health
    var spr := e.get_node("Sprite") as AnimatedSprite2D
    var es := float(lay.get("elder_scale", 2.7))
    spr.scale = Vector2(es, es)
    spr.modulate = lay.get("elder_tint", Color(1.0, 0.82, 0.85))

# Per-carriage enemy tint (carriages 3-7 shade their chochin to match
# the room); carriages 1-2 carry no tint and stay exactly as approved.
func _apply_tint(e: Node) -> void:
    var lay: Dictionary = LAYOUTS[carriage_no]
    if lay.has("tint"):
        (e.get_node("Sprite") as AnimatedSprite2D).modulate = lay["tint"]

func _move_platform(col: CollisionShape2D, vis: TextureRect, center: Vector2) -> void:
    col.position = center
    vis.position = center - vis.size * 0.5

func _snap_camera() -> void:
    camera.position = Vector2(player.global_position.x, 324)
    camera.reset_smoothing()

# Build the scrolling level from LAYOUTS data (director's brief
# 2026-10-31): stretch the room template to WORLD_W, lay the section
# slices after the start painting, build platforms and enemy posts,
# and set up the following camera. Runs for every carriage.
func _build_world() -> void:
    var lay: Dictionary = LAYOUTS[carriage_no]
    # --- room shell: floor, end wall, door assembly, floor visual ---
    var floor_shape := $World/Floor as CollisionShape2D
    var fs := floor_shape.shape.duplicate() as RectangleShape2D
    fs.size = Vector2(WORLD_W + 240.0, 56)
    floor_shape.shape = fs
    floor_shape.position = Vector2(WORLD_W * 0.5, 620)
    $World/RightWall.position = Vector2(WORLD_W + 20.0, 324)
    $World/AboveDoor.position = Vector2(WORLD_W - 100.0, 146)
    $Door.position = Vector2(WORLD_W - 100.0, 486)
    lever.position = Vector2(WORLD_W - 210.0, 592)
    exit_glow.offset_left = WORLD_W - 110.0
    exit_glow.offset_right = WORLD_W - 11.0
    ($ExitArea/CollisionShape2D as CollisionShape2D).position = Vector2(WORLD_W - 60.0, 465)
    var band := $FloorBand as TextureRect
    for i in range(1, 4): # three more floor tiles at the same stretch as the first
        var tile := band.duplicate() as TextureRect
        tile.offset_left = band.offset_left + 1760.0 * i
        tile.offset_right = band.offset_right + 1760.0 * i
        if i % 2 == 1:
            tile.flip_h = true # mirrored tiling: the wood grain meets itself at the joins
        add_child(tile)
        move_child(tile, band.get_index() + i) # keep the floor strip behind the actors
    # --- camera: follow the player, clamped to the world ---
    camera.limit_left = 8
    camera.limit_right = int(WORLD_W) - 8
    camera.limit_top = -160
    camera.limit_bottom = 808
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 7.0
    # --- carriage art: start painting + extension sections ---
    var tex := load(lay["tex"]) as Texture2D
    var sc := float(lay["scale"])
    if sc <= 0.0: # carriages 3-7: cover the view from the painting's own size
        sc = maxf(1680.0 / float(tex.get_width()), 945.0 / float(tex.get_height()))
    var bg := $Background as Sprite2D
    bg.texture = tex
    bg.scale = Vector2(sc, sc)
    bg.position = Vector2(840, 324)
    bg.modulate = Color.WHITE
    var sections := Node2D.new()
    sections.name = "Sections"
    add_child(sections)
    move_child(sections, bg.get_index() + 1)
    var dest_x := float(lay["paint_right"])
    if dest_x <= 0.0:
        dest_x = 840.0 + float(tex.get_width()) * sc * 0.5
    var top_y := 324.0 - float(tex.get_height()) * sc * 0.5
    for sdef in lay["sections"]:
        var spr := Sprite2D.new()
        spr.texture = tex
        spr.region_enabled = true
        spr.region_rect = Rect2(float(sdef[0]), 0, float(sdef[1]), float(tex.get_height()))
        spr.centered = false
        var w := float(sdef[1]) * sc
        if bool(sdef[2]):
            spr.scale = Vector2(-sc, sc)
            spr.position = Vector2(dest_x + w, top_y)
        else:
            spr.scale = Vector2(sc, sc)
            spr.position = Vector2(dest_x, top_y)
        sections.add_child(spr)
        dest_x += w
    # --- platforms from data (the scene's A/B are the first two) ---
    var world := $World
    var shape_a := ($World/PlatformA as CollisionShape2D).shape
    var shape_b := ($World/PlatformB as CollisionShape2D).shape
    var band_tex := load("res://assets/props/platform_band.png") as Texture2D
    var pdefs: Array = lay["platforms"]
    for i in pdefs.size():
        var col: CollisionShape2D
        var vis: TextureRect
        if i == 0:
            col = $World/PlatformA
            vis = $World/PlatformAVisual
        elif i == 1:
            col = $World/PlatformB
            vis = $World/PlatformBVisual
        else:
            col = CollisionShape2D.new()
            col.shape = shape_a if bool(pdefs[i][2]) else shape_b
            world.add_child(col)
            vis = TextureRect.new()
            vis.texture = band_tex
            vis.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            vis.size = Vector2(336, 29) if bool(pdefs[i][2]) else Vector2(240, 29)
            world.add_child(vis)
        _move_platform(col, vis, Vector2(float(pdefs[i][0]), float(pdefs[i][1])))
        _platforms.append({"col": col, "vis": vis})
    # --- bench + enemies from data ---
    bench.position = lay["bench"]
    enemy_homes.clear()
    for h in lay["homes"]:
        enemy_homes.append(h)
    var nodes: Array = [$Chochin, $Chochin2, $Chochin3, $Chochin4]
    while nodes.size() < enemy_homes.size():
        var e = chochin_scene.instantiate()
        e.name = "Chochin" + str(nodes.size() + 1)
        e.position = enemy_homes[nodes.size()]
        add_child(e)
        nodes.append(e)
    for i in nodes.size():
        nodes[i].global_position = enemy_homes[i]
        nodes[i].home = enemy_homes[i]
        _apply_tint(nodes[i])
    _make_elder(nodes[nodes.size() - 1])
    if carriage_no > 1:
        _back_active = true
        back_door.visible = true
        $BackExitArea.monitoring = true
        $World/BackAboveDoor.disabled = false
        lever_back.visible = true
        lever_back.get_node("InteractArea").monitoring = true
        hud.show_message(lay["name"])

# The exit door, in PROFILE (director's corrections 2026-10-31): the
# door lives in the carriage END wall, its face pointing LEFT toward
# the character, so from our side view we see its edge. The slab slides
# SIDEWAYS inside the doorway, parking at the right side when open,
# and the pier covers her as she steps through. State changes from
# the lever animate; state restored from a save snaps.
const SLAB_CLOSED_X := 40.0 # full door leaf centred over the doorway (outsourced painting, 2026-10-31)
const SLAB_OPEN_X := 142.0 # slid sideways, parked behind the (smaller) pier at the right
const MAX_CARRIAGE := 7 # the Locomotive: the train is complete (director, 2026-10-31)
const BACK_SLAB_CLOSED_X := -40.0 # back door (carriage 2+, director 2026-10-31): mirrored values
const BACK_SLAB_OPEN_X := -142.0

func apply_door(animate := false) -> void:
    apply_forward_door(animate)
    apply_back_door(animate)

func apply_forward_door(animate := false) -> void:
    door_shape.set_deferred("disabled", lever.is_open)
    exit_glow.visible = lever.is_open
    var target := SLAB_OPEN_X if lever.is_open else SLAB_CLOSED_X
    if animate:
        if _door_tween != null and _door_tween.is_valid():
            _door_tween.kill()
        _door_tween = create_tween()
        _door_tween.tween_property(door_slab, "position:x", target, 0.9)
    else:
        door_slab.position.x = target

func apply_back_door(animate := false) -> void:
    back_door_shape.set_deferred("disabled", lever_back.is_open or not _back_active)
    back_exit_glow.visible = lever_back.is_open and _back_active
    var back_target := BACK_SLAB_OPEN_X if lever_back.is_open else BACK_SLAB_CLOSED_X
    if animate:
        if _back_tween != null and _back_tween.is_valid():
            _back_tween.kill()
        _back_tween = create_tween()
        _back_tween.tween_property(back_slab, "position:x", back_target, 0.9)
    else:
        back_slab.position.x = back_target

func _on_exit_area_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") and lever.is_open and not transitioning:
        if carriage_no >= MAX_CARRIAGE:
            _do_ending() # the Locomotive's door opens onto dawn
            return
        _do_transfer(carriage_no + 1, false)

# The ending (director's story, brief v2): the Oni lord's great lantern
# holds the stolen dawn; stepping through the Locomotive's door frees
# it. Fade out on her message, then back to the menu, run reset.
func _do_ending() -> void:
    transitioning = true
    player.set_physics_process(false)
    player.velocity = Vector2.ZERO
    hud.show_message("The stolen dawn is free. The Night Freight runs into morning.")
    if sfx_door != null:
        sfx_door.play()
    var fade := create_tween()
    fade.tween_property(_fade, "color", Color(0, 0, 0, 1), 1.4)
    await get_tree().create_timer(2.8).timeout
    reset_carriage()
    get_tree().change_scene_to_file("res://menu.tscn")

func _on_back_exit_area_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") and lever_back.is_open and not transitioning and _back_active:
        _do_transfer(carriage_no - 1, true)

# The director's door vision (2026-10-31): with the door open, she steps
# in, the leaf slides shut COVERING her, and the transfer to the next
# carriage is instant behind a fade. Carriage 2 is a stub for now.
func _do_transfer(to_no: int, back: bool) -> void:
    transitioning = true
    player.set_physics_process(false)
    player.velocity = Vector2.ZERO
    player.invuln_timer = 99.0
    var door_x := 60.0 if back else WORLD_W - 60.0
    var walk := create_tween()
    walk.tween_property(player, "global_position", Vector2(door_x, 574), 0.3)
    var fade_her := create_tween()
    fade_her.tween_property(player, "modulate:a", 0.0, 0.28) # she steps into the dark passage; fast fade: the pier stops above her feet and the slab is narrow, so a slow fade left her lower body visible in the doorway (director's catch, 2026-10-31)
    await get_tree().create_timer(0.35).timeout
    var close := create_tween()
    if back:
        close.tween_property(back_slab, "position:x", BACK_SLAB_CLOSED_X, 0.45)
    else:
        close.tween_property(door_slab, "position:x", SLAB_CLOSED_X, 0.45)
    if sfx_door != null:
        sfx_door.play()
    await get_tree().create_timer(0.55).timeout
    var fade := create_tween()
    fade.tween_property(_fade, "color", Color(0, 0, 0, 1), 0.3)
    await get_tree().create_timer(0.35).timeout
    carriage_no = to_no
    entry_side = "right" if back else "left"
    just_transferred = true
    SaveSystem.delete_save(0) # the next carriage starts fresh; its own bench makes its own save
    get_tree().reload_current_scene()

# Capture the E press on the render frame (E1 lesson: polling only in
# _physics_process loses quick taps on high-refresh displays).
# F11 toggles fullscreen/windowed.
static func reset_carriage() -> void:
    carriage_no = 1
    just_transferred = false
    entry_side = "left"

# ESC returns to the main menu (director, 2026-10-31).
func return_to_menu() -> void:
    if transitioning:
        return
    get_tree().change_scene_to_file("res://menu.tscn")

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        return_to_menu()
        return
    # Cheat code (director, 2026-10-31): J teleports her to the OTHER
    # side's door, start end <-> exit end, camera snapped along.
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J:
        if not transitioning:
            if player.global_position.x < WORLD_W * 0.5:
                player.global_position = Vector2(WORLD_W - 260.0, 574)
            else:
                player.global_position = Vector2(260.0 if carriage_no > 1 else 200.0, 574)
            player.velocity = Vector2.ZERO
            _snap_camera()
        return
    if event.is_action_pressed("interact"):
        interact_buffer_timer = 0.15
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
        if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
        else:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _physics_process(delta: float) -> void:
    if Input.is_action_just_pressed("interact"):
        interact_buffer_timer = 0.15
    else:
        interact_buffer_timer = maxf(interact_buffer_timer - delta, 0.0)
    if interact_buffer_timer > 0.0:
        if bench.player_in_range:
            interact_buffer_timer = 0.0
            bench.rest(player)
            reset_all_enemies()
            sfx_chime.play()
            if SaveSystem.save_game(0):
                hud.show_message("Rested - game saved")
            else:
                hud.show_message("Rested - respawn point set")
        elif lever.player_in_range:
            interact_buffer_timer = 0.0
            lever.pull() # effects ride the state_changed signal
        elif lever_back.player_in_range and _back_active:
            interact_buffer_timer = 0.0
            lever_back.pull() # the back door's own lever (director; E-key path fixed 2026-10-31)
