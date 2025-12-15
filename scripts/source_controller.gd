#TODO: Change collision checks to only be raycasts (maybe)
class_name Player extends CharacterBody3D
@onready var world_model = $WorldModel
@onready var camera = $Head/Camera3D
@onready var standing_collider = $StandingCollider
@onready var crouching_collider = $CrouchingCollider
@onready var stream_player = $Head/Camera3D/ViewModel/Deagle/AudioStreamPlayer3D

@onready var ceiling = $ceiling
@onready var right = $WorldModel/right
@onready var left = $WorldModel/left
@onready var exit_timer = $"Exit Timer"

@export var look_sens : float = 0.002
@export var jump_velocity := 6.0
@export var auto_bhop := false

# Air movement settings. Need to tweak these to get the feeling dialed in.
@export var air_cap := 0.85 # Can surf steeper ramps if this is higher, makes it easier to stick and bhop
@export var air_accel := 800.0
@export var air_move_speed := 500.0

@export var wall_jump_up_force := 5.0
@export var wall_jump_side_force := 5.0
@export var wall_run_boost := 2.0
@export var wall_run_side_speed := 120.0

# Ground movement settings
var walk_speed := 7
var sprint_speed := 14.0
var crouch_speed := 3.5
var ground_accel := 7.0
var ground_decel := 4.0
var ground_friction := 5.0

@export var health := 100.0
@export var max_health := 100.0
const headbob_move_amount = 0.06
const headbob_move_frequency = 2.4
var headbob_time = 0.0

var wish_dir := Vector3.ZERO
var input_dir
var force_to_apply : Vector3

var gravity = ProjectSettings.get_setting('physics/3d/default_gravity')
var lerp_speed := 10.0

var can_slide := true
var slide_cooldown := 1.0
var slide_impulse := 1.5

var can_wall_run := true

var can_ledge_grab := true
var ledge_grab_cooldown := 1.0

const head_bobbing_sprinting_speed = 22.0
const head_bobbing_walking_speed = 14.0
const head_bobbing_crouching_speed = 10.0

const head_bobbing_crouching_intensity = 0.1
const head_bobbing_sprinting_intensity = 0.2
const head_bobbing_walking_intensity = 0.05

var head_bobbing_vector := Vector2.ZERO
var head_bobbing_index := 0.0
var head_bobbing_current_intensity

var previous_wall_jump_position : float
var wall_count : int 
var space_state : PhysicsDirectSpaceState3D

enum States {RUNNING, CROUCHING, JUMPING, FALLING, WALLRUNNING, WALLJUMPING, SLIDING, LEDGEGRABBING, WALKING}
var current_state : States:
	set = set_state

func _ready() -> void:
	for child : VisualInstance3D in world_model.find_children('*', 'VisualInstance3D'):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)

	create_rays()

func create_rays():
	var origin = position
	var distance = 0.6

	var ray_left = PhysicsRayQueryParameters3D.create(origin, origin - distance * global_basis.x)
	var ray_right = PhysicsRayQueryParameters3D.create(origin, origin + distance * global_basis.x)
	var ray_forward = PhysicsRayQueryParameters3D.create(Vector3(origin.x, origin.y + 0.4, origin.z), origin + distance * -global_basis.z) 

	return {
		'ray_left': ray_left,
		'ray_right': ray_right,
		'ray_forward': ray_forward,
	}
				
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

func raycast_get_collision():
	var result_left = space_state.intersect_ray(create_rays().ray_left)
	var result_right = space_state.intersect_ray(create_rays().ray_right)

	if result_left:
		return result_left
	elif result_right:
		return result_right

	# This is the dictionary that it will return.
	#    position: Vector2 # point in world space for collision
	#    normal: Vector2 # normal in world space for collision
	#    collider: Object # Object collided or null (if unassociated)
	#    collider_id: ObjectID # Object it collided against
	#    rid: RID # RID it collided against
	#    shape: int # shape index of collider
	#    metadata: Variant() # metadata of collider

func raycast_get_forward():
	var result_forward = space_state.intersect_ray(create_rays().ray_forward)

	if result_forward:
		return result_forward
	else: 
		return null

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
	if !raycast_get_collision():
		return

	if self.velocity.y >= 3:
		self.velocity.y -= gravity * delta * 5
	else:
		self.velocity.y -= gravity/3 * delta
	self.velocity += -raycast_get_collision().normal * delta

func get_move_speed():
	if Input.is_action_pressed('sprint') and !Input.is_action_pressed('crouch'):
		return sprint_speed
	elif Input.is_action_pressed('crouch') or ceiling.is_colliding():
		return crouch_speed
	else: 
		return walk_speed

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
	var control = max(self.velocity.length(), ground_decel)
	var drop = control * ground_friction/5 * delta
	var new_speed = max(self.velocity.length() - drop, 0.0)
	if self.velocity.length() > 0:
		new_speed /= self.velocity.length()
	self.velocity *= new_speed

