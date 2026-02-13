extends CanvasLayer

var player_node: Node = null

# UI Elements
var health_bar: ProgressBar
var temp_bar: ProgressBar
var protein_bar: ProgressBar
var carbs_bar: ProgressBar
var hydration_bar: ProgressBar

# Joystick
var joystick_base: Control
var joystick_knob: Control
var joystick_index: int = -1
var joystick_center: Vector2 = Vector2.ZERO
const JOYSTICK_RADIUS: float = 64.0

func _ready() -> void:
	# Create UI structure
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let touches pass through if needed
	add_child(root)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = Vector2(200, 150)
	root.add_child(vbox)

	health_bar = create_bar(vbox, Color.RED, "Health")
	temp_bar = create_bar(vbox, Color.ORANGE, "Temp")
	protein_bar = create_bar(vbox, Color.GREEN, "Protein")
	carbs_bar = create_bar(vbox, Color.YELLOW, "Carbs")
	hydration_bar = create_bar(vbox, Color.BLUE, "Water")

	# Joystick Setup
	joystick_base = Control.new()
	joystick_base.name = "JoystickBase"
	joystick_base.position = Vector2(150, 600) # Bottom left approximation
	joystick_base.size = Vector2(128, 128)

	# Visual for joystick base
	var base_rect = ColorRect.new()
	base_rect.color = Color(1, 1, 1, 0.3)
	base_rect.size = Vector2(128, 128)
	base_rect.position = Vector2(-64, -64)
	joystick_base.add_child(base_rect)

	joystick_knob = Control.new()
	joystick_knob.name = "JoystickKnob"
	var knob_rect = ColorRect.new()
	knob_rect.color = Color(1, 1, 1, 0.8)
	knob_rect.size = Vector2(64, 64)
	knob_rect.position = Vector2(-32, -32)
	joystick_knob.add_child(knob_rect)

	joystick_base.add_child(joystick_knob)
	root.add_child(joystick_base)

	joystick_center = joystick_base.position

func create_bar(parent: Node, color: Color, label_text: String) -> ProgressBar:
	var label = Label.new()
	label.text = label_text
	parent.add_child(label)

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 20)
	bar.modulate = color
	bar.value = 100
	parent.add_child(bar)
	return bar

func _process(delta: float) -> void:
	if player_node:
		health_bar.value = player_node.health
		temp_bar.value = player_node.temperature

		if player_node.nutrition:
			protein_bar.value = player_node.nutrition["proteins"]
			carbs_bar.value = player_node.nutrition["carbs"]
			hydration_bar.value = player_node.nutrition["hydration"]

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			# Check if touch is near joystick center
			if joystick_index == -1 and event.position.distance_to(joystick_center) < JOYSTICK_RADIUS * 2:
				joystick_index = event.index
		else:
			if event.index == joystick_index:
				joystick_index = -1
				joystick_knob.position = Vector2.ZERO
				if player_node and player_node.has_method("set_movement_input"):
					player_node.set_movement_input(Vector2.ZERO)

	elif event is InputEventScreenDrag:
		if event.index == joystick_index:
			var diff = event.position - joystick_center
			if diff.length() > JOYSTICK_RADIUS:
				diff = diff.normalized() * JOYSTICK_RADIUS

			joystick_knob.position = diff

			var input_vector = diff / JOYSTICK_RADIUS
			# Invert Y for 3D Z
			if player_node and player_node.has_method("set_movement_input"):
				player_node.set_movement_input(input_vector)

func set_player(player: Node) -> void:
	player_node = player
