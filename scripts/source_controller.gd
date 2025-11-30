#TODO: Wallrun only when holding forward
class_name Player extends CharacterBody3D
@onready var world_model = $WorldModel
@onready var camera = $Head/Camera3D
@onready var standing_collider = $StandingCollider
@onready var crouching_collider = $CrouchingCollider

@onready var ceiling = $ceiling
@onready var right = $WorldModel/right
@onready var left = $WorldModel/left
@onready var cam_cast = $Head/Camera3D/RayCast3D
@onready var exit_timer = $"Exit Timer"

@export var look_sens : float = 0.002
@export var jump_velocity := 6.0
@export var auto_bhop := true

# Air movement settings. Need to tweak these to get the feeling dialed in.
@export var air_cap := 0.85 # Can surf steeper ramps if this is higher, makes it easier to stick and bhop
@export var air_accel := 800.0
@export var air_move_speed := 500.0

@export var wall_jump_up_force := 7.0
@export var wall_jump_side_force := 17.0
@export var wall_run_boost := 2.0
@export var wall_run_side_speed := 120.0

# Ground movement settings
@export var walk_speed := 7
@export var sprint_speed := 8.5
@export var crouch_speed := 3.5
@export var ground_accel := 6.0
@export var ground_decel := 3.0
@export var ground_friction := 4.0

@export var health := 100.0
@export var max_health := 100.0
const headbob_move_amount = 0.06
const headbob_move_frequency = 2.4
var headbob_time = 0.0

var wish_dir := Vector3.ZERO
var input_dir
var force_to_apply : Vector3

var gravity = ProjectSettings.get_setting('physics/3d/default_gravity')
var lerp_speed := 7.0
var can_slide := true
var slide_cooldown := 2.0
var slide_impulse := 7.0

enum States {RUNNING, CROUCHING, JUMPING, FALLING, WALLRUNNING, WALLJUMPING, SLIDING}
var current_state : States:
	set = set_state

func _ready() -> void:
	for child : VisualInstance3D in world_model.find_children('*', 'VisualInstance3D'):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)
				
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:		
			rotate_y(-event.relative.x * look_sens)
			camera.rotate_x(-event.relative.y * look_sens)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _headbob_effect(delta : float):
	headbob_time = delta * self.velocity.length()
	camera.transform.origin = Vector3(
		cos(headbob_time * headbob_move_frequency/2) * delta,
		sin(headbob_time * headbob_move_frequency) * delta,
		0
	)

func get_move_speed() -> float:
	if Input.is_action_pressed('sprint') and !Input.is_action_pressed('crouch'):
		return sprint_speed
	elif Input.is_action_pressed('crouch'):
		return crouch_speed
	else: 
		return walk_speed

func _handle_air_physics(delta : float) -> void:
	self.velocity.y -= gravity * delta
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var capped_speed = min((air_move_speed * wish_dir).length(), air_cap)

	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = air_accel * air_move_speed * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir

func _handle_wallrun_physics(delta : float) -> void:
	self.velocity.y -= gravity/3 * delta
	self.velocity += -get_last_slide_collision().get_normal() * delta * 2

func _handle_ground_physics(delta : float) -> void:
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var add_speed_till_cap = get_move_speed() - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = ground_accel * get_move_speed() * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir

	var control = max(self.velocity.length(), ground_decel)
	var drop = control * ground_friction * delta
	var new_speed = max(self.velocity.length() - drop, 0.0)
	if self.velocity.length() > 0:
		new_speed /= self.velocity.length()
	self.velocity *= new_speed

func _handle_slide_physics(delta: float):
	#just added the friction code but there is no need for control
	var control = ground_decel
	var drop = control * ground_friction * delta
	var new_speed = max(self.velocity.length() - drop, 0.0)
	if self.velocity.length() > 0:
		new_speed /= self.velocity.length()
	self.velocity *= new_speed

func wall_jump() -> void:
	self.velocity += get_last_slide_collision().get_normal() * wall_jump_side_force + self.global_transform.basis.y * wall_jump_up_force

func jump():
	self.velocity.y += jump_velocity

