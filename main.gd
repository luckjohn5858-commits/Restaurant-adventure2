extends Node2D
# Restaurant Adventure - Godot 4.3, portrait mobile (540x960).
# Everything is drawn in code, so no assets are needed.

const W := 540.0
const H := 960.0
const TOP := 70.0
const BOT := 930.0
const SPEED := 270.0
const MAX_LEVEL := 10
const UP_COST := [3, 5, 8, 12, 17, 24, 33, 45, 60] # lemonade level upgrades
const BUY_COST := 5
const READ_TIME := 0.8
const UNLOCK_COINS := 13
const START_COINS := 6
const SAVE_PATH := "user://lemonade.cfg" # old file name kept so existing saves still load
const LOAD_TIME := 2.8 # seconds the loading screen is shown

# ---------------------------------------------------------------- config (testing)
# set_money_cheat: true adds a "$$$" button (top-left) that sets your money to
# cheat_money. Once you use it, nothing is saved any more in that session, so
# everything you buy works, but after you relog the progress is back to the
# last real save. Set it to false to remove the button.
const CONFIG := {
	"set_money_cheat": true,
	"cheat_money": 1000000,
}
const CHEAT_BTN := Rect2(18, 12, 100, 46)
var loading := true
var load_t := 0.0
var cheat_active := false # true after the cheat was used: saving is disabled
const SLOTS := [209.0, 270.0, 331.0] # customer places behind the counter
const CUST_Y := 440.0
const SERVE_Y := 550.0
const MACHINE_SPOTS := [Vector2(215, 640), Vector2(270, 640)]
const UPGRADES := [
	{"id": "customer", "title": "Get another customer", "sub": "+1 Customer", "cost": 13},
	{"id": "cashier", "title": "Hire Robert", "sub": "+1 Cashier", "cost": 30},
	{"id": "popularity", "title": "Popularity", "sub": "+1 Customer", "cost": 175},
	{"id": "income", "title": "More income", "sub": "x2 coins per sale", "cost": 250},
]

# Renovate (bottom-left hammer button, appears at RENO_COINS)
const RENO_COINS := 133
const RENO_LEVEL := 10 # lemonade level needed before you may renovate
const RENO_COST := 555 # coins to pay once the level requirement is met
const RENO_TIME := 5.0

const COUNTER := Rect2(181, 460, 178, 46)
const COUNTER_BLOCK := Rect2(170, 470, 200, 40)
const DELIVER_ZONE := Rect2(150, 500, 240, 90)
const PROD := Rect2(181, 666, 120, 72)
const PROD_BLOCK := Rect2(170, 678, 142, 60)
const BUYSPOT := Rect2(181, 688, 62, 50)
const BUY_TAP := Rect2(165, 650, 100, 95)
const GEAR := Rect2(478, 10, 50, 50)

const BUY_P := Rect2(110, 380, 320, 230)
const BUY_BTN := Rect2(150, 524, 240, 56)
const UP_P := Rect2(48, 250, 444, 470)
const LVL_P := Rect2(97, 420, 226, 235)
const LVL_BTN := Rect2(117, 602, 186, 40)
const OPEN_BTN := Rect2(452, 846, 70, 70)
const SET_P := Rect2(120, 380, 300, 200)
const RESET_BTN := Rect2(150, 490, 240, 54)
const RENO_BTN := Rect2(18, 846, 70, 70)
const RENO_P := Rect2(60, 250, 420, 450)
const RENO_X := Rect2(426, 258, 46, 46)
const RENO_GO := Rect2(160, 576, 220, 52)
const TEST_BACK := Rect2(170, 560, 200, 60)

var font: Font
var t := 0.0
var coins := START_COINS
var level := 1 # lemonade level (tap the lemonade table)
var stage := 1 # 1 = buy spot visible (start), 2 = machine owned
var owned := {"customer": false, "cashier": false, "popularity": false, "income": false}
var unlocked := false # upgrades button appears once you reach 13 coins
var up_seen := false
var reno_unlocked := false # hammer button appears once you reach 133 coins
var renovated := false
var reno_t := 0.0
var workers: Array = []
var customers: Array = []
var spawn_timer := 1.0
var popup := ""
var floaters: Array = []
var confetti: Array = []
var puffs: Array = []
var puff_timer := 0.0
var cv: CanvasItem


func _ready() -> void:
	font = ThemeDB.fallback_font
	cv = self
	_f_make_clip()
	randomize()
	_load()
	_setup_world()


func _setup_world() -> void:
	if renovated:
		_f_setup()
		return
	customers = []
	workers = [_make_worker(0, Vector2(209, 570))]
	if owned["cashier"]:
		workers.append(_make_worker(1, Vector2(330, 570)))
	if stage == 1:
		_new_customer(true)


func _make_worker(idx: int, pos: Vector2) -> Dictionary:
	return {
		"idx": idx, "pos": pos, "target": pos, "task": "idle", "t": 0.0,
		"carrying": false, "cust": null, "moving": false,
		"hair": Color("ee4566") if idx == 0 else Color("7a3b1e"),
		"body": Color("e6e6e6") if idx == 0 else Color("f2d94a"),
	}


# ---------------------------------------------------------------- numbers
func _price() -> int:
	return (2 + (level - 1)) * (2 if owned["income"] else 1)


func _make_time() -> float:
	return maxf(0.5, 2.0 * pow(0.88, level - 1))


func _fmt_time(x: float) -> String:
	return str(snappedf(x, 0.1)) + "s"


func _max_customers() -> int:
	return 1 + int(owned["customer"]) + int(owned["popularity"])


func _any_affordable() -> bool:
	for u in UPGRADES:
		if not owned[u["id"]] and coins >= int(u["cost"]):
			return true
	return false


