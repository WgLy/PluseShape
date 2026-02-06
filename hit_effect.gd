extends Node2D

@onready var circle_particle = $circle_particle
var circle_particle_list: Array[Sprite2D] = []
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in  range(10):
		generate_circle_particle()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
		

func generate_circle_particle() -> void:
	var circle = circle_particle.duplicate()
	circle.visible = true
	circle.velocity = get_random_direction() * randf_range(3.0, 15.0)
	circle.position = Vector2.ZERO
	circle.max_scale = randf_range(0.01, 0.1)
	add_child(circle)

func get_random_direction() -> Vector2:
	# TAU is a constant equal to 2 * PI radians (a full 360 degrees)
	var random_angle = randf_range(0, TAU)
	
	# Vector2.RIGHT (1, 0) is a unit vector that we rotate by the random angle
	var random_dir = Vector2.RIGHT.rotated(random_angle)
	
	return random_dir
