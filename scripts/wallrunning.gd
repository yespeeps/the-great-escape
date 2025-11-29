class_name WallRunning extends PlayerState
# get dot product of -globaltransformbasisz and wall normal and check if less than or equal or 0.5
func enter(_previous_state_path: String, _data := {}) -> void:
	player.velocity.y /= 2
	player.velocity += player.wall_run_boost * -player.global_transform.basis.z

func physics_update(delta: float) -> void:
	if !player.get_collision_x_normal():
		finished.emit(FALLING)
		return

	if Input.is_action_just_pressed('jump'):
		finished.emit(WALLJUMPING)

	player.velocity += -player.get_collision_x_normal()
	player.velocity.y -= player.gravity/2 * delta


	
