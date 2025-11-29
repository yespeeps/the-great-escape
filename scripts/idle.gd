class_name Idle extends PlayerState
#
# func enter(previous_state_path: String, data := {}) -> void:
# 	player.velocity *= 0
#
# func physics_update(_delta: float) -> void:
# 	if player.wish_dir:
# 		if Input.is_action_pressed('jump'):
# 			finished.emit(JUMPING)
# 		else:
# 			finished.emit(RUNNING)
