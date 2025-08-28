extends Area2D


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"): # make sure your player is in the "player" group
		get_tree().change_scene_to_file("res://scenes/world2.tscn")
