extends Node

# Melee attack parameters
@export var attack_range : float = 8.0  # Range of the melee attack (increased from 2.0)
@export var attack_angle : float = 90.0  # Angle of the attack cone in degrees (increased from 60.0)
@export var attack_damage : float = 20.0  # Damage dealt by the attack
@export var knockback_force : float = 5.0  # Force applied to hit targets
@export var attack_cooldown : float = 0.5  # Time between attacks in seconds

# Debug visualization
@export var show_debug_visuals : bool = true
var debug_mesh : MeshInstance3D

var can_attack : bool = true
var attack_timer : float = 0.0

# Reference to the player node
var player : Node3D

func _ready():
    # Get the player node (parent)
    player = get_parent()
    if not player:
        push_error("MeleeSystem: Parent node is not set. Please attach this script to a player node.")
    print("Melee system initialized with player: ", player)
    
    # Create debug visualization if enabled
    if show_debug_visuals:
        create_debug_visualization()

func create_debug_visualization():
    # Create a cylinder to visualize the attack cone
    var cylinder = CylinderMesh.new()
    cylinder.top_radius = 0.1
    cylinder.bottom_radius = attack_range * tan(deg_to_rad(attack_angle/2.0))
    cylinder.height = attack_range
    
    debug_mesh = MeshInstance3D.new()
    debug_mesh.mesh = cylinder
    debug_mesh.material_override = StandardMaterial3D.new()
    debug_mesh.material_override.albedo_color = Color(1, 0, 0, 0.3)  # Semi-transparent red
    debug_mesh.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    
    # Position the cone in front of the player
    debug_mesh.position = Vector3(0, 0, -attack_range/2.0)
    debug_mesh.rotation.x = PI/2.0  # Rotate to point forward
    
    add_child(debug_mesh)

func _process(delta):
    if not can_attack:
        attack_timer -= delta
        if attack_timer <= 0:
            can_attack = true
    
    # Update debug visualization if enabled
    if show_debug_visuals and debug_mesh:
        # Update the mesh's transform to match the camera's current position and rotation
        debug_mesh.global_transform = player.get_node("Head/Camera3D").global_transform
        debug_mesh.translate(Vector3(0, 0, -attack_range/2.0))
        debug_mesh.visible = true

func perform_attack():
    if not can_attack:
        return false
    
    can_attack = false
    attack_timer = attack_cooldown
    
    # Get all bodies in the scene
    var bodies = get_tree().get_nodes_in_group("enemy")
    print("Found potential targets: ", bodies.size())
    
    var hit_targets = []
    
    # Convert attack angle to radians for calculation
    var half_angle_rad = deg_to_rad(attack_angle) / 2.0
    
    # Get camera's forward direction
    var camera = player.get_node("Head/Camera3D")
    var player_forward = -camera.global_transform.basis.z.normalized()
    print("Camera forward direction: ", player_forward)
    print("Camera rotation (degrees): ", camera.rotation_degrees)
    
    for body in bodies:
        if body == player:
            continue
            
        # Calculate direction to target
        var direction_to_target = (body.global_position - camera.global_position).normalized()
        
        # Calculate angle between forward direction and direction to target
        var angle_rad = acos(player_forward.dot(direction_to_target))
        
        # Check if target is within attack range and angle
        var distance = camera.global_position.distance_to(body.global_position)
        print("Checking target at distance: ", distance, " and angle (degrees): ", rad_to_deg(angle_rad), " (max allowed: ", attack_angle/2.0, ")")
        
        if distance <= attack_range and angle_rad <= half_angle_rad:
            hit_targets.append(body)
            print("Target hit!")
    
    # Apply damage and knockback to hit targets
    for target in hit_targets:
        # Apply damage if target has a health system
        if target.has_method("take_damage"):
            target.take_damage(attack_damage)
            print("Applied damage to target")
        
        # Apply knockback
        var knockback_direction = (target.global_position - camera.global_position).normalized()
        if target.has_method("apply_knockback"):
            target.apply_knockback(knockback_direction * knockback_force)
            print("Applied knockback to target")
    
    return true 
