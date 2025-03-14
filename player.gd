extends CharacterBody3D

# Movement variables
var base_speed = 5.0
var sprint_speed = 10.0
var speed = base_speed
var gravity = 9.8
var mouse_sensitivity = 0.002
var jump_velocity = 7.0
var max_jumps = 2
var jumps_left = max_jumps
var was_in_air = false

# Shooting variables
var bullet_scene = preload("res://bullet.tscn")
var can_shoot = true
var shoot_cooldown = 0.2
var muzzle_flash_duration = 0.1
@export var bullet_speed : float = 20.0
@export var max_magazine : int = 30
var current_magazine : int = max_magazine
@export var total_reserve_ammo : int = 90
var current_reserve : int = total_reserve_ammo
var can_reload = true
@export var reload_time : float = 2.0

# Audio variables
@export var base_walk_pitch : float = 1.2
@export var sprint_pitch : float = 1.5
@export var footstep_delay : float = 0.3
@export var footstep_volume : float = 0.0

# Health variables
@export var max_health : float = 100.0
var current_health : float = max_health

# UI references
@onready var health_bar = get_node("/root/Main/HUD/HealthBarContainer/HealthBar")
@onready var ammo_label = get_node("/root/Main/HUD/HealthBarContainer/AmmoLabel")
@onready var enemy = get_node("/root/Main/Enemy") # May not be needed with spawner

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if not $FootstepTimer:
		print("Error: FootstepTimer missing!")
		return
	$FootstepTimer.wait_time = footstep_delay
	$FootstepPlayer.volume_db = footstep_volume
	health_bar.max_value = max_health
	health_bar.value = current_health
	update_ammo_display()
	if enemy:
		enemy.player = self

func _input(event):
	if event is InputEventMouseMotion:
		$Head.rotate_y(-event.relative.x * mouse_sensitivity)
		$Head/Camera3D.rotate_x(-event.relative.y * mouse_sensitivity)
		$Head/Camera3D.rotation.x = clamp($Head/Camera3D.rotation.x, -1.5, 1.5)
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		take_damage(10.0)
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_R and can_reload and current_magazine < max_magazine:
		reload()

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
		was_in_air = true
		if $FootstepPlayer.playing:
			$FootstepPlayer.stop()
	else:
		if was_in_air:
			$ThudPlayer.play()
			was_in_air = false
		jumps_left = max_jumps
	
	if Input.is_action_just_pressed("ui_accept") and jumps_left > 0:
		velocity.y = jump_velocity
		if jumps_left == max_jumps:
			$GruntPlayer.play()
		else:
			$AirJumpPlayer.play()
		jumps_left -= 1
	
	if Input.is_key_pressed(KEY_SHIFT):
		speed = sprint_speed
		$FootstepPlayer.pitch_scale = sprint_pitch
	else:
		speed = base_speed
		$FootstepPlayer.pitch_scale = base_walk_pitch
	
	var input_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_A):
		input_dir.x = -1
	elif Input.is_key_pressed(KEY_D):
		input_dir.x = 1
	if Input.is_key_pressed(KEY_W):
		input_dir.z = -1
	elif Input.is_key_pressed(KEY_S):
		input_dir.z = 1
	
	if input_dir:
		input_dir = input_dir.normalized()
		var direction = ($Head.transform.basis * Vector3(input_dir.x, 0, input_dir.z)).normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		if is_on_floor() and $FootstepTimer.is_stopped() and not $FootstepPlayer.playing:
			$FootstepPlayer.volume_db = footstep_volume
			$FootstepPlayer.play()
			$FootstepTimer.start()
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		
		if $FootstepPlayer.playing:
			$FootstepPlayer.stop()
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_shoot and current_magazine > 0:
		shoot()
	
	move_and_slide()

func _on_footstep_timer_timeout():
	var input_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_A): input_dir.x = -1
	elif Input.is_key_pressed(KEY_D): input_dir.x = 1
	if Input.is_key_pressed(KEY_W): input_dir.z = -1
	elif Input.is_key_pressed(KEY_S): input_dir.z = 1
	
	if input_dir and is_on_floor() and not $FootstepPlayer.playing:
		$FootstepPlayer.volume_db = footstep_volume
		$FootstepPlayer.play()
		$FootstepTimer.start()

func shoot():
	can_shoot = false
	current_magazine -= 1
	update_ammo_display()
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	# Spawn at GunTip's global position
	bullet.global_transform.origin = $Head/Camera3D/Gun/GunTip.global_transform.origin
	# Set velocity along camera's forward direction
	bullet.velocity = -$Head/Camera3D.global_transform.basis.z * bullet_speed
	
	$Head/Camera3D/Gun/MuzzleFlash.visible = true
	$Head/Camera3D/Gun/GunshotPlayer.play()
	await get_tree().create_timer(muzzle_flash_duration).timeout
	$Head/Camera3D/Gun/MuzzleFlash.visible = false
	
	await get_tree().create_timer(shoot_cooldown - muzzle_flash_duration).timeout
	can_shoot = true

func take_damage(amount: float):
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	health_bar.value = current_health
	if current_health <= 0:
		die()

func reload():
	if current_reserve > 0:
		can_reload = false
		$Head/Camera3D/Gun/ReloadPlayer.play()
		await get_tree().create_timer(reload_time).timeout
		var ammo_needed = max_magazine - current_magazine
		var ammo_to_load = min(ammo_needed, current_reserve)
		current_magazine += ammo_to_load
		current_reserve -= ammo_to_load
		update_ammo_display()
		can_reload = true

func update_ammo_display():
	ammo_label.text = str(current_magazine) + "/" + str(current_reserve)
	
func die():
	get_tree().change_scene_to_file("res://GameOver.tscn") # Switch to Game Over scene
