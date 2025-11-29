class_name Falling extends PlayerState
var can_wallrun := true 
var can_double_jump := true

func enter(previous_state_path: String, data := {}) -> void:
	if previous_state_path == WALLJUMPING:
		can_wallrun = false
		await get_tree().create_timer(0.2).timeout
		can_wallrun = true

	if previous_state_path == DOUBLEJUMPING: 
		can_double_jump = false

func physics_update(delta: float) -> void:
	if player.is_on_floor():
		can_double_jump = true
		finished.emit(RUNNING)

	var normal = player.get_collision_x_normal()
	var dot = 0.0
	var angle_constraint

	if normal != null:
		dot = player.global_transform.basis.z.dot(normal)
		angle_constraint = dot >= -0.5 and dot <= 0.5

	if player.get_collision_x_normal() and can_wallrun and angle_constraint and not player.get_collision_down():
		print(player.global_transform.basis.z.dot(player.get_collision_x_normal()))
		finished.emit(WALLRUNNING)
	elif Input.is_action_just_pressed('jump') and can_double_jump:
		finished.emit(DOUBLEJUMPING)

	player._handle_air_physics(delta)
