extends Node
## The smug, gaslighting narrator. Picks contextual lines based on
## level and attempt count, displays them with a typewriter effect.

# ── State ──────────────────────────────────────────────────────────
var _queue: Array[Dictionary] = []
var _current_text: String = ""
var _visible_chars: int = 0
var _char_timer: float = 0.0
var _display_timer: float = 0.0
var _last_line: String = ""

const CHAR_SPEED := 0.028          # seconds between characters
const DEFAULT_HOLD := 3.5          # seconds to hold after fully typed

signal text_changed(full_text: String, visible_count: int)
signal text_cleared

# ── Public API ─────────────────────────────────────────────────────
func say(text: String, hold: float = DEFAULT_HOLD) -> void:
	_queue.append({"text": text, "hold": hold})
	if _current_text == "":
		_advance_queue()

func say_intro(level: int) -> void:
	var line := _pick_intro(level)
	if line != "":
		say(line, 4.0)

func say_death(level: int, attempt: int) -> void:
	var line := _pick_death(level, attempt)
	if line != "":
		say(line)

func say_victory(level: int, attempt: int) -> void:
	var line := _pick_victory(level, attempt)
	if line != "":
		say(line, 4.0)

func clear() -> void:
	_queue.clear()
	_current_text = ""
	_visible_chars = 0
	text_cleared.emit()

# ── Tick ───────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _current_text == "":
		return
	# Typewriter
	if _visible_chars < _current_text.length():
		_char_timer -= delta
		if _char_timer <= 0.0:
			_visible_chars += 1
			_char_timer = CHAR_SPEED
			text_changed.emit(_current_text, _visible_chars)
	else:
		# Hold then clear
		_display_timer -= delta
		if _display_timer <= 0.0:
			_current_text = ""
			_visible_chars = 0
			text_cleared.emit()
			_advance_queue()

func _advance_queue() -> void:
	if _queue.is_empty():
		return
	var entry: Dictionary = _queue.pop_front()
	_current_text = entry.text
	_display_timer = entry.hold
	_visible_chars = 0
	_char_timer = 0.0
	_last_line = _current_text

# ── Line pools ─────────────────────────────────────────────────────

func _pick_intro(level: int) -> String:
	var pool: Array
	match level:
		0: pool = [
			"Welcome. Simply walk to the right.",
			"Level 1. This is the tutorial. Just... walk.",
			"Reach the flag. That's it. I promise.",
		]
		1: pool = [
			"One jump. That's all this is.",
			"A small gap. Nothing you can't handle.",
			"The gap is exactly jumpable. I measured.",
		]
		2: pool = [
			"Three platforms. Climb up. Reach the top.",
			"Some players call this 'the easy one.'",
			"Just hop up the stairs. Simple geometry.",
		]
		3: pool = [
			"A straight corridor. Walk through it.",
			"I literally made this a straight line for you.",
			"There's nothing in here. Just walk.",
		]
		4: pool = [
			"We've come full circle. Just walk to the right.",
			"Last level. Same as the first. Walk right.",
			"You've seen this before. Should be easy now.",
		]
		_: pool = ["Good luck."]
	return pool[randi() % pool.size()]

func _pick_death(level: int, attempt: int) -> String:
	# Phase 1: Professional (1-3)
	if attempt <= 3:
		return _pick(_death_phase1(level))
	# Phase 2: Condescending (4-7)
	if attempt <= 7:
		return _pick(_death_phase2())
	# Phase 3: Defensive (8-14)
	if attempt <= 14:
		return _pick(_death_phase3())
	# Phase 4: Cracking (15-24)
	if attempt <= 24:
		return _pick(_death_phase4())
	# Phase 5: Breaking (25+)
	return _pick(_death_phase5())

