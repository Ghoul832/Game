extends Area2D

@onready var timer = $Timer

func _on_body_entered(body: Node2D) -> void:
	print("ded")
	Engine.time_scale = 0.7
	timer.start()

func _on_timer_timeout() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/world.tscn")
