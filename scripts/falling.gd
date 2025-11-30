# TODO: add layer mask for walls

class_name Falling extends PlayerState
var can_wallrun := true
var space_state : PhysicsDirectSpaceState3D

func _handle_air_physics(delta : float) -> void:
	player.velocity.y -= player.gravity * delta
	var cur_speed_in_wish_dir = player.velocity.dot(player.wish_dir)
	var capped_speed = min((player.air_move_speed * player.wish_dir).length(), player.air_cap)

	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = player.air_accel * player.air_move_speed * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		player.velocity += accel_speed * player.wish_dir

func enter(previous_state_path: String, data := {}) -> void:
	if previous_state_path == WALLJUMPING:
		player.velocity += player.force_to_apply
		can_wallrun = false
		await get_tree().create_timer(1).timeout
		can_wallrun = true

func physics_update(delta: float) -> void:

	if player.is_on_floor():
		finished.emit(RUNNING)

	if player.get_collision_x_normal() and not player.get_collision_down() and can_wallrun and not player.input_dir:
		finished.emit(WALLRUNNING, {
			'space': space_state
		})

	_handle_air_physics(delta)
