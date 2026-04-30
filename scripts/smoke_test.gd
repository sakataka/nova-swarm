extends SceneTree


func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.reset()
	for i in range(30):
		scene._process(1.0 / 60.0)
		await process_frame
	quit()
