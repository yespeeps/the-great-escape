class_name Jumping extends PlayerState

func enter(_previous_state_path: String, _data := {}) -> void:
	player.velocity.y += player.jump_velocity
	finished.emit(FALLING)



			
