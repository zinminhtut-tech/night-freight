extends Node2D

# The carriage lever: ONE consistent two-state interaction (brief rule).
# State 0 (closed) <-> State 1 (open). In carriage 1 it works the exit door.
# Art: PixelLab "NF Lever Prop" (director's pick 2026-10-31, replacing the
# ChatGPT design) — 9 frames of a floor lever machine, handle swinging
# from up (closed) to down (open). Pulls animate; save-restores snap.

# Emitted on every state change; main owns the effects (door, sound,
# message) so the mechanism stays a pure two-state switch.
signal state_changed(open: bool)

var is_open := false
var player_in_range := false
var prompt: Label
var art: TextureRect
var atlas: AtlasTexture

const FRAME_W := 57
const FRAME_H := 57
const LAST_FRAME := 8
var _frame_f := 0.0
var _tween: Tween

func _ready() -> void:
    $InteractArea.body_entered.connect(_on_body_entered)
    $InteractArea.body_exited.connect(_on_body_exited)
    art = $LeverArt
    atlas = art.texture as AtlasTexture
    if atlas != null:
        # Each lever owns its atlas copy: the scene shares ONE AtlasTexture
        # resource, so without this both levers' handles moved in sync
        # (director's catch, 2026-10-31).
        atlas = atlas.duplicate() as AtlasTexture
        art.texture = atlas
    prompt = Label.new()
    prompt.text = "E: Pull lever"
    prompt.position = Vector2(-52, -168) # the lever art is smaller now (director, 2026-10-31)
    prompt.add_theme_font_size_override("font_size", 20)
    prompt.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
    prompt.visible = false
    add_child(prompt)
    _set_frame(float(LAST_FRAME) if is_open else 0.0)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        player_in_range = true
        prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
    if body.is_in_group("player"):
        player_in_range = false
        prompt.visible = false

func pull() -> void:
    is_open = not is_open
    _animate_to(float(LAST_FRAME) if is_open else 0.0)
    state_changed.emit(is_open)

func set_open(value: bool) -> void:
    is_open = value
    if _tween != null and _tween.is_valid():
        _tween.kill()
    _set_frame(float(LAST_FRAME) if is_open else 0.0)
    state_changed.emit(is_open)

func _animate_to(target: float) -> void:
    if atlas == null:
        _set_frame(target)
        return
    if _tween != null and _tween.is_valid():
        _tween.kill()
    _tween = create_tween()
    _tween.tween_method(_set_frame, _frame_f, target, 0.55)

func _set_frame(f: float) -> void:
    _frame_f = f
    if atlas != null:
        var idx := clampi(int(round(f)), 0, LAST_FRAME)
        atlas.region = Rect2(idx * FRAME_W, 0, FRAME_W, FRAME_H)
