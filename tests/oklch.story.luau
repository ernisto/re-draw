--!native

local draw = require '../lib'
local oklch = require '../lib/oklch'

local WIDTH = 100
local HEIGHT = 50

-- helpers
local function clamp01(rgb: vector): vector
	return vector.clamp(rgb, vector.zero, vector.one * 255)
end

local function lch_to_rgb_clamped(lightness: number, chroma: number, hue: number): vector
	local rgb = oklch.oklch_to_rgb(vector.create(lightness, chroma, hue))
	return clamp01(vector.floor(rgb + vector.one / 2))
end

-- panels
local function fill_pixel_rect(buf, col1, row1, col2, row2, color)
	for row = row1, row2 do
		for col = col1, col2 do
			draw.pixel(buf, vector.create(col, row, 0), color)
		end
	end
end

local function panel_hue_ring(buf, origin_x: number, origin_y: number, size: number, lightness: number, chroma: number)
	local radius_outer = size / 2
	local radius_inner = size / 2 - size / 5
	local center_x = origin_x + size / 2
	local center_y = origin_y + size / 2
	local size2 = vector.create(size, size, 0)

	for pixel_y = 0, size - 1 do
		for pixel_x = 0, size - 1 do
			local pixel_center = vector.create(pixel_x + 0.5, pixel_y + 0.5, 0)
			local delta = pixel_center - size2 / 2

			local radius = vector.magnitude(delta)
			if radius > radius_outer or radius < radius_inner then continue end

			local hue = math.atan2(-delta.y, delta.x)
			local rgb = lch_to_rgb_clamped(lightness, chroma, hue)

			draw.pixel(buf, vector.create(origin_x + pixel_x, origin_y + pixel_y, 0), rgb)
		end
	end

	-- center label
	draw.text.dim(
		buf,
		{ pos = vector.create(math.floor(center_x) - 5, math.floor(center_y / 2), 0), text = `L={lightness}` }
	)
end

local function panel_ch_plane(
	buf,
	origin_x: number,
	origin_y: number,
	size: number,
	lightness: number,
	max_chroma: number
)
	local size2 = vector.create(size, size, 0)

	for pixel_y = 0, size - 1 do
		for pixel_x = 0, size - 1 do
			local pixel_center = vector.create(pixel_x + 0.5, pixel_y + 0.5, 0)
			local delta = pixel_center - size2 / 2
			local radius = vector.magnitude(delta)

			local chroma = max_chroma * radius / (size / 2)
			if chroma > max_chroma then continue end

			local hue = math.atan2(-delta.y, delta.x)
			local lab = oklch.oklch_to_oklab(vector.create(lightness, chroma, hue))
			local linear = oklch.lms_to_linear(oklch.oklab_to_lms(lab))
			local in_gamut = linear.x >= 0
				and linear.x <= 1
				and linear.y >= 0
				and linear.y <= 1
				and linear.z >= 0
				and linear.z <= 1

			if not in_gamut then continue end

			local rgb = oklch.linear_to_rgb(linear)
			draw.pixel(
				buf,
				vector.create(origin_x + pixel_x, origin_y + pixel_y, 0),
				vector.floor(rgb + vector.one / 2)
			)
		end
	end
end

local function panel_lightness_ramp(buf, origin_x: number, origin_y_px: number, width: number, height_px: number)
	for pixel_x = 0, width - 1 do
		local lightness = pixel_x / (width - 1)
		local rgb = lch_to_rgb_clamped(lightness, 0, 0)
		fill_pixel_rect(buf, origin_x + pixel_x, origin_y_px, origin_x + pixel_x, origin_y_px + height_px - 1, rgb)
	end
end

local function panel_chroma_ramp(
	buf,
	origin_x: number,
	origin_y_px: number,
	width: number,
	height_px: number,
	lightness: number,
	hue: number
)
	for pixel_x = 0, width - 1 do
		local chroma = 0.4 * pixel_x / (width - 1)
		local rgb = lch_to_rgb_clamped(lightness, chroma, hue)
		fill_pixel_rect(buf, origin_x + pixel_x, origin_y_px, origin_x + pixel_x, origin_y_px + height_px - 1, rgb)
	end
