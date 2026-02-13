extends CharacterBody3D

# --- Movement Settings ---
const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.005

# --- Bio-System Stats ---
var health: float = 100.0
var max_health: float = 100.0
var temperature: float = 20.0 # Body temperature
var nutrition: Dictionary = {
	"proteins": 100.0,
	"carbs": 100.0,
	"hydration": 100.0
}
const MAX_NUTRITION: float = 100.0

# --- Survival Logic ---
var last_eaten_item: String = ""
var consecutive_eaten_count: int = 0
var hunger_rate: float = 1.0 # Base rate

# --- Input State ---
var touch_look_sensitivity: float = 0.2
var move_input: Vector2 = Vector2.ZERO
var look_input: Vector2 = Vector2.ZERO

# --- Nodes ---
var camera_pivot: Node3D
var camera: Camera3D
var collision_shape: CollisionShape3D

func _ready() -> void:
	# Ensure collision shape
	if has_node("CollisionShape3D"):
		collision_shape = $CollisionShape3D
	else:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var capsule = CapsuleShape3D.new()
		collision_shape.shape = capsule
		add_child(collision_shape)

	# Ensure camera setup
	if has_node("CameraPivot"):
		camera_pivot = $CameraPivot
	else:
		camera_pivot = Node3D.new()
		camera_pivot.name = "CameraPivot"
		add_child(camera_pivot)
		camera_pivot.position.y = 1.7 # Eye height

	if camera_pivot.has_node("Camera3D"):
		camera = camera_pivot.get_node("Camera3D")
	else:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera_pivot.add_child(camera)

func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
		velocity.y -= gravity * delta

	# Handle Jump (Mobile jump button needed, or double tap? Let's assume a button for now, or just auto-jump)
	# Since UI is not fully defined for buttons, we stick to movement.

	# Get the input direction and handle the movement/deceleration.
	var direction = (transform.basis * Vector3(move_input.x, 0, move_input.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	# Reset look input for next frame (since it's delta based from touch drag)
	# Actually for touch drag, we apply rotation immediately in _input, so no need to poll here.

func _process(delta: float) -> void:
	update_bio_system(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		# Right side of screen for look
		var viewport_size = get_viewport().size
		if event.position.x > viewport_size.x / 2:
			rotate_y(-event.relative.x * SENSITIVITY)
			camera_pivot.rotate_x(-event.relative.y * SENSITIVITY)
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func set_movement_input(input: Vector2) -> void:
	move_input = input

# --- Bio-System Logic ---
func update_bio_system(delta: float) -> void:
	# ambient temperature calculation
	var ambient_temp = get_ambient_temperature()

	# Body temp adjust towards ambient
	# If ambient is low, body temp drops unless active/clothed (not implemented)
	# Simplified: move towards ambient
	temperature = move_toward(temperature, ambient_temp, delta * 0.1)

	# Hunger rate based on temperature (shivering burns more)
	var current_hunger_rate = hunger_rate
	if temperature < 10.0:
		current_hunger_rate *= 1.5 # Shivering

	# Decrease nutrition
	nutrition["proteins"] -= 0.5 * current_hunger_rate * delta
	nutrition["carbs"] -= 0.8 * current_hunger_rate * delta # Carbs burn faster
	nutrition["hydration"] -= 1.0 * current_hunger_rate * delta

	# Health effects
	if temperature > 40.0: # Heatstroke
		health -= 2.0 * delta
	elif temperature < 0.0: # Hypothermia
		health -= 2.0 * delta

	if nutrition["hydration"] <= 0:
		health -= 1.0 * delta
	if nutrition["proteins"] <= 0 or nutrition["carbs"] <= 0:
		health -= 0.5 * delta

	# Clamp values
	health = clamp(health, 0, max_health)
	nutrition["proteins"] = clamp(nutrition["proteins"], 0, MAX_NUTRITION)
	nutrition["carbs"] = clamp(nutrition["carbs"], 0, MAX_NUTRITION)
	nutrition["hydration"] = clamp(nutrition["hydration"], 0, MAX_NUTRITION)

func get_ambient_temperature() -> float:
	# Calculate based on time of day and biome
	# Global.time, Global.is_night()
	var base_temp = 20.0
	if Global.is_night():
		base_temp -= 10.0
	return base_temp

func eat(item_id: String, created_timestamp: float) -> void:
	if not Global.item_db.has(item_id):
		return

	var item_data = Global.item_db[item_id]
	var nutrition_values = item_data.get("nutrition")

	if nutrition_values == null:
		return # Not food

	# Check spoilage
	if Global.check_spoilage(item_id, created_timestamp):
		# Rotten food logic
		print("Ate rotten food!")
		nutrition["hydration"] -= 20.0
		health -= 10.0
		return

	# Diminishing Returns Logic
	var multiplier = 1.0
	if item_id == last_eaten_item:
		consecutive_eaten_count += 1
		if consecutive_eaten_count >= 3:
			multiplier = 0.5
			print("Palate fatigue: Nutrition halved.")
	else:
		last_eaten_item = item_id
		consecutive_eaten_count = 1

	# Apply nutrition
	nutrition["proteins"] += nutrition_values.get("proteins", 0.0) * multiplier
	nutrition["carbs"] += nutrition_values.get("carbs", 0.0) * multiplier
	nutrition["hydration"] += nutrition_values.get("hydration", 0.0) * multiplier

	print("Ate ", item_data["name"], ". Stats: ", nutrition)
