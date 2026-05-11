local oklch = require '../lib/oklch'

local test = {}

local function approx(left: number, right: number, eps: number?): boolean
	return math.abs(left - right) <= (eps or 1e-3)
end

local function vec_approx(left: vector, right: vector, eps: number?): boolean
	return approx(left.x, right.x, eps) and approx(left.y, right.y, eps) and approx(left.z, right.z, eps)
end

-- channel conversions
function test.should_clamp_srgb_to_linear_at_extremes()
	assert(oklch.srgb_to_linear_channel(0) == 0)
	assert(oklch.srgb_to_linear_channel(1) == 1)
	assert(oklch.srgb_to_linear_channel(-0.5) == 0)
	assert(oklch.srgb_to_linear_channel(2) == 1)
end

function test.should_clamp_linear_to_srgb_at_extremes()
	assert(oklch.linear_to_srgb_channel(0) == 0)
	assert(oklch.linear_to_srgb_channel(1) == 1)
	assert(oklch.linear_to_srgb_channel(-0.5) == 0)
	assert(oklch.linear_to_srgb_channel(2) == 1)
end

function test.should_roundtrip_srgb_linear_channel()
	for _, channel in { 0.04, 0.18, 0.5, 0.73, 0.95 } do
		local linear = oklch.srgb_to_linear_channel(channel)
		local back = oklch.linear_to_srgb_channel(linear)
		assert(approx(back, channel, 1e-6), `roundtrip {channel} -> {back}`)
	end
end

function test.should_match_linear_threshold_piecewise()
	-- below threshold uses 12.92 * c
	assert(approx(oklch.srgb_to_linear_channel(0.02), 0.02 / 12.92, 1e-9))
	-- above threshold uses pow
	local channel = 0.5
	local expected = ((channel + 0.055) / 1.055) ^ 2.4
	assert(approx(oklch.srgb_to_linear_channel(channel), expected, 1e-9))
end

-- linear <-> lms
function test.should_roundtrip_linear_lms()
	local samples = {
		vector.create(0.1, 0.2, 0.3),
		vector.create(0.5, 0.5, 0.5),
		vector.create(0.9, 0.1, 0.4),
		vector.create(0.7, 0.7, 0.05),
	}
	for _, linear in samples do
		local lms = oklch.linear_to_lms(linear)
		local back = oklch.lms_to_linear(lms)
		assert(vec_approx(back, linear, 1e-6), `{linear} -> {back}`)
	end
end

-- lms <-> oklab
function test.should_roundtrip_lms_oklab()
	local samples = {
		vector.create(0.5, 0.6, 0.7),
		vector.create(0.2, 0.3, 0.4),
		vector.create(0.9, 0.85, 0.8),
	}
	for _, lms in samples do
		local lab = oklch.lms_to_oklab(lms)
		local back = oklch.oklab_to_lms(lab)
		assert(vec_approx(back, lms, 1e-6), `{lms} -> {back}`)
	end
end

-- oklab <-> oklch
function test.should_roundtrip_oklab_oklch()
	local samples = {
		vector.create(0.5, 0.1, 0.05),
		vector.create(0.7, -0.2, 0.15),
		vector.create(0.3, 0.0, -0.1),
	}
	for _, lab in samples do
		local lch = oklch.oklab_to_oklch(lab)
		local back = oklch.oklch_to_oklab(lch)
		assert(vec_approx(back, lab, 1e-6), `{lab} -> {back}`)
	end
end

-- linear <-> oklch (via stages)
function test.should_map_black_linear_to_zero_lightness()
	local lch = oklch.oklab_to_oklch(oklch.lms_to_oklab(oklch.linear_to_lms(vector.zero)))
	assert(approx(lch.x, 0, 1e-6), `L = {lch.x}`)
	assert(approx(lch.y, 0, 1e-6), `C = {lch.y}`)
end

function test.should_map_white_linear_to_unit_lightness_zero_chroma()
	local lch = oklch.oklab_to_oklch(oklch.lms_to_oklab(oklch.linear_to_lms(vector.one)))
	assert(approx(lch.x, 1, 1e-3), `L = {lch.x}`)
	assert(approx(lch.y, 0, 1e-3), `C = {lch.y}`)
end

