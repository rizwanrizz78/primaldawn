extends Node3D
class_name TerrainChunk

var mesh_instance: MeshInstance3D
var collision_body: StaticBody3D
var collision_shape: CollisionShape3D

func _ready() -> void:
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)

	collision_body = StaticBody3D.new()
	add_child(collision_body)

	collision_shape = CollisionShape3D.new()
	collision_body.add_child(collision_shape)

func set_mesh(mesh: ArrayMesh, shape: Shape3D = null) -> void:
	mesh_instance.mesh = mesh

	if shape:
		collision_shape.shape = shape
	else:
		# Fallback if shape not provided
		collision_shape.shape = mesh.create_trimesh_shape()
