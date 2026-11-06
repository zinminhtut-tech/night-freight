extends Node2D
func _ready() -> void:
    await get_tree().process_frame
    var M = load("res://main.gd")
    M.carriage_no = 2
    M.just_transferred = false
    var ps: PackedScene = load("res://main.tscn")
    var main = ps.instantiate()
    add_child(main)
    await get_tree().create_timer(1.0).timeout
    main.lever_back.set_open(true)
    await get_tree().create_timer(1.0).timeout
    var p = main.get_node("Player")
    p.global_position = Vector2(95, 574)
    await get_tree().create_timer(0.12).timeout
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png("user://capx_mid1.png")
    await get_tree().create_timer(0.18).timeout
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png("user://capx_mid2.png")
    print("CAPX_SAVED")
    get_tree().quit()
