extends Node3D
var player : Player
@onready var audiostreamplayer = $AudioStreamPlayer3D

func _ready() -> void:
	player = owner

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed('shoot'):
		audiostreamplayer.play()
		
