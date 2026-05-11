--!native

export type rgb = vector
export type lms = vector
export type oklab = vector
export type oklch = vector

-- helpers
local function linear_to_srgb_channel(channel: number): number
	return if channel <= 0
		then 0
		elseif channel >= 1 then 1
		elseif channel <= 0.0031308 then 12.92 * channel
		else 1.055 * channel ^ (1 / 2.4) - 0.055
end

local function srgb_to_linear_channel(channel: number): number
	return if channel <= 0
		then 0
		elseif channel >= 1 then 1
		elseif channel <= 0.04045 then channel / 12.92
		else ((channel + 0.055) / 1.055) ^ 2.4
end

-- functions
local function rgb_to_linear(rgb: rgb): vector
	local scalar = rgb / 255
	return vector.create(
		srgb_to_linear_channel(scalar.x),
		srgb_to_linear_channel(scalar.y),
		srgb_to_linear_channel(scalar.z)
	)
end
local function linear_to_rgb(linear: vector): rgb
	return 255
		* vector.create(
			linear_to_srgb_channel(linear.x),
			linear_to_srgb_channel(linear.y),
			linear_to_srgb_channel(linear.z)
		)
end

local function linear_to_lms(linear: vector): lms
	local row_l = linear * vector.create(0.4122214708, 0.5363325363, 0.0514459929)
	local row_m = linear * vector.create(0.2119034982, 0.6806995451, 0.1073969566)
	local row_s = linear * vector.create(0.0883024619, 0.2817188376, 0.6299787005)
	return vector.create(
		(row_l.x + row_l.y + row_l.z) ^ (1 / 3),
		(row_m.x + row_m.y + row_m.z) ^ (1 / 3),
		(row_s.x + row_s.y + row_s.z) ^ (1 / 3)
	)
end
local function lms_to_linear(lms: lms): vector
	local cubic = lms * lms * lms
	local row_r = cubic * vector.create(4.0767416621, 3.3077115913, 0.2309699292)
	local row_g = cubic * vector.create(1.2684380046, 2.6097574011, 0.3413193965)
	local row_b = cubic * vector.create(0.0041960863, 0.7034186147, 1.7076147010)
	return vector.create(row_r.x - row_r.y + row_r.z, -row_g.x + row_g.y - row_g.z, -row_b.x - row_b.y + row_b.z)
end

local function lms_to_oklab(lms: lms): oklab
	local row_l = lms * vector.create(0.2104542553, 0.7936177850, 0.0040720468)
	local row_a = lms * vector.create(1.9779984951, 2.4285922050, 0.4505937099)
	local row_b = lms * vector.create(0.0259040371, 0.7827717662, 0.8086757660)
	return vector.create(row_l.x + row_l.y - row_l.z, row_a.x - row_a.y + row_a.z, row_b.x + row_b.y - row_b.z)
end
local function oklab_to_lms(lab: oklab): lms
	local row_a = lab.y * vector.create(0.3963377774, 0.1055613458, 0.0894841775)
	local row_b = lab.z * vector.create(0.2158037573, 0.0638541728, 1.2914855480)
	local sign = vector.create(1, -1, -1)
	return vector.one * lab.x + (row_a + row_b) * sign
end

local function oklab_to_oklch(lab: oklab): oklch
	return vector.create(lab.x, math.sqrt(lab.y * lab.y + lab.z * lab.z), math.atan2(lab.z, lab.y))
end
local function oklch_to_oklab(lch: oklch): oklab
	return vector.create(lch.x, lch.y * math.cos(lch.z), lch.y * math.sin(lch.z))
end

local function rgb_to_oklch(rgb: rgb): oklch
	return oklab_to_oklch(lms_to_oklab(linear_to_lms(rgb_to_linear(rgb))))
end
local function oklch_to_rgb(lch: oklch): rgb
	return linear_to_rgb(lms_to_linear(oklab_to_lms(oklch_to_oklab(lch))))
end

local function lerp_hue(hue_from: number, hue_to: number, alpha: number): number
	local diff = (hue_to - hue_from) % math.tau
	if diff > math.pi then
		-- shortest-arc hue interpolation
		diff -= math.tau
	end
	return hue_from + diff * alpha
end

local function lerp_oklch(rgb_from: vector, rgb_to: vector, alpha: number): vector
	local lch_from = rgb_to_oklch(rgb_from)
	local lch_to = rgb_to_oklch(rgb_to)
	return vector.create(
		math.lerp(lch_from.x, lch_to.x, alpha),
		math.lerp(lch_from.y, lch_to.y, alpha),
		lerp_hue(lch_from.z, lch_to.z, alpha)
	)
end

local function palette(amount: number, lightness: number?, chroma: number?): { vector }
	local lightness_value = lightness or 0.78
	local chroma_value = chroma or 0.15
	local out = table.create(amount)

	for index = 1, amount do
		local hue = index / amount * math.tau
		local rgb = oklch_to_rgb(vector.create(lightness_value, chroma_value, hue))
		out[index] = (rgb + vector.one / 2) // 1
	end
	return out
end

-- module
return table.freeze {
	linear_to_srgb_channel = linear_to_srgb_channel,
	srgb_to_linear_channel = srgb_to_linear_channel,
	rgb_to_linear = rgb_to_linear,
	linear_to_rgb = linear_to_rgb,
	linear_to_lms = linear_to_lms,
	lms_to_linear = lms_to_linear,
	lms_to_oklab = lms_to_oklab,
	oklab_to_lms = oklab_to_lms,
	oklab_to_oklch = oklab_to_oklch,
	oklch_to_oklab = oklch_to_oklab,
	rgb_to_oklch = rgb_to_oklch,
	oklch_to_rgb = oklch_to_rgb,

	lerp = lerp_oklch,
	palette = palette,
}