# ---------------------------------------------------------------- save
func _save() -> void:
	if cheat_active:
		return # cheated session: progress is not stored
	var cf := ConfigFile.new()
	cf.set_value("g", "coins", coins)
	cf.set_value("g", "stage", stage)
	cf.set_value("g", "level", level)
	cf.set_value("g", "unlocked", unlocked)
	cf.set_value("g", "up_seen", up_seen)
	cf.set_value("g", "reno_unlocked", reno_unlocked)
	cf.set_value("g", "renovated", renovated)
	cf.set_value("g", "r_done", r_done)
	cf.set_value("f", "open", f_open)
	cf.set_value("f", "stage", f_stage)
	cf.set_value("f", "l0", f_lvl[0])
	cf.set_value("f", "l1", f_lvl[1])
	cf.set_value("f", "l2", f_lvl[2])
	for k in f_up:
		cf.set_value("fup", k, f_up[k])
	for k in owned:
		cf.set_value("owned", k, owned[k])
	cf.save(SAVE_PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		coins = cf.get_value("g", "coins", START_COINS)
		stage = clampi(int(cf.get_value("g", "stage", 1)), 1, 2)
		level = clampi(int(cf.get_value("g", "level", 1)), 1, MAX_LEVEL)
		unlocked = cf.get_value("g", "unlocked", false)
		up_seen = cf.get_value("g", "up_seen", false)
		reno_unlocked = cf.get_value("g", "reno_unlocked", false)
		renovated = cf.get_value("g", "renovated", false)
		r_done = cf.get_value("g", "r_done", false)
		f_open = cf.get_value("f", "open", false)
		f_stage = clampi(int(cf.get_value("f", "stage", 0)), 0, 3)
		f_lvl = [clampi(int(cf.get_value("f", "l0", 1)), 1, F_MAX_LEVEL), clampi(int(cf.get_value("f", "l1", 1)), 1, F_MAX_LEVEL), clampi(int(cf.get_value("f", "l2", 1)), 1, F_MAX_LEVEL)]
		for k in f_up:
			f_up[k] = cf.get_value("fup", k, false)
		if renovated and not f_open:
			popup = "food_intro"
		for k in owned:
			owned[k] = cf.get_value("owned", k, false)


func _reset() -> void:
	cheat_active = false
	coins = START_COINS
	stage = 1
	level = 1
	unlocked = false
	up_seen = false
	reno_unlocked = false
	renovated = false
	r_done = false
	reno_t = 0.0
	f_open = false
	f_stage = 0
	f_lvl = [1, 1, 1]
	for k in f_up:
		f_up[k] = false
	for k in owned:
		owned[k] = false
	popup = ""
	floaters = []
	_setup_world()
	_save()


# ---------------------------------------------------------------- customers
func _free_slot() -> int:
	for i in _max_customers():
		var used := false
		for c in customers:
			if c["slot"] == i:
				used = true
		if not used:
			return i
	return -1


func _occupied() -> int:
	var n := 0
	for c in customers:
		if c["slot"] >= 0:
			n += 1
	return n


func _new_customer(waiting: bool) -> void:
	var slot := _free_slot()
	if slot < 0:
		return
	var hairs := [Color("8e642a"), Color("2b2b2b"), Color("d9b04a"), Color("7a3b1e")]
	var bodies := [Color("4a90e2"), Color("56b36b"), Color("e8913a"), Color("9b6bd6")]
	var i := 0 if waiting else randi() % hairs.size()
	var j := 0 if waiting else randi() % bodies.size()
	customers.append({
		"pos": Vector2(SLOTS[slot], CUST_Y) if waiting else Vector2(-40, CUST_Y),
		"slot": slot,
		"state": "wait" if waiting else "in",
		"claimed": false,
		"hair": hairs[i],
		"body": bodies[j],
		"moving": false,
	})


func _update_customers(delta: float) -> void:
	for i in range(customers.size() - 1, -1, -1):
		var c: Dictionary = customers[i]
		var pos: Vector2 = c["pos"]
		match c["state"]:
			"in":
				var dest := Vector2(SLOTS[c["slot"]], CUST_Y)
				pos = pos.move_toward(dest, 150.0 * delta)
				c["moving"] = true
				if pos.distance_to(dest) < 1.0:
					c["state"] = "wait"
					c["moving"] = false
			"out":
				pos = pos.move_toward(Vector2(-70, 400), 170.0 * delta)
				c["moving"] = true
				if pos.x < -50.0:
					customers.remove_at(i)
					continue
		c["pos"] = pos
	if stage == 2 and _occupied() < _max_customers():
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_new_customer(false)
			spawn_timer = 1.0


# ---------------------------------------------------------------- game loop
func _process(delta: float) -> void:
	if loading:
		t += delta
		load_t += delta
		if load_t >= LOAD_TIME:
			loading = false
		queue_redraw()
		return
	if renovated:
		t += delta
		_f_process(delta)
		queue_redraw()
		return
	t += delta
	if stage == 2 and not unlocked and coins >= UNLOCK_COINS:
		unlocked = true
		_save()
	if not reno_unlocked and coins >= RENO_COINS:
		reno_unlocked = true
		_save()
	if popup == "renovating":
		reno_t += delta
		if reno_t >= RENO_TIME:
			_f_start()
	for w in workers:
		_move_worker(w, delta)
	_update_customers(delta)
	for w in workers:
		_update_ai(w, delta)
	_update_fx(delta)
	queue_redraw()


func _move_worker(w: Dictionary, delta: float) -> void:
	var pos: Vector2 = w["pos"]
	var to: Vector2 = w["target"] - pos
	w["moving"] = to.length() > 4.0
	if w["moving"]:
		pos += to.normalized() * minf(SPEED * delta, to.length())
	pos.x = clampf(pos.x, 30.0, W - 30.0)
	pos.y = clampf(pos.y, 130.0, 850.0)
	pos = _push_out(COUNTER_BLOCK, pos)
	if stage != 1:
		pos = _push_out(PROD_BLOCK, pos)
	w["pos"] = pos


func _push_out(r: Rect2, p: Vector2) -> Vector2:
	if not r.has_point(p):
		return p
	var dl := p.x - r.position.x
	var dr := r.end.x - p.x
	var dt := p.y - r.position.y
	var db := r.end.y - p.y
	var m := minf(minf(dl, dr), minf(dt, db))
	if m == dl:
		p.x = r.position.x
	elif m == dr:
		p.x = r.end.x
	elif m == dt:
		p.y = r.position.y
	else:
		p.y = r.end.y
	return p


func _arrived(w: Dictionary) -> bool:
	var pos: Vector2 = w["pos"]
	return pos.distance_to(w["target"]) < 6.0


# Each worker runs on his own:
# customer -> read order -> machine -> make (2s) -> deliver
func _update_ai(w: Dictionary, delta: float) -> void:
	if stage != 2:
		w["task"] = "idle"
		return
	match w["task"]:
		"idle":
			for c in customers:
				if c["state"] == "wait" and not c["claimed"]:
					c["claimed"] = true
					w["cust"] = c
					w["task"] = "to_customer"
					w["target"] = Vector2(SLOTS[c["slot"]], SERVE_Y)
					break
		"to_customer":
			if _arrived(w):
				w["task"] = "reading"
				w["t"] = 0.0
		"reading":
			w["t"] += delta
			if w["t"] >= READ_TIME:
				w["task"] = "to_machine"
				w["target"] = MACHINE_SPOTS[w["idx"]]
		"to_machine":
			if _arrived(w):
				w["task"] = "making"
				w["t"] = 0.0
		"making":
			w["t"] += delta
			if w["t"] >= _make_time():
				w["t"] = 0.0
				w["carrying"] = true
				w["task"] = "to_deliver"
				var c: Dictionary = w["cust"]
				w["target"] = Vector2(SLOTS[c["slot"]], SERVE_Y)
		"to_deliver":
			if _arrived(w):
				_serve(w)
				w["task"] = "idle"


func _serve(w: Dictionary) -> void:
	w["carrying"] = false
	var c: Dictionary = w["cust"]
	w["cust"] = null
	var cpos: Vector2 = c["pos"]
	c["state"] = "out"
	c["slot"] = -1
	spawn_timer = minf(spawn_timer, 1.2)
	var gain := _price()
	coins += gain
	_float_text(cpos + Vector2(0, -60), "+%d" % gain)
	_save()
	Input.vibrate_handheld(25)


func _buy() -> void:
	if coins < BUY_COST:
		_float_text(Vector2(270, 500), "Not enough coins")
		return
	coins -= BUY_COST
	stage = 2
	popup = ""
	spawn_timer = 1.0
	_spawn_confetti()
	_save()


func _upgrade_level() -> void:
	if level >= MAX_LEVEL:
		return
	var cost: int = UP_COST[level - 1]
	if coins >= cost:
		coins -= cost
		level += 1
		_float_text(Vector2(210, 410), "Level %d!" % level)
		_save()
	else:
		_float_text(Vector2(210, 410), "Not enough coins")


func _buy_upgrade(i: int) -> void:
	var u: Dictionary = UPGRADES[i]
	var id: String = u["id"]
	if owned[id]:
		return
	var cost: int = u["cost"]
	if coins < cost:
		_float_text(Vector2(270, 330), "Not enough coins")
		return
	coins -= cost
	owned[id] = true
	if id == "cashier":
		workers.append(_make_worker(1, Vector2(450, 600)))
	_spawn_confetti()
	_save()


# ---------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	if loading:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_press(get_global_mouse_position())
			else:
				_f_release(get_global_mouse_position())
		elif mb.pressed and popup == "fup":
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				f_scroll = clampf(f_scroll - 60.0, 0.0, _scroll_max())
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				f_scroll = clampf(f_scroll + 60.0, 0.0, _scroll_max())
	elif event is InputEventMouseMotion and f_drag:
		_f_drag(get_global_mouse_position())


func _cheat_on() -> bool:
	return bool(CONFIG.get("set_money_cheat", false))


func _on_press(p: Vector2) -> void:
	if popup != "":
		_popup_press(p)
		return
	if _cheat_on() and CHEAT_BTN.has_point(p):
		cheat_active = true
		coins = int(CONFIG.get("cheat_money", 1000000))
		_float_text(Vector2(270, 300), "Cheat: money set")
		return
	if renovated:
		_f_press(p)
		return
	if GEAR.grow(8.0).has_point(p):
		popup = "settings"
		return
	if stage == 1 and BUY_TAP.has_point(p):
		popup = "buy"
		return
	if stage == 2 and unlocked and OPEN_BTN.grow(6.0).has_point(p):
		popup = "upgrades"
		up_seen = true
		_save()
		return
	if reno_unlocked and RENO_BTN.grow(6.0).has_point(p):
		popup = "test" if renovated else "renovate"
		return
	if stage == 2 and PROD.grow(6.0).has_point(p):
		popup = "lemonade"


func _up_row(i: int) -> Rect2:
	return Rect2(UP_P.position.x + 12, UP_P.position.y + 72 + i * 94, UP_P.size.x - 24, 84)


func _up_btn(i: int) -> Rect2:
	var r := _up_row(i)
	return Rect2(r.end.x - 136, r.position.y + 19, 124, 46)


func _popup_press(p: Vector2) -> void:
	if renovated and popup != "settings" and popup != "test":
		_f_popup_press(p)
		return
	match popup:
		"buy":
			if Rect2(BUY_P.end.x - 44, BUY_P.position.y, 44, 44).has_point(p):
				popup = ""
			elif BUY_BTN.has_point(p):
				_buy()
			elif not BUY_P.has_point(p):
				popup = ""
		"lemonade":
			if LVL_BTN.has_point(p):
				_upgrade_level()
			elif not LVL_P.has_point(p):
				popup = ""
		"upgrades":
			if Rect2(UP_P.end.x - 54, UP_P.position.y + 12, 42, 42).has_point(p):
				popup = ""
				return
			for i in UPGRADES.size():
				if _up_btn(i).has_point(p):
					_buy_upgrade(i)
					return
			if not UP_P.has_point(p):
				popup = ""
		"settings":
			if RESET_BTN.has_point(p):
				_reset()
			elif not SET_P.has_point(p):
				popup = ""
		"renovate":
			if RENO_X.has_point(p):
				popup = ""
			elif RENO_GO.has_point(p):
				if _reno_ready() and coins >= RENO_COST:
					coins -= RENO_COST
					popup = "renovating"
					reno_t = 0.0
					_save()
			elif not RENO_P.has_point(p):
				popup = ""
		"test":
			if TEST_BACK.has_point(p):
				popup = ""


# ---------------------------------------------------------------- fx
func _float_text(p: Vector2, s: String) -> void:
	floaters.append({"p": p, "s": s, "t": 0.0})


func _spawn_confetti() -> void:
	var cols := [Color("a84de0"), Color("3b8be8"), Color("f2a33a"), Color("ee3b3b"), Color("f5e03a"), Color("6bd65a")]
	for i in 70:
		confetti.append({
			"p": Vector2(randf_range(0, W), randf_range(TOP, TOP + 120)),
			"v": Vector2(randf_range(-40, 40), randf_range(60, 220)),
			"r": randf() * TAU,
			"vr": randf_range(-8, 8),
			"c": cols[randi() % cols.size()],
			"s": Vector2(randf_range(4, 8), randf_range(8, 18)),
			"life": 0.0,
		})


func _update_fx(delta: float) -> void:
	var making := false
	for w in workers:
		if w["task"] == "making":
			making = true
	if making:
		puff_timer -= delta
		if puff_timer <= 0.0:
			puff_timer = 0.09
			puffs.append({
				"p": Vector2(272.0 + randf_range(-6.0, 6.0), 650.0),
				"v": Vector2.from_angle(randf_range(-0.5, 1.6)) * randf_range(30.0, 75.0),
				"life": 0.0,
				"r": randf_range(7.0, 11.0),
			})
	for i in range(puffs.size() - 1, -1, -1):
		var pf: Dictionary = puffs[i]
		pf["life"] += delta
		pf["p"] += pf["v"] * delta
		if pf["life"] > 1.3:
			puffs.remove_at(i)
	for i in range(floaters.size() - 1, -1, -1):
		var f: Dictionary = floaters[i]
		f["t"] += delta
		f["p"] += Vector2(0, -45.0 * delta)
		if f["t"] > 1.2:
			floaters.remove_at(i)
	for i in range(confetti.size() - 1, -1, -1):
		var c: Dictionary = confetti[i]
		c["p"] += c["v"] * delta
		c["r"] += c["vr"] * delta
		c["life"] += delta
		if c["p"].y > BOT or c["life"] > 4.0:
			confetti.remove_at(i)


# ---------------------------------------------------------------- draw helpers
func _rr(r: Rect2, col: Color, rad: int = 10) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(rad)
	cv.draw_style_box(sb, r)


func _txt(cx: float, y: float, s: String, size: int, col: Color) -> void:
	cv.draw_string(font, Vector2(cx - 150.0, y), s, HORIZONTAL_ALIGNMENT_CENTER, 300, size, col)
	cv.draw_string(font, Vector2(cx - 149.0, y), s, HORIZONTAL_ALIGNMENT_CENTER, 300, size, col)


func _txtl(x: float, y: float, s: String, size: int, col: Color) -> void:
	cv.draw_string(font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	cv.draw_string(font, Vector2(x + 1.0, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _coin(c: Vector2, r: float) -> void:
	cv.draw_circle(c, r, Color("e8962a"))
	cv.draw_circle(c, r * 0.82, Color("f7b733"))
	for i in 3:
		var yy := c.y + (i - 1) * r * 0.3
		cv.draw_line(Vector2(c.x - r * 0.42, yy), Vector2(c.x + r * 0.42, yy), Color("c9701a"), maxf(1.5, r * 0.14))


func _cup(c: Vector2, s: float = 1.0) -> void:
	var w := 16.0 * s
	var h := 22.0 * s
	draw_rect(Rect2(c.x - w / 2.0, c.y - h, w, h), Color("f2f6b0"))
	draw_rect(Rect2(c.x - w / 2.0, c.y - h * 0.6, w, h * 0.6), Color("fff176"))
	draw_rect(Rect2(c.x - w / 2.0, c.y - h, w, h), Color("b5c46a"), false, 1.5 * s)
	draw_line(Vector2(c.x + 2.0 * s, c.y - h), Vector2(c.x + 8.0 * s, c.y - h - 9.0 * s), Color("a8324a"), 2.5 * s)
	draw_circle(Vector2(c.x - w / 2.0, c.y - h + 3.0 * s), 5.0 * s, Color("ffe14d"))
	draw_circle(Vector2(c.x - w / 2.0, c.y - h + 3.0 * s), 2.5 * s, Color("c9a400"))


func _person(pos: Vector2, hair: Color, body: Color, face: bool, bob: float) -> void:
	var f := pos + Vector2(0, bob)
	var skin := Color("e6bb7e")
	var dark := Color("2b2b2b")
	# soft shadow, cast down-right
	draw_set_transform(pos + Vector2(14, 24), 0.0, Vector2(1, 0.85))
	draw_circle(Vector2.ZERO, 17, Color(0, 0, 0, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_rr(Rect2(f.x - 13, f.y - 10, 26, 28), body, 8)
	draw_circle(f + Vector2(0, -17), 12.5, skin)
	if face:
		# customer: bowl-cut hair on top, small oval eyes below it
		_rr(Rect2(f.x - 15, f.y - 40, 30, 23), hair, 11)
		_rr(Rect2(f.x - 7.0, f.y - 14.0, 3.0, 6.0), dark, 1)
		_rr(Rect2(f.x + 4.0, f.y - 14.0, 3.0, 6.0), dark, 1)
	else:
		# worker: big round hair, the eyes peek out underneath
		draw_circle(f + Vector2(0, -26), 16.5, hair)
		_rr(Rect2(f.x - 7.0, f.y - 8.0, 3.0, 5.0), dark, 1)
		_rr(Rect2(f.x + 4.0, f.y - 8.0, 3.0, 5.0), dark, 1)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)


# ---------------------------------------------------------------- draw
func _cloud(c: Vector2, sc: float) -> void:
	var col := Color(1, 1, 1, 0.5)
	draw_circle(c, 34.0 * sc, col)
	draw_circle(c + Vector2(40.0, 8.0) * sc, 28.0 * sc, col)
	draw_circle(c + Vector2(-38.0, 12.0) * sc, 24.0 * sc, col)
	_rr(Rect2(c.x - 60.0 * sc, c.y + 4.0 * sc, 130.0 * sc, 36.0 * sc), col, int(18.0 * sc))


func _logo_line(text: String, y: float, size: int) -> void:
	var x := W / 2.0 - 250.0
	draw_string_outline(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_CENTER, 500, size, 22, Color("3f74b8"))
	draw_string(font, Vector2(x, y + 6.0), text, HORIZONTAL_ALIGNMENT_CENTER, 500, size, Color("e8731f"))
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_CENTER, 500, size, Color("f9c235"))
	draw_string(font, Vector2(x + 1.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, 500, size, Color("f9c235"))


func _draw_loading() -> void:
	# sky
	var top := Color("4aa3df")
	var low := Color("d4ebf5")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]), PackedColorArray([top, top, low, low]))
	for cl in [[80.0, 190.0, 1.0, 12.0], [430.0, 330.0, 0.8, 8.0], [120.0, 560.0, 1.1, 10.0], [470.0, 650.0, 0.7, 6.0]]:
		var cx: float = fmod(float(cl[0]) + t * float(cl[3]), W + 240.0) - 120.0
		_cloud(Vector2(cx, float(cl[1])), float(cl[2]))
	# green hill
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 28:
		var x := W * i / 27.0
		var u := (x - 270.0) / 300.0
		pts.append(Vector2(x, 620.0 + u * u * 90.0))
		cols.append(Color("92d96c"))
	pts.append(Vector2(W, H))
	cols.append(Color("6dbb4c"))
	pts.append(Vector2(0, H))
	cols.append(Color("6dbb4c"))
	draw_polygon(pts, cols)
	# lemonade stand on the hill
	draw_set_transform(Vector2(270, 735), 0.0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 120, Color("7cc95a"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(205, 585, 5, 150), Color("8a5a3a"))
	draw_rect(Rect2(330, 585, 5, 150), Color("8a5a3a"))
	for i in 9:
		draw_rect(Rect2(205 + i * 14.4, 585, 14.4, 24), Color("6fa0d8") if i % 2 == 0 else Color("f2c94a"))
	draw_circle(Vector2(272, 662), 17, Color("f3c9a0"))
	draw_circle(Vector2(272, 652), 15, Color("e8344f"))
	draw_circle(Vector2(266, 664), 2.5, Color("2b2b2b"))
	draw_circle(Vector2(278, 664), 2.5, Color("2b2b2b"))
	draw_rect(Rect2(255, 678, 34, 14), Color("f2f2f2"))
	draw_rect(Rect2(222, 690, 104, 45), Color("7a5236"))
	draw_rect(Rect2(232, 666, 22, 26), Color("f4ec8a"))
	draw_line(Vector2(246, 666), Vector2(254, 650), Color("d6212f"), 3.0)
	draw_circle(Vector2(236, 662), 7, Color("f2d94a"))
	# logo: chef hat, title, fork
	draw_rect(Rect2(122, 268, 56, 40), Color("dfe2e8"))
	draw_circle(Vector2(128, 262), 26, Color.WHITE)
	draw_circle(Vector2(160, 244), 28, Color.WHITE)
	draw_circle(Vector2(190, 262), 24, Color.WHITE)
	_logo_line("RESTAURANT", 372, 78)
	_logo_line("ADVENTURE", 470, 92)
	for i in 3:
		draw_rect(Rect2(436 + i * 11, 232, 6, 34), Color("f0f0f4"))
	draw_rect(Rect2(436, 262, 28, 8), Color("f0f0f4"))
	draw_rect(Rect2(446, 268, 8, 62), Color("f0f0f4"))
	# loading text + bar
	var dots := ".".repeat(int(t * 3.0) % 4)
	_txt(W / 2.0, 862, "Loading" + dots, 34, Color("fdfff4"))
	var bar := Rect2(120, 884, 300, 14)
	_rr(bar, Color(1, 1, 1, 0.35), 7)
	_rr(Rect2(bar.position, Vector2(maxf(14.0, bar.size.x * clampf(load_t / LOAD_TIME, 0.0, 1.0)), 14)), Color("f9c235"), 7)


func _draw() -> void:
	if loading:
		_draw_loading()
		return
	draw_rect(Rect2(0, 0, W, H), Color("222629"))
	if renovated:
		_f_draw_world()
		_f_draw_hud()
	else:
		_draw_world()
		_draw_hud()
	_draw_cheat_btn()
	_draw_popup()


func _draw_cheat_btn() -> void:
	if not _cheat_on():
		return
	_rr(Rect2(CHEAT_BTN.position + Vector2(0, 4), CHEAT_BTN.size), Color("b8283d") if cheat_active else Color("3d8fd1"), 10)
	_rr(CHEAT_BTN, Color("e8344f") if cheat_active else Color("72c4f5"), 10)
	_txt(CHEAT_BTN.get_center().x, CHEAT_BTN.get_center().y + 8, "$$$", 22, Color.WHITE)


# awning sags in the middle (parabola between the two posts)
func _awn_s(x: float) -> float:
	var u := (x - 269.5) / 122.5
	return 1.0 - u * u


func _awn_top(x: float) -> float:
	return 309.0 + 11.0 * _awn_s(x)


func _awn_bot(x: float) -> float:
	return 355.0 + 7.0 * _awn_s(x)


func _draw_world() -> void:
	# sidewalk, road with crosswalk, pavement
	draw_rect(Rect2(0, TOP, W, BOT - TOP), Color("d0d0d2"))
	draw_rect(Rect2(0, TOP, W, 32), Color("d3d3d5"))
	draw_rect(Rect2(0, 102, W, 220), Color("8e8e8e"))
	draw_line(Vector2(0, 102), Vector2(W, 102), Color("7f7f80"), 2)
	for s in [[108, 10], [150, 26], [200, 26], [252, 26]]:
		draw_rect(Rect2(233, s[0], 169, s[1]), Color("c7c7c9"))
	draw_rect(Rect2(10, 265, 3, 78), Color("b4b4b6"))
	# grass (the right side lies in the shadow of the bush and the tree)
	draw_rect(Rect2(0, 425, 140, 431), Color("7bb96c"))
	draw_rect(Rect2(400, 425, 140, 200), Color("7bb96c"))
	draw_rect(Rect2(401, 496, 139, 31), Color("59954d"))
	draw_rect(Rect2(470, 527, 70, 98), Color("59954d"))
	# bushes: light top, darker front
	draw_rect(Rect2(0, 392, 120, 100), Color("65b434"))
	draw_rect(Rect2(0, 392, 120, 53), Color("7fd944"))
	draw_rect(Rect2(415, 392, 70, 100), Color("65b434"))
	draw_rect(Rect2(415, 392, 70, 53), Color("7fd944"))
	# tree
	_rr(Rect2(512, 515, 28, 65), Color("6a3833"), 2)
	draw_colored_polygon(PackedVector2Array([Vector2(445, 370), Vector2(500, 305), Vector2(540, 300), Vector2(540, 540), Vector2(470, 505), Vector2(440, 430)]), Color("62bb23"))
	draw_colored_polygon(PackedVector2Array([Vector2(445, 370), Vector2(500, 305), Vector2(525, 340), Vector2(470, 425)]), Color("78d03e"))
	# red carpet + bin
	draw_rect(Rect2(0, 856, W, BOT - 856), Color("952533"))
	draw_rect(Rect2(84, 840, 50, 92), Color(0, 0, 0, 0.15))
	_rr(Rect2(77, 834, 50, 92), Color("885c39"), 3)
	_rr(Rect2(88, 846, 28, 24), Color("6b3834"), 2)
	# walkway lane
	draw_rect(Rect2(181, 530, 178, 210), Color(0, 0, 0, 0.06))
	# shadows the stand throws down-right
	var sh := Color(0, 0, 0, 0.2)
	draw_colored_polygon(PackedVector2Array([Vector2(139, 488), Vector2(150, 488), Vector2(190, 524), Vector2(182, 533)]), sh)
	draw_colored_polygon(PackedVector2Array([Vector2(398, 488), Vector2(409, 488), Vector2(468, 540), Vector2(456, 550)]), sh)
	draw_rect(Rect2(184, 519, 183, 26), sh)
	draw_rect(Rect2(359, 487, 8, 32), sh)
	draw_rect(Rect2(367, 531, 95, 12), sh)
	# stand posts
	_rr(Rect2(139, 305, 9, 183), Color("895b37"), 3)
	_rr(Rect2(391, 305, 9, 183), Color("895b37"), 3)
	# striped awning (11 stripes, sagging in the middle)
	var ax0 := 147.0
	var aw := 245.0
	var n := 11
	for i in n:
		var xa := ax0 + i * aw / n
		var xb := xa + aw / n
		var scol := Color("e5c640") if i % 2 == 0 else Color("edeaee")
		draw_colored_polygon(PackedVector2Array([
			Vector2(xa, _awn_top(xa)), Vector2(xb, _awn_top(xb)),
			Vector2(xb, _awn_bot(xb)), Vector2(xa, _awn_bot(xa))]), scol)
	var hl := PackedVector2Array()
	for i in n + 1:
		var xe := ax0 + i * aw / n
		hl.append(Vector2(xe, _awn_top(xe) + 1.0))
	draw_polyline(hl, Color("f6f08c"), 2.5)
	# customers (behind the counter), then their order bubbles on top
	for c in customers:
		var cp: Vector2 = c["pos"]
		var cb := sin(t * 14.0) * 2.0 if c["moving"] else 0.0
		_person(cp, c["hair"], c["body"], true, cb)
	for c in customers:
		if c["state"] == "wait":
			var bp: Vector2 = c["pos"] + Vector2(38, -46)
			draw_colored_polygon(PackedVector2Array([bp + Vector2(-27, 6), bp + Vector2(-10, 24), bp + Vector2(-34, 32)]), Color.WHITE)
			draw_circle(bp, 29, Color("2b2b2b"))
			draw_circle(bp, 27, Color.WHITE)
			_cup(bp + Vector2(0, 12), 1.1)
	# counter
	draw_rect(Rect2(COUNTER.position.x, COUNTER.position.y, COUNTER.size.x, 42), Color("fde58d"))
	draw_rect(Rect2(COUNTER.position.x, COUNTER.position.y + 42, COUNTER.size.x, 14), Color("e3bb75"))
	_rr(Rect2(COUNTER.position.x + 3, COUNTER.position.y + 56, 12, 11), Color("895b37"), 2)
	_rr(Rect2(COUNTER.end.x - 15, COUNTER.position.y + 56, 12, 11), Color("895b37"), 2)
	# production table / buy spot
	if stage == 1:
		_draw_buy_spot()
	else:
		_draw_prod_table()
	# workers
	for w in workers:
		var wp: Vector2 = w["pos"]
		var pb := sin(t * 16.0) * 2.0 if w["moving"] else 0.0
		_person(wp, w["hair"], w["body"], false, pb)
		if w["carrying"]:
			_cup(wp + Vector2(0, -42 + pb), 1.2)
		if w["task"] == "making":
			var frac := clampf(float(w["t"]) / _make_time(), 0.0, 1.0)
			_rr(Rect2(wp.x - 24, wp.y - 64, 48, 9), Color("3a3d42"), 4)
			_rr(Rect2(wp.x - 24, wp.y - 64, maxf(8.0, 48.0 * frac), 9), Color("7be05a"), 4)
	# steam puffs from the machine
	for pf in puffs:
		var k: float = float(pf["life"]) / 1.3
		var pr: float = float(pf["r"]) * (0.8 + k * 1.2)
		var pp: Vector2 = pf["p"]
		var pcol := Color(0.95, 0.95, 0.97, (1.0 - k) * 0.85)
		draw_circle(pp, pr, pcol)
		draw_circle(pp + Vector2(pr * 0.8, pr * 0.2), pr * 0.7, pcol)
		draw_circle(pp + Vector2(-pr * 0.6, pr * 0.4), pr * 0.65, pcol)
	# fx
	for f in floaters:
		var a := 1.0 - float(f["t"]) / 1.2
		_txt(f["p"].x + 1, f["p"].y + 2, f["s"], 26, Color(0, 0, 0, a * 0.5))
		_txt(f["p"].x, f["p"].y, f["s"], 26, Color(1.0, 0.85, 0.15, a))
	for c in confetti:
		draw_set_transform(c["p"], c["r"], Vector2.ONE)
		var s: Vector2 = c["s"]
		draw_rect(Rect2(-s.x / 2.0, -s.y / 2.0, s.x, s.y), c["c"])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_prod_table() -> void:
	var r := PROD
	draw_rect(Rect2(r.position.x + 4, r.end.y, r.size.x, 10), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 51), Color("fce393"))
	draw_rect(Rect2(r.position.x, r.position.y + 51, r.size.x, 11), Color("e9c479"))
	draw_rect(Rect2(r.position.x, r.position.y + 62, r.size.x, 11), Color("875a39"))
	# a glass of lemonade waiting on the table
	_cup(Vector2(210, 708), 1.0)
	# machine: gray body, lime band, rounded black top
	draw_rect(Rect2(287, 688, 9, 28), Color(0, 0, 0, 0.2))
	_rr(Rect2(254, 686, 32, 30), Color("a6a5a0"), 3)
	draw_rect(Rect2(259, 692, 22, 7), Color("dfeaa6"))
	_rr(Rect2(253, 660, 34, 30), Color("38383a"), 7)


func _draw_buy_spot() -> void:
	draw_rect(BUYSPOT, Color(1, 1, 1, 0.35))
	var a := BUYSPOT.position
	var b := BUYSPOT.end
	var col := Color(1, 1, 1, 0.95)
	draw_dashed_line(a, Vector2(b.x, a.y), col, 2.5, 6.0)
	draw_dashed_line(Vector2(b.x, a.y), b, col, 2.5, 6.0)
	draw_dashed_line(b, Vector2(a.x, b.y), col, 2.5, 6.0)
	draw_dashed_line(Vector2(a.x, b.y), a, col, 2.5, 6.0)
	var bob := sin(t * 4.0) * 3.0
	var c := Vector2(189, 669 + bob)
	draw_circle(c, 17, Color("e8344f"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(-8, 0), c + Vector2(8, 0)]), Color.WHITE)
	draw_rect(Rect2(c.x - 3, c.y, 6, 9), Color.WHITE)


func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, W, TOP), Color("222629"))
	draw_rect(Rect2(0, BOT, W, H - BOT), Color("222629"))
	_rr(Rect2(190, 16, 140, 40), Color("fdfff4"), 10)
	_coin(Vector2(192, 36), 22)
	_txt(272, 47, _fmt_num(coins), 28, Color("1d1d1f"))
	# gear
	var gc := GEAR.get_center()
	for i in 8:
		var d := Vector2.from_angle(i * TAU / 8.0)
		draw_line(gc + d * 9.0, gc + d * 16.0, Color.WHITE, 6.0)
	draw_circle(gc, 12, Color.WHITE)
	draw_circle(gc, 5, Color("222629"))
	# upgrades button (appears at 13 coins)
	if stage == 2 and unlocked:
		var o := OPEN_BTN
		_rr(Rect2(o.position + Vector2(0, 5), o.size), Color("3d8fd1"), 10)
		_rr(o, Color("72c4f5"), 10)
		var oc := o.get_center()
		draw_colored_polygon(PackedVector2Array([oc + Vector2(0, -20), oc + Vector2(-18, 2), oc + Vector2(-7, 2), oc + Vector2(-7, 18), oc + Vector2(7, 18), oc + Vector2(7, 2), oc + Vector2(18, 2)]), Color.WHITE)
		if _any_affordable():
			var bc := o.position + Vector2(2, 2 + sin(t * 4.0) * 3.0)
			draw_circle(bc, 15, Color("e8344f"))
			draw_colored_polygon(PackedVector2Array([bc + Vector2(0, -8), bc + Vector2(-7, 0), bc + Vector2(7, 0)]), Color.WHITE)
			draw_rect(Rect2(bc.x - 3, bc.y, 6, 8), Color.WHITE)
		if not up_seen and popup == "":
			var tp := Vector2(o.get_center().x, o.position.y - 30 + sin(t * 5.0) * 6.0)
			var tri := PackedVector2Array([tp + Vector2(-22, -26), tp + Vector2(22, -26), tp])
			draw_colored_polygon(tri, Color.WHITE)
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color.BLACK, 3.0)
	# renovate button (appears at 133 coins)
	if reno_unlocked:
		var rb := RENO_BTN
		_rr(Rect2(rb.position + Vector2(0, 5), rb.size), Color("3d8fd1"), 10)
		_rr(rb, Color("72c4f5"), 10)
		_hammer(rb.get_center() + Vector2(0, -1), PI / 4.0, 1.0)
	# hints
	var hint := ""
	if stage == 1 and popup == "":
		hint = "Tap the white box to buy the machine!"
	elif stage == 2 and unlocked and not up_seen and popup == "":
		hint = "Tap the arrow to open upgrades!"
	if hint != "":
		_txt(W / 2.0, 892, hint, 18, Color.WHITE)


