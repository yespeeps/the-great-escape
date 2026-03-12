#TODO: Change collision checks to only be raycasts (maybe)
class_name Player extends CharacterBody3D
@onready var world_model = $WorldModel
@onready var camera = $Head/Camera3D
@onready var standing_collider = $StandingCollider
@onready var crouching_collider = $CrouchingCollider
@onready var stream_player = $Head/Camera3D/ViewModel/Deagle/AudioStreamPlayer3D
@onready var aim_ray = $Head/Camera3D/AimRay
@onready var head = $Head

@onready var ceiling = $ceiling
var left_ray 
var right_ray
@onready var exit_timer = $"Exit Timer"

@export var look_sens : float = 0.002
@export var jump_velocity := 6.0
@export var auto_bhop := false

# Air movement settings. Need to tweak these to get the feeling dialed in.
@export var air_cap := 0.45 # Can surf steeper ramps if this is higher, makes it easier to stick and bhop
@export var air_accel := 20.0
@export var air_move_speed := 10.0

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
var slide_cooldown := 0.0
var slide_impulse := 1.5

var can_wall_run := true
var wall_run_cooldown := 0.1

var can_ledge_grab := true
var ledge_grab_cooldown := 1.0

var can_dive = true

const head_bobbing_sprinting_speed = 22.0
const head_bobbing_walking_speed = 14.0
const head_bobbing_crouching_speed = 10.0

const head_bobbing_crouching_intensity = 0.1
const head_bobbing_sprinting_intensity = 0.2
const head_bobbing_walking_intensity = 0.05

var head_bobbing_vector := Vector2.ZERO
var head_bobbing_index := 0.0
var head_bobbing_current_intensity

var previous_wall
var wall_count : int 
var space_state : PhysicsDirectSpaceState3D

enum States {RUNNING, CROUCHING, JUMPING, FALLING, WALLRUNNING, WALLJUMPING, SLIDING, LEDGEGRABBING, WALKING, DIVING, INITIAL_DIVE}
var current_state : States:
	set = set_state

func _ready() -> void:
	for child : VisualInstance3D in world_model.find_children('*', 'VisualInstance3D'):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)

	create_rays()

