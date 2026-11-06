extends Node2D
func _ready() -> void:
    await get_tree().process_frame
    var M = load("res://main.gd")
    M.carriage_no = 2
    M.just_transferred = true
    M.entry_side = "left"
    var ps: PackedScene = load("res://main.tscn")
    var main = ps.instantiate()
    add_child(main)
    await get_tree().create_timer(2.0).timeout
    await get_tree().process_frame
    await get_tree().process_frame
    var img = get_viewport().get_texture().get_image()
    img.save_png("user://capy_car2.png")
    print("CAPY_SAVED")
    get_tree().quit()
