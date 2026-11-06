extends CharacterBody2D

signal health_changed(new_health: int)
signal died

const SPEED := 260.0
const ACCEL := 2000.0
const FRICTION := 2400.0
const JUMP_VELOCITY := -526.0 # ~145px rise. Director's tuning 2026-10-31: both jump steps 20% higher (velocity x sqrt(1.2)).
const DOUBLE_JUMP_VELOCITY := -504.0 # ~130px rise for the mid-air second jump, also +20%
const DASH_SPEED := 640.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.5
const SLASH_TIME := 0.14
const SLASH_COOLDOWN := 0.35
const MAX_HEALTH := 10 # doubled at the director's order (final tweak, 2026-10-31)
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.1

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var health := MAX_HEALTH
var facing := 1.0
var respawn_point := Vector2.ZERO

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var can_double_jump := true
var slash_buffer_timer := 0.0
var dash_buffer_timer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var slash_timer := 0.0
var slash_cooldown_timer := 0.0
var invuln_timer := 0.0
var hurt_timer := 0.0
var attack_anim_timer := 0.0
var dead_timer := 0.0
var current_anim := ""

@onready var slash_hitbox: Area2D = $SlashHitbox
@onready var sprite: AnimatedSprite2D = $Sprite

const ANIM_DEFS := {
    "idle": {"fps": 8.0, "loop": true},
    "run": {"fps": 12.0, "loop": true},
    "jump": {"fps": 10.0, "loop": true},
    "attack": {"fps": 20.0, "loop": false},
    "hurt": {"fps": 12.0, "loop": false},
    "death": {"fps": 9.0, "loop": false},
    "dash": {"fps": 16.0, "loop": true},
}

var sfx_slash: AudioStreamPlayer
var sfx_hurt: AudioStreamPlayer
var sfx_shout: AudioStreamPlayer

# Voice acting (director's rule 2026-10-31): on each swing she shouts
# "Haaaa!" with a 40% chance — random, not every time.
const SHOUT_CHANCE := 0.4

func _roll_shout() -> bool:
    return randf() < SHOUT_CHANCE

func _make_sfx(path: String, bus := "SFX") -> AudioStreamPlayer:
    var p := AudioStreamPlayer.new()
    p.stream = load(path)
    p.bus = bus
    add_child(p)
    return p

func _ready() -> void:
    respawn_point = global_position
    add_to_group("player")
    _build_sprite_frames()
    sfx_slash = _make_sfx("res://assets/sfx/slash.wav")
    sfx_hurt = _make_sfx("res://assets/sfx/player_hurt.wav")
    sfx_shout = _make_sfx("res://assets/sfx/shout.wav", "Voice")

func _build_sprite_frames() -> void:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    for anim_name in ANIM_DEFS.keys():
        frames.add_animation(anim_name)
        var def: Dictionary = ANIM_DEFS[anim_name]
        frames.set_animation_speed(anim_name, def["fps"])
        frames.set_animation_loop(anim_name, def["loop"])
        # Load frames by index (00.png, 01.png, ...). Directory listing is
        # NOT used: inside an exported .pck the raw .png names do not exist
        # (only .png.import entries), so DirAccess-based loading silently
        # yields zero frames and invisible sprites (playtest bug 2026-10-31).
        var dir_path: String = "res://assets/player/" + str(anim_name)
        var count := 0
        for i in range(40):
            var path := dir_path + "/" + "%02d.png" % i
            if not ResourceLoader.exists(path):
                break
            var tex := load(path) as Texture2D
            if tex == null:
                break
            frames.add_frame(anim_name, tex)
            count += 1
        if count == 0:
            push_error("No frames loaded for animation: " + dir_path)
        print("player anim ", anim_name, " frames=", count)
    sprite.sprite_frames = frames
    sprite.play("idle")
    current_anim = "idle"

func _play(anim_name: String) -> void:
    if current_anim != anim_name:
        current_anim = anim_name
        sprite.play(anim_name)

func _update_animation() -> void:
    sprite.flip_h = facing < 0.0
    if dead_timer > 0.0:
        _play("death")
    elif slash_timer > 0.0 or attack_anim_timer > 0.0:
        _play("attack")
    elif hurt_timer > 0.0:
        _play("hurt")
    elif dash_timer > 0.0:
        _play("dash")
    elif not is_on_floor():
        _play("jump")
    elif absf(velocity.x) > 20.0:
        _play("run")
    else:
        _play("idle")

# Real key presses are captured here, on the render frame where they happen,
# and buffered (E1 lesson: polling only in _physics_process loses quick taps).
# Attack is the LEFT MOUSE BUTTON (director's ruling 2026-10-31); it is bound
# to the slash action AND handled directly here so a click can never be lost.
func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        slash_buffer_timer = 0.15
    if event.is_action_pressed("slash"):
        slash_buffer_timer = 0.15
    if event.is_action_pressed("dash"):
        dash_buffer_timer = 0.15
    if event.is_action_pressed("jump"):
        jump_buffer_timer = JUMP_BUFFER_TIME

