extends Node3D

@export var player: Node3D
@export var noise: FastNoiseLite
@export var chunk_material: Material

const CHUNK_SIZE: int = 32
const VIEW_DISTANCE: int = 4
const TERRAIN_HEIGHT: float = 40.0 # Increased from 20.0 for more depth

var active_chunks: Dictionary = {} # Vector2i -> Node3D (TerrainChunk)
var pending_chunks: Dictionary = {} # Vector2i -> bool

# We don't instantiate WorkerThreadPool ourselves, it's a singleton in Godot 4
var thread_pool: WorkerThreadPool

func _ready() -> void:
	if not noise:
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.015 # Slightly lower frequency for larger hills
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM

	if not chunk_material:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.5, 0.3) # Grass green
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		chunk_material = mat

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

func get_height_at(x: float, z: float) -> float:
	if not noise:
		return 0.0
	return noise.get_noise_2d(x, z) * TERRAIN_HEIGHT

func request_chunk_generation(chunk_coord: Vector2i) -> void:
	pending_chunks[chunk_coord] = true
	WorkerThreadPool.add_task(Callable(self, "_generate_chunk_task").bind(chunk_coord))

func _generate_chunk_task(chunk_coord: Vector2i) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if chunk_material:
		st.set_material(chunk_material)

	# Store heights for skirt generation
	# Grid size is CHUNK_SIZE+1 vertices wide
	var grid_width = CHUNK_SIZE + 1
	var heights = PackedFloat32Array()
	heights.resize(grid_width * grid_width)

	# 1. Create Main Grid Vertices
	for x in range(grid_width):
		for z in range(grid_width):
			var world_x = chunk_coord.x * CHUNK_SIZE + x
			var world_z = chunk_coord.y * CHUNK_SIZE + z

			var height = noise.get_noise_2d(world_x, world_z) * TERRAIN_HEIGHT
			heights[x * grid_width + z] = height

			st.set_uv(Vector2(x, z))
			st.add_vertex(Vector3(x, height, z))

	# 2. Generate Grid Indices
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var i = x * grid_width + z
			# Triangle 1
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + grid_width)
			# Triangle 2
			st.add_index(i + grid_width)
			st.add_index(i + 1)
			st.add_index(i + grid_width + 1)

	# 3. Generate Skirts (Vertical walls at edges)
	var skirt_depth = 15.0

	# Helper to add quad
	var add_skirt_quad = func(v1: Vector3, v2: Vector3):
		# We add 4 new vertices for each quad to ensure hard edges (normals)
		# v1 and v2 are top vertices. We extend them down.
		var v3 = v2 - Vector3(0, skirt_depth, 0)
		var v4 = v1 - Vector3(0, skirt_depth, 0)

		# UVs don't matter much for skirts in this simple style
		var base_idx = st.get_vertex_count()

		st.add_vertex(v1)
		st.add_vertex(v2)
		st.add_vertex(v3)
		st.add_vertex(v4)

		st.add_index(base_idx)
		st.add_index(base_idx + 1)
		st.add_index(base_idx + 2)

		st.add_index(base_idx)
		st.add_index(base_idx + 2)
		st.add_index(base_idx + 3)

	# Edge x=0 (Left)
	for z in range(CHUNK_SIZE):
		var h1 = heights[0 * grid_width + z]
		var h2 = heights[0 * grid_width + (z + 1)]
		# Winding order: we want outside facing out.
		# For x=0, normal points -x.
		# Top edge: (0, h1, z) -> (0, h2, z+1).
		# To face -x, winding should be clockwise if looking from -x?
		# Verts: TopFar(z+1), TopNear(z), BottomNear(z), BottomFar(z+1)
		add_skirt_quad.call(Vector3(0, h2, z+1), Vector3(0, h1, z))

	# Edge x=CHUNK_SIZE (Right)
	for z in range(CHUNK_SIZE):
		var h1 = heights[CHUNK_SIZE * grid_width + z]
		var h2 = heights[CHUNK_SIZE * grid_width + (z + 1)]
		# Normal points +x.
		add_skirt_quad.call(Vector3(CHUNK_SIZE, h1, z), Vector3(CHUNK_SIZE, h2, z+1))

	# Edge z=0 (Top)
	for x in range(CHUNK_SIZE):
		var h1 = heights[x * grid_width + 0]
		var h2 = heights[(x + 1) * grid_width + 0]
		# Normal points -z.
		add_skirt_quad.call(Vector3(x, h1, 0), Vector3(x+1, h2, 0))

	# Edge z=CHUNK_SIZE (Bottom)
	for x in range(CHUNK_SIZE):
		var h1 = heights[x * grid_width + CHUNK_SIZE]
		var h2 = heights[(x + 1) * grid_width + CHUNK_SIZE]
		# Normal points +z.
		add_skirt_quad.call(Vector3(x+1, h2, CHUNK_SIZE), Vector3(x, h1, CHUNK_SIZE))

	st.generate_normals()
	var mesh = st.commit()

	# Create collision shape on thread
	# Note: Collision shape usually doesn't need skirts, but for safety it's fine.
	var shape = mesh.create_trimesh_shape()

	# Send back to main thread
	call_deferred("_on_chunk_generated", chunk_coord, mesh, shape)

func _on_chunk_generated(chunk_coord: Vector2i, mesh: ArrayMesh, shape: Shape3D) -> void:
	if not pending_chunks.has(chunk_coord):
		return # Might have been cancelled or unloaded already?

	pending_chunks.erase(chunk_coord)

	var chunk_script = load("res://scripts/TerrainChunk.gd")
	var chunk_node = Node3D.new()
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
