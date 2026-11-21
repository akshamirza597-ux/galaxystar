extends Node2D

# STAR DASH: GALAXY QUEST
# Godot 4.x
# Complete 5-Level Space Adventure

const SAVE_FILE = "user://galaxy_quest.cfg"

var rng = RandomNumberGenerator.new()
var screen = Vector2.ZERO
var player = Vector2.ZERO

var stage = 1
var state = "menu"
var score = 0
var best = 0
var lives = 3
var mission = 0

var stage_time = 0.0
var animation_time = 0.0
var spawn_clock = 0.0
var rock_clock = 0.0
var crystal_clock = 0.0
var fire_clock = 0.0
var enemy_clock = 0.0
var invincible = 0.0
var shield = 0.0

var boss_hp = 30
var boss_x = 0.0

var stars: Array[Vector2] = []
var rocks: Array[Vector2] = []
var crystals: Array[Vector2] = []
var bullets: Array[Vector2] = []
var enemy_bullets: Array[Vector2] = []
var sky: Array[Vector2] = []
var particles: Array[Dictionary] = []

var font: Font


func _ready() -> void:
	rng.randomize()
	font = ThemeDB.fallback_font
	screen = get_viewport_rect().size
	player = Vector2(screen.x * 0.5, screen.y - 85.0)

	for i in range(110):
		sky.append(Vector2(
			rng.randf_range(0.0, screen.x),
			rng.randf_range(0.0, screen.y)
		))

	var cfg = ConfigFile.new()
	if cfg.load(SAVE_FILE) == OK:
		best = int(cfg.get_value("game", "best", 0))

	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if state == "menu" or state == "lost" or state == "won":
				new_game()
			elif state == "transition":
				stage += 1
				start_stage()

		if event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			if state == "playing":
				state = "paused"
			elif state == "paused":
				state = "playing"

		if event.keycode == KEY_SPACE:
			if state == "playing" and stage == 5:
				shoot()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if state == "menu" or state == "lost" or state == "won":
				new_game()
			elif state == "transition":
				stage += 1
				start_stage()


func new_game() -> void:
	score = 0
	lives = 3
	stage = 1
	start_stage()


func start_stage() -> void:
	screen = get_viewport_rect().size
	player = Vector2(screen.x * 0.5, screen.y - 85.0)

	state = "playing"
	mission = 0
	stage_time = 0.0
	spawn_clock = 0.0
	rock_clock = 0.0
	crystal_clock = 0.0
	fire_clock = 0.0
	enemy_clock = 0.0
	invincible = 1.5
	shield = 0.0

	boss_hp = 30
	boss_x = screen.x * 0.5

	stars.clear()
	rocks.clear()
	crystals.clear()
	bullets.clear()
	enemy_bullets.clear()
	particles.clear()

	queue_redraw()


func shoot() -> void:
	if fire_clock > 0.0:
		return

	bullets.append(player + Vector2(0.0, -35.0))
	fire_clock = 0.18


func burst(pos: Vector2, color: Color, amount: int) -> void:
	for i in range(amount):
		var angle = rng.randf_range(0.0, TAU)
		var speed = rng.randf_range(50.0, 220.0)

		particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": 0.6,
			"color": color
		})


func damage_player() -> void:
	if invincible > 0.0 or shield > 0.0:
		return

	lives -= 1
	invincible = 1.5
	burst(player, Color("#ff7656"), 20)

	if lives <= 0:
		lives = 0
		state = "lost"
		save_best()


func save_best() -> void:
	best = max(best, score)

	var cfg = ConfigFile.new()
	cfg.set_value("game", "best", best)
	cfg.save(SAVE_FILE)


func complete_stage() -> void:
	state = "transition"
	save_best()


func win_game() -> void:
	state = "won"
	score += lives * 100
	save_best()

	for i in range(80):
		burst(
			Vector2(
				rng.randf_range(0.0, screen.x),
				rng.randf_range(0.0, screen.y)
			),
			Color.from_hsv(rng.randf(), 0.8, 1.0),
			1
		)


func update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var part = particles[i]

		var pos: Vector2 = part["pos"]
		var velocity: Vector2 = part["vel"]

		pos += velocity * delta

		part["pos"] = pos
		part["life"] = float(part["life"]) - delta

		if float(part["life"]) <= 0.0:
			particles.remove_at(i)


