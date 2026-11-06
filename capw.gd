extends Node2D
func _ready() -> void:
    await get_tree().process_frame
    var args := OS.get_cmdline_user_args()
    var car_no := 1
    if args.size() > 0:
        car_no = int(args[0])
    var M = load("res://main.gd")
    M.carriage_no = car_no
    M.just_transferred = false
    var ps: PackedScene = load("res://main.tscn")
    var main = ps.instantiate()
    add_child(main)
    await get_tree().create_timer(1.0).timeout
    var p = main.get_node("Player")
    var shots := [300.0, 2900.0, 5350.0]
    for i in shots.size():
        p.global_position = Vector2(shots[i], 574)
        p.velocity = Vector2.ZERO
        await get_tree().create_timer(1.6).timeout
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png("user://capw_c%d_%d.png" % [car_no, i])
    print("CAPW_SAVED")
    get_tree().quit()
