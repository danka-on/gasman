extends Control

@onready var center = $Center
@onready var horizontal = $Horizontal
@onready var vertical = $Vertical

var default_color = Color(1, 1, 1, 1)  # White
var hit_color = Color(1, 0, 0, 1)      # Red
var hit_duration = 0.2                  # How long the crosshair stays red

func _ready():
    # Set initial color
    set_color(default_color)

func set_color(color: Color):
    center.color = color
    horizontal.color = color
    vertical.color = color

func on_hit():
    # Change color to red
    set_color(hit_color)
    
    # Create a timer to return to default color
    var timer = get_tree().create_timer(hit_duration)
    timer.timeout.connect(func():
        set_color(default_color)
    ) 