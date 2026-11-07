extends Node3D
## The Little Bookshop - Sprint 0 prototype
## Mot can phong isometric 3D: xoay/keo/phong to camera, cham chon ke sach,
## mot khach di toi ke roi toi quay, bam "Ban sach" de nhan tien.

const ROOM := 8.0
const SELL_PRICE := 15
const DOOR_POS := Vector3(2.5, 0.0, 3.4)
const COUNTER_FRONT := Vector3(-1.5, 0.0, 1.7)

var coins := 0
var pivot: Node3D
var cam: Camera3D
var target_yaw := 45.0
var walls := []      # moi phan tu: [MeshInstance3D, Vector3 huong mat tuong]
var shelves := []
var selected = null
var customer: Node3D = null
var customer_waiting := false

var touches := {}
var drag_dist := 0.0
var pinch_start_dist := 0.0
var pinch_start_size := 12.0

var coins_label: Label
var fps_label: Label
var info_label: Label
var sell_button: Button


func _ready() -> void:
	_build_environment()
	_build_room()
	_build_camera()
	_build_ui()
	_spawn_customer()


# ---------- Dung canh ----------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(size: Vector3, pos: Vector3, c: Color, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2b2420")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffe2b8")
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffd59e")
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	sun.shadow_enabled = false
	add_child(sun)


func _build_room() -> void:
	var h := ROOM / 2.0
	_box(Vector3(ROOM, 0.2, ROOM), Vector3(0.0, -0.1, 0.0), Color("8a5a3b"), self)
	_box(Vector3(3.0, 0.02, 2.0), Vector3(0.5, 0.01, 0.3), Color("7d2f2f"), self)
	_add_wall(Vector3(0.0, 1.5, -h), Vector3(ROOM, 3.0, 0.2), Vector3(0, 0, -1))
	_add_wall(Vector3(-h, 1.5, 0.0), Vector3(0.2, 3.0, ROOM), Vector3(-1, 0, 0))
	_add_wall(Vector3(0.0, 1.5, h), Vector3(ROOM, 3.0, 0.2), Vector3(0, 0, 1))
	_add_wall(Vector3(h, 1.5, 0.0), Vector3(0.2, 3.0, ROOM), Vector3(1, 0, 0))
	var door := _box(Vector3(1.2, 2.2, 0.1), Vector3(DOOR_POS.x, 1.1, h - 0.12), Color("4e7a5a"), self)
	walls.append([door, Vector3(0, 0, 1)])

	_add_shelf(Vector3(-2.3, 0.0, -3.4), 0.0, "Kệ Tiểu thuyết", Color("c0392b"))
	_add_shelf(Vector3(0.6, 0.0, -3.4), 0.0, "Kệ Trinh thám", Color("34495e"))
	_add_shelf(Vector3(-3.4, 0.0, -0.6), 90.0, "Kệ Lịch sử", Color("b9770e"))

	# Quay thu ngan + may tinh tien
	_box(Vector3(2.0, 1.0, 0.8), Vector3(-1.5, 0.5, 2.6), Color("6e4a2f"), self)
	_box(Vector3(0.4, 0.3, 0.3), Vector3(-1.0, 1.15, 2.6), Color("d4ac0d"), self)
	# Ghe doc sach va chau cay
	_box(Vector3(0.8, 0.5, 0.8), Vector3(2.6, 0.25, -2.6), Color("a04000"), self)
	_box(Vector3(0.8, 0.6, 0.15), Vector3(2.6, 0.8, -2.95), Color("a04000"), self)
	_box(Vector3(0.4, 0.9, 0.4), Vector3(3.3, 0.45, -3.3), Color("2e7d32"), self)


func _add_wall(pos: Vector3, size: Vector3, normal: Vector3) -> void:
	var w := _box(size, pos, Color("e8d8b8"), self)
	walls.append([w, normal])


func _add_shelf(pos: Vector3, yaw: float, label: String, book_color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees.y = yaw
	add_child(body)
	var wood := Color("7b4a2a")
	_box(Vector3(2.0, 2.2, 0.15), Vector3(0.0, 1.1, -0.2), wood, body)
	_box(Vector3(0.1, 2.2, 0.5), Vector3(-1.0, 1.1, 0.0), wood, body)
	_box(Vector3(0.1, 2.2, 0.5), Vector3(1.0, 1.1, 0.0), wood, body)
	for row in 4:
		_box(Vector3(2.0, 0.06, 0.5), Vector3(0.0, 0.1 + row * 0.65, 0.0), wood, body)
	for row in 3:
		var y := 0.13 + row * 0.65 + 0.225
		for i in 6:
			var c := book_color.lightened(randf_range(0.0, 0.35))
			_box(Vector3(0.22, 0.45, 0.36), Vector3(-0.7 + i * 0.27, y, 0.02), c, body)
	var marker := _box(Vector3(2.2, 0.03, 0.9), Vector3(0.0, 0.02, 0.7), Color("f4d03f"), body)
	marker.visible = false
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2.2, 0.8)
	col.shape = shape
	col.position = Vector3(0.0, 1.1, 0.1)
	body.add_child(col)
	body.set_meta("label", label)
	body.set_meta("marker", marker)
	body.set_meta("front", pos + Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(yaw)))
	shelves.append(body)


func _build_camera() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	pivot.rotation_degrees.y = target_yaw
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 12.0
	cam.near = 0.1
	cam.far = 100.0
	cam.position = Vector3(0.0, 14.14, 20.0)
	cam.rotation_degrees.x = -35.264
	pivot.add_child(cam)
	cam.current = true