func _draw_popup() -> void:
	if renovated and popup != "settings" and popup != "test":
		_f_draw_popup()
		return
	match popup:
		"buy":
			draw_rect(Rect2(0, TOP, W, BOT - TOP), Color(0, 0, 0, 0.4))
			_rr(Rect2(BUY_P.position + Vector2(0, 5), BUY_P.size), Color(0, 0, 0, 0.15), 20)
			_rr(BUY_P, Color("f8f8fa"), 20)
			var cx := BUY_P.get_center().x
			_txt(cx, 430, "Are you sure you", 24, Color("2b2b2b"))
			_txt(cx, 460, "want to buy?", 24, Color("2b2b2b"))
			_cup(Vector2(cx, 506), 1.4)
			var ok := coins >= BUY_COST
			_rr(Rect2(BUY_BTN.position + Vector2(0, 5), BUY_BTN.size), Color("4aa3e0") if ok else Color("9aa5ae"), 12)
			_rr(BUY_BTN, Color("72c4f5") if ok else Color("b9c3cc"), 12)
			_coin(BUY_BTN.get_center() + Vector2(-18, 0), 14)
			_txt(BUY_BTN.get_center().x + 14, BUY_BTN.get_center().y + 11, str(BUY_COST), 30, Color.WHITE)
			draw_circle(Vector2(BUY_P.end.x - 22, BUY_P.position.y + 22), 13, Color("e0e0e6"))
			_txt(BUY_P.end.x - 22, BUY_P.position.y + 29, "x", 20, Color("777777"))
		"lemonade":
			_draw_lemonade()
		"upgrades":
			_draw_upgrades()
		"renovate":
			_draw_renovate()
		"renovating":
			_draw_renovating()
		"test":
			_draw_test()
		"settings":
			draw_rect(Rect2(0, TOP, W, BOT - TOP), Color(0, 0, 0, 0.4))
			_rr(SET_P, Color("f8f8fa"), 20)
			_txt(SET_P.get_center().x, 435, "Settings", 28, Color("2b2b2b"))
			_rr(Rect2(RESET_BTN.position + Vector2(0, 4), RESET_BTN.size), Color("b8283d"), 12)
			_rr(RESET_BTN, Color("e8344f"), 12)
			_txt(RESET_BTN.get_center().x, RESET_BTN.get_center().y + 8, "Reset progress", 22, Color.WHITE)


