extends Area3D

# Damage properties
@export_group("Damage")
@export var damage_per_tick: float = 5.0
@export var damage_interval: float = 0.5

# Cloud properties
@export_group("Cloud")
@export var lifetime: float = 3.0
@export var fade_out_time: float = 0.5
@export var cloud_size: float = 2.0
@export var particle_amount: int = 50
@export var particle_scale_min: float = 2.0
@export var particle_scale_max: float = 3.0
@export var cloud_color: Color = Color(0.0, 0.8, 0.0, 0.3)
@export var emission_strength: float = 0.5
@export var preserve_scene_visuals: bool = true

var enemies_in_cloud: Array = []
var current_lifetime: float = 0.0
var is_fading_out: bool = false

func _ready():
    # Debug print
    print("Gas cloud created! Looking for enemies...")
    
    # Update cloud size
    $CollisionShape3D.shape.radius = cloud_size
    
    # Create unique materials for this instance to prevent shared fading
    var particle_material = $GPUParticles3D.process_material.duplicate()
    $GPUParticles3D.process_material = particle_material
    
    var mesh = $GPUParticles3D.draw_pass_1.duplicate()
    var mesh_material = mesh.material.duplicate()
    mesh.material = mesh_material
    $GPUParticles3D.draw_pass_1 = mesh
    
    # Only override visual properties if preserve_scene_visuals is false
    if not preserve_scene_visuals:
        # Update particle properties
        $GPUParticles3D.amount = particle_amount
        particle_material.emission_sphere_radius = cloud_size
        particle_material.scale_min = particle_scale_min
        particle_material.scale_max = particle_scale_max
        particle_material.color = cloud_color
        
        # Update visual properties
        mesh_material.albedo_color = cloud_color
        mesh_material.emission = Color(cloud_color.r, cloud_color.g, cloud_color.b, 1.0)
        mesh_material.emission_energy_multiplier = emission_strength
    
    # Store original scene material colors for fading
    var original_alpha = mesh_material.albedo_color.a
    var original_emission = mesh_material.emission_energy_multiplier
    
    # Start the damage timer
    $DamageTimer.wait_time = damage_interval
    $DamageTimer.start()
    
    # Try to find any enemies already in the area
    scan_for_enemies()

func _process(delta):
    # Handle cloud lifetime
    if not is_fading_out:
        current_lifetime += delta
        if current_lifetime >= lifetime:
            start_fade_out()

func scan_for_enemies():
    # Try to find all enemies in the scene that are in range
    var overlapping_bodies = get_overlapping_bodies()
    for body in overlapping_bodies:
        if body.is_in_group("enemy"):
            if not enemies_in_cloud.has(body):
                print("Enemy found in gas cloud:", body.name)
                enemies_in_cloud.append(body)

func start_fade_out():
    is_fading_out = true
    
    # Get this cloud's unique material
    var mesh_material = $GPUParticles3D.draw_pass_1.material
    
    # Create weak reference to self to prevent crashes if freed early
    var self_ref = weakref(self)
    
    # Fade out effect with unique material
    var tween = create_tween()
    tween.tween_property(mesh_material, "albedo_color:a", 0.0, fade_out_time)
    tween.parallel().tween_property(mesh_material, "emission_energy_multiplier", 0.0, fade_out_time)
    
    # Safe callback that checks if object still exists
    tween.tween_callback(func():
        if self_ref.get_ref():
            queue_free()
    )

func _on_body_entered(body):
    if body.is_in_group("enemy"):
        print("Enemy entered gas cloud:", body.name)
        if not enemies_in_cloud.has(body):
            enemies_in_cloud.append(body)

func _on_body_exited(body):
    if enemies_in_cloud.has(body):
        enemies_in_cloud.erase(body)

func _on_damage_timer_timeout():
    # Scan for enemies on every tick to ensure we find them
    scan_for_enemies()
    
    # Apply damage to all enemies in the cloud
    for enemy in enemies_in_cloud:
        if is_instance_valid(enemy):
            print("Damaging enemy:", enemy.name, " Amount:", damage_per_tick)
            enemy.take_damage(damage_per_tick) 
