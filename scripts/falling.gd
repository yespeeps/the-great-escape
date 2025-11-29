class_name Falling extends PlayerState

func enter(previous_state_path: String, data := {}) -> void:
	pass

func physics_update(delta: float) -> void:
	if player.is_on_floor():
		finished.emit(RUNNING)

	player.velocity.y -= player.gravity * delta
	var cur_speed_in_wish_dir = player.velocity.dot(player.wish_dir)
	var capped_speed = min((player.air_move_speed * player.wish_dir).length(), player.air_cap)

	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = player.air_accel * player.air_move_speed * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		player.velocity += accel_speed * player.wish_dir
