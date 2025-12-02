extends Node3D

@onready var player = $SourceController

func _physics_process(delta: float) -> void:
	get_tree().call_group('enemies', 'update_target_position', player.global_transform.origin)
