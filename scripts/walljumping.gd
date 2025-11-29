class_name WallJumping extends PlayerState

func enter(previous_state_path: String, data := {}) -> void:
	pass

func physics_update(delta: float) -> void:
	var force_to_apply = player.get_collision_x_normal() * player.wall_jump_side_force + player.global_transform.basis.y * player.wall_jump_up_force 
	player.velocity += force_to_apply * delta
	finished.emit(FALLING)