func _hammer(c: Vector2, rot: float, s: float) -> void:
	draw_set_transform(c, rot, Vector2(s, s))
	draw_rect(Rect2(-3.5, -6, 7, 28), Color("e8f6fd"))
	draw_rect(Rect2(-15, -20, 30, 14), Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _stand_icon(c: Vector2, food: bool) -> void:
	draw_circle(c, 62, Color("d4f3f5"))
	draw_set_transform(c + Vector2(0, 36), 0.0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 54, Color("6fc23f"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var skin := Color("f3c9a0")
	var cap := Color("e8344f")
	if not food:
		# lemonade stand: posts + striped awning, one seller, a cup
		draw_line(c + Vector2(-40, -42), c + Vector2(-40, 36), Color("8a5a3a"), 3.0)
		draw_line(c + Vector2(40, -42), c + Vector2(40, 36), Color("8a5a3a"), 3.0)
		for i in 8:
			var x0 := c.x - 42.0 + i * 10.5
			var col := Color("4a90e2") if i % 2 == 0 else Color("f2c94a")
			draw_rect(Rect2(x0, c.y - 46, 10.5, 14), col)
		draw_circle(c + Vector2(6, -8), 11, skin)
		draw_circle(c + Vector2(6, -16), 9, cap)
	else:
		# food stand: two umbrellas, two sellers, sign and burger
		draw_colored_polygon(PackedVector2Array([c + Vector2(-58, -26), c + Vector2(-34, -48), c + Vector2(-8, -26)]), Color("9a9aa0"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(8, -26), c + Vector2(34, -48), c + Vector2(58, -26)]), Color("9a9aa0"))
		for dx in [-12.0, 14.0]:
			draw_circle(c + Vector2(dx, -8), 10, skin)
			draw_circle(c + Vector2(dx, -15), 8, cap)
	draw_rect(Rect2(c.x - 34, c.y + 6, 68, 30), Color("a8683f"))
	draw_rect(Rect2(c.x - 34, c.y + 6, 68, 6), Color("c28a5a"))
	if not food:
		_cup(c + Vector2(-20, 6), 0.7)
	else:
		draw_rect(Rect2(c.x - 50, c.y + 8, 20, 26), Color.WHITE)
		draw_circle(c + Vector2(-40, 21), 6, Color("d9822b"))
		draw_circle(c + Vector2(24, 2), 7, Color("e8913a"))


func _draw_renovate() -> void:
	var p := RENO_P
	var cx := p.get_center().x
	var dark := Color("1d1d1f")
	draw_rect(Rect2(0, TOP, W, BOT - TOP), Color(0, 0, 0, 0.55))
	_rr(Rect2(p.position + Vector2(0, 5), p.size), Color(0, 0, 0, 0.15), 20)
	_rr(p, Color("f8f8fa"), 20)
	# map pin tile (top-left)
	var pt := Rect2(p.position + Vector2(8, 8), Vector2(46, 46))
	_rr(Rect2(pt.position + Vector2(0, 3), pt.size), Color("3d8fd1"), 8)
	_rr(pt, Color("72c4f5"), 8)
	var pc := pt.get_center()
	draw_colored_polygon(PackedVector2Array([pc + Vector2(-9, 0), pc + Vector2(9, 0), pc + Vector2(0, 15)]), Color.WHITE)
	draw_circle(pc + Vector2(0, -4), 11, Color.WHITE)
	draw_circle(pc + Vector2(0, -4), 4.5, Color("72c4f5"))
	# close button
	_rr(Rect2(RENO_X.position + Vector2(0, 3), RENO_X.size), Color("b8283d"), 8)
	_rr(RENO_X, Color("e8344f"), 8)
	var cc := RENO_X.get_center()
	draw_line(cc + Vector2(-8, -8), cc + Vector2(8, 8), Color.WHITE, 4.0)
	draw_line(cc + Vector2(-8, 8), cc + Vector2(8, -8), Color.WHITE, 4.0)
	_txt(cx, p.position.y + 46, "Renovate", 30, dark)
	_txt(cx, p.position.y + 100, "Upgrade your restaurant!", 19, dark)
	# before / after cards
	var left := Rect2(p.position.x + 20, p.position.y + 118, 160, 190)
	var right := Rect2(p.end.x - 180, p.position.y + 118, 160, 190)
	var ccy := left.get_center().y
	for i in 2:
		var r := left if i == 0 else right
		_rr(r, Color("efeff2"), 14)
		_txt(r.get_center().x, r.position.y + 28, "Before" if i == 0 else "After", 18, dark)
		_stand_icon(Vector2(r.get_center().x, r.position.y + 98), i == 1)
		_txt(r.get_center().x, r.end.y - 14, "Lemonade Stand" if i == 0 else "Food Stand", 16, dark)
	draw_polyline(PackedVector2Array([Vector2(cx - 6, ccy - 14), Vector2(cx + 6, ccy), Vector2(cx - 6, ccy + 14)]), Color("8d8d8d"), 4.0)
	# upgrade button
	var lvl_ok := _reno_ready()
	var ok := lvl_ok and coins >= RENO_COST
	_rr(Rect2(RENO_GO.position + Vector2(0, 5), RENO_GO.size), Color("4aa3e0") if ok else Color("9aa5ae"), 12)
	_rr(RENO_GO, Color("72c4f5") if ok else Color("c9ced4"), 12)
	if lvl_ok:
		_coin(RENO_GO.get_center() + Vector2(-34, 0), 14)
		_txt(RENO_GO.get_center().x + 24, RENO_GO.get_center().y + 10, str(RENO_COST), 28, Color.WHITE if ok else Color("d4202f"))
	else:
		_txt(RENO_GO.get_center().x, RENO_GO.get_center().y + 10, "Upgrade", 28, Color.WHITE)
	if not lvl_ok:
		_txt(cx, p.position.y + 408, "Max the lemonade level and", 18, Color("8d8d8d"))
		_txt(cx, p.position.y + 432, "buy all upgrades first!", 18, Color("8d8d8d"))


func _resto_icon(c: Vector2) -> void:
	draw_circle(c, 62, Color("fde8c8"))
	draw_rect(Rect2(c.x - 40, c.y - 26, 80, 58), Color("fff6e4"))
	for i in 8:
		var col := Color("d6362f") if i % 2 == 0 else Color("fff6e4")
		draw_rect(Rect2(c.x - 44 + i * 11.0, c.y - 44, 11, 18), col)
	draw_rect(Rect2(c.x - 10, c.y + 6, 20, 26), Color("895b38"))
	draw_rect(Rect2(c.x - 34, c.y - 14, 18, 16), Color("9ad5f0"))
	draw_rect(Rect2(c.x + 16, c.y - 14, 18, 16), Color("9ad5f0"))


func _draw_renovate2() -> void:
	var p := RENO_P
	var cx := p.get_center().x
	var dark := Color("1d1d1f")
	draw_rect(Rect2(0, TOP, W, BOT - TOP), Color(0, 0, 0, 0.55))
	_rr(Rect2(p.position + Vector2(0, 5), p.size), Color(0, 0, 0, 0.15), 20)
	_rr(p, Color("f8f8fa"), 20)
	_rr(Rect2(RENO_X.position + Vector2(0, 3), RENO_X.size), Color("b8283d"), 8)
	_rr(RENO_X, Color("e8344f"), 8)
	var cc := RENO_X.get_center()
	draw_line(cc + Vector2(-8, -8), cc + Vector2(8, 8), Color.WHITE, 4.0)
	draw_line(cc + Vector2(-8, 8), cc + Vector2(8, -8), Color.WHITE, 4.0)
	_txt(cx, p.position.y + 46, "Renovate", 30, dark)
	_txt(cx, p.position.y + 100, "Time for a bigger kitchen!", 19, dark)
	var left := Rect2(p.position.x + 20, p.position.y + 118, 160, 190)
	var right := Rect2(p.end.x - 180, p.position.y + 118, 160, 190)
	var ccy := left.get_center().y
	for i in 2:
		var r := left if i == 0 else right
		_rr(r, Color("efeff2"), 14)
		_txt(r.get_center().x, r.position.y + 28, "Before" if i == 0 else "After", 18, dark)
		var ic := Vector2(r.get_center().x, r.position.y + 98)
		if i == 0:
			_stand_icon(ic, true)
		else:
			_resto_icon(ic)
		_txt(r.get_center().x, r.end.y - 14, "Food Stand" if i == 0 else "Restaurant", 16, dark)
	draw_polyline(PackedVector2Array([Vector2(cx - 6, ccy - 14), Vector2(cx + 6, ccy), Vector2(cx - 6, ccy + 14)]), Color("8d8d8d"), 4.0)
	var lvl_ok := _f_reno_ready()
	var ok := lvl_ok and coins >= R_COST
	_rr(Rect2(RENO_GO.position + Vector2(0, 5), RENO_GO.size), Color("4aa3e0") if ok else Color("9aa5ae"), 12)
	_rr(RENO_GO, Color("72c4f5") if ok else Color("c9ced4"), 12)
	if lvl_ok:
		_coin(RENO_GO.get_center() + Vector2(-34, 0), 14)
		_txt(RENO_GO.get_center().x + 24, RENO_GO.get_center().y + 10, _fmt_num(R_COST), 28, Color.WHITE if ok else Color("d4202f"))
	else:
		_txt(RENO_GO.get_center().x, RENO_GO.get_center().y + 10, "Upgrade", 28, Color.WHITE)
		_txt(cx, p.position.y + 408, "Max both stations and buy", 18, Color("8d8d8d"))
		_txt(cx, p.position.y + 432, "all upgrades first!", 18, Color("8d8d8d"))


func _draw_renovating() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.08, 0.09, 0.1, 1.0))
	var swing := PI / 4.0 + sin(t * 9.0) * 0.45
	_hammer(Vector2(W / 2.0, 380), swing, 3.0)
	_txt(W / 2.0, 500, "Renovating...", 36, Color.WHITE)
	var bar := Rect2(120, 540, 300, 20)
	var frac := clampf(reno_t / RENO_TIME, 0.0, 1.0)
	_rr(bar, Color("3a3d42"), 10)
	_rr(Rect2(bar.position, Vector2(maxf(20.0, bar.size.x * frac), 20)), Color("7be05a"), 10)


func _draw_test() -> void:
	draw_rect(Rect2(0, 0, W, H), Color.WHITE)
	_txt(W / 2.0, 470, "TEST", 72, Color("1d1d1f"))
	_rr(Rect2(TEST_BACK.position + Vector2(0, 5), TEST_BACK.size), Color("4aa3e0"), 14)
	_rr(TEST_BACK, Color("72c4f5"), 14)
	_txt(TEST_BACK.get_center().x, TEST_BACK.get_center().y + 10, "Back", 28, Color.WHITE)


