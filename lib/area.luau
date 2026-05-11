type range = vector
type pos2 = vector

export type area = { x1: number, x2: number, y1: number, y2: number } -- vector faster if vector4 FFlag enabled
export type area_def =
	| { pos: pos2, size: pos2, start: nil, final: nil, x: nil, y: nil }
	| { x: range, y: range, pos: nil, size: nil, start: nil, final: nil }
	| { start: pos2, final: pos2, pos: nil, size: nil, x: nil, y: nil }

local function new_area(opts: area_def): area
	local any_opts: any = opts
	return table.freeze(if opts.x
		then { x1 = opts.x.x, x2 = opts.x.y, y1 = opts.y.x, y2 = opts.y.y }
		elseif opts.start then { x1 = opts.start.x, x2 = opts.final.x, y1 = opts.start.y, y2 = opts.final.y }
		else {
			x1 = any_opts.pos.x,
			x2 = any_opts.pos.x + any_opts.size.x,
			y1 = any_opts.pos.y,
			y2 = any_opts.pos.y + any_opts.size.y,
		})
end

return table.freeze { new = new_area }
