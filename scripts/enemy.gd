extends CharacterBody3D

@onready var agent = $NavigationAgent3D
@onready var found_audio = $FoundAudio
@onready var died_audio = $DiedAudio
@export var speed := 3.0
@export var health := 100.0

enum States {WALKING, IDLE, DEAD}
var current_state := States.IDLE:
	set = set_state

func set_state(new_state):
	var previous_state = current_state
	current_state = new_state

	if new_state == States.WALKING:
		found_audio.play()
	
	if new_state == States.DEAD:
		died_audio.play()

func _physics_process(delta: float) -> void:
	if health <= 0:
		died_audio.play()
		queue_free()

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

			if health <= 0:
				current_state = States.DEAD
		States.WALKING:
			if next_location_relative.length() >= idle_distance:
				current_state = States.IDLE
			if health <= 0:
				current_state = States.DEAD

	if current_state == States.WALKING:
		velocity = velocity.move_toward(new_velocity, 0.25)
	elif current_state == States.IDLE:
		velocity = Vector3()
	move_and_slide()

func update_target_position(target_position):
	agent.target_position = target_position
