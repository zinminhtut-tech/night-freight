extends Node2D

func _ready() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    var menu = load("res://menu.tscn").instantiate()
    get_tree().root.add_child(menu)
    get_tree().current_scene = menu
    await get_tree().create_timer(1.4).timeout
    get_viewport().get_texture().get_image().save_png("user://cap_menu.png")
    menu._on_settings()
    await get_tree().create_timer(0.5).timeout
    get_viewport().get_texture().get_image().save_png("user://cap_settings.png")
    print("CAPTURE_SAVED")
    get_tree().quit()
