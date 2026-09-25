extends Node2D
class_name UiLayer

# Drawn after the world and the additive light pass so HUD and overlays stay crisp.

var game: Node2D


func _init() -> void:
	name = "UiLayer"


func _draw() -> void:
	if game and game.has_method("draw_ui_pass"):
		game.draw_ui_pass(self)
