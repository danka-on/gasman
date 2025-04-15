extends Node3D

@export var text: String = "0"
@export var color: Color = Color(1, 0, 0)  # Default red color
@export var duration: float = 1.0
@export var float_height: float = 2.0
@export var scale_start: float = 0.5
@export var scale_end: float = 1.0
@export var spawn_height_offset: float = 0.0  # Added exportable spawn height offset
@export var text_size: int = 32  # Added text size variable

@onready var label: Label3D = $Label3D
@onready var player = get_node("/root/Main/Player")  # Get reference to player

func _ready():
    # Set initial properties
    label.text = text
    label.modulate = color
    label.scale = Vector3(scale_start, scale_start, scale_start)
    label.font_size = text_size  # Apply the text size
    
    # Create the animation
    var tween = create_tween()
    tween.set_parallel(true)
    
    # Float upward from the spawn position
    tween.tween_property(self, "position:y", position.y + float_height, duration)
    
    # Scale up
    tween.tween_property(label, "scale", Vector3(scale_end, scale_end, scale_end), duration * 0.2)
    
    # Fade out
    tween.tween_property(label, "modulate:a", 0.0, duration)
    
    # Wait for animation to complete and then free the node
    await tween.finished
    queue_free() 

func _process(_delta):
    if is_instance_valid(player):
        # Get the player's camera
        var camera = player.get_node("Head/Camera3D")
        if is_instance_valid(camera):
            # Make the label look at the camera
            look_at(camera.global_transform.origin)
            # Rotate 180 degrees around Y axis to face the camera
            rotate_y(PI) 