func _process(delta: float) -> void:
	screen = get_viewport_rect().size
	animation_time += delta

	# Background stars
	for i in range(sky.size()):
		var pos: Vector2 = sky[i]

		pos.y += (15.0 + float(i % 5) * 9.0) * delta

		if pos.y > screen.y:
			pos.y = 0.0
			pos.x = rng.randf_range(0.0, screen.x)

		sky[i] = pos

	update_particles(delta)

	if state != "playing":
		queue_redraw()
		return

	stage_time += delta

	invincible = max(0.0, invincible - delta)
	shield = max(0.0, shield - delta)
	fire_clock = max(0.0, fire_clock - delta)

	# Player movement
	var movement = 0.0

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		movement -= 1.0

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		movement += 1.0

	player.x += movement * 450.0 * delta
	player.x = clamp(player.x, 30.0, max(30.0, screen.x - 30.0))

	# Spawn timers
	spawn_clock += delta
	rock_clock += delta
	crystal_clock += delta

	# Stars in levels 1 and 3
	if stage == 1 or stage == 3:
		if spawn_clock >= 0.55:
			spawn_clock = 0.0

			stars.append(Vector2(
				rng.randf_range(35.0, max(36.0, screen.x - 35.0)),
				-20.0
			))

	# Asteroids in levels 2, 3 and 4
	if stage >= 2 and stage <= 4:
		var interval = 0.9 if stage == 4 else 1.3

		if rock_clock >= interval:
			rock_clock = 0.0

			rocks.append(Vector2(
				rng.randf_range(30.0, max(31.0, screen.x - 30.0)),
				-25.0
			))

	# Crystals in level 3
	if stage == 3 and crystal_clock >= 2.0:
		crystal_clock = 0.0

		crystals.append(Vector2(
			rng.randf_range(35.0, max(36.0, screen.x - 35.0)),
			-20.0
		))

	# Move stars
	for i in range(stars.size() - 1, -1, -1):
		var pos: Vector2 = stars[i]
		pos.y += 220.0 * delta
		stars[i] = pos

		if player.distance_to(pos) < 35.0:
			score += 10

			if stage == 1:
				mission += 10

			burst(pos, Color.YELLOW, 12)
			stars.remove_at(i)

		elif pos.y > screen.y + 30.0:
			stars.remove_at(i)

	# Move crystals
	for i in range(crystals.size() - 1, -1, -1):
		var pos: Vector2 = crystals[i]
		pos.y += 185.0 * delta
		crystals[i] = pos

		if player.distance_to(pos) < 35.0:
			mission += 1
			score += 50
			shield = 2.0

			burst(pos, Color("#bb80ff"), 20)
			crystals.remove_at(i)

		elif pos.y > screen.y + 30.0:
			crystals.remove_at(i)

	# Move asteroids
	for i in range(rocks.size() - 1, -1, -1):
		var pos: Vector2 = rocks[i]
		pos.y += (230.0 + float(stage) * 35.0) * delta
		rocks[i] = pos

		if player.distance_to(pos) < 38.0:
			damage_player()
			rocks.remove_at(i)

			if state != "playing":
				break

		elif pos.y > screen.y + 30.0:
			rocks.remove_at(i)

	if state != "playing":
		queue_redraw()
		return

	# Final boss
	if stage == 5:
		boss_x = screen.x * 0.5 + sin(stage_time * 1.3) * screen.x * 0.32

		enemy_clock += delta

		if enemy_clock >= 0.8:
			enemy_clock = 0.0
			enemy_bullets.append(Vector2(boss_x, 115.0))

		# Player bullets
		for i in range(bullets.size() - 1, -1, -1):
			var pos: Vector2 = bullets[i]
			pos.y -= 620.0 * delta
			bullets[i] = pos

			if abs(pos.x - boss_x) < 80.0 and pos.y < 135.0 and pos.y > 35.0:
				boss_hp -= 1
				burst(pos, Color.CYAN, 6)
				bullets.remove_at(i)

				if boss_hp <= 0:
					win_game()
					break

			elif pos.y < -20.0:
				bullets.remove_at(i)

		# Enemy bullets
		if state == "playing":
			for i in range(enemy_bullets.size() - 1, -1, -1):
				var pos: Vector2 = enemy_bullets[i]
				pos.y += 310.0 * delta
				enemy_bullets[i] = pos

				if player.distance_to(pos) < 28.0:
					damage_player()
					enemy_bullets.remove_at(i)

					if state != "playing":
						break

				elif pos.y > screen.y + 20.0:
					enemy_bullets.remove_at(i)

	if state != "playing":
		queue_redraw()
		return

	# Level completion
	if stage == 1 and mission >= 100:
		complete_stage()

	elif stage == 2 and stage_time >= 20.0:
		complete_stage()

	elif stage == 3 and mission >= 5:
		complete_stage()

	elif stage == 4 and stage_time >= 25.0:
		complete_stage()

	queue_redraw()


func draw_text_center(message: String, y: float, size: int, color: Color) -> void:
	var width = font.get_string_size(
		message,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size
	).x

	draw_string(
		font,
		Vector2((screen.x - width) * 0.5, y),
		message,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size,
		color
	)


