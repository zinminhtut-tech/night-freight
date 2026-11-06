extends Node2D
func _ready() -> void:
    await get_tree().process_frame
    var M = load("res://main.gd")
    M.carriage_no = 2
    M.just_transferred = false
    var ps: PackedScene = load("res://main.tscn")
    var main = ps.instantiate()
    add_child(main)
    await get_tree().create_timer(1.2).timeout
    var p = main.get_node("Player")
    p.global_position = Vector2(150, 574)
    await get_tree().create_timer(0.6).timeout
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png("user://capz_doorfront.png")
    print("CAPZ_SAVED")
    get_tree().quit()
