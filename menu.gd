extends Control
# Main menu (director, 2026-10-31; layout rebuilt the same day after his
# widescreen screenshot): everything is anchored to the centre so the
# composition holds at any aspect ratio. Pure English. Carved wooden
# plank buttons, a sun-disc seal, the scrolling night backdrop.
# Play starts the game; Settings holds MUSIC / SOUND EFFECTS /
# CHARACTER VOICE sliders plus a master mute (AudioSettings autoload).
# ESC closes Settings; in the game, ESC returns here.

const TILE_W := 3024.0 # backdrop texture 4704px (mirrored seamless) at 0.6429 scale
var _scroll := 0.0

@onready var backdrop_a: TextureRect = $BackdropA
@onready var backdrop_b: TextureRect = $BackdropB
@onready var play_btn: TextureButton = $Content/PlayBtn
@onready var settings_btn: TextureButton = $Content/SettingsBtn
@onready var panel: Control = $SettingsPanel
@onready var bgm_slider: HSlider = $SettingsPanel/BgmSlider
@onready var sfx_slider: HSlider = $SettingsPanel/SfxSlider
@onready var voice_slider: HSlider = $SettingsPanel/VoiceSlider
@onready var bgm_value: Label = $SettingsPanel/BgmValue
@onready var sfx_value: Label = $SettingsPanel/SfxValue
@onready var voice_value: Label = $SettingsPanel/VoiceValue
@onready var mute_btn: CheckButton = $SettingsPanel/MuteBtn

func _ready() -> void:
    var stream := load("res://assets/music/bgm_carriage1.wav") as AudioStreamWAV
    if stream != null:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_begin = 0
        stream.loop_end = int(stream.get_length() * stream.mix_rate)
        $MenuBGM.stream = stream
        $MenuBGM.play()
    # The train is audible at the menu too (director: "the train SFX is
    # not in there", 2026-10-31): same ambience loop as the game.
    var amb_stream := load("res://assets/sfx/train_ambience.wav") as AudioStreamWAV
    if amb_stream != null:
        amb_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        amb_stream.loop_begin = 0
        amb_stream.loop_end = int(amb_stream.get_length() * amb_stream.mix_rate)
        var amb := AudioStreamPlayer.new()
        amb.name = "MenuAmbience"
        amb.bus = "SFX"
        amb.stream = amb_stream
        amb.volume_db = -13.0
        add_child(amb)
        amb.play()
    bgm_slider.set_value_no_signal(AudioSettings.bgm_volume * 100.0)
    sfx_slider.set_value_no_signal(AudioSettings.sfx_volume * 100.0)
    voice_slider.set_value_no_signal(AudioSettings.voice_volume * 100.0)
    mute_btn.set_pressed_no_signal(AudioSettings.master_muted)
    _refresh_labels()
    play_btn.pressed.connect(_on_play)
    settings_btn.pressed.connect(_on_settings)
    $SettingsPanel/BackBtn.pressed.connect(_on_back)
    bgm_slider.value_changed.connect(_on_bgm_changed)
    sfx_slider.value_changed.connect(_on_sfx_changed)
    voice_slider.value_changed.connect(_on_voice_changed)
    mute_btn.toggled.connect(_on_mute_toggled)

func _process(delta: float) -> void:
    _scroll = fmod(_scroll + 20.0 * delta, TILE_W)
    backdrop_a.position.x = -_scroll
    backdrop_b.position.x = TILE_W - _scroll

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE and panel.visible:
            _on_back()
        elif event.keycode == KEY_F11:
            var mode := DisplayServer.window_get_mode()
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if mode != DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED)

func _refresh_labels() -> void:
    bgm_value.text = "%d%%" % int(round(AudioSettings.bgm_volume * 100.0))
    sfx_value.text = "%d%%" % int(round(AudioSettings.sfx_volume * 100.0))
    voice_value.text = "%d%%" % int(round(AudioSettings.voice_volume * 100.0))

func _on_play() -> void:
    load("res://main.gd").reset_carriage()
    get_tree().change_scene_to_file("res://main.tscn")

func _on_settings() -> void:
    $Content.visible = false
    panel.visible = true

func _on_back() -> void:
    panel.visible = false
    $Content.visible = true

func _on_bgm_changed(v: float) -> void:
    AudioSettings.set_bgm_volume(v / 100.0)
    _refresh_labels()

func _on_sfx_changed(v: float) -> void:
    AudioSettings.set_sfx_volume(v / 100.0)
    _refresh_labels()

func _on_voice_changed(v: float) -> void:
    AudioSettings.set_voice_volume(v / 100.0)
    _refresh_labels()

func _on_mute_toggled(on: bool) -> void:
    AudioSettings.set_master_muted(on)
