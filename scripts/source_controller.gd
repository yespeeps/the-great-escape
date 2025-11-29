#TODO: Add exiting wall state so walljumping is not interrupted, wallrun timer
class_name Player extends CharacterBody3D
@onready var world_model = $WorldModel
@onready var camera = $Head/Camera3D
@onready var standing_collider = $StandingCollider
@onready var crouching_collider = $CrouchingCollider

@onready var right = $WorldModel/right
@onready var left = $WorldModel/left
@onready var exit_timer = $"Exit Timer"

@export var look_sens : float = 0.006
@export var jump_velocity := 6.0
@export var auto_bhop := true

# Air movement settings. Need to tweak these to get the feeling dialed in.
@export var air_cap := 0.85 # Can surf steeper ramps if this is higher, makes it easier to stick and bhop
@export var air_accel := 800.0
@export var air_move_speed := 500.0

@export var wall_jump_up_force := 700
@export var wall_jump_side_force := 1200
@export var wall_run_boost := 2.0
@export var wall_run_side_speed := 7.0

# Ground movement settings
@export var walk_speed := 7
@export var sprint_speed := 8.5
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

var gravity = ProjectSettings.get_setting('physics/3d/default_gravity')

var ray_left : PhysicsRayQueryParameters3D
var ray_right : PhysicsRayQueryParameters3D
var ray_down : PhysicsRayQueryParameters3D

var can_wall_action := true 
var can_gravity : bool
var wall_running : bool
var crouching := false

func _ready() -> void:
	for child : VisualInstance3D in world_model.find_children('*', 'VisualInstance3D'):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)

	ray_left = PhysicsRayQueryParameters3D.new()
	ray_right = PhysicsRayQueryParameters3D.new()
	ray_down = PhysicsRayQueryParameters3D.new()

	ray_left.collide_with_areas = true
	ray_left.collide_with_bodies = true

	ray_right.collide_with_areas = true
	ray_right.collide_with_bodies = true

	ray_down.collide_with_bodies = true
	ray_down.collide_with_bodies = true
				
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
	return sprint_speed if Input.is_action_pressed('sprint') else walk_speed

func update_rays():
	var origin = global_transform.origin

	ray_left.from = origin
	ray_left.to = origin + Vector3(-0.6, 0, 0)

	ray_right.from = origin
	ray_right.to = origin + Vector3(0.6, 0, 0)

	ray_down.from = origin
	ray_down.to = origin + Vector3(0, -0.6, 0)

func get_collision_x_normal():
	var space = get_world_3d().direct_space_state
	update_rays()

	var result_left = space.intersect_ray(ray_left)
	var result_right = space.intersect_ray(ray_right)

	if result_left:
		return result_left.normal
	elif result_right:
		return result_right.normal
	return null

func get_collision_down():
	var space = get_world_3d().direct_space_state
	var result_down = space.intersect_ray(ray_down)

	if result_down:
		return result_down
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
	self.velocity.y -= gravity/2 * delta
	self.velocity.x += wish_dir.x * wall_run_side_speed * delta

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

func _on_exit_timer_timeout() -> void:
	can_wall_action = true

func _physics_process(_delta: float) -> void:
	input_dir = Input.get_vector('input_left', 'input_right', 'input_back', 'input_forward').normalized()
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0, -input_dir.y)

	if Input.is_action_pressed("crouch"):
		camera.position.y = -0.5
		standing_collider.disabled = true
		crouching_collider.disabled = false
	else:
		crouching_collider.disabled = true
		standing_collider.disabled = false
		camera.position.y = 0
	move_and_slide()



	
