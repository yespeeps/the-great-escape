extends CharacterBody3D

@export var speed = 5.0
@export var jump_velocity = 4.5
@export var rotation_speed = 3.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Get input direction for movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Apply movement velocity
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# Handle rotation (e.g., for camera-based movement)
	# This example assumes a camera parented to the character and rotating with it
	var mouse_delta = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	rotate_y(deg_to_rad(-mouse_delta.x * rotation_speed * delta))

	move_and_slide()
