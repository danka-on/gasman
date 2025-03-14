extends Node3D

@export var enemy_scene : PackedScene = preload("res://Enemy.tscn")
@export var spawn_radius : float = 10.0 # Distance from origin to spawn
@onready var player = $Player
@onready var spawn_timer = $EnemySpawnTimer

func _ready():
	spawn_timer.wait_time = 1.0 # Spawn every 1 second
	spawn_timer.connect("timeout", _on_spawn_timer_timeout)
	spawn_timer.start() # Start timer immediately

func _on_spawn_timer_timeout():
	spawn_enemy() # Spawn an enemy every timeout (no limit)

func spawn_enemy():
	var enemy = enemy_scene.instantiate()
	add_child(enemy)
	# Random position within spawn_radius around origin
	var random_angle = randf() * 2 * PI
	var random_distance = randf_range(spawn_radius * 0.5, spawn_radius)
	var spawn_x = cos(random_angle) * random_distance
	var spawn_z = sin(random_angle) * random_distance
	enemy.global_transform.origin = Vector3(spawn_x, 0, spawn_z)
	enemy.player = player
