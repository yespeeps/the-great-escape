class_name DoubleJumping extends PlayerState

func enter(previous_state_path: String, data := {}) -> void:
	player.velocity.y += player.jump_velocity/2
	player.velocity += player.jump_velocity * player.wish_dir
	finished.emit(FALLING)



