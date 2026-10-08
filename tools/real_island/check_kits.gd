extends SceneTree
# Acceptance of the detail kits (checklist by Codex):
#   godot --headless --path . --script res://tools/real_island/check_kits.gd -- <baseline.scn> <kits.scn>
# - the grid: cells that changed blocked state, and whether each lies within
#   1 cell of an OSM house footprint (a Buildings/House_* node);
# - Buildings/ holds only house bodies, lighthouse and the like;
# - route legs equal to the baseline's.

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var a: HandmadeIsland = (load(args[0]) as PackedScene).instantiate()
	var b: HandmadeIsland = (load(args[1]) as PackedScene).instantiate()
	root.add_child(a)
	root.add_child(b)
	var pa: Array[String] = []
	var pb: Array[String] = []
	var ma: IslandMap = a.build_map(pa)
	var mb: IslandMap = b.build_map(pb)
	var fail: bool = false
	if not pb.is_empty():
		print("TEST FAIL: problems ", pb)
		fail = true
	# Footprints of the kit's houses, grown by one cell, from their boxes.
	var near := PackedByteArray()
	var n: int = mb.field.width
	near.resize(n * n)
	for h: Node in b.get_node("Buildings").get_children():
		print("  Buildings/", h.name, " children ", h.get_child_count())
		var box: AABB = AABB()
		var first: bool = true
		for mi: MeshInstance3D in h.find_children("*", "MeshInstance3D", true, false) + ([h] if h is MeshInstance3D else []):
			var bb: AABB = mi.global_transform * mi.get_aabb()
			box = bb if first else box.merge(bb)
			first = false
		for z in range(int(box.position.z) - 1, int(box.end.z) + 2):
			for x in range(int(box.position.x) - 1, int(box.end.x) + 2):
				if x >= 0 and z >= 0 and x < n and z < n:
					near[z * n + x] = 1
	var more: int = 0
	var less: int = 0
	var stray: int = 0
	for i in n * n:
		var ba: int = ma.field.blocked[i]
		var bb: int = mb.field.blocked[i]
		if ba == bb:
			continue
		if bb > ba:
			more += 1
		else:
			less += 1
		if near[i] == 0:
			stray += 1
			if stray <= 10:
				print("  changed far from any house: (%d, %d) %d -> %d" % [i % n, i / n, ba, bb])
	print("TEST: grid cells newly blocked %d, newly open %d, away from houses %d" % [more, less, stray])
	if stray > 0:
		print("TEST FAIL: grid changed away from the house footprints")
		fail = true
	for m: IslandMap in [ma, mb]:
		m.field.max_distance = 0
		var stops: Array[Vector3] = [m.player_start]
		stops.append_array(m.generators)
		stops.append(m.boat)
		var legs: PackedInt32Array = []
		for k in stops.size() - 1:
			m.field.compute_now(m.field.world_to_cell(stops[k + 1]))
			legs.append(m.field.distance_at(stops[k]))
		m.set_meta("legs", legs)
	print("TEST: legs baseline %s, kits %s" % [ma.get_meta("legs"), mb.get_meta("legs")])
	if ma.get_meta("legs") != mb.get_meta("legs"):
		print("TEST FAIL: route changed")
		fail = true
	print("TEST: decor nodes ", b.get_node("Decor").get_child_count(), " (baseline ", a.get_node("Decor").get_child_count(), ")")
	print("TEST FAIL" if fail else "TEST: kits accepted")
	quit(1 if fail else 0)