func _physics_process(delta: float) -> void:
    if dead_timer > 0.0:
        dead_timer -= delta
        velocity = Vector2.ZERO
        _update_animation()
        if dead_timer <= 0.0:
            # Director's rule (2026-10-31): death resets EVERYTHING to the
            # last bench save, exactly like resting — the scene reloads and
            # main re-applies the save (enemy restored, door/lever as saved).
            # With no save, the scene reloads to its starting parameters.
            get_tree().reload_current_scene()
        return

    # --- timers ---
    if is_on_floor():
        coyote_timer = COYOTE_TIME
        can_double_jump = true
    else:
        coyote_timer = maxf(coyote_timer - delta, 0.0)
    if Input.is_action_just_pressed("jump"):
        jump_buffer_timer = JUMP_BUFFER_TIME
    else:
        jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
    if Input.is_action_just_pressed("slash"):
        slash_buffer_timer = 0.15
    else:
        slash_buffer_timer = maxf(slash_buffer_timer - delta, 0.0)
    if Input.is_action_just_pressed("dash"):
        dash_buffer_timer = 0.15
    else:
        dash_buffer_timer = maxf(dash_buffer_timer - delta, 0.0)
    dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
    slash_cooldown_timer = maxf(slash_cooldown_timer - delta, 0.0)
    invuln_timer = maxf(invuln_timer - delta, 0.0)
    hurt_timer = maxf(hurt_timer - delta, 0.0)
    attack_anim_timer = maxf(attack_anim_timer - delta, 0.0)

    var dir := Input.get_axis("move_left", "move_right")
    if dir != 0.0:
        facing = signf(dir)

    # --- dash trigger (buffered) ---
    if dash_buffer_timer > 0.0 and dash_cooldown_timer <= 0.0 and dash_timer <= 0.0:
        dash_timer = DASH_TIME
        dash_cooldown_timer = DASH_COOLDOWN
        dash_buffer_timer = 0.0

    if dash_timer > 0.0:
        dash_timer -= delta
        velocity.x = facing * DASH_SPEED
        velocity.y = 0.0
    else:
        if not is_on_floor():
            velocity.y += gravity * delta
        if dir != 0.0:
            velocity.x = move_toward(velocity.x, dir * SPEED, ACCEL * delta)
        else:
            velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
        if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
            velocity.y = JUMP_VELOCITY
            jump_buffer_timer = 0.0
            coyote_timer = 0.0
        elif jump_buffer_timer > 0.0 and can_double_jump and dash_timer <= 0.0:
            # The second, mid-air jump (also available after walking off a
            # ledge, since can_double_jump only resets on the floor).
            velocity.y = DOUBLE_JUMP_VELOCITY
            jump_buffer_timer = 0.0
            can_double_jump = false

    # --- slash trigger (buffered) ---
    if slash_buffer_timer > 0.0 and slash_cooldown_timer <= 0.0:
        slash_buffer_timer = 0.0
        _start_slash()

    move_and_slide()

    # --- slash hit detection ---
    if slash_timer > 0.0:
        slash_timer -= delta
        for body in slash_hitbox.get_overlapping_bodies():
            if body.is_in_group("enemy") and body.has_method("take_damage"):
                body.take_damage(1)
        if slash_timer <= 0.0:
            slash_hitbox.monitoring = false

    # --- invulnerability blink ---
    if invuln_timer > 0.0:
        sprite.modulate.a = 0.35 if int(invuln_timer * 14.0) % 2 == 0 else 0.9
    else:
        sprite.modulate.a = 1.0

    _update_animation()

func _start_slash() -> void:
    if sfx_slash != null:
        sfx_slash.play()
    if sfx_shout != null and _roll_shout() and not sfx_shout.playing:
        sfx_shout.play()
    # Force-restart the swing animation on EVERY slash. Without this, a
    # slash that starts while the previous (non-looping) attack animation
    # is still the current one never replays — the hit lands invisibly
    # (playtest bug 2026-10-31: animation disappears after the first strike).
    current_anim = "attack"
    sprite.play("attack")
    slash_cooldown_timer = SLASH_COOLDOWN
    slash_timer = SLASH_TIME
    attack_anim_timer = 0.45
    slash_hitbox.position = Vector2(facing * 36.0, -6.0)
    slash_hitbox.monitoring = true

func take_damage(amount: int, from_position: Vector2) -> void:
    if invuln_timer > 0.0 or health <= 0 or dead_timer > 0.0:
        return
    health -= amount
    invuln_timer = 1.0
    hurt_timer = 0.3
    if sfx_hurt != null:
        sfx_hurt.play()
    var kb_dir := signf(global_position.x - from_position.x)
    if kb_dir == 0.0:
        kb_dir = -facing
    velocity.x = kb_dir * 240.0
    velocity.y = -180.0
    health_changed.emit(health)
    if health <= 0:
        die()

func heal_full() -> void:
    health = MAX_HEALTH
    health_changed.emit(health)

func die() -> void:
    died.emit()
    dead_timer = 0.9
    velocity = Vector2.ZERO
