extends Resource
class_name ArcadeCalloutTuning

@export_category("Combo Alerts")
## First Combo value allowed to produce an arcade callout. Values through 10 stay quiet.
@export_range(11, 100, 1) var first_combo_alert := 11
## After the first alert, recognize each multiple of this interval.
@export_range(1, 50, 1) var combo_alert_interval := 5

@export_category("Score Alerts")
## Current-run score thresholds. Durable high-score comparison remains profile-owned.
@export var score_milestones: Array[int] = [10000, 25000, 50000, 100000]

@export_category("Difficulty Copy")
## Exceptional-pair percentile that upgrades EAGLE EYES to AMAZING FIND.
@export_range(0, 10000, 100) var amazing_find_min_percentile_basis_points := 9700


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if first_combo_alert <= 10:
		errors.append("First Combo alert must be greater than 10.")
	if combo_alert_interval <= 0:
		errors.append("Combo alert interval must be positive.")
	if amazing_find_min_percentile_basis_points < 0 or amazing_find_min_percentile_basis_points > 10000:
		errors.append("Amazing Find percentile must be between 0 and 10000.")
	var previous := 0
	for milestone in score_milestones:
		if milestone <= previous:
			errors.append("Score milestones must be positive and strictly increasing.")
			break
		previous = milestone
	return errors