func draw_text_left(message: String, pos: Vector2, size: int, color: Color) -> void:
	draw_string(
		font,
		pos,
		message,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size,
		color
	)


func glow(pos: Vector2, radius: float, color: Color) -> void:
	var c = color

	c.a = 0.08
	draw_circle(pos, radius * 2.1, c)

	c.a = 0.18
	draw_circle(pos, radius * 1.5, c)


func star_shape(pos: Vector2, radius: float, color: Color) -> void:
	var points = PackedVector2Array()

	for i in range(10):
		var angle = -PI / 2.0 + float(i) * PI / 5.0
		var r = radius if i % 2 == 0 else radius * 0.45

		points.append(
			pos + Vector2(cos(angle), sin(angle)) * r
		)

	draw_colored_polygon(points, color)


func draw_player() -> void:
	var flame = 12.0 + sin(animation_time * 20.0) * 7.0

	var fire = PackedVector2Array([
		player + Vector2(-10, 19),
		player + Vector2(0, 35.0 + flame),
		player + Vector2(10, 19)
	])

	draw_colored_polygon(fire, Color.ORANGE)
	glow(player, 29.0, Color.CYAN)

	var ship = PackedVector2Array([
		player + Vector2(0, -34),
		player + Vector2(-12, -5),
		player + Vector2(-27, 22),
		player + Vector2(0, 13),
		player + Vector2(27, 22),
		player + Vector2(12, -5)
	])

	draw_colored_polygon(ship, Color("#36eaff"))
	draw_circle(player + Vector2(0, -7), 8.0, Color.WHITE)

	if shield > 0.0:
		draw_arc(
			player,
			42.0,
			0.0,
			TAU,
			60,
			Color.GREEN,
			3.0
		)