func _death_phase1(level: int) -> Array:
	match level:
		0: return [
			"That looked like a miscalculation.",
			"Interesting approach. Not the right one, but interesting.",
			"The flag is to the right. You were going right, yes?",
			"Hm. Try again?",
		]
		1: return [
			"You need to jump. Over the gap.",
			"Gravity is not your enemy here. Timing is.",
			"The gap hasn't changed. Just so you know.",
		]
		_: return [
			"That happens to everyone. Probably.",
			"A minor setback.",
			"Hm. Unlucky.",
			"Almost.",
		]

func _death_phase2() -> Array:
	return [
		"Most players get this on their first try, for what it's worth.",
		"The platforms haven't moved, if that's what you're thinking.",
		"I assure you, the physics engine is working correctly.",
		"Have you tried... jumping better?",
		"That was closer. In a manner of speaking.",
		"The level is identical to when you started. Just saying.",
		"I'm not judging. But the ghost did it in eight seconds.",
		"You're consistent, I'll give you that. Consistently wrong.",
	]

func _death_phase3() -> Array:
	return [
		"The hitboxes are pixel-perfect. I checked.",
		"Look, I didn't design this to be hard.",
		"Have you considered that maybe platformers aren't your genre?",
		"I can see the flag from here. Can you?",
		"The controls are responsive. The issue is... elsewhere.",
		"I'm starting to wonder if you're doing this on purpose.",
		"This level was playtested by a child. The child won.",
		"The game is functioning exactly as intended.",
		"No, the platforms did not move. Why do you keep asking?",
	]

func _death_phase4() -> Array:
	return [
		"You're still here? ...Admirable, actually.",
		"I'm starting to feel something. Is this guilt? No. Definitely not.",
		"Okay the platforms might be... look, it's fine.",
		"I want you to know I believe in you. Sort of.",
		"Are you... are you recording this?",
		"Between attempts, do you ever just... stare at the wall?",
		"The game is fair. The game is FAIR. Moving on.",
		"You've died more times than I have lines for this. Impressive.",
		"I'm not nervous. Why would I be nervous.",
	]

func _death_phase5() -> Array:
	return [
		"Okay, between us? The hitboxes might be slightly... creative.",
		"I may have made some... adjustments. To the physics. Possibly.",
		"Fine! FINE. The game cheats. There. I said it. ...Try again though.",
		"Look, the invisible walls were supposed to be SUBTLE.",
		"In my defense, you were supposed to quit by now.",
		"Most people rage-quit at attempt twelve. You're built different.",
		"The gravity thing? That was an accident. The rest was on purpose.",
		"I'm going to level with you: nothing in this game is real.",
		"You want the truth? The ghost replay doesn't have the cheats on.",
		"At this point I'm rooting for you. Don't tell my supervisor.",
	]

func _pick_victory(level: int, attempt: int) -> String:
	if attempt <= 1:
		return _pick([
			"...What? How did you—  I mean, well done.",
			"First try? That... shouldn't have happened.",
			"Okay. Fine. You're good. Whatever.",
		])
	if attempt <= 5:
		return _pick([
			"Congratulations. That only took you %d tries." % attempt,
			"See? I told you it was easy.",
			"You did it. The crowd goes mild.",
		])
	if attempt <= 15:
		return _pick([
			"Finally. I was starting to worry about you.",
			"Against all odds — and there were many — you did it.",
			"%d attempts. A new record. Not a good one." % attempt,
		])
	return _pick([
		"I genuinely cannot believe you beat that. I'm... proud?",
		"%d attempts. You absolute legend. Or fool. Both?" % attempt,
		"You won. Despite EVERYTHING. I have nothing left to say.",
		"The cheats weren't enough. You are unstoppable. I'm scared.",
	])

func _pick(pool: Array) -> String:
	if pool.is_empty():
		return ""
	var line: String = pool[randi() % pool.size()]
	# Avoid repeating the last line
	if pool.size() > 1 and line == _last_line:
		line = pool[(pool.find(line) + 1) % pool.size()]
	return line