func _draw_lemonade() -> void:
	var p := LVL_P
	var cx := p.get_center().x
	_rr(Rect2(p.position + Vector2(0, 5), p.size), Color(0, 0, 0, 0.15), 18)
	_rr(p, Color("f8f8fa"), 18)
	draw_colored_polygon(PackedVector2Array([Vector2(188, p.end.y - 4), Vector2(212, p.end.y - 4), Vector2(200, p.end.y + 12)]), Color("f8f8fa"))
	_txt(cx, p.position.y + 40, "Level %d" % level, 28, Color("2b2b2b"))
	_txt(cx, p.position.y + 66, "Lemonade", 20, Color("9a9a9a"))
	_star(Vector2(cx - 18, p.position.y + 92), 13, Color("f5b800") if level >= 5 else Color("dcdde2"))
	_star(Vector2(cx + 18, p.position.y + 92), 13, Color("f5b800") if level >= 10 else Color("dcdde2"))
	var lo := 0 if level < 5 else 5
	var hi := 5 if level < 5 else 10
	var frac := clampf(float(level - lo) / float(hi - lo), 0.0, 1.0)
	var bar := Rect2(p.position.x + 20, p.position.y + 118, p.size.x - 40, 22)
	_rr(bar, Color("e3e5ea"), 11)
	_rr(Rect2(bar.position, Vector2(maxf(22.0, bar.size.x * frac), 22)), Color("72c4f5"), 11)
	var dc := Vector2(bar.end.x - 14, bar.position.y + 11)
	draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -8), dc + Vector2(7, 0), dc + Vector2(0, 8), dc + Vector2(-7, 0)]), Color("9b6bd6"))
	var sy := p.position.y + 160
	_coin(Vector2(p.position.x + 36, sy), 12)
	_txtl(p.position.x + 52, sy + 9, str(_price()), 24, Color("5b5b5b"))
	var kc := Vector2(p.position.x + 128, sy)
	draw_arc(kc, 11, 0, TAU, 20, Color("8d8d8d"), 3.0)
	draw_line(kc, kc + Vector2(0, -7), Color("8d8d8d"), 2.5)
	draw_line(kc, kc + Vector2(5, 2), Color("8d8d8d"), 2.5)
	_txtl(p.position.x + 144, sy + 9, _fmt_time(_make_time()), 24, Color("5b5b5b"))
	var maxed := level >= MAX_LEVEL
	var cost: int = 0 if maxed else UP_COST[level - 1]
	var ok := (not maxed) and coins >= cost
	_rr(Rect2(LVL_BTN.position + Vector2(0, 4), LVL_BTN.size), Color("4aa3e0") if ok else Color("9aa5ae"), 10)
	_rr(LVL_BTN, Color("72c4f5") if ok else Color("b9c3cc"), 10)
	if maxed:
		_txt(LVL_BTN.get_center().x, LVL_BTN.get_center().y + 9, "MAX", 26, Color.WHITE)
	else:
		_coin(LVL_BTN.get_center() + Vector2(-16, 0), 12)
		_txt(LVL_BTN.get_center().x + 14, LVL_BTN.get_center().y + 10, str(cost), 28, Color.WHITE)


func _draw_upgrades() -> void:
	var p := UP_P
	draw_rect(Rect2(0, TOP, W, BOT - TOP), Color(0, 0, 0, 0.55))
	_rr(Rect2(p.position + Vector2(0, 5), p.size), Color(0, 0, 0, 0.15), 20)
	_rr(p, Color("f8f8fa"), 20)
	_txt(p.get_center().x, p.position.y + 48, "Upgrades", 32, Color("1d1d1f"))
	var cl := Rect2(p.end.x - 54, p.position.y + 12, 42, 42)
	_rr(Rect2(cl.position + Vector2(0, 3), cl.size), Color("b8283d"), 8)
	_rr(cl, Color("e8344f"), 8)
	var cc := cl.get_center()
	draw_line(cc + Vector2(-8, -8), cc + Vector2(8, 8), Color.WHITE, 4.0)
	draw_line(cc + Vector2(-8, 8), cc + Vector2(8, -8), Color.WHITE, 4.0)
	for i in UPGRADES.size():
		var u: Dictionary = UPGRADES[i]
		var id: String = u["id"]
		var cost: int = u["cost"]
		var r := _up_row(i)
		_rr(r, Color("e8e8ec"), 14)
		var ic := Vector2(r.position.x + 40, r.position.y + 44)
		match id:
			"customer", "popularity":
				_rr(Rect2(ic.x - 17, ic.y - 4, 34, 24), Color("e8486f"), 10)
				draw_circle(ic + Vector2(0, -10), 13, Color("f3c9a0"))
			"cashier":
				_rr(Rect2(ic.x - 17, ic.y - 4, 34, 24), Color("f2d94a"), 10)
				draw_circle(ic + Vector2(0, -10), 13, Color("f3c9a0"))
				draw_circle(ic + Vector2(0, -15), 13, Color("7a3b1e"))
			"income":
				_coin(ic, 20)
		_txtl(r.position.x + 78, r.position.y + 38, str(u["title"]), 20, Color("1d1d1f"))
		_txtl(r.position.x + 78, r.position.y + 62, str(u["sub"]), 15, Color("7a7a7a"))
		var b := _up_btn(i)
		if owned[id]:
			_rr(Rect2(b.position + Vector2(0, 4), b.size), Color("3f9b4f"), 10)
			_rr(b, Color("5fc873"), 10)
			_txt(b.get_center().x, b.get_center().y + 8, "Owned", 22, Color.WHITE)
		else:
			var ok := coins >= cost
			_rr(Rect2(b.position + Vector2(0, 4), b.size), Color("4aa3e0") if ok else Color("9aa5ae"), 10)
			_rr(b, Color("72c4f5") if ok else Color("c9ced4"), 10)
			_coin(b.position + Vector2(24, 23), 11)
			_txt(b.get_center().x + 14, b.get_center().y + 9, str(cost), 24, Color.WHITE if ok else Color("d4202f"))


# ================================================================ FOOD STAND
const F_MAX_LEVEL := 75
const F_BUY := [5, 50]
const F_SLOT_X := [270.0, 209.0, 389.0, 150.0, 329.0]
const F_CUST_Y := 518.0
const F_SERVE_Y := 612.0
const F_SPOTS := [[Vector2(208, 765), Vector2(208, 808)], [Vector2(329, 768), Vector2(385, 768)], [Vector2(329, 660), Vector2(385, 660)]]
const F_BUY_RECT := [Rect2(120, 709, 60, 50), Rect2(361, 814, 59, 50), Rect2(361, 684, 59, 50)]
const F_UPS := [
	{"id": "friends", "title": "Text your friends", "sub": "+1 Customer", "cost": 13, "ic": "cust"},
	{"id": "raymond", "title": "Hire Raymond", "sub": "+1 Cashier", "cost": 18, "ic": "cash"},
	{"id": "flyers", "title": "Hand out flyers", "sub": "+1 Customer", "cost": 80, "ic": "cust"},
	{"id": "equip", "title": "Faster Soda", "sub": "Soda is made faster", "cost": 500, "ic": "sodafast"},
	{"id": "referral", "title": "Hire Raymond's referral", "sub": "+1 Cashier", "cost": 1000, "ic": "cash"},
	{"id": "social", "title": "Post on social media", "sub": "+1 Customer", "cost": 2500, "ic": "cust"},
	{"id": "batches", "title": "Make in batches", "sub": "Soda profit x2", "cost": 3500, "ic": "sodaprofit"},
	{"id": "tutorial", "title": "Faster Hot Dog", "sub": "Hot Dog is made faster", "cost": 5000, "ic": "dogfast"},
	{"id": "shoes", "title": "Better shoes", "sub": "Cashiers walk faster", "cost": 8000, "ic": "shoe"},
	{"id": "advert", "title": "Post a job advert", "sub": "+1 Cashier", "cost": 10000, "ic": "cash"},
	{"id": "vocal", "title": "Be vocal", "sub": "+1 Customer", "cost": 18000, "ic": "cust"},
	{"id": "bbq", "title": "BBQ Sauce", "sub": "Hot Dog profit x2", "cost": 35000, "ic": "dogprofit"},
]
const FUP_P := Rect2(40, 334, 460, 494)
const FUP_X := Rect2(429, 345, 58, 56)
const FUP_LIST := Rect2(48, 418, 444, 400)
const F_ROW := 90.0
const F_SCROLL_MAX := 12.0 * 90.0 - 8.0 - 400.0
const FINTRO_P := Rect2(100, 330, 340, 330)
const FINTRO_BTN := Rect2(150, 540, 240, 60)

# Map 3: Restaurant (food truck renovation)
const R_COST := 5000
const R_BUY := [5, 250, 12500] # Fries, Wrap, Milk Shake
const R_UPS := [
	{"id": "friends", "title": "Say 'Come Again'", "sub": "+1 Customer", "cost": 40, "ic": "cust"},
	{"id": "raymond", "title": "Hire Sean's brother", "sub": "+1 Cashier", "cost": 60, "ic": "cash"},
	{"id": "flyers", "title": "Hand out flyers", "sub": "+1 Customer", "cost": 300, "ic": "cust"},
	{"id": "equip", "title": "Faster Fries", "sub": "Fries are made faster", "cost": 2000, "ic": "sodafast"},
	{"id": "referral", "title": "Hire Sean's cousin", "sub": "+1 Cashier", "cost": 4000, "ic": "cash"},
	{"id": "social", "title": "Post on social media", "sub": "+1 Customer", "cost": 10000, "ic": "cust"},
	{"id": "batches", "title": "Extra ketchup", "sub": "Fries profit x3", "cost": 14000, "ic": "sodaprofit"},
	{"id": "tutorial", "title": "Faster Wrap", "sub": "Wrap is made faster", "cost": 20000, "ic": "wrapfast"},
	{"id": "shoes", "title": "Better shoes", "sub": "Cashiers walk faster", "cost": 32000, "ic": "shoe"},
	{"id": "advert", "title": "Hire Sean's uncle", "sub": "+1 Cashier", "cost": 40000, "ic": "cash"},
	{"id": "vocal", "title": "Be vocal", "sub": "+1 Customer", "cost": 72000, "ic": "cust"},
	{"id": "bbq", "title": "Secret recipe", "sub": "Wrap profit x2", "cost": 140000, "ic": "wrapprofit"},
	{"id": "wrapfast", "title": "Faster Milk Shake", "sub": "Milk Shake is made faster", "cost": 25000000, "ic": "dogfast"},
	{"id": "wrapprofit", "title": "Extra sprinkles", "sub": "Milk Shake profit x2", "cost": 60000000, "ic": "dogprofit"},
]
var r_done := false # true once the food truck has been renovated into the restaurant

var f_open := false
var f_stage := 0 # 0 nothing, 1 soda, 2 soda + hot dog
var f_lvl := [1, 1, 1]
var f_up := {"friends": false, "raymond": false, "flyers": false, "equip": false, "referral": false, "social": false, "batches": false, "tutorial": false, "shoes": false, "advert": false, "vocal": false, "bbq": false, "wrapfast": false, "wrapprofit": false}
var f_workers: Array = []
var f_customers: Array = []
var f_spawn := 1.0
var f_busy := [[false, false], [false, false], [false, false]]
var f_scroll := 0.0
var f_drag := false
var f_drag_moved := false
var f_drag_start := Vector2.ZERO
var f_scroll_start := 0.0
var f_target := 0 # station shown in the unlock / level popup
var f_cars: Array = []
var f_car_timer := 2.0
var up_clip: Control
var up_list: Control


func _f_make_clip() -> void:
	up_clip = Control.new()
	up_clip.position = FUP_LIST.position
	up_clip.size = FUP_LIST.size
	up_clip.clip_contents = true
	up_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	up_clip.visible = false
	add_child(up_clip)
	up_list = Control.new()
	up_list.size = FUP_LIST.size
	up_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	up_list.draw.connect(_draw_up_rows)
	up_clip.add_child(up_list)


func _fmt_num(n: int) -> String:
	# 1000 = 1K, 1 million = 1M, 1 billion = 1B, then T, Qa, Qi
	if n < 1000:
		return str(n)
	var suf := ["K", "M", "B", "T", "Qa", "Qi"]
	var v := float(n)
	var i := -1
	while v >= 1000.0 and i < suf.size() - 1:
		v /= 1000.0
		i += 1
	v = snappedf(v, 0.1)
	if v >= 1000.0 and i < suf.size() - 1:
		v /= 1000.0
		i += 1
	var t := str(v)
	if t.ends_with(".0"):
		t = t.substr(0, t.length() - 2)
	return t + str(suf[i])


func _ups() -> Array:
	return R_UPS if r_done else F_UPS


func _f_buy_cost(k: int) -> int:
	return R_BUY[k] if r_done else F_BUY[k]


func _n_items() -> int:
	return 3 if r_done else 2


func _item_name(k: int) -> String:
	if r_done:
		return ["Fries", "Wrap", "Milk Shake"][k]
	return ["Soda", "Hot Dog"][k]


func _all_f_owned(arr: Array) -> bool:
	for u in arr:
		if not f_up[u["id"]]:
			return false
	return true


# you must max every station and own every upgrade to move on to the next map
func _f_reno_ready() -> bool:
	if f_stage < 2 or f_lvl[0] < F_MAX_LEVEL or f_lvl[1] < F_MAX_LEVEL:
		return false
	return _all_f_owned(F_UPS)


func _r_maxed() -> bool:
	if f_stage < 3 or f_lvl[0] < F_MAX_LEVEL or f_lvl[1] < F_MAX_LEVEL or f_lvl[2] < F_MAX_LEVEL:
		return false
	return _all_f_owned(R_UPS)


func _reno_ready() -> bool:
	if level < RENO_LEVEL:
		return false
	for u in UPGRADES:
		if not owned[u["id"]]:
			return false
	return true


func _scroll_max() -> float:
	return float(_ups().size()) * F_ROW - 8.0 - 400.0


