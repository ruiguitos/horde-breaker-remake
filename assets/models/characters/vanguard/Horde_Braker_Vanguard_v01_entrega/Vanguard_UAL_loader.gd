extends Node
## Attach to the imported Vanguard scene. No bone mapping by hand is required.
## The external .tres was generated from the supplied UAL for this rig's rest offsets.
@export var animation_library: AnimationLibrary
@export var skeleton_path: NodePath
@export var use_rifle_hold: bool = false
var player: AnimationPlayer

func _ready() -> void:
	var skeleton: Skeleton3D = get_node_or_null(skeleton_path) as Skeleton3D
	if skeleton == null:
		skeleton = _find_skeleton(self)
	if skeleton == null:
		skeleton = _find_skeleton(get_parent())
	if skeleton == null or animation_library == null:
		push_error("Vanguard: assign Vanguard_UAL_compatible.tres; Skeleton3D not found or library missing.")
		return
	player = AnimationPlayer.new()
	player.name = "VanguardAnimationPlayer"
	skeleton.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library(&"UAL", animation_library)
	player.play("UAL/Idle_Loop")
	if use_rifle_hold:
		var hold := SkeletonModifier3D.new()
		hold.set_script(load(get_script().resource_path.get_base_dir().path_join("Vanguard_Rifle_Hold.gd")))
		hold.set("pose_file", get_script().resource_path.get_base_dir().path_join("Vanguard_Rifle_Hold_pose.json"))
		skeleton.add_child(hold)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func play_ual(clip: StringName) -> void:
	if player:
		player.play("UAL/" + str(clip), 0.15)
