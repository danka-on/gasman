extends Node

var player = null  # Will reference the parent player node

# Debug flag
var debug_pickup = true

func _ready():
    # Wait until the next frame to ensure player is set
    if debug_pickup:
        print("Pickup Component: Ready called")
    call_deferred("setup_pickup_area")

func setup_pickup_area():
    if not player:
        # If still no player reference, try to get it from parent
        player = get_parent()
        if debug_pickup:
            print("Pickup Component: Got player reference from parent: ", player != null)
        
    if player:
        var pickup_area = player.get_node_or_null("PickupArea")
        if pickup_area:
            # Ensure the area is properly set up
            pickup_area.collision_layer = 0  # Don't collide with anything
            pickup_area.collision_mask = 2   # Detect items on layer 2 (pickups)
            
            if debug_pickup:
                print("Pickup Component: Setting up pickup area collision: layer=", pickup_area.collision_layer, 
                      " mask=", pickup_area.collision_mask)
                
            # Connect signal if not already connected
            if not pickup_area.body_entered.is_connected(_on_pickup_area_body_entered):
                pickup_area.body_entered.connect(_on_pickup_area_body_entered)
                if debug_pickup:
                    print("Pickup Component: Connected body_entered signal")
            else:
                if debug_pickup:
                    print("Pickup Component: body_entered signal already connected")
        else:
            print("Error: PickupArea not found on player!")
    else:
        print("Error: No player reference in pickup component!")

func _on_pickup_area_body_entered(body):
    if debug_pickup:
        print("Pickup Component: Body entered pickup area: ", body.name, " groups: ", body.get_groups())
        
    if not player or not is_instance_valid(body):
        return
    
    # Check for health packs    
    if body.is_in_group("health_pack"):
        if debug_pickup:
            print("Pickup Component: Health pack detected")
        if player.has_method("take_damage"):
            var health_amount = body.get("health_amount") if body.has_method("get") else 25.0
            player.take_damage(-health_amount)  # Negative damage = healing
            if debug_pickup:
                print("Pickup Component: Applied healing: ", health_amount)
            
            # Return to pool instead of queue_free
            var object_pool = get_node_or_null("/root/ObjectPool")
            if object_pool:
                object_pool.return_object(body)
            else:
                body.queue_free()
    
    # Check for ammo packs
    elif body.is_in_group("ammo_pack"):
        if debug_pickup:
            print("Pickup Component: Ammo pack detected")
        if player.has_method("add_ammo"):
            var ammo_amount = body.get("ammo_amount") if body.has_method("get") else 30
            player.add_ammo(ammo_amount)
            if debug_pickup:
                print("Pickup Component: Added ammo: ", ammo_amount)
            
            # Return to pool instead of queue_free
            var object_pool = get_node_or_null("/root/ObjectPool")
            if object_pool:
                object_pool.return_object(body)
            else:
                body.queue_free()
    
    # Check for gas packs
    elif body.is_in_group("gas_pack"):
        if debug_pickup:
            print("Pickup Component: Gas pack detected")
        if player.has_method("add_gas"):
            var gas_amount = body.get("gas_amount") if body.has_method("get") else 30.0
            player.add_gas(gas_amount)
            if debug_pickup:
                print("Pickup Component: Added gas: ", gas_amount)
            
            # Return to pool instead of queue_free
            var object_pool = get_node_or_null("/root/ObjectPool")
            if object_pool:
                object_pool.return_object(body)
            else:
                body.queue_free()