end

local function panel_mix_strip(
	buf,
	origin_x: number,
	origin_y_px: number,
	width: number,
	height_px: number,
	rgb_from: vector,
	rgb_to: vector,
	blend_mode: 'oklch' | 'rgb'
)
	for pixel_x = 0, width - 1 do
		local alpha = pixel_x / (width - 1)
		local rgb = if blend_mode == 'oklch'
			then oklch.oklch_to_rgb(oklch.lerp(rgb_from, rgb_to, alpha))
			else vector.lerp(rgb_from, rgb_to, alpha)

		fill_pixel_rect(
			buf,
			origin_x + pixel_x,
			origin_y_px,
			origin_x + pixel_x,
			origin_y_px + height_px - 1,
			clamp01(rgb)
		)
	end
end

local function panel_palette(
	buf,
	origin_x: number,
	origin_y_px: number,
	height_px: number,
	swatch_w: number,
	amount: number,
	lightness: number,
	chroma: number
)
	local colors = oklch.palette(amount, lightness, chroma)
	for index, color in colors do
		local col1 = origin_x + (index - 1) * swatch_w
		fill_pixel_rect(buf, col1, origin_y_px, col1 + swatch_w - 1, origin_y_px + height_px - 1, color)
	end
end

-- layout
local buf = draw.canvas(WIDTH, HEIGHT)

draw.text.bold(buf, { pos = vector.create(1, 1, 0), text = 'oklch visual demo' })
draw.text.dim(buf, {
	pos = vector.create(1, 2, 0),
	text = 'rings/planes show perceptual uniformity. ramps + mixes show gradient quality.',
})

-- row 1: hue ring (40px) + ch plane (40px). cell rows 4..23 → pixel rows 7..46
local RING = 40
local RING_OY_PX = (4 - 1) * 2 + 1
panel_hue_ring(buf, 2, RING_OY_PX, RING, 0.78, 0.15)
draw.text.dim(buf, { pos = vector.create(2, 4 + RING / 2 + 1, 0), text = 'hue ring · L=0.78 C=0.15' })

panel_ch_plane(buf, 50, RING_OY_PX, RING, 0.7, 0.4)
draw.text.dim(buf, { pos = vector.create(50, 4 + RING / 2 + 1, 0), text = 'C×h plane · L=0.7 (out-of-gamut blank)' })

-- row 2: lightness ramp
local R2_CELL = 4 + RING / 2 + 3
draw.text.bold(buf, { pos = vector.create(1, R2_CELL, 0), text = 'lightness · L 0→1, C=0' })
panel_lightness_ramp(buf, 2, (R2_CELL + 1 - 1) * 2 + 1, 80, 4)

-- row 3: chroma ramp at hue=orange
local R3_CELL = R2_CELL + 4
draw.text.bold(buf, { pos = vector.create(1, R3_CELL, 0), text = 'chroma · C 0→0.4 at L=0.7 hue=0.5rad' })
panel_chroma_ramp(buf, 2, (R3_CELL + 1 - 1) * 2 + 1, 80, 4, 0.7, 0.5)

-- row 4: mix red→blue, oklch vs rgb
local R4_CELL = R3_CELL + 4
draw.text.bold(buf, { pos = vector.create(1, R4_CELL, 0), text = 'mix red→blue · oklch (top) vs naive rgb (bot)' })
local red = vector.create(255, 32, 32)
local blue = vector.create(32, 32, 255)
panel_mix_strip(buf, 2, (R4_CELL + 1 - 1) * 2 + 1, 80, 3, red, blue, 'oklch')
panel_mix_strip(buf, 2, (R4_CELL + 1 - 1) * 2 + 1 + 3, 80, 3, red, blue, 'rgb')

-- row 5: palette swatches
local R5_CELL = R4_CELL + 5
draw.text.bold(buf, { pos = vector.create(1, R5_CELL, 0), text = 'palette · 16 hues at L=0.78 C=0.15' })
panel_palette(buf, 2, (R5_CELL + 1 - 1) * 2 + 1, 4, 5, 16, 0.78, 0.15)

draw.print(buf)
