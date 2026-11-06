extends Node2D

var failures := 0
var main: Node2D
var player: CharacterBody2D
var chochin: CharacterBody2D
var bench: Node2D
var lever: Node2D

func check(name: String, ok: bool) -> void:
    if ok:
        print("PASS: ", name)
    else:
        failures += 1
        print("FAIL: ", name)

func wait_s(seconds: float) -> void:
    var frames := int(seconds * 60.0)
    for i in range(frames):
        await get_tree().physics_frame

func press_key(physical: int) -> void:
    var ev := InputEventKey.new()
    ev.physical_keycode = physical
    ev.pressed = true
    Input.parse_input_event(ev)
    var ev2 := InputEventKey.new()
    ev2.physical_keycode = physical
    ev2.pressed = false
    Input.parse_input_event(ev2)

func click_left() -> void:
    var ev := InputEventMouseButton.new()
    ev.button_index = MOUSE_BUTTON_LEFT
    ev.pressed = true
    Input.parse_input_event(ev)
    var ev2 := InputEventMouseButton.new()
    ev2.button_index = MOUSE_BUTTON_LEFT
    ev2.pressed = false
    Input.parse_input_event(ev2)

func spawn_main() -> void:
    main = load("res://main.tscn").instantiate()
    get_tree().root.add_child(main)
    get_tree().current_scene = main
    player = main.get_node("Player")
    chochin = main.get_node("Chochin")
    bench = main.get_node("Bench")
    lever = main.get_node("Lever")

func _ready() -> void:
    # Wait until the root is fully set up before adding the game scene to it
    # (SaveSystem requires the game scene to be a root child / current_scene).
    await get_tree().process_frame
    await get_tree().process_frame
    run_tests()

