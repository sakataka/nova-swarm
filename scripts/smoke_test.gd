extends SceneTree


func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.selected_control_mode = scene.ControlMode.AI
	scene.reset()
	_assert(scene.control_mode == scene.ControlMode.AI, "smoke starts ai mode")
	for i in range(30):
		scene._process(1.0 / 60.0)
		await process_frame
	root.remove_child(scene)
	scene.free()
	await process_frame
	quit()


func _assert(condition: bool, label: String) -> void:
	if condition:
		return
	push_error("Smoke test failed: " + label)
	quit(1)