# ---------------------------------------------------------------- numbers
func _f_price(k: int) -> int:
	var lv: int = f_lvl[k]
	var base: int = 2 + lv if k == 0 else 4 + int(1.5 * lv)
	if r_done:
		base = [5 + 2 * lv, 9 + 3 * lv, 12000 + 400 * (lv - 1)][k]
	var m := 1
	if k == 0 and f_up["batches"]:
		m = 3 if r_done else 2
	if k == 1 and f_up["bbq"]:
		m = 2
	if k == 2 and f_up["wrapprofit"]:
		m = 2
	var milestones: int = mini(lv / 25, 3) # each filled bar / star doubles the price
	return base * m * (1 << milestones)


func _f_time(k: int) -> float:
	# the make time is fixed for the whole map: levels do not change it,
	# only the "Faster ..." upgrades do
	var t0: float = float([2.5, 3.0, 4.0][k]) if r_done else float([2.0, 3.0][k])
	if k == 0 and f_up["equip"]:
		t0 *= 0.6
	if k == 1 and f_up["tutorial"]:
		t0 *= 0.6
	if k == 2 and f_up["wrapfast"]:
		t0 *= 0.6
	return maxf(0.4, t0)


func _f_level_cost(k: int) -> int:
	var lv: int = f_lvl[k]
	var c := 3.0 + 0.9 * pow(float(lv), 1.9)
	return int(c * float([1.0, 1.5, 2.2][k]) * (3.0 if r_done else 1.0) * (300.0 if r_done and k == 2 else 1.0))


func _f_max_cust() -> int:
	return 1 + int(f_up["friends"]) + int(f_up["flyers"]) + int(f_up["social"]) + int(f_up["vocal"])


func _f_max_workers() -> int:
	return 1 + int(f_up["raymond"]) + int(f_up["referral"]) + int(f_up["advert"])


func _f_units() -> int:
	return mini(2, f_workers.size())


func _f_speed() -> float:
	return SPEED * (1.5 if f_up["shoes"] else 1.0)


func _f_can_level(k: int) -> bool:
	return f_stage > k and f_lvl[k] < F_MAX_LEVEL and coins >= _f_level_cost(k)


func _f_any_affordable() -> bool:
	for u in _ups():
		if not f_up[u["id"]] and coins >= int(u["cost"]):
			return true
	return false


# ---------------------------------------------------------------- setup
func _f_make_worker(idx: int, pos: Vector2) -> Dictionary:
	var w := _make_worker(idx, pos)
	w["hair"] = Color("ee4566") if idx != 1 else Color("a8322a")
	w["body"] = Color("e6e6e6") if idx != 1 else Color("f2d94a")
	w["item"] = 0
	w["qty"] = 1
	w["spot"] = -1
	return w


func _f_setup() -> void:
	workers = []
	customers = []
	f_customers = []
	f_busy = [[false, false], [false, false], [false, false]]
	f_workers = [_f_make_worker(0, Vector2(270, F_SERVE_Y))]
	for i in range(1, _f_max_workers()):
		f_workers.append(_f_make_worker(i, Vector2(270 + 40 * i, F_SERVE_Y)))
	f_spawn = 1.0


func _f_start() -> void:
	# renovation finished: new stand, fresh money
	renovated = true
	f_open = false
	f_stage = 0
	f_lvl = [1, 1, 1]
	for k in f_up:
		f_up[k] = false
	coins = 5
	popup = "food_intro"
	_f_setup()
	_save()


# ---------------------------------------------------------------- update
func _r_start() -> void:
	# truck renovated into the restaurant: fresh money, fresh stations
	r_done = true
	reno_t = 0.0
	f_open = false
	f_stage = 0
	f_lvl = [1, 1, 1]
	for k in f_up:
		f_up[k] = false
	f_cars = []
	coins = 5
	popup = "food_intro"
	_f_setup()
	_save()


func _f_process(delta: float) -> void:
	if popup == "renovating2":
		reno_t += delta
		if reno_t >= RENO_TIME:
			_r_start()
		return
	up_clip.visible = popup == "fup"
	if up_clip.visible:
		up_list.queue_redraw()
	# hire workers bought as upgrades
	while f_workers.size() < _f_max_workers():
		f_workers.append(_f_make_worker(f_workers.size(), Vector2(450, 640)))
	for w in f_workers:
		_f_move(w, delta)
	_f_update_customers(delta)
	for w in f_workers:
		_f_ai(w, delta)
	_f_update_cars(delta)
	_update_fx(delta)


func _f_move(w: Dictionary, delta: float) -> void:
	var pos: Vector2 = w["pos"]
	var to: Vector2 = w["target"] - pos
	w["moving"] = to.length() > 4.0
	if w["moving"]:
		pos += to.normalized() * minf(_f_speed() * delta, to.length())
	w["pos"] = pos


func _f_slot_free(i: int) -> bool:
	for c in f_customers:
		if c["slot"] == i:
			return false
	return true


func _f_new_customer() -> void:
	var slot := -1
	for i in _f_max_cust():
		if _f_slot_free(i):
			slot = i
			break
	if slot < 0:
		return
	var hairs := [Color("8e642a"), Color("2f2622"), Color("9a9a9a"), Color("5a3a22")]
	var bodies := [Color("6aa0e6"), Color("56b36b"), Color("e8913a"), Color("9b6bd6")]
	var sx := -40.0 if randf() < 0.5 else W + 40.0
	var dx: float = F_SLOT_X[slot]
	var item := 0
	if r_done and f_stage >= 2:
		item = randi() % f_stage
	elif f_stage >= 2 and randf() < 0.5:
		item = 1
	f_customers.append({
		"pos": Vector2(sx, 405), "slot": slot, "state": "in", "claimed": false,
		"item": item, "qty": 1 if randf() < 0.7 else 2,
		"hair": hairs[randi() % hairs.size()], "body": bodies[randi() % bodies.size()],
		"moving": true, "path": [Vector2(dx, 405), Vector2(dx, F_CUST_Y)],
	})


func _f_update_customers(delta: float) -> void:
	for i in range(f_customers.size() - 1, -1, -1):
		var c: Dictionary = f_customers[i]
		var path: Array = c["path"]
		if path.size() > 0:
			var pos: Vector2 = c["pos"]
			var dest: Vector2 = path[0]
			pos = pos.move_toward(dest, 150.0 * delta)
			c["pos"] = pos
			c["moving"] = true
			if pos.distance_to(dest) < 1.0:
				path.remove_at(0)
		else:
			c["moving"] = false
			if c["state"] == "in":
				c["state"] = "wait"
			elif c["state"] == "out":
				f_customers.remove_at(i)
	if f_customers.size() < _f_max_cust():
		f_spawn -= delta
		if f_spawn <= 0.0:
			_f_new_customer()
			f_spawn = 1.0


func _f_free_spot(k: int) -> int:
	if f_stage <= k:
		return -1
	for s in _f_units():
		if not f_busy[k][s]:
			return s
	return -1


func _f_cust_pos(c: Dictionary) -> Vector2:
	return Vector2(F_SLOT_X[c["slot"]], F_SERVE_Y)


func _f_ai(w: Dictionary, delta: float) -> void:
	match w["task"]:
		"idle":
			if f_stage < 1:
				return
			for c in f_customers:
				if c["state"] == "wait" and not c["claimed"]:
					var k: int = c["item"]
					var s := _f_free_spot(k)
					if s < 0:
						continue
					c["claimed"] = true
					f_busy[k][s] = true
					w["cust"] = c
					w["item"] = k
					w["qty"] = c["qty"]
					w["spot"] = s
					w["task"] = "to_customer"
					w["target"] = _f_cust_pos(c)
					break
		"to_customer":
			if _arrived(w):
				w["task"] = "reading"
				w["t"] = 0.0
		"reading":
			w["t"] += delta
			if w["t"] >= 0.6:
				var spots: Array = F_SPOTS[w["item"]]
				w["task"] = "to_machine"
				w["target"] = spots[w["spot"]]
		"to_machine":
			if _arrived(w):
				w["task"] = "making"
				w["t"] = 0.0
		"making":
			w["t"] += delta
			if w["t"] >= _f_make_time(w):
				w["t"] = 0.0
				f_busy[w["item"]][w["spot"]] = false
				w["carrying"] = true
				w["task"] = "to_deliver"
				w["target"] = _f_cust_pos(w["cust"])
		"to_deliver":
			if _arrived(w):
				_f_serve(w)
				w["task"] = "idle"


func _f_make_time(w: Dictionary) -> float:
	return _f_time(w["item"]) * (1.0 if w["qty"] == 1 else 1.6)


func _f_serve(w: Dictionary) -> void:
	w["carrying"] = false
	var c: Dictionary = w["cust"]
	w["cust"] = null
	var cpos: Vector2 = c["pos"]
	var dx: float = F_SLOT_X[c["slot"]]
	var ex := -60.0 if dx < 270.0 else W + 60.0
	c["state"] = "out"
	c["slot"] = -1
	c["path"] = [Vector2(dx, 405), Vector2(ex, 405)]
	f_spawn = minf(f_spawn, 1.2)
	var gain: int = _f_price(w["item"]) * int(w["qty"])
	coins += gain
	_float_text(cpos + Vector2(0, -60), "+" + _fmt_num(gain))
	_save()
	Input.vibrate_handheld(25)


func _f_update_cars(delta: float) -> void:
	f_car_timer -= delta
	if f_car_timer <= 0.0:
		f_car_timer = randf_range(6.0, 12.0)
		var cols := [Color("faec4d"), Color("4a6fb5"), Color("d9483b")]
		var right := randf() < 0.5
		f_cars.append({"x": -70.0 if right else W + 70.0, "dir": 1.0 if right else -1.0, "col": cols[randi() % cols.size()]})
	for i in range(f_cars.size() - 1, -1, -1):
		var c: Dictionary = f_cars[i]
		c["x"] += c["dir"] * 110.0 * delta
		if c["x"] < -90.0 or c["x"] > W + 90.0:
			f_cars.remove_at(i)


# ---------------------------------------------------------------- input
func _f_press(p: Vector2) -> void:
	if GEAR.grow(8.0).has_point(p):
		popup = "settings"
		return
	if reno_unlocked and RENO_BTN.grow(6.0).has_point(p):
		if r_done:
			if _r_maxed():
				popup = "test"
			else:
				_float_text(Vector2(270, 500), "Max everything first!")
		else:
			popup = "renovate2"
		return
	if f_stage >= 1 and OPEN_BTN.grow(6.0).has_point(p):
		popup = "fup"
		f_scroll = 0.0
		return
	for k in _n_items():
		if f_stage == k and F_BUY_RECT[k].grow(10.0).has_point(p):
			f_target = k
			popup = "funlock"
			return
	if f_stage >= 1 and _f_table(0).grow(8.0).has_point(p):
		f_target = 0
		popup = "flevel"
	elif f_stage >= 2 and _f_table(1).grow(8.0).has_point(p):
		f_target = 1
		popup = "flevel"
	elif f_stage >= 3 and _f_table(2).grow(8.0).has_point(p):
		f_target = 2
		popup = "flevel"


func _f_table(k: int) -> Rect2:
	if k == 0:
		return Rect2(120, 683, 60, 125 + 53 * (_f_units() - 1))
	if k == 2:
		return Rect2(300, 680, 120, 60)
	return Rect2(300, 790, 120, 74)


func _f_lvl_rect() -> Rect2:
	if f_target == 2:
		return Rect2(200, 420, 226, 235)
	return Rect2(196, 590, 226, 235) if f_target == 0 else Rect2(200, 520, 226, 235)


func _f_unlock_rect() -> Rect2:
	var r: Rect2 = F_BUY_RECT[f_target]
	return Rect2(clampf(r.get_center().x - 109.0, 10.0, W - 228.0), r.position.y - 150.0, 218, 128)


func _f_unlock_btn() -> Rect2:
	var r := _f_unlock_rect()
	return Rect2(r.position.x + 12, r.position.y + 44, 194, 70)


func _f_buy(k: int) -> void:
	var cost: int = _f_buy_cost(k)
	if coins < cost:
		_float_text(Vector2(270, 520), "Not enough coins")
		return
	coins -= cost
	f_stage = k + 1
	popup = ""
	_spawn_confetti()
	_save()


func _f_level_up(k: int) -> void:
	if f_lvl[k] >= F_MAX_LEVEL:
		return
	var cost := _f_level_cost(k)
	if coins >= cost:
		coins -= cost
		f_lvl[k] += 1
		_float_text(Vector2(270, 500), "Level %d!" % f_lvl[k])
		_save()
	else:
		_float_text(Vector2(270, 500), "Not enough coins")


func _f_buy_up(i: int) -> void:
	var u: Dictionary = _ups()[i]
	var id: String = u["id"]
	if f_up[id] or coins < int(u["cost"]):
		return
	coins -= int(u["cost"])
	f_up[id] = true
	_spawn_confetti()
	_save()


func _f_popup_press(p: Vector2) -> void:
	match popup:
		"renovate2":
			if RENO_X.has_point(p):
				popup = ""
			elif RENO_GO.has_point(p):
				if _f_reno_ready() and coins >= R_COST:
					coins -= R_COST
					popup = "renovating2"
					reno_t = 0.0
					_save()
			elif not RENO_P.has_point(p):
				popup = ""
		"food_intro":
			if FINTRO_BTN.has_point(p):
				f_open = true
				popup = ""
				_save()
		"funlock":
			if _f_unlock_btn().has_point(p):
				_f_buy(f_target)
			elif not _f_unlock_rect().has_point(p):
				popup = ""
		"flevel":
			var r := _f_lvl_rect()
			if Rect2(r.position.x + 20, r.position.y + 182, 186, 40).has_point(p):
				_f_level_up(f_target)
			elif not r.has_point(p):
				popup = ""
		"fup":
			if FUP_X.has_point(p):
				popup = ""
			elif FUP_LIST.has_point(p):
				f_drag = true
				f_drag_moved = false
				f_drag_start = p
				f_scroll_start = f_scroll
			elif not FUP_P.has_point(p):
				popup = ""


