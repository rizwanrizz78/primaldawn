extends Node3D

func _ready() -> void:
	# 1. Environment (Sun)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 45, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var env = WorldEnvironment.new()
	# Default environment is usually handled by Godot editor, but in code:
	var environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var procedural_sky = ProceduralSkyMaterial.new()
	sky.sky_material = procedural_sky
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment = environment
	add_child(env)

	# 2. Player
	var player_script = load("res://scripts/Player.gd")
	var player = player_script.new()
	player.name = "Player"
	add_child(player)
	player.position.y = 10.0 # Start high to avoid falling through terrain immediately

	# 3. Chunk Manager
	var chunk_manager_script = load("res://scripts/ChunkManager.gd")
	var chunk_manager = Node3D.new()
	chunk_manager.set_script(chunk_manager_script)
	chunk_manager.name = "ChunkManager"
	add_child(chunk_manager)

	# Connect ChunkManager to Player
	chunk_manager.player = player

	# 4. UI Overlay
	var ui_script = load("res://scripts/UI_Overlay.gd")
	var ui = CanvasLayer.new()
	ui.set_script(ui_script)
	ui.name = "UI_Overlay"
	add_child(ui)

	ui.set_player(player)

	# 5. Mobs (Example: Spawn one wolf)
	# Since we don't have a mob manager yet, just spawn one near player
	var mob_script = load("res://scripts/MobAI.gd")
	var mob = CharacterBody3D.new()
	mob.set_script(mob_script)
	mob.name = "Wolf"
	add_child(mob)

	# Create a mesh for the mob so we can see it
	var mob_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1, 1, 2)
	mob_mesh.mesh = box
	mob.add_child(mob_mesh)

	mob.position = Vector3(10, 10, 10)
