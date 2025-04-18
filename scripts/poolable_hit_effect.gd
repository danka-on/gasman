extends Node3D

class_name PoolableHitEffect

var _lifetime_timer: SceneTreeTimer = null

func _ready():
	reset()

## Reset the hit effect for reuse from the pool
func reset():
	# Reset transform
	transform = Transform3D.IDENTITY
	
	# Ensure visibility
	visible = true
	
	# Reset visual effects
	if has_node("Sparks"):
		var sparks = $Sparks
		# Reset emitter state
		sparks.emitting = false
		# Restart emission
		sparks.restart()
		sparks.emitting = true
	
	# Cancel any existing lifetime timer
	if _lifetime_timer != null and _lifetime_timer.time_left > 0:
		if _lifetime_timer.timeout.is_connected(_on_lifetime_timeout):
			_lifetime_timer.timeout.disconnect(_on_lifetime_timeout)
	
	# Start a new lifetime timer
	# Use 0.7 seconds to match effect lifetime
	_lifetime_timer = get_tree().create_timer(0.7)
	_lifetime_timer.timeout.connect(_on_lifetime_timeout)

func _on_lifetime_timeout():
	# Return to pool instead of queue_free
	if PoolManager.instance != null:
		PoolManager.instance.release_object(self)
	else:
		queue_free() 