func _f_drag(p: Vector2) -> void:
	var dy := p.y - f_drag_start.y
	if absf(dy) > 8.0:
		f_drag_moved = true
	if f_drag_moved:
		f_scroll = clampf(f_scroll_start - dy, 0.0, _scroll_max())


func _f_release(p: Vector2) -> void:
	if not f_drag:
		return
	f_drag = false
	if f_drag_moved or popup != "fup":
		return
	var loc := Vector2(f_drag_start.x - FUP_LIST.position.x, f_drag_start.y - FUP_LIST.position.y + f_scroll)
	var i := int(floor(loc.y / F_ROW))
	if i >= 0 and i < _ups().size():
		if Rect2(320, i * F_ROW + 11.0, 112, 57).grow(4.0).has_point(loc):
			_f_buy_up(i)


# ---------------------------------------------------------------- food draw helpers
func _soda(c: Vector2, s: float = 1.0) -> void:
	var w := 14.0 * s
	var h := 22.0 * s
	cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-w / 2, -h), c + Vector2(w / 2, -h), c + Vector2(w * 0.38, 0), c + Vector2(-w * 0.38, 0)]), Color("f4f4f2"))
	cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 0.45, -h * 0.72), c + Vector2(w * 0.45, -h * 0.72), c + Vector2(w * 0.4, -h * 0.12), c + Vector2(-w * 0.4, -h * 0.12)]), Color("d6212f"))
	cv.draw_rect(Rect2(c.x - w * 0.55, c.y - h - 3.0 * s, w * 1.1, 4.0 * s), Color("3a3a3c"))
	cv.draw_line(c + Vector2(1.0 * s, -h - 3.0 * s), c + Vector2(5.0 * s, -h - 12.0 * s), Color("d6212f"), 2.4 * s)


func _hotdog(c: Vector2, s: float = 1.0) -> void:
	_rr(Rect2(c.x - 14.0 * s, c.y - 6.0 * s, 28.0 * s, 13.0 * s), Color("e8a23a"), 6)
	_rr(Rect2(c.x - 16.0 * s, c.y - 3.0 * s, 32.0 * s, 7.0 * s), Color("c8392b"), 3)
	cv.draw_line(c + Vector2(-9.0 * s, 0), c + Vector2(9.0 * s, 0), Color("f2c230"), 1.8 * s)


func _fries(c: Vector2, s: float = 1.0) -> void:
	for i in 5:
		var x := c.x + (-8.0 + i * 4.0) * s
		cv.draw_line(Vector2(x, c.y - 3.0 * s), Vector2(x + (i - 2) * 1.2 * s, c.y - 14.0 * s), Color("f2c230"), 3.2 * s)
	cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -4) * s, c + Vector2(10, -4) * s, c + Vector2(7, 11) * s, c + Vector2(-7, 11) * s]), Color("d6212f"))
	cv.draw_rect(Rect2(c.x - 9.0 * s, c.y - 1.0 * s, 18.0 * s, 3.0 * s), Color("f2c230"))


func _shake(c: Vector2, s: float = 1.0) -> void:
	cv.draw_line(c + Vector2(2, -10) * s, c + Vector2(7, -22) * s, Color("d6212f"), 2.6 * s)
	cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -9) * s, c + Vector2(9, -9) * s, c + Vector2(6, 12) * s, c + Vector2(-6, 12) * s]), Color("f4a6b8"))
	cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -9) * s, c + Vector2(9, -9) * s, c + Vector2(8, -2) * s, c + Vector2(-8, -2) * s]), Color("fffaf0"))
	cv.draw_circle(c + Vector2(0, -11) * s, 6.0 * s, Color.WHITE)
	cv.draw_circle(c + Vector2(0, -16) * s, 2.6 * s, Color("d6212f"))


func _wrap(c: Vector2, s: float = 1.0) -> void:
	cv.draw_circle(c + Vector2(-4, -6) * s, 6.0 * s, Color("6bd65a"))
	cv.draw_circle(c + Vector2(4, -8) * s, 6.0 * s, Color("4caf50"))
	cv.draw_circle(c + Vector2(0, -11) * s, 4.0 * s, Color("e8a23a"))
	cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -3) * s, c + Vector2(9, -3) * s, c + Vector2(6, 12) * s, c + Vector2(-6, 12) * s]), Color("d6212f"))


func _item(k: int, c: Vector2, s: float) -> void:
	if r_done:
		match k:
			0:
				_fries(c, s)
			1:
				_wrap(c, s)
			_:
				_shake(c, s)
		return
	if k == 0:
		_soda(c + Vector2(0, 11.0 * s), s)
	else:
		_hotdog(c, s)


func _pie(c: Vector2, r: float, frac: float) -> void:
	cv.draw_circle(c, r, Color("6b6d70"))
	if frac < 0.04:
		return
	var pts := PackedVector2Array([c])
	var n := maxi(3, int(frac * 32.0))
	for i in n + 1:
		var a := -PI / 2.0 + TAU * frac * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * (r - 2.0))
	cv.draw_colored_polygon(pts, Color("30fd10"))


func _umbrella(c: Vector2, r: float, shadow: Vector2, sr: float) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		pts.append(shadow + Vector2.from_angle(i * TAU / 9.0 + 0.3) * sr)
	draw_colored_polygon(pts, Color("59954d"))
	for i in 16:
		var a0 := i * TAU / 16.0
		var a1 := (i + 1) * TAU / 16.0
		var col := Color("7fb2f5") if i % 2 == 0 else Color("fffbe0")
		draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0) * r, c + Vector2.from_angle(a1) * r]), col)


func _car(x: float, dir: float, col: Color) -> void:
	var c := Vector2(x, 262.0)
	draw_rect(Rect2(c.x - 40, c.y + 22, 86, 10), Color(0, 0, 0, 0.18))
	_rr(Rect2(c.x - 42, c.y - 14, 84, 38), col, 7)
	_rr(Rect2(c.x - 26, c.y - 30, 50, 24), col.lightened(0.15), 6)
	draw_rect(Rect2(c.x - 20, c.y - 24, 18, 11), Color("f2f2f4"))
	draw_rect(Rect2(c.x + 2, c.y - 24, 18, 11), Color("f2f2f4"))
	draw_circle(Vector2(c.x - 26, c.y + 24), 5, Color("1d1d1f"))
	draw_circle(Vector2(c.x + 28, c.y + 24), 5, Color("1d1d1f"))


func _badge(c: Vector2) -> void:
	draw_circle(c, 15, Color("e8344f"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(-8, 0), c + Vector2(8, 0)]), Color.WHITE)
	draw_rect(Rect2(c.x - 3, c.y, 6, 8), Color.WHITE)