-- rgb <-> oklch
function test.should_roundtrip_rgb_oklch()
	local samples = {
		vector.create(255, 0, 0),
		vector.create(0, 255, 0),
		vector.create(0, 0, 255),
		vector.create(128, 64, 200),
		vector.create(33, 180, 90),
		vector.create(255, 255, 255),
	}
	for _, rgb in samples do
		local lch = oklch.rgb_to_oklch(rgb)
		local back = oklch.oklch_to_rgb(lch)
		assert(vec_approx(back, rgb, 0.5), `{rgb} -> {back}`)
	end
end

function test.should_map_black_rgb_to_zero_lightness()
	local lch = oklch.rgb_to_oklch(vector.zero)
	assert(approx(lch.x, 0, 1e-6), `L = {lch.x}`)
	assert(approx(lch.y, 0, 1e-6), `C = {lch.y}`)
end

function test.should_map_white_rgb_to_unit_lightness_zero_chroma()
	local lch = oklch.rgb_to_oklch(vector.create(255, 255, 255))
	assert(approx(lch.x, 1, 1e-3), `L = {lch.x}`)
	assert(approx(lch.y, 0, 1e-3), `C = {lch.y}`)
end

-- mix
function test.should_mix_identical_colors_to_self()
	local color = vector.create(120, 60, 200)
	local lch_self = oklch.lerp(color, color, 0.5)
	local lch_direct = oklch.rgb_to_oklch(color)
	assert(approx(lch_self.x, lch_direct.x, 1e-6))
	assert(approx(lch_self.y, lch_direct.y, 1e-6))
end

function test.should_mix_endpoints_match_inputs()
	local rgb_from = vector.create(255, 0, 0)
	local rgb_to = vector.create(0, 0, 255)

	local lch_from = oklch.rgb_to_oklch(rgb_from)
	local lch_to = oklch.rgb_to_oklch(rgb_to)

	local at_zero = oklch.lerp(rgb_from, rgb_to, 0)
	local at_one = oklch.lerp(rgb_from, rgb_to, 1)
	assert(approx(at_zero.x, lch_from.x, 1e-6) and approx(at_zero.y, lch_from.y, 1e-6))
	assert(approx(at_one.x, lch_to.x, 1e-6) and approx(at_one.y, lch_to.y, 1e-6))
end

function test.should_mix_take_shortest_hue_arc()
	-- hues 350° and 10° should mix through 0°, not the long way around
	local lch_a = vector.create(0.7, 0.15, math.rad(350))
	local lch_b = vector.create(0.7, 0.15, math.rad(10))
	local rgb_a = oklch.oklch_to_rgb(lch_a)
	local rgb_b = oklch.oklch_to_rgb(lch_b)
	local mid = oklch.lerp(rgb_a, rgb_b, 0.5)
	-- normalize hue into (-pi, pi]
	local hue = ((mid.z + math.pi) % math.tau) - math.pi
	assert(math.abs(hue) < math.rad(15), `mid hue = {math.deg(hue)}°`)
end

-- palette
function test.should_produce_grey_when_chroma_zero()
	for _, lightness in { 0.2, 0.5, 0.8 } do
		local rgb = oklch.oklch_to_rgb(vector.create(lightness, 0, 0))
		local rounded = vector.floor(rgb + vector.one / 2)
		assert(rounded.x == rounded.y and rounded.y == rounded.z, `L={lightness} -> {rounded} not grey`)
	end
end

function test.should_return_requested_palette_size()
	for _, amount in { 1, 5, 12, 32 } do
		local colors = oklch.palette(amount)
		assert(#colors == amount, `requested {amount} got {#colors}`)
	end
end

function test.should_palette_entries_in_byte_range()
	local colors = oklch.palette(16)
	for index, color in colors do
		assert(color.x >= 0 and color.x <= 255, `entry {index} R out of range: {color.x}`)
		assert(color.y >= 0 and color.y <= 255, `entry {index} G out of range: {color.y}`)
		assert(color.z >= 0 and color.z <= 255, `entry {index} B out of range: {color.z}`)
	end
end

function test.should_palette_entries_distinct()
	local colors = oklch.palette(8)
	for index = 1, #colors do
		for other = index + 1, #colors do
			assert(colors[index] ~= colors[other], `entries {index} and {other} equal: {colors[index]}`)
		end
	end
end

return test
