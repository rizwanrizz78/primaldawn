extends Node3D

@export var player: Node3D
@export var noise: FastNoiseLite
@export var chunk_material: Material

const CHUNK_SIZE: int = 32
const VIEW_DISTANCE: int = 4
const TERRAIN_HEIGHT: float = 20.0

var active_chunks: Dictionary = {} # Vector2i -> Node3D (TerrainChunk)
var pending_chunks: Dictionary = {} # Vector2i -> bool

var thread_pool: WorkerThreadPool

func _ready() -> void:
	if not noise:
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.02
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM

	if not chunk_material:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.5, 0.3) # Grass green
		chunk_material = mat

	# Just use the global singleton instance if available, but here we call functions directly
	# We don't instantiate WorkerThreadPool ourselves, it's a singleton in Godot 4
	pass

func _process(_delta: float) -> void:
	if not player:
		return

	var p_pos = player.global_position
	# Use floori to handle negative coordinates correctly
	var p_chunk_x = floori(p_pos.x / CHUNK_SIZE)
	var p_chunk_z = floori(p_pos.z / CHUNK_SIZE)
	var current_chunk_coord = Vector2i(p_chunk_x, p_chunk_z)

	# Identify chunks to load
	for x in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
		for z in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
			var chunk_coord = current_chunk_coord + Vector2i(x, z)
			if not active_chunks.has(chunk_coord) and not pending_chunks.has(chunk_coord):
				request_chunk_generation(chunk_coord)

	# Identify chunks to unload
	var chunks_to_remove = []
	for chunk_coord in active_chunks:
		var dist = chunk_coord - current_chunk_coord
		if abs(dist.x) > VIEW_DISTANCE or abs(dist.y) > VIEW_DISTANCE: # using .y for z component in Vector2i
			chunks_to_remove.append(chunk_coord)

	for chunk_coord in chunks_to_remove:
		unload_chunk(chunk_coord)

func request_chunk_generation(chunk_coord: Vector2i) -> void:
	pending_chunks[chunk_coord] = true
	WorkerThreadPool.add_task(Callable(self, "_generate_chunk_task").bind(chunk_coord))

func _generate_chunk_task(chunk_coord: Vector2i) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if chunk_material:
		st.set_material(chunk_material)

	# Create vertices for a grid
	for x in range(CHUNK_SIZE + 1):
		for z in range(CHUNK_SIZE + 1):
			var world_x = chunk_coord.x * CHUNK_SIZE + x
			var world_z = chunk_coord.y * CHUNK_SIZE + z # Vector2i uses x, y

			var height = noise.get_noise_2d(world_x, world_z) * TERRAIN_HEIGHT
			# Add UVs and normals as needed
			st.set_uv(Vector2(x, z))
			st.add_vertex(Vector3(x, height, z))

	# Generate indices
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var i = x * (CHUNK_SIZE + 1) + z
			# Triangle 1
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + CHUNK_SIZE + 1)
			# Triangle 2
			st.add_index(i + CHUNK_SIZE + 1)
			st.add_index(i + 1)
			st.add_index(i + CHUNK_SIZE + 2)

	st.generate_normals()
	var mesh = st.commit()

	# Create collision shape on thread to avoid lag spike on main thread
	var shape = mesh.create_trimesh_shape()

	# Send back to main thread
	call_deferred("_on_chunk_generated", chunk_coord, mesh, shape)

func _on_chunk_generated(chunk_coord: Vector2i, mesh: ArrayMesh, shape: Shape3D) -> void:
	if not pending_chunks.has(chunk_coord):
		return # Might have been cancelled or unloaded already?

	pending_chunks.erase(chunk_coord)

	var chunk_script = load("res://scripts/TerrainChunk.gd")
	var chunk_node = Node3D.new() # We can just instance a new Node3D and attach script, or instance scene
	chunk_node.set_script(chunk_script)
	chunk_node.name = "Chunk_%d_%d" % [chunk_coord.x, chunk_coord.y]

	add_child(chunk_node)
	chunk_node.position = Vector3(chunk_coord.x * CHUNK_SIZE, 0, chunk_coord.y * CHUNK_SIZE)
	chunk_node.set_mesh(mesh, shape)

	active_chunks[chunk_coord] = chunk_node

func unload_chunk(chunk_coord: Vector2i) -> void:
	if active_chunks.has(chunk_coord):
		var chunk_node = active_chunks[chunk_coord]
		chunk_node.queue_free()
		active_chunks.erase(chunk_coord)
