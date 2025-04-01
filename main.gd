extends Node3D

@export var enemy_scene : PackedScene = preload("res://Enemy.tscn")
@export var spawn_radius : float = 10.0
@onready var player = $Player
@onready var spawn_timer = $EnemySpawnTimer
@onready var enemy_count_label = $HUD/HealthBarContainer/EnemyCountLabel
var enemy_count = 0

func _ready():
    spawn_timer.wait_time = 1.0
    spawn_timer.connect("timeout", _on_spawn_timer_timeout)
    spawn_timer.start()

func _on_spawn_timer_timeout():
    if enemy_count < 50:
        spawn_enemy()
        
func update_enemy_count():
    enemy_count_label.text = "Enemies: " + str(enemy_count)

func _on_enemy_died():
    enemy_count -= 1
    update_enemy_count()

func spawn_enemy():
    var enemy = enemy_scene.instantiate()
    add_child(enemy)
    var random_angle = randf() * 2 * PI
    var random_distance = randf_range(spawn_radius * 0.5, spawn_radius)
    var spawn_x = cos(random_angle) * random_distance
    var spawn_z = sin(random_angle) * random_distance
    enemy.global_transform.origin = Vector3(spawn_x, 1.5, spawn_z)
    enemy.player = player
    enemy_count += 1
    enemy.connect("tree_exited", _on_enemy_died)
    update_enemy_count()