# ---------- Giao dien ----------

func _label(parent: Node, text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("fff4e0"))
	l.add_theme_color_override("font_outline_color", Color("2b2420"))
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 96)
	b.add_theme_font_size_override("font_size", 32)
	parent.add_child(b)
	return b


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 16
	top.offset_bottom = 70
	top.add_theme_constant_override("separation", 40)
	layer.add_child(top)
	coins_label = _label(top, "Tiền: 0", 34)
	info_label = _label(top, "Chạm vào kệ sách để xem", 30)
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_label = _label(top, "FPS: 0", 26)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -120
	bottom.offset_bottom = -20
	bottom.add_theme_constant_override("separation", 24)
	layer.add_child(bottom)
	var rotate_btn := _button(bottom, "Xoay phòng")
	rotate_btn.pressed.connect(_on_rotate)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	sell_button = _button(bottom, "Bán sách (+%d)" % SELL_PRICE)
	sell_button.disabled = true
	sell_button.pressed.connect(_on_sell)


func _on_rotate() -> void:
	target_yaw += 90.0


# ---------- Moi khung hinh ----------

func _process(delta: float) -> void:
	pivot.rotation_degrees.y = lerpf(pivot.rotation_degrees.y, target_yaw, clampf(delta * 8.0, 0.0, 1.0))
	var back := cam.global_transform.basis.z
	back.y = 0.0
	back = back.normalized()
	for w in walls:
		var normal: Vector3 = w[1]
		w[0].visible = normal.dot(back) < 0.3
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


# ---------- Cam ung: cham, keo, chum hai ngon ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 1:
				drag_dist = 0.0
			elif touches.size() == 2:
				pinch_start_dist = _touch_distance()
				pinch_start_size = cam.size
		else:
			if touches.size() == 1 and drag_dist < 12.0:
				_tap(event.position)
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() == 1:
			drag_dist += event.relative.length()
			_pan(event.relative)
		elif touches.size() == 2 and pinch_start_dist > 0.0:
			drag_dist = 999.0
			var d := _touch_distance()
			cam.size = clampf(pinch_start_size * pinch_start_dist / maxf(d, 1.0), 5.0, 20.0)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.size = clampf(cam.size * 0.9, 5.0, 20.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.size = clampf(cam.size * 1.1, 5.0, 20.0)


func _touch_distance() -> float:
	var pts := touches.values()
	if pts.size() < 2:
		return 0.0
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	return a.distance_to(b)


func _pan(rel: Vector2) -> void:
	var k := cam.size / get_viewport().get_visible_rect().size.y
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var p := pivot.position - right * rel.x * k + fwd * rel.y * k * 1.7
	p.x = clampf(p.x, -4.0, 4.0)
	p.z = clampf(p.z, -4.0, 4.0)
	pivot.position = p


func _tap(screen_pos: Vector2) -> void:
	var vh := get_viewport().get_visible_rect().size.y
	if screen_pos.y < 80.0 or screen_pos.y > vh - 140.0:
		return  # vung thanh tren / nut bam
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_select(null)
		return
	var col = hit["collider"]
	if col in shelves:
		_select(col)
	else:
		_select(null)


func _select(s) -> void:
	if selected != null:
		selected.get_meta("marker").visible = false
	selected = s
	if selected != null:
		selected.get_meta("marker").visible = true
		info_label.text = selected.get_meta("label")
	else:
		info_label.text = "Chạm vào kệ sách để xem"


# ---------- Khach hang ----------

func _walk_time(a: Vector3, b: Vector3) -> float:
	return a.distance_to(b) / 1.6


func _spawn_customer() -> void:
	customer = Node3D.new()
	add_child(customer)
	var palette := [Color("e67e22"), Color("8e44ad"), Color("16a085"), Color("2980b9"), Color("c0392b")]
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.28
	cm.height = 1.3
	body.mesh = cm
	body.material_override = _mat(palette.pick_random())
	body.position = Vector3(0.0, 0.65, 0.0)
	customer.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	head.mesh = sm
	head.material_override = _mat(Color("f1c27d"))
	head.position = Vector3(0.0, 1.5, 0.0)
	customer.add_child(head)
	customer.position = DOOR_POS

	var shelf: Node3D = shelves.pick_random()
	var shelf_front: Vector3 = shelf.get_meta("front")
	info_label.text = "Có khách vào tiệm!"
	var tw := create_tween()
	tw.tween_property(customer, "position", shelf_front, _walk_time(DOOR_POS, shelf_front))
	tw.tween_interval(1.5)
	tw.tween_property(customer, "position", COUNTER_FRONT, _walk_time(shelf_front, COUNTER_FRONT))
	tw.tween_callback(_customer_at_counter)


func _customer_at_counter() -> void:
	customer_waiting = true
	sell_button.disabled = false
	info_label.text = "Khách đang chờ ở quầy"


func _on_sell() -> void:
	if not customer_waiting:
		return
	customer_waiting = false
	sell_button.disabled = true
	coins += SELL_PRICE
	coins_label.text = "Tiền: %d" % coins
	info_label.text = "Đã bán 1 cuốn sách!"
	var leaving := customer
	var tw := create_tween()
	tw.tween_property(leaving, "position", DOOR_POS, _walk_time(leaving.position, DOOR_POS))
	tw.tween_callback(leaving.queue_free)
	tw.tween_interval(1.5)
	tw.tween_callback(_spawn_customer)
