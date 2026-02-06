extends Sprite2D

var velocity: Vector2
var max_scale: float
var shirking = false
var max_speed = 20.0
var speed
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.scale = Vector2.ZERO
	self.position = Vector2.ZERO
	shirking = false
	speed = max_speed


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if not shirking:
		self.scale += Vector2.ONE * max_scale * delta * 10
		self.position += velocity * delta * speed
		speed -= max_speed * delta
		if self.scale.x >= max_scale:
			shirking = true
	else:
		self.scale -= Vector2.ONE * max_scale * delta * 3
		if self.scale.x <= 0 :
			# delete myself
			queue_free()
