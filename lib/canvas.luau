--!native

local ansi = require './ansi'

-- defs
type rgb = vector

export type canvas = {
	width: number,
	height: number,
	mode: buffer, -- mode: 0=empty, 1=char, 2=pixel
	z: buffer,
	chars: { string },
	ansis: { string },
	top: { vector? },
	bot: { vector? },
}

-- functions
local function create(width: number, height: number): canvas
	local count = width * height
	return {
		width = width,
		height = height,
		mode = buffer.create(count),
		z = buffer.create(count),
		chars = table.create(count, ''),
		ansis = table.create(count, ''),
		top = table.create(count),
		bot = table.create(count),
	}
end

local function in_bounds(buf: canvas, pos: vector): boolean
	return pos.x >= 1 and pos.x <= buf.width and pos.y >= 1 and pos.y <= buf.height
end

local function put(buf: canvas, pos: vector, char: string, color: rgb?)
	local col, row, zindex = pos.x, pos.y, pos.z
	if col < 1 or col > buf.width or row < 1 or row > buf.height then return end

	local index = (row - 1) * buf.width + col - 1
	if buffer.readu8(buf.mode, index) ~= 0 and zindex < buffer.readi8(buf.z, index) then return end

	buffer.writeu8(buf.mode, index, 1)
	buffer.writei8(buf.z, index, zindex)

	buf.chars[index + 1] = char
	buf.ansis[index + 1] = if color then ansi.foreground(color) else ''
	buf.top[index + 1] = nil
	buf.bot[index + 1] = nil
end

local function pixel(buf: canvas, pos: vector, color: rgb)
	local col, pixel_row, zindex = pos.x, pos.y, pos.z
	local cell_row = (pixel_row + 1) // 2
	if col < 1 or col > buf.width or cell_row < 1 or cell_row > buf.height then return end

	local index = (cell_row - 1) * buf.width + col - 1
	local prev_mode = buffer.readu8(buf.mode, index)
	if prev_mode ~= 0 and zindex < buffer.readi8(buf.z, index) then return end

	buffer.writeu8(buf.mode, index, 2)
	buffer.writei8(buf.z, index, zindex)

	if prev_mode ~= 2 then
		buf.top[index + 1] = nil
		buf.bot[index + 1] = nil
		buf.chars[index + 1] = ''
		buf.ansis[index + 1] = ''
	end

	if pixel_row % 2 == 1 then
		buf.top[index + 1] = color
	else
		buf.bot[index + 1] = color
	end
end

local function emit(buf: canvas)
	local width = buf.width
	local mode_buf = buf.mode
	local chars = buf.chars
	local ansis = buf.ansis
	local top = buf.top
	local bot = buf.bot

	local RESET = ansi.RESET
	local parts = table.create(width)
	for row = 1, buf.height do
		local base = (row - 1) * width
		local count = 0

		for col = 1, width do
			local cell_index = base + col - 1
			local mode = buffer.readu8(mode_buf, cell_index)

			local output
			if mode == 1 then
				local code = ansis[cell_index + 1]
				output = if code == '' then chars[cell_index + 1] else code .. chars[cell_index + 1] .. RESET
			elseif mode == 2 then
				local top_rgb, bot_rgb = top[cell_index + 1], bot[cell_index + 1]
				output = if top_rgb and bot_rgb
					then ansi.foreground(top_rgb) .. ansi.background(bot_rgb) .. '▀' .. RESET
					elseif top_rgb then ansi.foreground(top_rgb) .. '▀' .. RESET
					elseif bot_rgb then ansi.foreground(bot_rgb) .. '▄' .. RESET
					else ' '
			else
				output = ' '
			end

			count += 1
			parts[count] = output
		end

		print(table.concat(parts, '', 1, count))
	end
end

-- module
return table.freeze {
	create = create,
	in_bounds = in_bounds,
	put = put,
	pixel = pixel,
	emit = emit,
}
