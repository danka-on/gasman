# pickup_component.gd - Updated version
extends Node

var player = null  # Will reference the parent player node

func _ready():
    # Attempt to get player reference directly first
    player = get_parent()
    if player:
        # Set up pickup area immediately if possible
        var pickup_area = player.get_node_or_null("PickupArea")
        if pickup_area:
            if not pickup_area.body_entered.is_connected(_on_pickup_area_body_entered):
                pickup_area.body_entered.connect(_on_pickup_area_body_entered)
        else:
            print("Warning: PickupArea not found on player")
    else:
        # Defer setup if parent isn't available yet
        print("Warning: No player reference in pickup component, deferring setup")
        call_deferred("setup_pickup_area")

func setup_pickup_area():
    if not player:
        # If still no player reference, try to get it from parent
        player = get_parent()
        
    if player:
        var pickup_area = player.get_node_or_null("PickupArea")
        if pickup_area:
            if not pickup_area.body_entered.is_connected(_on_pickup_area_body_entered):
                pickup_area.body_entered.connect(_on_pickup_area_body_entered)
        else:
            push_error("Error: PickupArea not found on player!")
    else:
        push_error("Error: No player reference in pickup component!")

func _on_pickup_area_body_entered(body):
    if not player or not is_instance_valid(body):
        return
        
    if body.is_in_group("health_pack") and body.has_method("health_amount"):
        player.take_damage(-body.health_amount)  # Negative damage = healing
        
        # Return to pool instead of queue_free
        var object_pool = get_node_or_null("/root/ObjectPool")
        if object_pool:
            object_pool.return_object(body)
        else:
            body.queue_free()
            
    elif body.is_in_group("ammo_pack") and body.has_method("ammo_amount"):
        player.add_ammo(body.ammo_amount)
        
        # Return to pool instead of queue_free
        var object_pool = get_node_or_null("/root/ObjectPool")
        if object_pool:
            object_pool.return_object(body)
        else:
            body.queue_free()
            
    elif body.is_in_group("gas_pack") and body.has_method("gas_amount"):
        player.add_gas(body.gas_amount)
        
        # Return to pool instead of queue_free
        var object_pool = get_node_or_null("/root/ObjectPool")
        if object_pool:
            object_pool.return_object(body)
        else:
            body.queue_free()
