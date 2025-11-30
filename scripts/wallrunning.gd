class_name WallRunning extends PlayerState
var wallrun_start : bool

func enter(_previous_state_path: String, data := {}) -> void:
	player.velocity.y /= 2
	player.velocity += player.wall_run_boost * -player.global_transform.basis.z

	player.update_rays()
	var collision = player.get_collision_x()
	if data.space:
		if collision == data.space.intersect_ray(player.ray_left):
			player.camera.rotation.z -= 0.2
		elif collision == data.space.intersect_ray(player.ray_right):
			player.camera.rotation.z += 0.2
	

func physics_update(delta: float) -> void:
	if !player.get_collision_x_normal() or player.input_dir:
		finished.emit(FALLING)
		return

	if Input.is_action_just_pressed('jump'):
		print(-player.global_transform.basis.z.dot(player.get_collision_x_normal()))
		finished.emit(WALLJUMPING)
	
	player._handle_wallrun_physics(delta)

func exit() -> void:
	player.camera.rotation.z = 0