func set_state(new_state):
	var previous_state = current_state
	current_state = new_state

	if new_state == States.WALLRUNNING:
		self.velocity.y /= 2
	
	if new_state == States.SLIDING:
		self.velocity += -global_basis.z * slide_impulse

	if previous_state == States.SLIDING:
		can_slide = false
		await get_tree().create_timer(slide_cooldown).timeout
		can_slide = true

	return previous_state

func _physics_process(delta: float) -> void:
	input_dir = Input.get_vector('input_left', 'input_right', 'input_back', 'input_forward').normalized()
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0, -input_dir.y)

	## State Machine
	match (current_state):
		States.RUNNING:
			if Input.is_action_pressed('jump'):
				current_state = States.JUMPING
			elif not is_on_floor():
				current_state = States.FALLING
			elif Input.is_action_pressed('crouch') and !Input.is_action_pressed('sprint'):
				current_state = States.CROUCHING
			elif Input.is_action_pressed('crouch') and Input.is_action_pressed('sprint'):
				if can_slide:
					current_state = States.SLIDING
				else:
					current_state = States.CROUCHING
		States.JUMPING:
			current_state = States.FALLING
		States.FALLING:
			if is_on_floor():
				current_state = States.RUNNING
			elif is_on_wall_only() and (left.is_colliding() or right.is_colliding()) and Input.is_action_pressed('input_forward') and self.velocity.length() > (walk_speed - 0.5):
				current_state = States.WALLRUNNING
		States.WALLRUNNING:
			if Input.is_action_just_pressed('jump'):
				current_state = States.WALLJUMPING
			elif !get_last_slide_collision() or !Input.is_action_pressed('input_forward') or Input.is_action_just_pressed('crouch') or is_on_floor():
				current_state = States.FALLING
		States.WALLJUMPING:
			current_state = States.FALLING
		States.CROUCHING:
			if not is_on_floor():
				current_state = States.FALLING
			elif !Input.is_action_pressed('crouch'):
				current_state = States.RUNNING
		States.SLIDING:
			if !Input.is_action_pressed('crouch'):
				current_state = States.RUNNING
			elif self.velocity.length() <= 0.1:
				current_state = States.CROUCHING
			elif not is_on_floor():
				current_state = States.FALLING

	## Movement
	if current_state in [States.RUNNING, States.CROUCHING]:
		_handle_ground_physics(delta)
	elif current_state == States.JUMPING:
		jump()
	elif current_state == States.FALLING:	
		_handle_air_physics(delta)
	elif current_state == States.WALLRUNNING:
		_handle_wallrun_physics(delta)
	elif current_state == States.WALLJUMPING:
		wall_jump()
	elif current_state == States.SLIDING:
		_handle_slide_physics(delta)

	## Camera Movement
	if current_state in [States.RUNNING, States.WALLJUMPING, States.FALLING]: 
		camera.position.y = lerp(camera.position.y, 0.0, lerp_speed * delta)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, lerp_speed * delta)
	elif current_state == States.CROUCHING:
		camera.rotation.z = lerp(camera.rotation.z, 0.0, lerp_speed * delta)
		camera.position.y = lerp(camera.position.y, -0.5, lerp_speed * delta)
	elif current_state == States.WALLRUNNING:
		camera.position.y = lerp(camera.position.y, 0.0, lerp_speed * delta)
		var target_pos = 0.2
		if left.is_colliding():
			camera.rotation.z = lerp(camera.rotation.z, -target_pos, delta * lerp_speed)
		else:
			camera.rotation.z = lerp(camera.rotation.z, target_pos, delta * lerp_speed)
	elif current_state == States.SLIDING:
		camera.rotation.z = lerp(camera.rotation.z, 0.0, lerp_speed * delta)
		camera.position.y = lerp(camera.position.y, -0.7, lerp_speed * delta)

	## Collider Setting
	if current_state in [States.RUNNING, States.WALLJUMPING, States.FALLING, States.WALLRUNNING, States.JUMPING]:
		standing_collider.disabled = false
		crouching_collider.disabled = true
	else:
		standing_collider.disabled = true
		crouching_collider.disabled = false

	move_and_slide()



	
