extends ProgressBar

var energy: float = 100.0 : set = set_energy

func set_energy(val: float):
	energy = clamp(val, 0.0, max_value)
	value = energy
