extends Node2D

var player_in_range := false
var prompt: Label

func _ready() -> void:
    $InteractArea.body_entered.connect(_on_body_entered)
    $InteractArea.body_exited.connect(_on_body_exited)
    prompt = Label.new()
    prompt.text = "E: Rest"
    prompt.position = Vector2(-30, -88)
    prompt.add_theme_font_size_override("font_size", 20)
    prompt.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
    prompt.visible = false
    add_child(prompt)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        player_in_range = true
        prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
    if body.is_in_group("player"):
        player_in_range = false
        prompt.visible = false

# Resting at the bench: full heal + bench becomes the respawn point.
# Main handles the actual save write via SaveSystem.
func rest(player: Node2D) -> void:
    player.heal_full()
    player.respawn_point = global_position + Vector2(0.0, -26.0)
