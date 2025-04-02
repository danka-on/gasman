extends Node

var player = null  # Will reference the parent player node

func _ready():
    # Wait until the next frame to ensure player is set
    call_deferred("setup_pickup_area")

func setup_pickup_area():
    if not player:
        # If still no player reference, try to get it from parent
        player = get_parent()
        
    if player:
        var pickup_area = player.get_node_or_null("PickupArea")
        if pickup_area:
            pickup_area.body_entered.connect(_on_pickup_area_body_entered)
        else:
            print("Error: PickupArea not found on player!")
    else:
        print("Error: No player reference in pickup component!")

func _on_pickup_area_body_entered(body):
    if not player:
        return
        
    if body.is_in_group("health_pack"):
        player.take_damage(-body.health_amount)  # Negative damage = healing
        body.queue_free()
    elif body.is_in_group("ammo_pack"):
        player.add_ammo(body.ammo_amount)
        body.queue_free()
    elif body.is_in_group("gas_pack"):
        player.add_gas(body.gas_amount)
        body.queue_free()
