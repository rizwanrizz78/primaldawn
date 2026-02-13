extends CharacterBody3D
class_name MobAI

enum State { IDLE, WANDER, CHASE, FLEE }

@export var movement_speed: float = 4.0
@export var detection_radius: float = 15.0
@export var flee_radius: float = 10.0
@export var aggressive: bool = true
@export var afraid_of_fire: bool = true
@export var pack_behavior: bool = false # Not fully implemented, placeholder for group logic

var state: State = State.IDLE
var target: Node3D = null
var wander_target: Vector3 = Vector3.ZERO
var state_timer: float = 0.0

# References
var nav_agent: NavigationAgent3D
var collision_shape: CollisionShape3D

func _ready() -> void:
	# Ensure collision shape
	if has_node("CollisionShape3D"):
		collision_shape = $CollisionShape3D
	else:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var capsule = CapsuleShape3D.new()
		capsule.radius = 0.5
		capsule.height = 1.0 # Wolf size approx
		collision_shape.shape = capsule
		add_child(collision_shape)

	# If no NavigationAgent3D, create one? Or just move directly.
	if has_node("NavigationAgent3D"):
		nav_agent = $NavigationAgent3D
	else:
		var agent = NavigationAgent3D.new()
		agent.name = "NavigationAgent3D"
		add_child(agent)
		nav_agent = agent

	# Find player once or periodically
	# For simplicity, search once. In real game, use Area3D or global manager.
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		target = players[0]

func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			velocity = Vector3.ZERO
		State.WANDER:
			move_towards_point(wander_target, delta)
		State.CHASE:
			if target:
				move_towards_point(target.global_position, delta)
		State.FLEE:
			if target:
				var flee_dir = (global_position - target.global_position).normalized()
				var flee_pos = global_position + flee_dir * 5.0
				move_towards_point(flee_pos, delta)

	move_and_slide()

func _process(delta: float) -> void:
	state_timer -= delta

	# State Transitions
	if target:
		var dist = global_position.distance_to(target.global_position)

		if dist < detection_radius:
			# Check for fire/light
			var player_safe = is_player_near_fire()

			if afraid_of_fire and player_safe:
				state = State.FLEE
			elif aggressive:
				state = State.CHASE
			else:
				# Neutral behavior
				if state != State.WANDER and state != State.IDLE:
					state = State.IDLE
		else:
			# Lost player
			if state == State.CHASE or state == State.FLEE:
				state = State.IDLE
				state_timer = 2.0

	# Idle/Wander logic
	if state == State.IDLE:
		if state_timer <= 0:
			# Pick random wander point
			var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			wander_target = global_position + random_dir * randf_range(5.0, 10.0)
			state = State.WANDER
			state_timer = randf_range(3.0, 6.0)

	elif state == State.WANDER:
		if global_position.distance_to(wander_target) < 1.0 or state_timer <= 0:
			state = State.IDLE
			state_timer = randf_range(2.0, 4.0)

func move_towards_point(point: Vector3, delta: float) -> void:
	# Simple movement without pathfinding for now, or use nav agent
	if nav_agent:
		nav_agent.target_position = point
		var next_pos = nav_agent.get_next_path_position()
		var dir = (next_pos - global_position).normalized()
		velocity.x = dir.x * movement_speed
		velocity.z = dir.z * movement_speed
	else:
		var dir = (point - global_position).normalized()
		velocity.x = dir.x * movement_speed
		velocity.z = dir.z * movement_speed

	# Face direction
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)

func is_player_near_fire() -> bool:
	if not target:
		return false

	# Check distance from player to any node in "LightSource" group
	var light_sources = get_tree().get_nodes_in_group("LightSource")
	for light in light_sources:
		if light is Node3D:
			if target.global_position.distance_to(light.global_position) < 5.0: # 5 meters safety radius
				return true
	return false
