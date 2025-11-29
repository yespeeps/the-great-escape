class_name Running extends PlayerState

func _handle_ground_physics(delta : float) -> void:
	var cur_speed_in_wish_dir = player.velocity.dot(player.wish_dir)
	var add_speed_till_cap = player.get_move_speed() - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = player.ground_accel * player.get_move_speed() * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		player.velocity += accel_speed * player.wish_dir

	var control = max(player.velocity.length(), player.ground_decel)
	var drop = control * player.ground_friction * delta
	var new_speed = max(player.velocity.length() - drop, 0.0)
	if player.velocity.length() > 0:
		new_speed /= player.velocity.length()
	player.velocity *= new_speed

func enter(previous_state_path: String, data := {}) -> void:
	pass

func physics_update(delta: float) -> void:
	if Input.is_action_pressed('jump'):
		finished.emit(JUMPING)
	
	if not player.is_on_floor():
		finished.emit(FALLING)

	_handle_ground_physics(delta)