func create_rays():
	var origin = position
	var distance = 0.8

	var ray_left = PhysicsRayQueryParameters3D.create(origin, origin - distance * global_basis.x)
	var ray_right = PhysicsRayQueryParameters3D.create(origin, origin + distance * global_basis.x)
	var ray_forward = PhysicsRayQueryParameters3D.create(Vector3(origin.x, origin.y + 0.4, origin.z), origin + distance * -global_basis.z) 
	var ray_down = PhysicsRayQueryParameters3D.create(origin, origin - 0.1 * global_basis.y)

	return {
		'ray_left': ray_left,
		'ray_right': ray_right,
		'ray_forward': ray_forward,
		'ray_down': ray_down
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
		left_ray = result_left
		right_ray = null
		return result_left
	elif result_right:
		right_ray = result_right
		left_ray = null
		return result_right

	# This is the dictionary that it will return.
	#    position: Vector2 # point in world space for collision
	#    normal: Vector2 # normal in world space for collision
	#    collider: Object # Object collided or null (if unassociated)
	#    collider_id: ObjectID # Object it collided against
	#    rid: RID # RID it collided against
	#    shape: int # shape index of collider
	#    metadata: Variant() # metadata of collider

func raycast_get_down():
	var result_down = space_state.intersect_ray(create_rays().ray_down)
	if result_down:
		return result_down
	else:
		return null

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

	if raycast_get_down():
		var n = raycast_get_down().normal
		var slope_angle = (rad_to_deg(acos(n.dot(Vector3(0,-1,0)))) -180)*-1
		if slope_angle > 39:
			var slide_dir = n.slide(Vector3(0,-1,0))
			velocity += slide_dir
			velocity.y -= slope_angle

			var control = max(self.velocity.length(), ground_decel)
			var drop = control * ground_friction/5 * delta
			var new_speed = max(self.velocity.length() - drop, 0.0)
			if self.velocity.length() > 0:
				new_speed /= self.velocity.length()
			self.velocity *= new_speed

			# self.rotation.y = atan2(slide_dir.x,slide_dir.y+slide_dir.z)
			# self.rotation.x = deg_to_rad(slope_angle)
		else:
			var control = max(self.velocity.length(), ground_decel)
			var drop = control * ground_friction/5 * delta
			var new_speed = max(self.velocity.length() - drop, 0.0)
			if self.velocity.length() > 0:
				new_speed /= self.velocity.length()
			self.velocity *= new_speed
	else:
		var control = max(self.velocity.length(), ground_decel)
		var drop = control * ground_friction/5 * delta
		var new_speed = max(self.velocity.length() - drop, 0.0)
		if self.velocity.length() > 0:
			new_speed /= self.velocity.length()
		self.velocity *= new_speed

func _handle_dive_physics(delta: float):
	velocity.y -= gravity * 1.5 * delta

func dive():
	var previous_velocity_magnitude = velocity.length()
	var previous_vertical_velocity = velocity.y

	if previous_vertical_velocity > 0:
		velocity.y = 0
	else:
		velocity.y /= 2

	var dive_vertical_impulse = 3.0
	var dive_horizontal_impulse = 15
	var dive_cap = 30.0

	if previous_velocity_magnitude < dive_cap:
		velocity += (Vector3(velocity.x, 0, velocity.z).normalized() + wish_dir)/2 * dive_horizontal_impulse

	if velocity.y > 0:
		velocity.y += dive_vertical_impulse
	elif velocity.y < dive_vertical_impulse / 2:
		velocity.y += dive_vertical_impulse * 2


func wall_jump() -> void:
	if raycast_get_collision():
		if raycast_get_collision().normal:
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
		wall_count += 1
		can_wall_run = false
		await get_tree().create_timer(wall_run_cooldown).timeout
		can_wall_run = true

	if previous_state == States.SLIDING:
		can_slide = false
		await get_tree().create_timer(slide_cooldown).timeout
		can_slide = true

	if current_state == States.LEDGEGRABBING:
		can_ledge_grab = false
		await get_tree().create_timer(ledge_grab_cooldown).timeout
		can_ledge_grab = true

	if new_state == States.RUNNING:
		can_dive = true

	if new_state == States.DIVING: 
		can_dive = false
	
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
		States.JUMPING:
			current_state = States.FALLING
		States.FALLING:
			if is_on_floor():
				current_state = States.RUNNING
			elif raycast_get_collision() and can_wall_run:
				current_state = States.WALLRUNNING
			elif Input.is_action_just_pressed('crouch') and can_dive:
				current_state = States.INITIAL_DIVE

			# if raycast_get_forward() and Input.is_action_just_pressed('jump') and can_ledge_grab:
			# 	current_state = States.LEDGEGRABBING
		States.WALLRUNNING:
			if Input.is_action_just_pressed('jump'):
				if raycast_get_collision():
					if !wish_dir.normalized().dot(raycast_get_collision().normal) <= -0.2:
						current_state = States.WALLJUMPING
			elif !raycast_get_collision() or is_on_floor(): #or wish_dir.normalized().dot(raycast_get_collision().normal) >= 0.9:
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
		States.INITIAL_DIVE:
			current_state = States.DIVING
		States.DIVING:
			if is_on_floor():
				current_state = States.RUNNING
			elif raycast_get_collision() and can_wall_run:
				current_state = States.WALLRUNNING

	## movement
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
	elif current_state == States.INITIAL_DIVE:
		dive()
	elif current_state == States.DIVING:
		_handle_dive_physics(delta)

	## headbob
	if get_move_speed() == sprint_speed:
		head_bobbing_current_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_sprinting_speed * delta
	elif get_move_speed() == walk_speed:
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
	else:
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed * delta

	## camera movement
	if !(current_state in [States.WALLRUNNING, States.LEDGEGRABBING]):
		camera.rotation.z = lerp(camera.rotation.z, 0.0, lerp_speed * delta)
	if !(current_state in [States.CROUCHING, States.SLIDING]):
		camera.position.y = lerp(camera.position.y, 0.0, lerp_speed * delta)

	if current_state == States.WALLRUNNING:
		var target_pos = 0.2
		# raycast_get_collision()
		if left_ray:
			camera.rotation.z = lerp(camera.rotation.z, -target_pos, delta * lerp_speed)
		elif right_ray:
			camera.rotation.z = lerp(camera.rotation.z, target_pos, delta * lerp_speed)
	elif current_state == States.SLIDING:
		camera.position.y = lerp(camera.position.y, -0.9, lerp_speed * delta * 2)
	elif current_state == States.CROUCHING:
		camera.position.y = lerp(camera.position.y, -0.5, lerp_speed * delta * 1.5)
	elif current_state == States.LEDGEGRABBING:
		camera.rotation.z = lerp(camera.rotation.z, 0.2, delta * lerp_speed * 3)

	if current_state in [States.RUNNING] and input_dir: 
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index/2) + 0.5

		camera.position.y = lerp(camera.position.y, head_bobbing_vector.y*(head_bobbing_current_intensity/2.0), delta * lerp_speed)
		camera.position.x = lerp(camera.position.x, head_bobbing_vector.x*(head_bobbing_current_intensity), delta * lerp_speed)

		if Input.is_action_pressed('input_left'):
			camera.rotation.z = lerp(camera.rotation.z, +0.05, delta * lerp_speed/4)
		elif Input.is_action_pressed('input_right'):
			camera.rotation.z = lerp(camera.rotation.z, -0.05, delta * lerp_speed/4)
	
	## collider setting
	if current_state in [States.RUNNING, States.WALLJUMPING, States.FALLING, States.WALLRUNNING, States.JUMPING]:
		standing_collider.disabled = false
		crouching_collider.disabled = true
	else:
		standing_collider.disabled = true
		crouching_collider.disabled = false
	
	## animations

	move_and_slide()
