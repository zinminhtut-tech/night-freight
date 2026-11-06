extends CharacterBody2D

const MAX_HEALTH := 2 # small enemies die after 2 hits (director's final tweak, 2026-10-31)
const DRIFT_SPEED := 45.0
const WANDER_RANGE := 90.0 # idle enemies stay within this of home (director, 2026-10-31)
const PEACEFUL := false # combat LIVE (director ended the testing phase 2026-10-31): they chase, lunge and hurt again
const CHASE_SPEED := 75.0
const AGGRO_RANGE := 380.0
const LUNGE_RANGE := 120.0
const LUNGE_SPEED := 330.0
const LUNGE_TIME := 0.32
const LUNGE_COOLDOWN := 1.1

var health := MAX_HEALTH
var max_health := MAX_HEALTH # the Dining Car's Elder runs 6 (set by main)
var home := Vector2.ZERO
var hover_time := 0.0
var _phase := 0.0 # per-enemy random sway phase (they must not move in sync)
var _drift_dir := 1.0
var _flip_timer := 0.0
var direction := 1.0
var hit_cooldown := 0.0
var lunge_timer := 0.0
var lunge_cooldown_timer := 0.0
var lunge_dir := Vector2.ZERO
var dying := false
var death_timer := 0.0
var current_anim := ""
var _player: Node2D # cached player reference (refreshed when stale)

func _get_player() -> Node2D:
    if not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player") as Node2D
    return _player

@onready var sprite: AnimatedSprite2D = $Sprite

const ANIM_DEFS := {
    "idle": {"fps": 9.0, "loop": true},
    "attack": {"fps": 14.0, "loop": false},
    "death": {"fps": 10.0, "loop": false},
}

var sfx_hit: AudioStreamPlayer

func _ready() -> void:
    home = global_position
    add_to_group("enemy")
    _build_sprite_frames()
    sfx_hit = AudioStreamPlayer.new()
    sfx_hit.stream = load("res://assets/sfx/enemy_hit.wav")
    sfx_hit.bus = "SFX"
    add_child(sfx_hit)
    $DamageArea.body_entered.connect(_on_damage_area_body_entered)
    _phase = randf() * TAU
    _drift_dir = 1.0 if randf() < 0.5 else -1.0
    _flip_timer = randf_range(1.5, 4.0)

func _build_sprite_frames() -> void:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    for anim_name in ANIM_DEFS.keys():
        frames.add_animation(anim_name)
        var def: Dictionary = ANIM_DEFS[anim_name]
        frames.set_animation_speed(anim_name, def["fps"])
        frames.set_animation_loop(anim_name, def["loop"])
        # Index-based loading; see player.gd for why DirAccess is not used
        # (exported .pck builds hide the raw .png file names).
        var dir_path: String = "res://assets/enemy/" + str(anim_name)
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
            push_error("No frames loaded for enemy animation: " + dir_path)
        print("chochin anim ", anim_name, " frames=", count)
    sprite.sprite_frames = frames
    sprite.play("idle")
    current_anim = "idle"

func _play(anim_name: String) -> void:
    if current_anim != anim_name:
        current_anim = anim_name
        sprite.play(anim_name)

func _physics_process(delta: float) -> void:
    if dying:
        death_timer -= delta
        sprite.modulate.a = clampf(death_timer / 0.9, 0.0, 1.0)
        if death_timer <= 0.0:
            queue_free()
        return

    if hit_cooldown > 0.0:
        hit_cooldown -= delta
        if hit_cooldown <= 0.0:
            sprite.modulate = Color.WHITE
    lunge_cooldown_timer = maxf(lunge_cooldown_timer - delta, 0.0)
    hover_time += delta

    var player := _get_player()
    var to_player := Vector2.ZERO
    var dist := 99999.0
    if player != null:
        to_player = player.global_position - global_position
        dist = to_player.length()
    if PEACEFUL:
        dist = 99999.0 # forced idle: drift and wander only

    if lunge_timer > 0.0:
        lunge_timer -= delta
        velocity = lunge_dir * LUNGE_SPEED
        _play("attack")
    elif player != null and dist < AGGRO_RANGE:
        # Drift toward the player, hovering at roughly player height.
        var target_y := clampf(player.global_position.y - 66.0, home.y - 90.0, home.y + 120.0)
        velocity.x = signf(to_player.x) * CHASE_SPEED if absf(to_player.x) > 26.0 else 0.0
        velocity.y = clampf((target_y - global_position.y) * 3.0, -130.0, 130.0)
        if to_player.x != 0.0:
            direction = signf(to_player.x)
        _play("idle")
        if dist < LUNGE_RANGE and lunge_cooldown_timer <= 0.0:
            lunge_timer = LUNGE_TIME
            lunge_cooldown_timer = LUNGE_COOLDOWN
            lunge_dir = to_player.normalized()
    else:
        # Idle patrol: each lantern wanders on its OWN random rhythm
        # (director, 2026-10-31: they must not all face/move one way),
        # inside a limited area around home (director, 2026-10-31):
        # at the edge of the area it always turns back toward home.
        _flip_timer -= delta
        if _flip_timer <= 0.0:
            _drift_dir = 1.0 if randf() < 0.5 else -1.0
            _flip_timer = randf_range(1.5, 4.0)
        var off_home := global_position.x - home.x
        if off_home > WANDER_RANGE:
            _drift_dir = -1.0
            _flip_timer = randf_range(1.5, 4.0)
        elif off_home < -WANDER_RANGE:
            _drift_dir = 1.0
            _flip_timer = randf_range(1.5, 4.0)
        velocity.x = _drift_dir * DRIFT_SPEED * (0.55 + 0.45 * sin(hover_time * 0.9 + _phase))
        velocity.y = clampf((home.y - global_position.y) * 2.0, -50.0, 50.0)
        if velocity.x != 0.0:
            direction = signf(velocity.x)
        _play("idle")

    sprite.flip_h = direction < 0.0
    move_and_slide()

# Full reset to the spawn state (used when the player rests at a bench:
# the director's rule is that resting resets ALL enemies, dead or alive).
func reset_enemy() -> void:
    health = max_health
    dying = false
    death_timer = 0.0
    hit_cooldown = 0.0
    lunge_timer = 0.0
    lunge_cooldown_timer = 0.0
    hover_time = 0.0
    _phase = randf() * TAU
    _drift_dir = 1.0 if randf() < 0.5 else -1.0
    _flip_timer = randf_range(1.5, 4.0)
    velocity = Vector2.ZERO
    global_position = home
    sprite.modulate = Color.WHITE
    if not is_in_group("enemy"):
        add_to_group("enemy")
    $DamageArea.set_deferred("monitoring", true)
    $CollisionShape2D.set_deferred("disabled", false)
    current_anim = ""
    _play("idle")

func take_damage(amount: int) -> void:
    if hit_cooldown > 0.0 or dying:
        return
    health -= amount
    hit_cooldown = 0.3
    if sfx_hit != null:
        sfx_hit.play()
    sprite.modulate = Color(2.4, 2.4, 2.4)
    var player := _get_player()
    if player != null:
        global_position.x += signf(global_position.x - player.global_position.x) * 12.0
    if health <= 0:
        dying = true
        death_timer = 0.9
        remove_from_group("enemy")
        $DamageArea.set_deferred("monitoring", false)
        $CollisionShape2D.set_deferred("disabled", true)
        _play("death")

func _on_damage_area_body_entered(body: Node2D) -> void:
    if PEACEFUL:
        return # testing phase: contact does not hurt
    if body.is_in_group("player") and body.has_method("take_damage"):
        body.take_damage(1, global_position)
