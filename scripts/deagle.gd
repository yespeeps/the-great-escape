extends Node3D
signal Shot()

var player : Player
@onready var audiostreamplayer = $AudioStreamPlayer3D
@onready var anim = $AnimationPlayer

const RAY_LENGTH = 99999
const damage = 33.4

func _ready() -> void:
	player = owner

func get_collision():
	var cam = player.camera
	var mousepos = player.get_viewport().get_size()/2

	var origin = cam.project_ray_origin(mousepos)
	var end = origin + cam.project_ray_normal(mousepos) * RAY_LENGTH

	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result

func shoot():
	var mousepos = player.get_viewport().get_mouse_position()
	var collider : Object = get_collision().collider
	if collider is RigidBody3D:
		collider.apply_impulse(player.camera.project_ray_normal(mousepos) * 15, get_collision().normal)

	if collider.is_in_group('enemies'):
		collider.health -= damage
		print(collider.health)
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed('shoot'):
		if anim.is_playing():
			anim.stop()
		anim.play('shoot')
		audiostreamplayer.play()

		if get_collision():
			shoot()
