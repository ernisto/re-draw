local ansi = require '../ansi'

-- defs
local RESET = ansi.DEFAULT_FG .. ansi.NORMAL

local colors = {
	symbol = ansi.BRIGHT_RED,
	keyword = ansi.BRIGHT_RED,
	func_name = ansi.BRIGHT_MAGENTA,
	number = ansi.BRIGHT_BLUE,
	string = ansi.BRIGHT_BLUE,
	boolean = ansi.BRIGHT_BLUE,
	escape = ansi.BLUE,
	builtin = ansi.BLUE,
	brace1 = ansi.GREEN,
	brace2 = ansi.YELLOW,
	brace3 = ansi.BLUE,
	comment = ansi.DIM,
}

-- functions
local function highlight_syntax(code)
	local display = RESET
	local init = 1

	local function escape(c)
		repeat
			local _, e, escape, raw = string.find(code, `^(\\.)([^\\{c}]*)`, init)
			if not e then break end

			init = 1 + e
			display ..= colors.escape .. escape .. colors.string .. raw
		until false
	end

	local function str(c: string)
		local _, e, raw = string.find(code, `^{c}([^\\{c}]*)`, init)
		if not e then return end

		init = 1 + e
		display ..= colors.string .. "'" .. raw

		escape(c)

		if string.sub(code, init, init) ~= c then return true end
		init += 1
		display ..= "'" .. RESET
		return true
	end
	local function str_block()
		local _, e, eqs, raw = string.find(code, `^%[(=*)%[([^%]]*)`, init)
		if not e or not eqs or not raw then return end

		init = 1 + e
		display ..= colors.escape .. '[' .. eqs .. '[' .. colors.string .. raw

		while string.sub(code, init, init + 1 + #eqs) ~= ']' .. eqs .. ']' do
			local _, e2, raw2 = string.find(code, `^[^%]]+`, init + 1)
			if not e2 or not raw2 then
				display ..= string.sub(code, init, init)
				init += 1
				continue
			end

			init = 2 + e2
			display ..= '[' .. raw2
		end

		init += 2 + #eqs
		display ..= colors.escape .. ']' .. eqs .. ']' .. RESET
		return true
	end

	local did_str_interp = false
	local function interp_str_start()
		local _, e, raw = string.find(code, '^`([^\\{`]*)', init)
		if not e or not raw then return end

		did_str_interp = true

		init = 1 + e
		display ..= colors.string .. '`' .. raw

		escape '`{'

		local c = string.sub(code, init, init)
		if c == '`' then
			init += 1
			display ..= '`' .. RESET
			did_str_interp = false
		elseif c == '{' then
			init += 1
			display ..= colors.escape .. '{' .. RESET
		end
		return true
	end
	local function interp_str_mid()
		local _, e, raw = string.find(code, '^}([^\\{`]*)', init)
		if not e or not raw then return end

		init = 1 + e
		display ..= colors.escape .. '}' .. colors.string .. raw

		escape '`{'

		local c = string.sub(code, init, init)
		if c == '`' then
			init += 1
			display ..= '`' .. RESET
			did_str_interp = false
		elseif c == '{' then
			init += 1
			display ..= colors.escape .. '{' .. RESET
		end
		return true
	end

	local function comment()
		local _, e, raw = string.find(code, `^(%-%-[^\n]+)`, init)
		if not e or not raw then return end

		init = 1 + e
		display ..= colors.comment .. raw .. RESET
		return true
	end
	local function comment_block()
		local _, e, eqs, raw = string.find(code, `^%-%-%[(=*)%[([^%]]*)`, init)
		if not e or not eqs or not raw then return end

		init = 1 + e
		display ..= colors.comment .. '--[' .. eqs .. '[' .. raw

		while string.sub(code, init, init + 1 + #eqs) ~= ']' .. eqs .. ']' do
			local _, e2, raw2 = string.find(code, `^[^%]]+`, init + 1)
			if not e2 or not raw2 then
				display ..= string.sub(code, init, init)
				init += 1
				continue
			end

			init = 2 + e2
			display ..= '[' .. raw2
		end

		init += 2 + #eqs
		display ..= ']' .. eqs .. ']' .. RESET
		return true
	end

	local function number()
		local _, e, raw = string.find(code, `^(%d[%de%+%-]*%s*)`, init)
		if not e or not raw then return end

		init = e + 1
		display ..= colors.number .. raw .. RESET
		return true
	end

	local function callment()
		local _, e, name, c = string.find(code, '^([%a_][%w_]*%s*)([%({\'"])', init)
		if not e then
			_, e, name, c = string.find(code, `^([%a_][%w_]*%s*)(%[=*%[)`, init)
		end
		if not e or not name or not c then return end

		init = e - #c + 1
		display ..= colors.func_name .. name .. RESET
		return true
	end

	local chars = { '.', ',', '+', '-', '*', '/', '^', '%', '&', '|', '?', '>', '=', '<', ':', ';', '#', '~' }
	local close_paren = { ')', ']', '}' }
	local open_paren = { '(', '[', '{' }

	local l = 0
	local brace_colors = { colors.brace1, colors.brace2, colors.brace3 }
	local function symbol()
		local c = string.sub(code, init, init)
		init += 1
		if table.find(chars, c) then
			display ..= colors.symbol .. c .. RESET
		elseif table.find(open_paren, c) then
			display ..= brace_colors[1 + l % #brace_colors] .. c .. RESET
			l += 1
		elseif table.find(close_paren, c) then
			l -= 1
			display ..= brace_colors[1 + l % #brace_colors] .. c .. RESET
		else
			display ..= c
		end
	end

	-- stylua: ignore
	local keywords = {
		'and', 'break', 'do', 'else', 'elseif', 'end',
		'for', 'function', 'if', 'in', 'local', 'not',
		'or', 'repeat', 'return', 'then', 'until', 'do',
		'while', 'continue', 'type', 'export', 'repeat',
	}
	-- stylua: ignore
	local globals: { [string]: any } = {
		print = true, require = true, time = true,  assert = true, gcinfo = true, newproxy = true,
		error = true, ipairs = true, next = true, pairs = true, pcall = true, select = true,
		getmetatable = true, rawset = true, rawget = true, rawequal = true, rawlen = true,
		tonumber = true, tostring = true, type = true, unpack = true, xpcall = true,
		getfenv = true, setfenv = true, collectgarbage = true, setmetatable = true,
		table = true, coroutine = true, buffer = true, debug = true, os = true,
		math = true, vector = true, bit32 = true, string = true, utf8 = true,
	}

	local builtins = {
		['nil'] = true,
		['false'] = true,
		['true'] = true,
	}

	local function word()
		local _, e, name, space = string.find(code, `^([%a_][%w_]*)(%s*)`, init)
		if not e or not name then return end

		init = 1 + e

		if builtins[name] then
			display ..= colors.boolean .. name .. assert(space) .. RESET
			return true
		end
		if table.find(keywords, name) then
			display ..= colors.keyword .. name .. assert(space) .. RESET
			return true
		end

		for _, lib in { globals, math, vector, bit32, string, utf8, table, coroutine, buffer, debug, os } do
			for k in lib do
				if name ~= k then continue end
				display ..= colors.builtin .. name .. assert(space) .. RESET
				return true
			end
		end

		display ..= name .. assert(space)
		return true
	end

	while init <= #code do
		if
			str '"'
			or str "'"
			or str_block()
			or interp_str_start()
			or (did_str_interp and interp_str_mid())
			or number()
			or word()
			or callment()
			or comment_block()
			or comment()
			or symbol()
		then
			continue
		end
	end

	return display
end

-- module
return table.freeze {
	theme = colors,
	highlight = highlight_syntax,
}
