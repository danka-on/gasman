extends Control

@export var default_color: Color = Color(1, 1, 1, 1)  # White
@export var hit_color: Color = Color(1, 0, 0, 1)  # Red
@export var hit_duration: float = 0.2  # Duration of hit feedback
@export var explosion_scale: float = 2.0  # Scale multiplier for explosions

@onready var regular_cross = $RegularCross
@onready var diagonal_cross = $DiagonalCross

var default_scale: Vector2
var is_hit: bool = false
var hit_timer: float = 0.0

func _ready():
    default_scale = regular_cross.scale
    set_color(default_color)
    diagonal_cross.hide()

func _process(delta):
    if is_hit:
        hit_timer -= delta
        if hit_timer <= 0:
            reset_crosshair()

func set_color(color: Color):
    # Set color for regular cross
    for child in regular_cross.get_children():
        if child is ColorRect:
            child.color = color
    
    # Set color for rotated cross
    for child in diagonal_cross.get_children():
        if child is ColorRect:
            child.color = color

func on_hit(is_headshot: bool = false, is_explosion: bool = false):
    is_hit = true
    hit_timer = hit_duration
    set_color(hit_color)
    
    if is_headshot or is_explosion:
        diagonal_cross.show()  # Show rotated cross for 8-point star pattern
        
        if is_explosion:
            # Scale up both crosses for explosion
            var explosion_size = default_scale * explosion_scale
            regular_cross.scale = explosion_size
            diagonal_cross.scale = explosion_size
        else:
            # Reset scale for headshot
            regular_cross.scale = default_scale
            diagonal_cross.scale = default_scale
    else:
        # Normal hit, just show regular cross
        diagonal_cross.hide()
        regular_cross.scale = default_scale

func reset_crosshair():
    is_hit = false
    set_color(default_color)
    diagonal_cross.hide()
    regular_cross.scale = default_scale
    diagonal_cross.scale = default_scale 