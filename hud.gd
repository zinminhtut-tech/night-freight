extends CanvasLayer

# Sacred Lantern HP bar (design: ChatGPT UI/UX chat, approved by Htut
# 2026-10-31). One continuous bar in a lacquered frame with a lantern
# ornament; the fill lives in the frame's window (measured from the art:
# x 213..905 of 1024, y 84..171 of 256). Damage flashes the fill, healing
# shimmers it gold, critical HP flickers the frame, death dims the bar.

const MAX_HEALTH := 10 # doubled at the director's order (final tweak, 2026-10-31)
const BAR_POS := Vector2(16, 12)
const BAR_SIZE := Vector2(300, 75) # 25% smaller than the first integration (director's tweak 2026-10-31)
const WIN_REL := Rect2(0.208, 0.328, 0.676, 0.340)
const FILL_TEX_W := 692.0
const FILL_H_FRAC := 0.55 # director: the red fill read "so fat" — draw it as a thinner line, centered in the window
var _fill_size := Vector2.ZERO

var shown_health := MAX_HEALTH
var _frame: TextureRect
var _fill: TextureRect
var _fill_atlas: AtlasTexture
var _flash_timer := 0.0
var _flash_color := Color.WHITE
var _flicker_t := 0.0

var _msg: Label
var _msg_timer := 0.0

func _make_rect(tex: Texture2D, pos: Vector2, size: Vector2) -> TextureRect:
    var r := TextureRect.new()
    # expand_mode FIRST: with the default EXPAND_KEEP_SIZE, assigning a
    # smaller size than the texture snaps back to the native texture size
    # (this made the frame render at 1024x256 instead of 400x100).
    r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    r.stretch_mode = TextureRect.STRETCH_SCALE
    r.texture = tex
    r.position = pos
    r.size = size
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(r)
    return r

func _ready() -> void:
    var win_pos := BAR_POS + WIN_REL.position * BAR_SIZE
    var win_size := WIN_REL.size * BAR_SIZE
    # Layer order matters: the frame art's window is OPAQUE dark paint
    # (verified: alpha 255 at its center), not a hole — so the frame goes
    # down FIRST and the empty/fill sit on top, inside the window rect.
    _frame = _make_rect(load("res://assets/ui/hp_frame.png"), BAR_POS, BAR_SIZE)
    _make_rect(load("res://assets/ui/hp_empty.png"), win_pos, win_size)
    _fill_atlas = AtlasTexture.new()
    _fill_atlas.atlas = load("res://assets/ui/hp_fill.png")
    _fill_size = Vector2(win_size.x, win_size.y * FILL_H_FRAC)
    var fill_pos := win_pos + Vector2(0, (win_size.y - _fill_size.y) * 0.5)
    _fill = _make_rect(_fill_atlas, fill_pos, _fill_size)
    set_health(shown_health)
    _msg = Label.new()
    _msg.position = Vector2(376, 84)
    _msg.size = Vector2(400, 40)
    _msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _msg.add_theme_font_size_override("font_size", 26)
    _msg.add_theme_color_override("font_color", Color(0.95, 0.93, 0.8))
    _msg.visible = false
    add_child(_msg)

func show_message(text: String) -> void:
    _msg.text = text
    _msg.visible = true
    _msg_timer = 1.4

func fill_fraction() -> float:
    return float(shown_health) / float(MAX_HEALTH)

func set_health(value: int) -> void:
    var old := shown_health
    shown_health = value
    if _fill == null:
        return
    var frac := fill_fraction()
    _fill.size = Vector2(_fill_size.x * frac, _fill_size.y)
    _fill_atlas.region = Rect2(0, 0, FILL_TEX_W * frac, 87)
    if value < old:
        _flash_color = Color(2.4, 0.8, 0.7)
        _flash_timer = 0.18
    elif value > old:
        _flash_color = Color(1.9, 1.7, 0.9)
        _flash_timer = 0.32

func _process(delta: float) -> void:
    if _msg_timer > 0.0:
        _msg_timer -= delta
        if _msg_timer <= 0.0:
            _msg.visible = false
    if _fill == null:
        return
    if _flash_timer > 0.0:
        _flash_timer -= delta
        var k: float = clampf(_flash_timer / 0.32, 0.0, 1.0)
        _fill.modulate = Color.WHITE.lerp(_flash_color, k)
        if _flash_timer <= 0.0:
            _fill.modulate = Color.WHITE
    # Critical HP: the lantern light flickers. Death: the bar goes dim.
    if shown_health == 1:
        _flicker_t += delta * 11.0
        var a := 0.86 + 0.14 * sin(_flicker_t)
        _frame.modulate = Color(1, 1, 1, a)
    elif shown_health <= 0:
        _frame.modulate = Color(1, 1, 1, 0.35)
        _fill.modulate.a = 0.35
    else:
        _frame.modulate = Color.WHITE
        if _flash_timer <= 0.0:
            _fill.modulate.a = 1.0
