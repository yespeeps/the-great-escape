extends CharacterBody3D

@onready var head: Node3D = $neck/Head
@onready var eyes: Node3D = $neck/Head/eyes
@onready var neck: Node3D = $neck
@onready var camera: Node3D = $neck/Head/eyes/Camera3D

@onready var standing_collider = $Standing_Collider
@onready var crouching_collider = $Crouching_Collider
@onready var raycast = $RayCast3D
@onready var feet = $feet

@export var current_speed = 5.0
@export var jump_velocity = 4.5
@export var walking_speed = 5.0
@export var sprinting_speed = 10.0
@export var crouching_speed = 3.0
@export var mouse_sens = 0.4
@export var lerp_speed = 10.0
@export var crouching_depth : float = -0.5

var direction = Vector3.ZERO
var input_dir = Vector2.ZERO

const head_bobbing_sprinting_speed = 22
const head_bobbing_walking_speed = 14
const head_bobbing_crouching_speed = 10

const head_bobbing_sprinting_intensity = 0.2 #* 100
const head_bobbing_crouching_intensity = 0.05# * 100
const head_bobbing_walking_intensity = 0.1 #* 100

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0

# states
var sprinting = false
var walking = false
var crouching = false 
var sliding = false 
var leaning = false
var midair = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta: float) -> void:
	if is_on_wall():
		velocity.y = velocity.y/3.5

	if Input.is_action_pressed("crouch"):
		current_speed = lerp(current_speed, crouching_speed, delta*lerp_speed)
		head.position.y = lerp(head.position.y, crouching_depth, delta*lerp_speed)
		standing_collider.disabled = true
		crouching_collider.disabled = false

		crouching = true
		sprinting = false
		walking = false
	elif !raycast.is_colliding():
		head.position.y = lerp(head.position.y, 0.0, delta*lerp_speed)    
		standing_collider.disabled = false
		crouching_collider.disabled = true
		if Input.is_action_pressed("sprint"):
			current_speed = lerp(current_speed, sprinting_speed, delta*lerp_speed)
			sprinting = true 
			walking = false
			crouching = false
		else:
			current_speed = lerp(current_speed, walking_speed, delta*lerp_speed)
			sprinting = false 
			if input_dir == Vector2.ZERO:
				walking = false
			else:
				walking = true
			crouching = false

	if sprinting:
		head_bobbing_current_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_sprinting_speed*delta
	elif walking:
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed*delta
	elif crouching:
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed*delta

	if is_on_floor() && input_dir != Vector2.ZERO && !leaning:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index/2.0) + 0.5  # sin(head_bobbing_index/2) + 0.5

		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y*(head_bobbing_current_intensity/2.0), lerp_speed*delta)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x*head_bobbing_current_intensity, lerp_speed*delta)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, lerp_speed*delta)
		eyes.position.x = lerp(eyes.position.x, 0.0, lerp_speed*delta)


# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		midair = true

# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

# Get the input direction and handle the movement/deceleration.
# As good practice, you should replace UI actions with custom gameplay actions.
	input_dir = Input.get_vector("input_left", "input_right", 'input_forward', "input_back")
	direction = transform.basis * Vector3(input_dir.x, 0, input_dir.y).normalized()

	if direction:
		velocity.x = lerp(velocity.x, direction.x * current_speed, delta*lerp_speed)
		velocity.z = lerp(velocity.z, direction.z * current_speed, delta*lerp_speed)
	else:
		velocity.x = lerp(velocity.x, 0.0, delta*lerp_speed)
		velocity.z = lerp(velocity.z, 0.0, delta*lerp_speed)

	move_and_slide()


func _on_feet_body_entered(body: Node3D) -> void:
	if body.is_in_group('Box'):
		body.collision_layer = 1
		body.collision_mask = 1


func _on_feet_body_exited(body: Node3D) -> void:
	if body.is_in_group('Box'):
		body.collision_layer = 2
		body.collision_mask = 2
