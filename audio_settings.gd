extends Node
# AudioSettings (autoload): owns the BGM / SFX / Voice buses and the
# player's volume preferences, saved to user://audio_settings.json.
# The settings menu writes through here; gameplay code only routes its
# players onto the buses by name.

const SAVE_PATH := "user://audio_settings.json"
const BUS_NAMES: Array[String] = ["BGM", "SFX", "Voice"]

var bgm_volume := 0.8
var sfx_volume := 0.9
var voice_volume := 0.9
var master_muted := false

func _ready() -> void:
    for bus_name in BUS_NAMES:
        if AudioServer.get_bus_index(bus_name) == -1:
            AudioServer.add_bus()
            var idx := AudioServer.bus_count - 1
            AudioServer.set_bus_name(idx, bus_name)
            AudioServer.set_bus_send(idx, "Master")
    _load_settings()
    apply_all()

func _db(v: float) -> float:
    return linear_to_db(clampf(v, 0.0001, 1.0))

func apply_all() -> void:
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("BGM"), _db(bgm_volume))
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), _db(sfx_volume))
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), _db(voice_volume))
    AudioServer.set_bus_mute(0, master_muted)

func set_bgm_volume(v: float) -> void:
    bgm_volume = clampf(v, 0.0, 1.0)
    apply_all()
    _save_settings()

func set_sfx_volume(v: float) -> void:
    sfx_volume = clampf(v, 0.0, 1.0)
    apply_all()
    _save_settings()

func set_voice_volume(v: float) -> void:
    voice_volume = clampf(v, 0.0, 1.0)
    apply_all()
    _save_settings()

func set_master_muted(m: bool) -> void:
    master_muted = m
    apply_all()
    _save_settings()

func _save_settings() -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify({
            "bgm": bgm_volume, "sfx": sfx_volume,
            "voice": voice_volume, "muted": master_muted}))

func _load_settings() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return
    var data = JSON.parse_string(f.get_as_text())
    if data is Dictionary:
        bgm_volume = clampf(float(data.get("bgm", bgm_volume)), 0.0, 1.0)
        sfx_volume = clampf(float(data.get("sfx", sfx_volume)), 0.0, 1.0)
        voice_volume = clampf(float(data.get("voice", voice_volume)), 0.0, 1.0)
        master_muted = bool(data.get("muted", false))
