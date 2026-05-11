--!native

local canvas = require '../canvas'

local segment_char = require './segment_char'
local put_segment_char = segment_char.put
type style = segment_char.style

local area_mod = require '../area'
type area = area_mod.area

-- defs
type buff = canvas.canvas
type pos2 = vector
type range = vector
type rgb = vector

export type line_def = endpoints & stroke
export type box_def = area & stroke

type stroke = { color: rgb, depth: number, style: style }
type endpoints =
	| { from: pos2, to: pos2, x: nil, y: nil }
	| { x: range, y: number, from: nil, to: nil }
	| { x: number, y: range, from: nil, to: nil }

local NORTH, EAST, SOUTH, WEST =
	segment_char.dir.NORTH, segment_char.dir.EAST, segment_char.dir.SOUTH, segment_char.dir.WEST

-- functions
local function resolve(def: line_def): (number, number, number, number)
	local any_def: any = def
	if def.from then return def.from.x, def.from.y, any_def.to.x, any_def.to.y end

	if typeof(def.x) == 'vector' then
		local x_range = def.x :: range
		return x_range.x, def.y :: number, x_range.y, def.y :: number
	end

	local y_range = any_def.y
	return any_def.x, y_range.x, any_def.x, y_range.y
end

local function line(buf: buff, def: line_def)
	local color, depth, style = def.color, def.depth, def.style
	local x1, y1, x2, y2 = resolve(def)

	if y1 == y2 then
		local lo, hi = math.min(x1, x2), math.max(x1, x2)
		for col = lo, hi do
			local dirs = (if col > lo then WEST else 0) + (if col < hi then EAST else 0)
			put_segment_char(buf, vector.create(col, y1, depth), dirs, color, style)
		end
	elseif x1 == x2 then
		local lo, hi = math.min(y1, y2), math.max(y1, y2)
		for row = lo, hi do
			local dirs = (if row > lo then NORTH else 0) + (if row < hi then SOUTH else 0)
			put_segment_char(buf, vector.create(x1, row, depth), dirs, color, style)
		end
	else
		error 'diagonal lines not supported yet'
	end
end

local function box(buf: buff, def: box_def)
	local color, depth, style = def.color, def.depth, def.style
	local x1, x2, y1, y2 = def.x1, def.x2, def.y1, def.y2
	line(buf, { x = vector.create(x1, x2), y = y1, color = color, depth = depth, style = style })
	line(buf, { x = vector.create(x1, x2), y = y2, color = color, depth = depth, style = style })
	line(buf, { x = x1, y = vector.create(y1, y2), color = color, depth = depth, style = style })
	line(buf, { x = x2, y = vector.create(y1, y2), color = color, depth = depth, style = style })
end

-- module
return table.freeze { line = line, box = box }
