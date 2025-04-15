extends Label

@export var damage_text: String = "0"
@export var color: Color = Color(1, 0, 0)  # Default red color
@export var duration: float = 1.0
@export var float_distance: float = 50.0  # How far to float up
@export var text_size: int = 24

func _ready():
    # Set initial properties
    self.text = damage_text
    add_theme_color_override("font_color", color)
    add_theme_font_size_override("font_size", text_size)
    
    # Create the animation
    var tween = create_tween()
    tween.set_parallel(true)
    
    # Float upward
    tween.tween_property(self, "position:y", position.y - float_distance, duration)
    
    # Fade out
    tween.tween_property(self, "modulate:a", 0.0, duration)
    
    # Wait for animation to complete and then free the node
    await tween.finished
    queue_free() 
