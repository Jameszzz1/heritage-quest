extends ProgressBar

var battery: float = 100.0 : set = set_battery

func set_battery(val: float):
	battery = clamp(val, 0.0, max_value)
	value = battery