func run_tests() -> void:
    SaveSystem.delete_save(0)
    spawn_main()
    # Freeze all enemies up front: solid, diving chochins otherwise wander
    # into the scripted movement checks (they are re-enabled per-section
    # where a live enemy is the thing being tested).
    for e in get_tree().get_nodes_in_group("enemy"):
        e.set_physics_process(false)
    await wait_s(0.6)

    # 1. Player lands on the carriage floor
    check("player lands on floor", player.is_on_floor())
    check("heroine renders in front of the door walls", player.z_index > 2)
    check("enemies render in front of the door walls", main.get_node("Chochin").z_index > 2)
    check("nine chochins patrol the long carriage", get_tree().get_nodes_in_group("enemy").size() == 9)
    check("camera zoom is unchanged", absf(main.get_node("Camera2D").zoom.x - 0.686) < 0.01)
    check("camera is limited to the world", main.get_node("Camera2D").limit_left == 8 and main.get_node("Camera2D").limit_right == int(main.WORLD_W) - 8)
    check("camera starts framed on the start section", absf(main.get_node("Camera2D").get_screen_center_position().x - 847.7) < 3.0) # limit_left 8 + half the 1679-wide view
    check("exit door is far beyond the starting view", main.WORLD_W - 100.0 > 1680.0 + 2000.0)
    var bd_a = main.get_node("Backdrop/BackdropA")
    var bx: float = bd_a.position.x
    await wait_s(0.4)
    check("backdrop scrolls past the windows", bd_a.position.x < bx)
    check("backdrop always covers the screen", bd_a.position.x - 1512.4 <= 1.0 and main.get_node("Backdrop/BackdropB").position.x + 1512.4 >= 1151.0)
    main.trigger_bump()
    check("bump has a sound", main.sfx_bump != null and main.sfx_bump.playing)
    var max_off := 0.0
    for i in range(30):
        await get_tree().physics_frame
        max_off = maxf(max_off, main.get_node("Camera2D").offset.length())
    check("pothole bump visibly shakes the train", max_off > 8.0)
    check("pothole bump is strong but bounded", max_off <= 20.0)
    check("backdrop cannot shake with the train (CanvasLayer)", main.get_node("Backdrop") is CanvasLayer)
    var bgm_node = main.get_node_or_null("BGM")
    check("BGM plays quietly under the SFX", bgm_node != null and bgm_node.playing and bgm_node.volume_db <= -10.0)
    var shout_hits := 0
    for i in range(2000):
        if player._roll_shout():
            shout_hits += 1
    var shout_rate := shout_hits / 2000.0
    check("attack shout chance is ~40 percent", shout_rate > 0.32 and shout_rate < 0.48)
    check("attack shout sound is loaded", player.sfx_shout != null and player.sfx_shout.stream != null)

    # 2. Run right
    var x0: float = player.global_position.x
    Input.action_press("move_right")
    await wait_s(0.5)
    Input.action_release("move_right")
    check("run right moves player", player.global_position.x > x0 + 60.0)

    # 3. Jump leaves the floor and lands again
    Input.action_press("jump")
    await wait_s(0.15)
    Input.action_release("jump")
    var airborne := not player.is_on_floor()
    await wait_s(1.6)
    check("jump goes airborne then lands", airborne and player.is_on_floor())

    # 4. Dash is faster than run speed
    player.facing = 1.0
    Input.action_press("dash")
    var max_vx := 0.0
    for i in range(20):
        await get_tree().physics_frame
        max_vx = maxf(max_vx, absf(player.velocity.x))
    Input.action_release("dash")
    check("dash exceeds run speed", max_vx > 400.0)

    # 4b. DOUBLE jump apex beats the luggage-rack rise (single jump ~118px
    # is NOT enough by design; the second jump must add real height).
    player.global_position = Vector2(300, 574)
    player.velocity = Vector2.ZERO
    await wait_s(0.1)
    var y0: float = player.global_position.y
    Input.action_press("jump")
    var min_y: float = y0
    var min_y_single: float = y0
    for i in range(110):
        await get_tree().physics_frame
        min_y = minf(min_y, player.global_position.y)
        if i < 28:
            min_y_single = minf(min_y_single, player.global_position.y)
        if i == 9:
            Input.action_release("jump")
        if i == 28:
            Input.action_press("jump")
        if i == 33:
            Input.action_release("jump")
    print("  single rise: ", y0 - min_y_single, " double rise: ", y0 - min_y)
    check("single jump rise is ~145 after +20 percent tuning", y0 - min_y_single > 136.0 and y0 - min_y_single < 156.0)
    check("double jump apex clears platform rise", y0 - min_y > 150.0)

    # 4c. Run + double jump actually mounts platform A (playtest 2026-10-31).
    player.global_position = Vector2(340, 574)
    player.velocity = Vector2.ZERO
    await wait_s(0.1)
    Input.action_press("move_right")
    await wait_s(0.03)
    Input.action_press("jump")
    await wait_s(0.05)
    Input.action_release("jump")
    await wait_s(0.2)
    Input.action_press("jump")
    await wait_s(0.05)
    Input.action_release("jump")
    await wait_s(0.42)
    Input.action_release("move_right")
    await wait_s(1.1)
    print("  mount test: pos=", player.global_position, " on_floor=", player.is_on_floor())
    check("run+double jump mounts platform A", player.is_on_floor() and absf(player.global_position.y - 440.0) < 6.0 and player.global_position.x > 480.0 and player.global_position.x < 760.0)

    # 5b. Attack animation RESTARTS on a re-click after it finished
    # (regression: rapid clicking used to leave later slashes invisible).
    var sprite: AnimatedSprite2D = player.get_node("Sprite")
    click_left()
    await wait_s(0.6) # first swing fully plays out (0.45s)
    click_left()
    await wait_s(0.08)
    check("attack animation restarts on re-click", sprite.animation == "attack" and sprite.is_playing())

    # 5. Combat is LIVE (director ended the testing phase 2026-10-31):
    # contact with a chochin hurts her (this one is frozen in place,
    # but its damage area is very much awake).
    player.global_position = chochin.global_position + Vector2(4, 10)
    await wait_s(0.4)
    check("live chochin deals contact damage", player.health == 9)
    player.health = 10 # restore for the sections below
    player.health_changed.emit(player.health)
    player.velocity = Vector2.ZERO
    await wait_s(0.15)
    check("HP bar fill follows health", absf(main.get_node("HUD").fill_fraction() - 1.0) < 0.01)
    var hud_node := main.get_node("HUD")
    check("HP fill renders above the frame", hud_node.get("_fill").get_index() > hud_node.get("_frame").get_index())
    check("HP frame renders at designed size", hud_node.get("_frame").size == Vector2(300, 75))

    # 6. Two slashes kill the chochin (real left-mouse-click events).
    # Player stays invulnerable so contact knockback cannot break the aim;
    # the chochin is re-pinned in front of the blade before each swing.
    # It must be LIVE here: its death countdown runs in _physics_process.
    chochin.set_physics_process(true)
    player.invuln_timer = 30.0
    for hit in range(2):
        player.global_position = Vector2(600, 500)
        player.velocity = Vector2.ZERO
        chochin.global_position = player.global_position + Vector2(50, -4)
        chochin.velocity = Vector2.ZERO
        player.facing = 1.0
        await wait_s(0.1)
        click_left()
        await wait_s(0.6)
        print("  after slash ", hit + 1, ": chochin health=", chochin.health if is_instance_valid(chochin) else -999)
    await wait_s(1.2)
    check("chochin dies after 2 slashes", not is_instance_valid(chochin) or chochin.is_queued_for_deletion())
    player.invuln_timer = 0.0

    # 7. Bench rest (real E key event) heals and writes a save
    player.global_position = bench.global_position + Vector2(0, -24)
    await wait_s(0.3)
    press_key(69) # E
    await wait_s(0.4)
    check("bench rest heals to full", player.health == 10)
    check("bench rest writes save file", SaveSystem.has_save(0))

    # 7b. Resting respawns the slain chochin at full health (director's rule)
    var ch_after_rest := main.get_node_or_null("Chochin")
    check("rest respawns dead enemy at full health", ch_after_rest != null and ch_after_rest.health == 2 and ch_after_rest.is_in_group("enemy"))

    # 8. Lever (real E key event) opens the door.
    # Freeze the enemies first: a diving chochin can otherwise knock her
    # into the open doorway mid-section and trigger a real transfer.
    for e in get_tree().get_nodes_in_group("enemy"):
        e.set_physics_process(false)
    player.global_position = lever.global_position + Vector2(0, -24)
    await wait_s(0.3)
    press_key(69) # E
    await wait_s(0.4)
    var door_shape: CollisionShape2D = main.get_node("Door/DoorShape")
    check("lever pull opens door", lever.is_open and door_shape.disabled)
    await wait_s(1.2)
    check("door slab slides sideways in the pier", main.door_slab.position.x > 60.0)
    check("lever handle animates to pulled frame", lever.atlas.region.position.x == 456.0)

    # 9. Persistence: rest again (saves door state), rebuild scene, state survives
    player.global_position = bench.global_position + Vector2(0, -24)
    await wait_s(0.3)
    press_key(69) # E
    await wait_s(0.4)
    var old_main := main
    get_tree().root.remove_child(old_main)
    old_main.queue_free()
    await wait_s(0.2)
    spawn_main()
    await wait_s(0.6)
    check("door state persists across reload", lever.is_open)
    check("player reloads at bench respawn", player.global_position.distance_to(bench.global_position + Vector2(0, -26)) < 30.0)

    # 10. Death resets EVERYTHING to the last bench save (scene reloads):
    # healed at the bench, chochin restored, saved door state kept.
    player.invuln_timer = 0.0
    player.health = 1
    player.take_damage(1, player.global_position + Vector2(-50, 0))
    await wait_s(2.4)
    main = get_tree().current_scene
    player = main.get_node("Player")
    chochin = main.get_node("Chochin")
    bench = main.get_node("Bench")
    lever = main.get_node("Lever")
    await wait_s(0.5)
    print("  death test: health=", player.health, " pos=", player.global_position, " respawn=", player.respawn_point)
    check("death resets to bench save healed", player.health == 10 and absf(player.global_position.x - player.respawn_point.x) < 30.0)
    check("death restores the chochin", is_instance_valid(chochin) and chochin.health == 2)
    check("death keeps saved door state", lever.is_open)

    # 11. Enemies are SOLID (director, 2026-10-31): she cannot walk
    # through a chochin; its body stops her like a wall.
    var c1 = main.get_node("Chochin")
    c1.set_physics_process(false) # parked frozen in her path (testing phase: it will not dive)
    player.global_position = Vector2(700, 574)
    player.velocity = Vector2.ZERO
    c1.global_position = Vector2(830, 556)
    await wait_s(0.3)
    Input.action_press("move_right")
    await wait_s(0.9)
    Input.action_release("move_right")
    check("enemy body blocks the player", player.global_position.x < c1.global_position.x - 15.0)

    # 12. Door transfer: walk into the open doorway at the far end of
    # the level and the leaf covers her; she lands in carriage 2.
    player.global_position = Vector2(main.WORLD_W - 60, 574)
    await wait_s(0.4)
    check("she is fully faded before the slab closes", player.modulate.a < 0.05)
    await wait_s(2.4)
    main = get_tree().current_scene
    player = main.get_node("Player")
    check("door transfer arrives in carriage 2", main.carriage_no == 2)
    check("carriage 2 entry point is at the left", player.global_position.x < 400.0)

    # 13. Audio settings: the BGM / SFX / Voice buses exist and the
    # settings API actually moves them (menu screen, 2026-10-31).
    check("audio buses exist", AudioServer.get_bus_index("BGM") > 0 and AudioServer.get_bus_index("SFX") > 0 and AudioServer.get_bus_index("Voice") > 0)
    check("game BGM rides the BGM bus", main.get_node("BGM").bus == "BGM")
    AudioSettings.set_bgm_volume(0.5)
    check("bgm volume applies to the bus", absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")) - linear_to_db(0.5)) < 0.6)
    AudioSettings.set_master_muted(true)
    check("master mute applies", AudioServer.is_bus_mute(0))
    AudioSettings.set_master_muted(false)
    AudioSettings.set_bgm_volume(0.8)

    # 14. Menu scene is wired: play + settings + sliders + mute.
    # (Layout rebuilt 2026-10-31: anchored containers, find_child paths.)
    var menu = load("res://menu.tscn").instantiate()
    get_tree().root.add_child(menu)
    await wait_s(0.3)
    check("menu has play and settings buttons", menu.find_child("PlayBtn") != null and menu.find_child("SettingsBtn") != null)
    check("menu settings has 3 sliders and mute", menu.find_child("BgmSlider") != null and menu.find_child("SfxSlider") != null and menu.find_child("VoiceSlider") != null and menu.find_child("MuteBtn") != null)
    menu.find_child("SettingsBtn").pressed.emit()
    check("settings button opens the panel", menu.find_child("SettingsPanel").visible)
    menu.find_child("BgmSlider").value = 35.0
    check("menu slider drives the BGM setting", absf(AudioSettings.bgm_volume - 0.35) < 0.02)
    AudioSettings.set_bgm_volume(0.8)
    menu.queue_free()

    # 15. Train ambience + unsynchronized enemies (director, 2026-10-31).
    check("train ambience plays on the SFX bus", main.get_node("Ambience") != null and main.get_node("Ambience").bus == "SFX" and main.get_node("Ambience").playing)
    check("ambience stays environmental", main.get_node("Ambience").volume_db <= -11.0)
    check("enemies have individual random phases", absf(main.get_node("Chochin")._phase - main.get_node("Chochin2")._phase) > 0.0005)

    # 16. Idle enemies stay in a limited area around home (director,
    # 2026-10-31): one placed far outside its area must head back.
    var wanderer = main.get_node("Chochin2")
    wanderer.set_physics_process(true)
    wanderer.global_position = wanderer.home + Vector2(200.0, 0.0)
    await wait_s(0.3)
    check("idle enemy turns back toward home at its area edge", wanderer.velocity.x < 0.0)

    # 17. Carriage 2 is a real Dining Car (2026-10-31): own painting,
    # table platforms, and an Elder Chochin with 6 HP.
    check("carriage 2 wears the dining painting", (main.get_node("Background") as Sprite2D).texture.resource_path.ends_with("dining_body.png"))
    check("carriage 2 backdrop streams behind cut windows", main.get_node("Backdrop").visible)
    check("carriage 2 tables are platforms", (main.get_node("World/PlatformA") as CollisionShape2D).position == Vector2(540, 490))
    var elder_ok := false
    for e in get_tree().get_nodes_in_group("enemy"):
        if e.max_health == 6 and e.home == main.enemy_homes[main.enemy_homes.size() - 1]:
            elder_ok = true
    check("elder chochin guards the exit end with 6 HP", elder_ok)
    check("carriage 2 back door has its own lever", main.get_node("Lever2").visible)

    # 18. The full train (director, 2026-10-31): carriage 2's forward
    # door leads ON to carriage 3, and the back doors walk her back
    # down the train, each arrival at the end she came from.
    for e in get_tree().get_nodes_in_group("enemy"):
        e.set_physics_process(false)
    main.get_node("Lever").pull()
    await wait_s(0.4)
    player.global_position = Vector2(main.WORLD_W - 60, 500)
    await wait_s(3.2)
    main = get_tree().current_scene
    player = main.get_node("Player")
    check("forward door leads on to carriage 3", main.carriage_no == 3)
    check("carriage 3 entry point is at the left", player.global_position.x < 400.0)
    for e in get_tree().get_nodes_in_group("enemy"):
        e.set_physics_process(false)
    player.global_position = main.get_node("Lever2").global_position + Vector2(0, -24)
    player.velocity = Vector2.ZERO
    await wait_s(0.3)
    press_key(69) # E, the real key path (the back lever shipped broken once: prompt showed, E did nothing)
    await wait_s(0.4)
    check("back lever answers the E key", main.get_node("Lever2").is_open and main.get_node("BackDoor/BackDoorShape").disabled)
    player.global_position = Vector2(100, 500)
    await wait_s(3.2)
    main = get_tree().current_scene
    player = main.get_node("Player")
    check("back door returns to carriage 2", main.carriage_no == 2)
    check("backward arrival is at the right end", player.global_position.x > main.WORLD_W - 400.0)
    for e in get_tree().get_nodes_in_group("enemy"):
        e.set_physics_process(false)
    main.get_node("Lever2").pull()
    await wait_s(0.4)
    player.global_position = Vector2(100, 500)
    await wait_s(3.2)
    main = get_tree().current_scene
    player = main.get_node("Player")
    check("back door returns to carriage 1", main.carriage_no == 1)
    check("carriage 1 arrival is at the right end", player.global_position.x > main.WORLD_W - 400.0)

    # 18b. Scrolling level (director's brief 2026-10-31): fresh carriage
    # 1; the floor is one continuous shape, the camera follows and
    # clamps at both ends, and she can walk the whole level.
    var old_main2 := main
    get_tree().root.remove_child(old_main2)
    old_main2.queue_free()
    await wait_s(0.2)
    spawn_main()
    await wait_s(0.6)
    for e in get_tree().get_nodes_in_group("enemy"):
        e.set_physics_process(false)
        e.global_position.y -= 170.0 # parked above the walkway for a clean traversal
    var floor_shape := main.get_node("World/Floor") as CollisionShape2D
    check("floor collision spans the whole level", (floor_shape.shape as RectangleShape2D).size.x >= main.WORLD_W and absf(floor_shape.position.x - main.WORLD_W * 0.5) < 1.0)
    check("level is built from reusable sections", main.get_node("Sections").get_child_count() >= 10)
    var cam := main.get_node("Camera2D") as Camera2D
    player.global_position = Vector2(3000, 574)
    player.velocity = Vector2.ZERO
    await wait_s(1.4)
    check("camera follows the player mid-level", absf(cam.get_screen_center_position().x - 3000.0) < 60.0)
    player.global_position = Vector2(5700, 574)
    await wait_s(1.4)
    check("camera stops at the far world edge", absf(cam.get_screen_center_position().x - (main.WORLD_W - 840.0)) < 60.0)
    player.global_position = Vector2(200, 574)
    await wait_s(1.4)
    check("camera stops at the start world edge", absf(cam.get_screen_center_position().x - 840.0) < 60.0)
    player.global_position = Vector2(300, 574)
    player.velocity = Vector2.ZERO
    await wait_s(0.3)
    press_key(74) # J, the director's cheat key (2026-10-31)
    await wait_s(0.3)
    check("J cheat teleports to the exit door end", player.global_position.x > main.WORLD_W - 400.0)
    press_key(74)
    await wait_s(0.3)
    check("J cheat teleports back to the start end", player.global_position.x < 500.0)
    var traversed := true
    for cp in [1200.0, 2400.0, 3600.0, 4800.0, 5560.0]:
        player.global_position = Vector2(cp - 500.0, 574)
        player.velocity = Vector2.ZERO
        await wait_s(0.15)
        Input.action_press("move_right")
        await wait_s(2.2)
        Input.action_release("move_right")
        if player.global_position.x < cp - 60.0 or not player.is_on_floor():
            traversed = false
            print("  traversal stalled before checkpoint ", cp, " at ", player.global_position)
    check("she can walk the entire level end to end", traversed)

    # 19. ESC returns from the game to the menu (director, 2026-10-31).
    main.return_to_menu()
    await wait_s(0.8)
    check("esc returns to the menu scene", get_tree().current_scene != null and get_tree().current_scene.name == "Menu")

    # 20. The Locomotive ending (director, 2026-10-31): with all seven
    # carriages built, the last carriage's open door frees the dawn
    # and returns to the menu.
    var maingd = load("res://main.gd") # section 19 freed the old main instance
    check("all seven carriages are built", maingd.LAYOUTS.size() == 7 and maingd.MAX_CARRIAGE == 7)
    maingd.carriage_no = 7
    spawn_main()
    await wait_s(0.6)
    for e in get_tree().get_nodes_in_group("enemy"):
        e.set_physics_process(false)
    check("the Oni Lord waits in the locomotive", main.get_node("Chochin9").max_health == 12)
    main.get_node("Lever").pull()
    await wait_s(0.4)
    player.global_position = Vector2(main.WORLD_W - 60, 500)
    await wait_s(4.5)
    # scene_file_path, not name: section 19's menu still sits in the
    # tree, so the ending's menu instance is auto-renamed @Control@N.
    check("the locomotive door frees the dawn and returns to menu", get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://menu.tscn")

    if failures == 0:
        print("SLICE_TESTS_PASS")
    else:
        print("SLICE_TESTS_FAIL count=", failures)
    get_tree().quit()
