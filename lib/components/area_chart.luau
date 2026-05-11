local ansi = require '../ansi'
local area_mod = require '../area'
local canvas = require '../canvas'
local oklch = require '../oklch'
local rgb_to_oklch = oklch.rgb_to_oklch
local oklch_to_rgb = oklch.oklch_to_rgb

local geometry = require './geometry'
local segment_char = require './segment_char'
local text = require './text'

type rgb = oklch.rgb
type buff = canvas.canvas
type area = area_mod.area

-- defs
local DEFAULT_X_TICKS = 9
local DEFAULT_Y_TICKS = 4
local GREY = ansi.to_rgb(ansi.GREY)

export type point = { x: number, y: number }
export type sequence = { point }
export type chart_opts = {
	zone: area,
	sequences: { sequence },
	x_format: ((value: number) -> string)?,
	y_format: ((value: number) -> string)?,
	x_ticks: number?,
	y_ticks: number?,
	y_min: number?,
	y_max: number?,
}

-- functions
local function default_format(value: number): string
	return string.format('%.3g', value)
end

local function dim_lch(lch: vector, y: number, h: number): vector
	local lightness = math.map(y, 0, h, 0.2, 0.9)
	return lch * vector.create(lightness, 1, 1)
end

local function bounds(sequences: { sequence }): (number, number, number, number)
	local x_min, x_max = math.huge, -math.huge
	local y_min, y_max = math.huge, -math.huge
	for _, seq in sequences do
		for _, point in seq do
			if point.x < x_min then x_min = point.x end
			if point.x > x_max then x_max = point.x end
			if point.y < y_min then y_min = point.y end
			if point.y > y_max then y_max = point.y end
		end
	end
	return x_min, x_max, y_min, y_max
end

local function print_chart(opts: chart_opts)
	local zone = opts.zone
	local width, height = zone.x2 - zone.x1, zone.y2 - zone.y1

	local x_format = opts.x_format or default_format
	local y_format = opts.y_format or default_format
	local x_tick_count = opts.x_ticks or DEFAULT_X_TICKS
	local y_tick_count = opts.y_ticks or DEFAULT_Y_TICKS

	local x_min, x_max, auto_y_min, auto_y_max = bounds(opts.sequences)
	local y_min = opts.y_min or auto_y_min
	local y_max = opts.y_max or auto_y_max
	local x_range = math.max(1, x_max - x_min)
	local y_range = math.max(1, y_max - y_min)

	local x_labels = table.create(x_tick_count)
	for index = 1, x_tick_count do
		local fraction = (index - 1) / (x_tick_count - 1)
		x_labels[index] = x_format(x_min + fraction * x_range)
	end

	local y_labels = table.create(y_tick_count)
	local y_label_w = 0
	for index = 1, y_tick_count do
		local fraction = 1 - (index - 1) / y_tick_count
		local label = y_format(y_min + fraction * y_range)
		y_labels[index] = label
		if #label > y_label_w then y_label_w = #label end
	end

	local left_w = y_label_w + 1
	local total_w = left_w + width + 2
	local total_h = height + 3
	local dot_rows = height * 2

	local x_tick_cells = table.create(x_tick_count, 0)
	for index = 1, x_tick_count do
		x_tick_cells[index] = 1 + (width - 1) * (index - 1) // (x_tick_count - 1)
	end

	local y_tick_rows = table.create(y_tick_count, 0)
	for index = 1, y_tick_count do
		local fraction = 1 - (index - 1) / y_tick_count
		y_tick_rows[index] = 1 + (1 - fraction) * (height - 1) // 1
	end

	local buf = canvas.create(total_w, total_h)
	geometry.box(buf, {
		x1 = left_w,
		x2 = left_w + width + 1,
		y1 = 1,
		y2 = height + 2,
		color = GREY,
		depth = 0,
		style = segment_char.style.SOLID,
	})

	for _, col in x_tick_cells do
		geometry.line(buf, {
			x = left_w + col,
			y = vector.create(1, height + 2),
			color = GREY,
			depth = 0,
			style = segment_char.style.DASHED,
		})
	end
	for index, cell_y in y_tick_rows do
		geometry.line(buf, {
			x = vector.create(left_w, left_w + width + 1),
			y = 1 + cell_y,
			color = GREY,
			depth = 0,
			style = segment_char.style.DASHED,
		})
		text.dim(buf, { pos = vector.create(1, 1 + cell_y, 0), text = y_labels[index] })
	end

	local palette = oklch.palette(#opts.sequences)
	local seq_lch = table.create(#opts.sequences)
	local seq_heights: { { number } } = table.create(#opts.sequences)

	for seq_index, seq in opts.sequences do
		seq_lch[seq_index] = rgb_to_oklch(palette[seq_index])
		local heights = table.create(width, 0)
		for _, point in seq do
			local col = 1 + math.round((point.x - x_min) / x_range * (width - 1))
			local level = math.ceil((point.y - y_min) / y_range * dot_rows)

			if level > heights[col] then heights[col] = level end
		end
		seq_heights[seq_index] = heights
	end

	for col = 1, width do
		for level = 1, dot_rows do
			local edge_sum, fill_sum = vector.zero, vector.zero
			local edge_count, fill_count = 0, 0
			for seq_index, heights in seq_heights do
				local height = heights[col]
				if level > height then continue end

				local height_left = if col > 1 then heights[col - 1] else height
				local height_right = if col < width then heights[col + 1] else height

				local lch = seq_lch[seq_index]
				if level == height or height_left < level or height_right < level then
					edge_sum += lch
					edge_count += 1
				else
					fill_sum += dim_lch(lch, level, dot_rows)
					fill_count += 1
				end
			end
			local rgb = if edge_count > 0
				then oklch_to_rgb(edge_sum / edge_count)
				elseif fill_count > 0 then oklch_to_rgb(fill_sum / fill_count)
				else nil
			if rgb then canvas.pixel(buf, vector.create(left_w + col, dot_rows - level + 3, 0), rgb) end
		end
	end

	for index, col in x_tick_cells do
		text.dim(buf, {
			pos = vector.create(left_w + col, height + 3, 0),
			anchor = vector.create(0.5, 0, 0),
			text = x_labels[index],
		})
	end

	canvas.emit(buf)
end

-- module
return table.freeze { print = print_chart }
