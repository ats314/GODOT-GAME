extends Node
## Global signal bus — all game-wide communication flows through here.

signal player_died(pos: Vector2)
signal player_respawned
signal level_started(level_idx: int)
signal level_completed(level_idx: int, time_sec: float, attempts: int)
signal attempt_started(attempt_num: int)
signal cheat_activated(cheat_name: String)
signal ghost_started
signal ghost_finished
signal game_completed(total_deaths: int, total_time: float)
signal narrator_requested(text: String, duration: float)
signal screen_shake(strength: float, duration: float)
