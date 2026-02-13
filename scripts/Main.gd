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

	# 2. Chunk Manager (Create first to get height)
	var chunk_manager_script = load("res://scripts/ChunkManager.gd")
	var chunk_manager = Node3D.new()
	chunk_manager.set_script(chunk_manager_script)
	chunk_manager.name = "ChunkManager"
	add_child(chunk_manager)

	# 3. Player
	# Get terrain height at spawn (0,0)
	var spawn_height = chunk_manager.get_height_at(0, 0)

	var player_script = load("res://scripts/Player.gd")
	var player = player_script.new()
	player.name = "Player"
	add_child(player)
	player.position = Vector3(0, spawn_height + 5.0, 0) # Spawn 5m above ground to ensure chunk loads

	# Connect ChunkManager to Player
	chunk_manager.player = player

	# 4. UI Overlay
	var ui_script = load("res://scripts/UI_Overlay.gd")
	var ui = CanvasLayer.new()
	ui.set_script(ui_script)
	ui.name = "UI_Overlay"
	add_child(ui)

	ui.set_player(player)

	# 5. Mobs (Spawn one wolf)
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

	# Spawn mob near player but on ground
	var mob_spawn_x = 10.0
	var mob_spawn_z = 10.0
	var mob_spawn_h = chunk_manager.get_height_at(mob_spawn_x, mob_spawn_z)
	mob.position = Vector3(mob_spawn_x, mob_spawn_h + 1.0, mob_spawn_z)
