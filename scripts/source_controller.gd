extends CharacterBody3D
@onready var world_model = $WorldModel
@onready var camera = $Head/Camera3D

@export var look_sens : float = 0.006
@export var jump_velocity := 6.0
@export var auto_bhop := 6.0

# Air movement settings. Need to tweak these to get the feeling dialed in.
@export var air_cap := 0.85 # Can surf steeper ramps if this is higher, makes it easier to stick and bhop
@export var air_accel := 800.0
@export var air_move_speed := 500.0

# Ground movement settings
@export var walk_speed := 7
@export var sprint_speed := 8.5
@export var ground_accel := 14.0
@export var ground_decel := 10.0
@export var ground_friction := 6.0

@export var health := 100.0
@export var max_health := 100.0
const headbob_move_amount = 0.06
const headbob_move_frequency = 2.4
var headbob_time = 0.0

var wish_dir := Vector3.ZERO

var gravity = ProjectSettings.get_setting('physics/3d/default_gravity')

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

func wall_run():
	self.velocity.y = self.velocity.y/3.5
	if Input.is_action_just_released('jump'):
		print('yeahyeah')
		self.velocity.y += 50

func wall_rays(): # and feet
	var space_state = get_world_3d().direct_space_state

	var ray_distance = 1.5
	var feet_distance = 50
	var origin = self.position

	var end_left = self.position.x - ray_distance
	var end_right = self.position.x + ray_distance
	var end_feet = self.position.y - feet_distance

	var ray_left = PhysicsRayQueryParameters3D.create(origin, Vector3(end_left, self.position.y, self.position.z))
	var ray_right = PhysicsRayQueryParameters3D.create(origin, Vector3(end_right, self.position.y, self.position.z))
	var ray_feet =  PhysicsRayQueryParameters3D.create(origin, Vector3(self.position.x, end_feet, self.position.z))

	var result_left = space_state.intersect_ray(ray_left)
	var result_right = space_state.intersect_ray(ray_right)
	var result_feet = space_state.intersect_ray(ray_feet)

	return {
		"left": result_left,
		"right": result_right,
		"feet": result_feet
	}

func get_move_speed() -> float:
	return sprint_speed if Input.is_action_pressed('sprint') else walk_speed

func _handle_air_physics(delta : float) -> void:
	if wall_rays() and not wall_rays().feet and Input.is_action_pressed('jump'):
		if wall_rays().left or wall_rays().right:
			wall_run()
			return

	self.velocity.y -= gravity * delta

	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	var capped_speed = min((air_move_speed * wish_dir).length(), air_cap)

	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = air_accel * air_move_speed * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir

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

	_headbob_effect(delta)

func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector('input_left', 'input_right', 'input_back', 'input_forward').normalized()

	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0, -input_dir.y)

	if is_on_floor():
		if Input.is_action_just_pressed('jump') or (auto_bhop and Input.is_action_pressed('jump')):
			self.velocity.y += jump_velocity
		_handle_ground_physics(delta)
	else:
		_handle_air_physics(delta)

	move_and_slide()



	

# func _process(delta: float) -> void:
