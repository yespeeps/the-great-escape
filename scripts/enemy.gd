extends CharacterBody3D

@onready var agent = $NavigationAgent3D
@onready var audio = $AudioStreamPlayer3D
var speed := 3.0

enum States {WALKING, IDLE}
var current_state := States.IDLE:
	set = set_state

func set_state(new_state):
	var previous_state = current_state
	current_state = new_state

	if new_state == States.WALKING:
		audio.play()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 19 * delta
	else:
		velocity.y -= 2

	var current_location = global_transform.origin
	var next_location = agent.get_next_path_position()
	var next_location_relative = next_location * global_transform
	var new_velocity = (next_location - current_location).normalized() * speed

	var idle_distance = 5
	match (current_state):
		States.IDLE:
			if next_location_relative.length() <= idle_distance:
				current_state = States.WALKING
		States.WALKING:
			if next_location_relative.length() >= idle_distance:
				current_state = States.IDLE

	if current_state == States.WALKING:
		velocity = velocity.move_toward(new_velocity, 0.25)
	else:
		velocity = Vector3()
	move_and_slide()

func update_target_position(target_position):
	agent.target_position = target_position
