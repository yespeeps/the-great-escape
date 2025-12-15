extends CenterContainer

@export var DOT_RADIUS := 1.0
@export var DOT_COLOR := Color.RED

func _ready() -> void:
	queue_redraw()

func _draw():
	draw_circle(Vector2(0,0),DOT_RADIUS,DOT_COLOR)
