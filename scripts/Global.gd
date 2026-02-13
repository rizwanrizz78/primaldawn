extends Node

# --- Time System ---
var time: float = 0.0
const DAY_LENGTH: float = 1200.0 # 20 minutes per day
const NIGHT_START: float = 0.7 # 70% of day is day, rest is night

# --- Age System ---
var current_age: int = 1
const MAX_AGE: int = 7

# --- Item Database ---
# Format: { "item_id": { "name": String, "nutrition": Dictionary, "spoil_time": float (seconds), "stackable": bool } }
# Nutrition: { "proteins": float, "carbs": float, "hydration": float }
var item_db: Dictionary = {
	"berry": {
		"name": "Red Berry",
		"nutrition": { "proteins": 0.5, "carbs": 2.0, "hydration": 5.0 },
		"spoil_time": 600.0, # 10 minutes
		"stackable": true
	},
	"meat_raw": {
		"name": "Raw Meat",
		"nutrition": { "proteins": 8.0, "carbs": 0.0, "hydration": 1.0 },
		"spoil_time": 300.0, # 5 minutes
		"stackable": true
	},
	"meat_cooked": {
		"name": "Cooked Meat",
		"nutrition": { "proteins": 12.0, "carbs": 0.0, "hydration": -2.0 },
		"spoil_time": 1800.0, # 30 minutes
		"stackable": true
	},
	"rotten_food": {
		"name": "Rotten Food",
		"nutrition": { "proteins": 0.0, "carbs": 0.0, "hydration": -15.0 }, # Causes sickness
		"spoil_time": -1.0, # Never spoils further
		"stackable": true
	},
	"rock": {
		"name": "Rock",
		"nutrition": null,
		"spoil_time": -1.0,
		"stackable": true
	},
	"stick": {
		"name": "Stick",
		"nutrition": null,
		"spoil_time": -1.0,
		"stackable": true
	},
	"fiber": {
		"name": "Fiber",
		"nutrition": null,
		"spoil_time": -1.0,
		"stackable": true
	},
	"sharp_stone": {
		"name": "Sharp Stone",
		"nutrition": null,
		"spoil_time": -1.0,
		"stackable": false
	},
	"spear_wood": {
		"name": "Wooden Spear",
		"nutrition": null,
		"spoil_time": -1.0,
		"stackable": false
	},
	"totem_base": {
		"name": "Chieftain's Totem",
		"nutrition": null,
		"spoil_time": -1.0,
		"stackable": false
	}
}

# Inventory Logic Helper
# Tracks when items were created to calculate spoilage.
# Returns true if the item has spoiled.
func check_spoilage(item_id: String, created_timestamp: float) -> bool:
	if not item_db.has(item_id):
		return false

	var spoil_duration = item_db[item_id].get("spoil_time", -1.0)
	if spoil_duration < 0:
		return false # Does not spoil

	if time - created_timestamp > spoil_duration:
		return true
	return false

func _process(delta: float) -> void:
	time += delta
	# Loop time for day/night cycle logic visuals, but keep absolute time for spoilage
	# For actual game loop day/night, we might want a separate variable for 'day_time' vs 'total_time'
	# checking if time > DAY_LENGTH: time = 0.0 would break spoilage.
	# So we will use fmod(time, DAY_LENGTH) for visuals.

func get_day_progress() -> float:
	return fmod(time, DAY_LENGTH) / DAY_LENGTH

func is_night() -> bool:
	return get_day_progress() > NIGHT_START

func unlock_age(target_age: int) -> void:
	if target_age == current_age + 1:
		current_age = target_age
		print("Age unlocked: " + str(current_age))
		# Signal or event could be emitted here
