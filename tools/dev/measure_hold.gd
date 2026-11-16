extends SceneTree
## Dev tool: how the third-person soldier holds each gun (tools for RifleShoulderHold):
## per gun, the largest miss of the support palm on the gun's forearm and of the stock end
## on the shoulder pocket, sampled when the skeleton finishes each pose (as test_weapon_grips).
##   godot --headless --path . --script res://tools/dev/measure_hold.gd -- [scale inward down forward]

const PALM_LOCAL := Vector3(0.000000342, 0.07845914, -0.000000016)
var _f: int = 0
var _soldiers: Array = []
var _miss: Dictionary = {}


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() >= 4:
		SoldierModel.TP_GUN_SCALE = float(a[0])
	for id: StringName in WeaponModel.IDS:
		var s: SoldierModel = SoldierModel.create(&"recruit")
		root.add_child(s)
		s.set_weapon(id)
		var sh: Node = s.get("_shoulder")
		if a.size() >= 4:
			sh.set("inward", float(a[1]))
			sh.set("down", float(a[2]))
			sh.set("forward", float(a[3]))
		var sk: Skeleton3D = s.find_child("Skeleton3D", true, false)
		_miss[id] = [0.0, 0.0]
		sk.skeleton_updated.connect(func() -> void:
			var gun: WeaponModel = s.get("_gun_node")
			var tip: Node3D = s.get("_rifle_muzzle")
			var grip: Transform3D = tip.transform * Transform3D(Basis.IDENTITY, WeaponModel.GRIP_FROM_MUZZLE)
			var palm: Vector3 = sk.get_bone_global_pose(sk.find_bone("DEF-hand.L")) * PALM_LOCAL
			var target: Vector3 = sk.get_bone_global_pose(sk.find_bone("DEF-hand.R")) * grip * (gun.basis * (gun.support_point + Vector3(0, 0, float(s.get("_support").get("slide")))))
			var stock: float = float(sh.call("pocket", sk).distance_to(sh.call("butt", sk)))
			_miss[id] = [maxf(_miss[id][0], palm.distance_to(target)), maxf(_miss[id][1], stock)])
		_soldiers.append([id, s])


func _process(_d: float) -> bool:
	_f += 1
	for pair: Array in _soldiers:
		(pair[1] as SoldierModel).aim_pitch = deg_to_rad(15.0) * sin(float(_f) * 0.15)
		(pair[1] as SoldierModel).animate(1.0, 0.0, false, 1.0 / 60.0)
	if _f < 30:
		return false
	for id: StringName in _miss:
		print("%s support palm miss %.3f m (slid %.3f m), stock to pocket %.3f m" % [id, _miss[id][0], float(_soldiers[WeaponModel.IDS.find(id)][1].get("_support").get("slide")), _miss[id][1]])
	quit(0)
	return true
