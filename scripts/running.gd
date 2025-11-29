class_name Running extends PlayerState

func enter(previous_state_path: String, data := {}) -> void:
	pass

func physics_update(delta: float) -> void:
	if Input.is_action_pressed('jump'):
		finished.emit(JUMPING)
	
	if not player.is_on_floor():
		finished.emit(FALLING)

	player._handle_ground_physics(delta)

