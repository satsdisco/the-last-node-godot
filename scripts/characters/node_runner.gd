extends Player
class_name NodeRunner
## The Node Runner — balanced all-rounder. Default character.
## Uses the base Player specials: Full Validation, Broadcast, Consensus.

func _ready():
	character_name = "NODE RUNNER"
	speed = 160.0
	max_hp = 100
	base_damage = 10
	combo_length = 4
	attack_range = 44.0
	finisher_taunt = "VALIDATED."
	special_1_cost = 500
	special_2_cost = 1000
	super_cost = 5000
	super._ready()