func _draw() -> void:
	var size = get_viewport_rect().size

	# Level backgrounds
	var bg = Color("#080d27")

	if stage == 2:
		bg = Color("#251022")
	elif stage == 3:
		bg = Color("#160e37")
	elif stage == 4:
		bg = Color("#30101d")
	elif stage == 5:
		bg = Color("#100d29")

	draw_rect(Rect2(Vector2.ZERO, size), bg)

	# Galaxy atmosphere
	glow(
		Vector2(size.x * 0.18, size.y * 0.35),
		130.0,
		Color("#7745ff")
	)

	glow(
		Vector2(size.x * 0.82, size.y * 0.7),
		120.0,
		Color("#146bff")
	)

	# Background stars
	for s in sky:
		draw_circle(s, 1.3, Color("#9aafff"))

	# Planet
	var planet = Vector2(size.x * 0.85, size.y * 0.25)

	glow(planet, 48.0, Color("#835cff"))
	draw_circle(planet, 36.0, Color("#493c98"))
	draw_circle(
		planet + Vector2(-10, -10),
		20.0,
		Color("#6954b2")
	)

	# Collectible stars
	for s in stars:
		glow(s, 18.0, Color.YELLOW)
		star_shape(s, 16.0, Color("#ffdd55"))
		draw_circle(s, 4.0, Color.WHITE)

	# Crystals
	for c in crystals:
		glow(c, 23.0, Color("#bb80ff"))

		var diamond = PackedVector2Array([
			c + Vector2(0, -21),
			c + Vector2(16, 0),
			c + Vector2(0, 21),
			c + Vector2(-16, 0)
		])

		draw_colored_polygon(diamond, Color("#bb80ff"))

	# Asteroids
	for r in rocks:
		glow(r, 22.0, Color("#ff7656"))
		draw_circle(r, 21.0, Color("#ff7656"))
		draw_circle(r + Vector2(-6, -4), 8.0, Color("#a83b42"))
		draw_circle(r + Vector2(7, 8), 5.0, Color("#b4483e"))

	# Boss
	if stage == 5 and state == "playing":
		var boss = Vector2(boss_x, 85.0)

		glow(boss, 90.0, Color.RED)

		var body = PackedVector2Array([
			boss + Vector2(0, -45),
			boss + Vector2(-90, 25),
			boss + Vector2(-48, 42),
			boss + Vector2(0, 20),
			boss + Vector2(48, 42),
			boss + Vector2(90, 25)
		])

		draw_colored_polygon(body, Color("#8e3de8"))
		draw_circle(boss, 22.0, Color("#ff4c87"))
		draw_circle(boss, 11.0, Color.WHITE)

		draw_rect(
			Rect2(boss.x - 75.0, 145.0, 150.0, 9.0),
			Color("#4b263b")
		)

		draw_rect(
			Rect2(
				boss.x - 75.0,
				145.0,
				150.0 * float(boss_hp) / 30.0,
				9.0
			),
			Color("#ff507b")
		)

	# Player bullets
	for b in bullets:
		glow(b, 8.0, Color.CYAN)

		draw_rect(
			Rect2(b.x - 3.0, b.y - 12.0, 6.0, 20.0),
			Color.CYAN
		)

	# Enemy bullets
	for b in enemy_bullets:
		glow(b, 13.0, Color.RED)
		draw_circle(b, 10.0, Color("#ff476a"))

	# Particles
	for p in particles:
		var color: Color = p["color"]

		color.a = clamp(
			float(p["life"]) / 0.6,
			0.0,
			1.0
		)

		draw_circle(p["pos"], 3.5, color)

	# Player spaceship
	if state == "playing" or state == "paused":
		if invincible <= 0.0 or int(animation_time * 12.0) % 2 == 0:
			draw_player()

	# HUD
	if state == "playing" or state == "paused":
		draw_rect(
			Rect2(0, 0, size.x, 85),
			Color(0.03, 0.05, 0.15, 0.85)
		)

		draw_text_left(
			"LEVEL " + str(stage) + "/5",
			Vector2(15, 28),
			21,
			Color("#ffdf75")
		)

		draw_text_left(
			"SCORE: " + str(score) + "   HP: " + str(lives),
			Vector2(15, 55),
			19,
			Color.WHITE
		)

		var mission_text = ""

		match stage:
			1:
				mission_text = "COLLECT: " + str(mission) + "/100"
			2:
				mission_text = "SURVIVE: " + str(min(int(stage_time), 20)) + "/20 SEC"
			3:
				mission_text = "CRYSTALS: " + str(mission) + "/5"
			4:
				mission_text = "SURVIVE: " + str(min(int(stage_time), 25)) + "/25 SEC"
			5:
				mission_text = "BOSS HP: " + str(max(boss_hp, 0)) + "/30"

		draw_text_left(
			mission_text,
			Vector2(15, 78),
			17,
			Color("#73f5ff")
		)

	# Start screen
	if state == "menu":
		draw_text_center(
			"STAR DASH",
			size.y * 0.30,
			52,
			Color("#66f4ff")
		)

		draw_text_center(
			"GALAXY QUEST",
			size.y * 0.40,
			28,
			Color.WHITE
		)

		draw_text_center(
			"5 LEVEL SPACE ADVENTURE",
			size.y * 0.53,
			20,
			Color("#ffdf75")
		)

		draw_text_center(
			"PRESS ENTER TO START",
			size.y * 0.70,
			22,
			Color("#73f5ff")
		)

	# Pause screen
	elif state == "paused":
		draw_rect(
			Rect2(Vector2.ZERO, size),
			Color(0, 0, 0, 0.7)
		)

		draw_text_center(
			"PAUSED",
			size.y * 0.45,
			45,
			Color.WHITE
		)

		draw_text_center(
			"PRESS P TO RESUME",
			size.y * 0.57,
			21,
			Color("#73f5ff")
		)

	# Level complete
	elif state == "transition":
		draw_rect(
			Rect2(Vector2.ZERO, size),
			Color(0, 0, 0, 0.75)
		)

		draw_text_center(
			"LEVEL " + str(stage) + " COMPLETE!",
			size.y * 0.38,
			38,
			Color("#7cffe4")
		)

		draw_text_center(
			"SCORE: " + str(score),
			size.y * 0.50,
			23,
			Color.WHITE
		)

		draw_text_center(
			"PRESS ENTER FOR NEXT LEVEL",
			size.y * 0.65,
			20,
			Color("#ffdf75")
		)

	# Game over
	elif state == "lost":
		draw_rect(
			Rect2(Vector2.ZERO, size),
			Color(0, 0, 0, 0.75)
		)

		draw_text_center(
			"MISSION FAILED",
			size.y * 0.38,
			43,
			Color("#ff6d8e")
		)

		draw_text_center(
			"FINAL SCORE: " + str(score),
			size.y * 0.50,
			24,
			Color.WHITE
		)

		draw_text_center(
			"PRESS ENTER TO RETRY",
			size.y * 0.65,
			21,
			Color("#73f5ff")
		)

	# Victory screen
	elif state == "won":
		draw_rect(
			Rect2(Vector2.ZERO, size),
			Color(0, 0, 0, 0.65)
		)

		draw_text_center(
			"YOU WIN!",
			size.y * 0.35,
			54,
			Color("#7cffe4")
		)

		draw_text_center(
			"ALL 5 LEVELS COMPLETED",
			size.y * 0.46,
			23,
			Color.WHITE
		)

		draw_text_center(
			"FINAL SCORE: " + str(score),
			size.y * 0.55,
			24,
			Color("#ffdf75")
		)

		draw_text_center(
			"PRESS ENTER TO PLAY AGAIN",
			size.y * 0.70,
			20,
			Color("#73f5ff")
		)