# ---------------------------------------------------------------- food world
func _f_draw_world() -> void:
	draw_rect(Rect2(0, TOP, W, BOT - TOP), Color("d0d0d2"))
	draw_rect(Rect2(0, 144, W, 200), Color("909090"))
	draw_line(Vector2(0, 144), Vector2(W, 144), Color("7f7f80"), 2)
	for s in [[148, 10], [184, 26], [236, 26], [288, 26], [340, 4]]:
		draw_rect(Rect2(174, s[0], 168, s[1]), Color("c7c7c9"))
	draw_rect(Rect2(10, 266, 3, 78), Color("b4b4b6"))
	for car in f_cars:
		_car(car["x"], car["dir"], car["col"])
	draw_rect(Rect2(0, 446, W, BOT - 446), Color("7bb96c"))
	if not r_done:
		draw_rect(Rect2(120, 446, 300, 418), Color("c5c5c5"))
	if r_done:
		_r_decor()
	# bush + tree
	draw_rect(Rect2(0, 418, 64, 97), Color("65b433"))
	draw_rect(Rect2(0, 418, 64, 47), Color("7edc40"))
	_rr(Rect2(512, 535, 28, 60), Color("6a3833"), 2)
	draw_colored_polygon(PackedVector2Array([Vector2(445, 390), Vector2(500, 325), Vector2(540, 320), Vector2(540, 560), Vector2(470, 525), Vector2(440, 450)]), Color("64c223"))
	draw_colored_polygon(PackedVector2Array([Vector2(445, 390), Vector2(500, 325), Vector2(525, 360), Vector2(470, 445)]), Color("78d03e"))
	if not r_done:
		# sign
		draw_set_transform(Vector2(110, 436), -0.2, Vector2.ONE)
		draw_rect(Rect2(-28, -38, 56, 76), Color("885b39"))
		draw_rect(Rect2(-21, -31, 42, 56), Color("f4efe6"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_hotdog(Vector2(110, 436), 0.9)
		# umbrellas
		_umbrella(Vector2(67, 574), 67.0, Vector2(64, 665), 54.0)
		_umbrella(Vector2(460, 624), 72.0, Vector2(476, 727), 62.0)
	# customers
	for c in f_customers:
		_person(c["pos"], c["hair"], c["body"], true, sin(t * 14.0) * 2.0 if c["moving"] else 0.0)
	# counter: yellow + white table
	var sh := Color(0, 0, 0, 0.2)
	draw_rect(Rect2(125, 589, 300, 14), sh)
	draw_rect(Rect2(123, 532, 177, 48), Color("fce58e"))
	draw_rect(Rect2(123, 580, 177, 9), Color("e0bb70"))
	draw_rect(Rect2(305, 532, 115, 48), Color("fffbf2"))
	draw_rect(Rect2(305, 580, 115, 9), Color("d0d0c8"))
	for lx in [126.0, 283.0, 308.0]:
		_rr(Rect2(lx, 589, 12, 10), Color("895d3e"), 2)
	for c in f_customers:
		if c["state"] == "wait":
			var bp: Vector2 = c["pos"] + Vector2(38, -44)
			draw_colored_polygon(PackedVector2Array([bp + Vector2(-27, 6), bp + Vector2(-10, 24), bp + Vector2(-34, 32)]), Color.WHITE)
			draw_circle(bp, 29, Color("2b2b2b"))
			draw_circle(bp, 27, Color.WHITE)
			_item(c["item"], bp, 1.2)
			draw_circle(bp + Vector2(15, 14), 9, Color("6b6d70"))
			_txt(bp.x + 15, bp.y + 19, str(c["qty"]), 14, Color.WHITE)
	_f_draw_stations()
	for w in f_workers:
		var wp: Vector2 = w["pos"]
		_person(wp, w["hair"], w["body"], false, sin(t * 16.0) * 2.0 if w["moving"] else 0.0)
		if w["carrying"]:
			_item(w["item"], wp + Vector2(0, -56), 1.3)
			var val: int = _f_price(w["item"]) * int(w["qty"])
			_coin(wp + Vector2(-16, -84), 8)
			_txtl(wp.x - 6, wp.y - 78, _fmt_num(val), 16, Color.WHITE)
		if w["task"] == "making":
			_pie(wp + Vector2(0, -62), 14.0, clampf(float(w["t"]) / _f_make_time(w), 0.0, 1.0))
	for f in floaters:
		var a := 1.0 - float(f["t"]) / 1.2
		_txt(f["p"].x + 1, f["p"].y + 2, f["s"], 26, Color(0, 0, 0, a * 0.5))
		_txt(f["p"].x, f["p"].y, f["s"], 26, Color(1.0, 0.85, 0.15, a))
	for c in confetti:
		draw_set_transform(c["p"], c["r"], Vector2.ONE)
		var s: Vector2 = c["s"]
		draw_rect(Rect2(-s.x / 2.0, -s.y / 2.0, s.x, s.y), c["c"])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _r_decor() -> void:
	# white truck body with a wooden floor and wheels, like in the video
	draw_rect(Rect2(108, 526, 336, 372), Color(0, 0, 0, 0.14))
	_rr(Rect2(100, 520, 336, 366), Color("f4f4f2"), 8)
	draw_rect(Rect2(112, 589, 312, 285), Color("f0d3a8"))
	for y in range(615, 874, 30):
		draw_line(Vector2(112, y), Vector2(424, y), Color(0, 0, 0, 0.06), 2.0)
	for sx in [210.0, 330.0]:
		_rr(Rect2(sx - 34, 868, 68, 38), Color("1d1d1f"), 14)
		draw_circle(Vector2(sx, 888), 9, Color("8a8a8e"))
	_rr(Rect2(190, 860, 150, 12), Color("ffffff"), 4)
	draw_rect(Rect2(112, 556, 8, 30), Color("1d1d1f"))
	draw_rect(Rect2(112, 596, 8, 30), Color("1d1d1f"))


func _f_buy_spot(k: int) -> void:
	var r: Rect2 = F_BUY_RECT[k]
	draw_rect(r, Color(1, 1, 1, 0.35))
	var a := r.position
	var b := r.end
	var col := Color(1, 1, 1, 0.95)
	draw_dashed_line(a, Vector2(b.x, a.y), col, 2.5, 6.0)
	draw_dashed_line(Vector2(b.x, a.y), b, col, 2.5, 6.0)
	draw_dashed_line(b, Vector2(a.x, b.y), col, 2.5, 6.0)
	draw_dashed_line(Vector2(a.x, b.y), a, col, 2.5, 6.0)
	_badge(Vector2(a.x + 9, a.y - 17 + sin(t * 4.0) * 3.0))


func _f_draw_stations() -> void:
	var n := _f_units()
	if f_stage < 1:
		_f_buy_spot(0)
		return
	# soda table: yellow top, brown front, one machine per cashier (max 2)
	var h := 125.0 + 53.0 * (n - 1)
	draw_rect(Rect2(124, 689, 62, h), Color(0, 0, 0, 0.16))
	draw_rect(Rect2(120, 683, 60, h - 19.0), Color("fde293"))
	draw_rect(Rect2(120, 683 + h - 19.0, 60, 19), Color("895b38"))
	if r_done:
		_fries(Vector2(150, 712), 1.5)
	else:
		_soda(Vector2(150, 722), 1.1)
	for i in n:
		var y := 727.0 + 53.0 * i
		draw_rect(Rect2(128, y, 30, 46), Color("fffedc"))
		draw_rect(Rect2(128, y + 32, 30, 10), Color("c83b50"))
		draw_rect(Rect2(160, y + 6, 9, 9), Color("1d1d1f"))
		draw_rect(Rect2(160, y + 22, 9, 9), Color("1d1d1f"))
	if _f_can_level(0) and popup == "":
		_badge(Vector2(129, 692))
	if f_stage < 2:
		_f_buy_spot(1)
		return
	# hot dog table
	draw_rect(Rect2(304, 796, 120, 74), Color(0, 0, 0, 0.16))
	draw_rect(Rect2(300, 790, 120, 59), Color("fde293"))
	draw_rect(Rect2(300, 849, 120, 15), Color("895c3c"))
	for i in n:
		var x := 307.0 + 55.0 * i
		draw_rect(Rect2(x, 787, 45, 58), Color("fffbf2"))
		draw_rect(Rect2(x + 4, 791, 37, 26), Color("363636"))
		draw_rect(Rect2(x + 4, 822, 37, 8), Color("e6c84a"))
	if n < 2:
		if r_done:
			_wrap(Vector2(392, 820), 1.5)
		else:
			_hotdog(Vector2(392, 820), 1.5)
	if _f_can_level(1) and popup == "":
		_badge(Vector2(369, 794))
	if not r_done:
		return
	if f_stage < 3:
		_f_buy_spot(2)
		return
	draw_rect(Rect2(304, 686, 120, 60), Color(0, 0, 0, 0.16))
	draw_rect(Rect2(300, 680, 120, 47), Color("fde293"))
	draw_rect(Rect2(300, 727, 120, 13), Color("895c3c"))
	for i in n:
		var x3 := 307.0 + 55.0 * i
		draw_rect(Rect2(x3, 677, 45, 46), Color("fffbf2"))
		draw_rect(Rect2(x3 + 4, 681, 37, 20), Color("363636"))
		draw_rect(Rect2(x3 + 4, 706, 37, 7), Color("e6c84a"))
	if n < 2:
		_shake(Vector2(392, 706), 1.5)
	if _f_can_level(2) and popup == "":
		_badge(Vector2(369, 684))


func _f_draw_hud() -> void:
	draw_rect(Rect2(0, 0, W, TOP), Color("222629"))
	draw_rect(Rect2(0, BOT, W, H - BOT), Color("222629"))
	_rr(Rect2(190, 16, 140, 40), Color("fdfff4"), 10)
	_coin(Vector2(192, 36), 22)
	var cs := _fmt_num(coins)
	_txt(272, 47, cs, 28, Color("1d1d1f"))
	var gc := GEAR.get_center()
	for i in 8:
		var d := Vector2.from_angle(i * TAU / 8.0)
		draw_line(gc + d * 9.0, gc + d * 16.0, Color.WHITE, 6.0)
	draw_circle(gc, 12, Color.WHITE)
	draw_circle(gc, 5, Color("222629"))
	var rb := RENO_BTN
	_rr(Rect2(rb.position + Vector2(0, 5), rb.size), Color("3d8fd1"), 10)
	_rr(rb, Color("72c4f5"), 10)
	_hammer(rb.get_center() + Vector2(0, -1), PI / 4.0, 1.0)
	if f_stage >= 1:
		var o := OPEN_BTN
		_rr(Rect2(o.position + Vector2(0, 5), o.size), Color("3d8fd1"), 10)
		_rr(o, Color("72c4f5"), 10)
		var oc := o.get_center()
		draw_colored_polygon(PackedVector2Array([oc + Vector2(0, -20), oc + Vector2(-18, 2), oc + Vector2(-7, 2), oc + Vector2(-7, 18), oc + Vector2(7, 18), oc + Vector2(7, 2), oc + Vector2(18, 2)]), Color.WHITE)
		if _f_any_affordable() and popup == "":
			_badge(o.position + Vector2(2, 2 + sin(t * 4.0) * 3.0))


# ---------------------------------------------------------------- food popups
func _f_draw_popup() -> void:
	match popup:
		"renovate2":
			_draw_renovate2()
		"renovating2":
			_draw_renovating()
		"food_intro":
			draw_rect(Rect2(0, TOP, W, BOT - TOP), Color(0, 0, 0, 0.55))
			_rr(FINTRO_P, Color.WHITE, 20)
			_txt(FINTRO_P.get_center().x, 385, "Restaurant" if r_done else "Food Stand", 30, Color("1d1d1f"))
			var c := Vector2(FINTRO_P.get_center().x, 470)
			draw_circle(c, 62, Color("d4f3f5"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-54, -26), c + Vector2(-30, -46), c + Vector2(-6, -26)]), Color("9a9aa0"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(6, -26), c + Vector2(30, -46), c + Vector2(54, -26)]), Color("9a9aa0"))
			draw_circle(c + Vector2(-12, -8), 10, Color("e6bb7e"))
			draw_circle(c + Vector2(14, -8), 10, Color("e6bb7e"))
			draw_circle(c + Vector2(-12, -15), 8, Color("e8344f"))
			draw_circle(c + Vector2(14, -15), 8, Color("e8344f"))
			draw_rect(Rect2(c.x - 34, c.y + 6, 68, 30), Color("895b38"))
			if r_done:
				_resto_icon(c)
			_rr(Rect2(FINTRO_BTN.position + Vector2(0, 5), FINTRO_BTN.size), Color("4aa3e0"), 12)
			_rr(FINTRO_BTN, Color("72c4f5"), 12)
			_txt(FINTRO_BTN.get_center().x, FINTRO_BTN.get_center().y + 11, "Open", 32, Color.WHITE)
		"funlock":
			var r := _f_unlock_rect()
			var cost: int = _f_buy_cost(f_target)
			var ok := coins >= cost
			_rr(r, Color("f8f8fa"), 16)
			var tx: float = F_BUY_RECT[f_target].get_center().x
			draw_colored_polygon(PackedVector2Array([Vector2(tx - 14, r.end.y - 2), Vector2(tx + 14, r.end.y - 2), Vector2(tx, r.end.y + 16)]), Color("f8f8fa"))
			_txt(r.get_center().x, r.position.y + 34, "Unlock", 26, Color("1d1d1f"))
			var b := _f_unlock_btn()
			_rr(Rect2(b.position + Vector2(0, 5), b.size), Color("4aa3e0") if ok else Color("9aa5ae"), 12)
			_rr(b, Color("72c4f5") if ok else Color("b9c3cc"), 12)
			_coin(b.get_center() + Vector2(-34, 0), 14)
			_txt(b.get_center().x + 16, b.get_center().y + 11, str(cost), 32, Color.WHITE)
		"flevel":
			_f_draw_level()
		"fup":
			draw_rect(Rect2(0, TOP, W, BOT - TOP), Color(0, 0, 0, 0.55))
			_rr(FUP_P, Color.WHITE, 20)
			_txt(FUP_P.get_center().x, FUP_P.position.y + 50, "Upgrades", 32, Color("1d1d1f"))
			_rr(Rect2(FUP_X.position + Vector2(0, 4), FUP_X.size), Color("b8283d"), 8)
			_rr(FUP_X, Color("e8344f"), 8)
			var cc := FUP_X.get_center()
			draw_line(cc + Vector2(-9, -9), cc + Vector2(9, 9), Color.WHITE, 4.0)
			draw_line(cc + Vector2(-9, 9), cc + Vector2(9, -9), Color.WHITE, 4.0)


func _f_draw_level() -> void:
	var k := f_target
	var p := _f_lvl_rect()
	var cx := p.get_center().x
	var lv: int = f_lvl[k]
	draw_rect(Rect2(0, TOP, W, BOT - TOP), Color(0, 0, 0, 0.3))
	_rr(p, Color("f8f8fa"), 18)
	if k == 0:
		draw_colored_polygon(PackedVector2Array([Vector2(p.position.x + 2, 688), Vector2(p.position.x + 2, 712), Vector2(p.position.x - 14, 700)]), Color("f8f8fa"))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(345, p.end.y - 2), Vector2(375, p.end.y - 2), Vector2(360, p.end.y + 16)]), Color("f8f8fa"))
	_txt(cx, p.position.y + 40, "Level %d" % lv, 28, Color("2b2b2b"))
	_txt(cx, p.position.y + 66, _item_name(k), 20, Color("9a9a9a"))
	for i in 3:
		_star(Vector2(cx + (i - 1) * 36.0, p.position.y + 92), 13, Color("f5b800") if lv >= 25 * (i + 1) else Color("dcdde2"))
	var lo := 25 * int(lv / 25) if lv < F_MAX_LEVEL else 50
	var hi := lo + 25
	var frac := clampf(float(lv - lo) / 25.0, 0.0, 1.0)
	var bar := Rect2(p.position.x + 20, p.position.y + 118, p.size.x - 40, 22)
	_rr(bar, Color("e3e5ea"), 11)
	_rr(Rect2(bar.position, Vector2(maxf(22.0, bar.size.x * frac), 22)), Color("72c4f5"), 11)
	var sy := p.position.y + 160
	_coin(Vector2(p.position.x + 36, sy), 12)
	_txtl(p.position.x + 52, sy + 9, _fmt_num(_f_price(k)), 24, Color("5b5b5b"))
	_txtl(p.position.x + 128, sy + 9, str(snappedf(_f_time(k), 0.1)) + "s", 24, Color("5b5b5b"))
	var btn := Rect2(p.position.x + 20, p.position.y + 182, 186, 40)
	var maxed := lv >= F_MAX_LEVEL
	var cost := 0 if maxed else _f_level_cost(k)
	var ok := (not maxed) and coins >= cost
	_rr(Rect2(btn.position + Vector2(0, 4), btn.size), Color("4aa3e0") if ok else Color("9aa5ae"), 10)
	_rr(btn, Color("72c4f5") if ok else Color("b9c3cc"), 10)
	if maxed:
		_txt(btn.get_center().x, btn.get_center().y + 9, "MAX", 26, Color.WHITE)
	else:
		_coin(btn.get_center() + Vector2(-20, 0), 12)
		_txt(btn.get_center().x + 14, btn.get_center().y + 10, _fmt_num(cost), 28, Color.WHITE)


func _f_icon(kind: String, c: Vector2) -> void:
	match kind:
		"cust", "cash":
			var body := Color("f35c6e") if kind == "cust" else Color("f2e04a")
			cv.draw_circle(c + Vector2(0, 16), 15, Color("8fb0c8"))
			_rr(Rect2(c.x - 16, c.y - 2, 32, 24), body, 10)
			cv.draw_circle(c + Vector2(0, -10), 13, Color("f5b08a"))
			if kind == "cash":
				cv.draw_circle(c + Vector2(0, -15), 12, Color("a8322a"))
		"sodafast", "sodaprofit":
			if r_done:
				_fries(c + Vector2(0, 6), 1.4)
			else:
				_soda(c + Vector2(0, 16), 1.3)
			cv.draw_circle(c + Vector2(-14, 20), 9, Color("2b2b2b") if kind == "sodafast" else Color("f2f2f2"))
		"dogfast", "dogprofit":
			if r_done:
				_shake(c + Vector2(0, 2), 1.3)
			else:
				_hotdog(c + Vector2(0, 4), 1.2)
			cv.draw_circle(c + Vector2(-14, 20), 9, Color("2b2b2b") if kind == "dogfast" else Color("f2f2f2"))
		"wrapfast", "wrapprofit":
			_wrap(c + Vector2(0, 2), 1.4)
			cv.draw_circle(c + Vector2(-14, 20), 9, Color("2b2b2b") if kind == "wrapfast" else Color("f2f2f2"))
		"shoe":
			cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-18, 8), c + Vector2(-16, -10), c + Vector2(-4, -8), c + Vector2(4, 2), c + Vector2(18, 6), c + Vector2(18, 14), c + Vector2(-18, 14)]), Color("4a8fe0"))


func _draw_up_rows() -> void:
	cv = up_list
	for i in _ups().size():
		var y := i * F_ROW - f_scroll
		if y < -F_ROW or y > FUP_LIST.size.y:
			continue
		var u: Dictionary = _ups()[i]
		var id: String = u["id"]
		var cost: int = u["cost"]
		_rr(Rect2(3, y, 438, 82), Color("e5e5e5"), 14)
		_f_icon(str(u["ic"]), Vector2(38, y + 38))
		_txtl(74, y + 36, str(u["title"]), 20, Color("1d1d1f"))
		_txtl(74, y + 58, str(u["sub"]), 15, Color("7a7a7a"))
		var b := Rect2(320, y + 11, 112, 57)
		if f_up[id]:
			_rr(Rect2(b.position + Vector2(0, 4), b.size), Color("3f9b4f"), 10)
			_rr(b, Color("5fc873"), 10)
			_txt(b.get_center().x, b.get_center().y + 8, "Owned", 22, Color.WHITE)
		else:
			var ok := coins >= cost
			_rr(Rect2(b.position + Vector2(0, 4), b.size), Color("4aa3e0") if ok else Color("9aa5ae"), 10)
			_rr(b, Color("72c4f5") if ok else Color("c9ced4"), 10)
			_coin(b.position + Vector2(22, 28), 11)
			_txt(b.get_center().x + 14, b.get_center().y + 9, _fmt_num(cost), 24, Color.WHITE if ok else Color("d4202f"))
	cv = self
