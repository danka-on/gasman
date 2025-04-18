extends Node3D

class_name PoolableExplosion

var _lifetime_timer: SceneTreeTimer = null

func _ready():
	reset()

## Reset the explosion for reuse from the pool
func reset():
	# Reset visual effects
	if has_node("Blast"):
		$Blast.emitting = true
	
	# Play sound effect
	if has_node("BoomSound"):
		$BoomSound.play()
	
	# Cancel any existing lifetime timer
	if _lifetime_timer != null and _lifetime_timer.time_left > 0:
		_lifetime_timer.timeout.disconnect(_on_lifetime_timeout)
	
	# Start a new lifetime timer
	# Use 0.7 seconds to match effect lifetime + buffer
	_lifetime_timer = get_tree().create_timer(0.7)
	_lifetime_timer.timeout.connect(_on_lifetime_timeout)

func _on_lifetime_timeout():
	# Return to pool instead of queue_free
	if PoolManager.instance != null:
		PoolManager.instance.release_object(self)
	else:
		queue_free() 