extends Resource
## Replaceable personality/art. Never part of a gameplay definition or RNG stream.
@export var display_name := "Rivet"
@export_file("*.png", "*.webp") var portrait_path := "res://game-assets/characters/rivet/confident.png"
@export_file("*.png", "*.webp") var frustrated_path := "res://game-assets/characters/rivet/frustrated.png"
@export_range(0.5, 5.0) var duration_seconds := 1.35
@export_range(0.0, 30.0) var cooldown_seconds := 7.0
@export_range(0.05, 0.5) var entrance_seconds := 0.18
@export var reactions: Dictionary = {
	"battle_started": {"text": "Ready? Let's play!", "priority": 1},
	"cpu_big_attack": {"text": "Take this!", "priority": 3},
	"cpu_attack": {"text": "Hope you're ready!", "priority": 2},
	"player_big_attack": {"text": "Hey! That's not fair!", "priority": 3, "expression": "frustrated"},
	"player_long_streak": {"text": "Okay, nice moves...", "priority": 2},
	"cpu_long_streak": {"text": "Try to keep up!", "priority": 2},
	"player_near_win": {"text": "You're not done yet!", "priority": 4, "expression": "frustrated"},
	"cpu_near_win": {"text": "Almost there!", "priority": 4},
	"player_attack_cancelled": {"text": "Nice try. Cancelled!", "priority": 3},
	"cpu_attack_cancelled": {"text": "Oh, come on!", "priority": 3, "expression": "frustrated"},
	"cpu_hit_hard": {"text": "Seriously?!", "priority": 4, "expression": "frustrated"},
	"player_hit_hard": {"text": "Good luck with that!", "priority": 4},
	"cpu_comeback": {"text": "I'm still in this!", "priority": 2},
	"player_comeback": {"text": "Not so fast!", "priority": 2, "expression": "frustrated"},
	"cpu_win": {"text": "Better luck next time!", "priority": 10},
	"player_win": {"text": "Not bad... for now.", "priority": 10, "expression": "frustrated"}
}