func wall_jump() -> void:
	if raycast_get_collision():
		self.velocity += raycast_get_collision().normal * wall_jump_side_force + self.global_transform.basis.y * wall_jump_up_force

func jump():
	self.velocity.y += jump_velocity

func ledge_grab():
	self.velocity.y += 5

func set_state(new_state):
	var previous_state = current_state
	current_state = new_state

	if new_state == States.SLIDING:
		self.velocity += wish_dir * slide_impulse
	
	if previous_state == States.WALLJUMPING or (new_state == States.FALLING and previous_state == States.WALLRUNNING):
		previous_wall_jump_position = self.position.y
		wall_count += 1

	if previous_state == States.SLIDING:
		can_slide = false
		await get_tree().create_timer(slide_cooldown).timeout
		can_slide = true

	if current_state == States.LEDGEGRABBING:
		can_ledge_grab = false
		await get_tree().create_timer(ledge_grab_cooldown).timeout
		can_ledge_grab = true


	return previous_state

func _physics_process(delta: float) -> void:
	space_state = get_world_3d().direct_space_state
	input_dir = Input.get_vector('input_left', 'input_right', 'input_back', 'input_forward').normalized()
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0, -input_dir.y)

	## State Machine
	match (current_state):
		States.RUNNING:
			if Input.is_action_just_pressed('jump'):
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

			if ceiling.is_colliding():
				current_state = States.CROUCHING

			if Input.is_action_just_released('sprint'):
				current_state = States.WALKING
		States.WALKING:
			if Input.is_action_just_pressed('jump'):
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

			if ceiling.is_colliding():
				current_state = States.CROUCHING
			
			if Input.is_action_pressed('sprint'):
				current_state = States.RUNNING
		States.JUMPING:
			current_state = States.FALLING
		States.FALLING:
			if is_on_floor():
				current_state = States.RUNNING
			elif raycast_get_collision() and can_wall_run:
				current_state = States.WALLRUNNING

			if raycast_get_forward() and Input.is_action_just_pressed('jump') and can_ledge_grab:
				current_state = States.LEDGEGRABBING
		States.WALLRUNNING:
			if Input.is_action_just_pressed('jump'): #and !wish_dir.normalized().dot(raycast_get_collision().normal) <= 0.6:
				current_state = States.WALLJUMPING
			elif !raycast_get_collision() or Input.is_action_just_pressed('crouch') or is_on_floor() or wish_dir.normalized().dot(raycast_get_collision().normal) >= 0.9:
				current_state = States.FALLING
		States.WALLJUMPING:
			current_state = States.FALLING
		States.CROUCHING:
			if not is_on_floor():
				current_state = States.FALLING
			elif !Input.is_action_pressed('crouch') and !ceiling.is_colliding():
				current_state = States.RUNNING
		States.SLIDING:
			if !Input.is_action_pressed('crouch'):
				current_state = States.RUNNING
			elif self.velocity.length() <= 0.1:
				current_state = States.CROUCHING
			elif not is_on_floor():
				current_state = States.FALLING
		States.LEDGEGRABBING:
			if is_on_floor():
				current_state = States.RUNNING
			else:
				print(camera.rotation.z)
				current_state = States.FALLING

	## Movement
	if current_state in [States.RUNNING, States.CROUCHING, States.WALKING]:
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
	elif current_state == States.LEDGEGRABBING:
		ledge_grab()

	## Camera Movement
	if current_state in [States.WALLJUMPING, States.FALLING, States.WALKING, States.RUNNING]: 
		camera.position.y = lerp(camera.position.y, 0.0, lerp_speed * delta)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, lerp_speed * delta)
	elif current_state == States.CROUCHING:
		camera.rotation.z = lerp(camera.rotation.z, 0.0, lerp_speed * delta)
		camera.position.y = lerp(camera.position.y, -0.5, lerp_speed * delta * 1.5)
	elif current_state == States.WALLRUNNING:
		camera.position.y = lerp(camera.position.y, 0.0, lerp_speed * delta)
		var target_pos = 0.2
		if left.is_colliding():
			camera.rotation.z = lerp(camera.rotation.z, -target_pos, delta * lerp_speed)
		elif right.is_colliding():
			camera.rotation.z = lerp(camera.rotation.z, target_pos, delta * lerp_speed)
	elif current_state == States.SLIDING:
		camera.rotation.z = lerp(camera.rotation.z, 0.0, lerp_speed * delta)
		camera.position.y = lerp(camera.position.y, -0.9, lerp_speed * delta * 2)
	elif current_state == States.LEDGEGRABBING:
		camera.rotation.z = lerp(camera.rotation.z, 0.2, delta * lerp_speed * 3)

	## Collider Setting
	if current_state in [States.RUNNING, States.WALLJUMPING, States.FALLING, States.WALLRUNNING, States.JUMPING]:
		standing_collider.disabled = false
		crouching_collider.disabled = true
	else:
		standing_collider.disabled = true
		crouching_collider.disabled = false

	move_and_slide()
