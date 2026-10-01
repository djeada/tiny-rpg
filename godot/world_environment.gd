# Web builds use the Compatibility renderer, which lights the scene much brighter than
# the desktop Forward+ renderer. Rebalance the light there so both look the same.
extends WorldEnvironment

const COMPAT_SUN_ENERGY := 0.55
const COMPAT_SKY_LIGHT := 0.5
const COMPAT_EXPOSURE := 0.65


func _ready() -> void:
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		return
	environment.tonemap_exposure = COMPAT_EXPOSURE
	environment.ambient_light_sky_contribution = COMPAT_SKY_LIGHT
	var sun := get_node_or_null("../Sun") as DirectionalLight3D
	if sun:
		sun.light_energy = COMPAT_SUN_ENERGY
