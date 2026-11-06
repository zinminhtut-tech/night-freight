extends Node2D

func _ready() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    SaveSystem.delete_save(0)
    var main = load("res://main.tscn").instantiate()
    get_tree().root.add_child(main)
    get_tree().current_scene = main
    await get_tree().create_timer(1.0).timeout
    get_viewport().get_texture().get_image().save_png("user://cap_door_closed.png")
    main.get_node("Lever").pull()
    main.apply_door(true)
    await get_tree().create_timer(1.8).timeout
    get_viewport().get_texture().get_image().save_png("user://cap_door_open.png")
    print("CAPTURE_SAVED")
    get_tree().quit()
