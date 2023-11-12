local util = {}

---@param cb fun(body: table, job: Job?)
function util.handle_stream(cb)
	---@param job Job?
	return function(_, chunk, job)
		vim.schedule(function()
			local _, body = pcall(function()
				return vim.json.decode(chunk)
			end)
			if type(body) ~= "table" or body.response == nil then
				return
			end
			cb(body, job)
		end)
	end
end

-- Show a spinner in the given buffer (overwrites existing lines)
---@param bufnr number The buffer to show the spinner in
---@return uv_timer_t timer The timer object for rotating the spinner
function util.show_spinner(bufnr)
	local spinner_chars = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
	local curr_char = 1
	local timer = vim.loop.new_timer()
	timer:start(
		100,
		100,
		vim.schedule_wrap(function()
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Generating... " .. spinner_chars[curr_char], "" })
			curr_char = curr_char % #spinner_chars + 1
		end)
	)

	return timer
end

-- Opens a floating window with a new buffer, returning the buffer and window IDs.
---@param bufnr number The buffer to show in the window
---@param win_opts table Window option overrides to pass to nvim_open_win
---@return number buf The buffer ID
function util.open_floating_win(bufnr, win_opts)
	local win_width = math.floor(vim.api.nvim_get_option_value("columns", {}) * 0.8)
	local win_height = math.floor(vim.api.nvim_get_option_value("lines", {}) * 0.8)

	if win_width > 100 then
		win_width = 100
	end

	local out_win = vim.api.nvim_open_win(
		bufnr,
		true,
		vim.tbl_deep_extend("force", {
			relative = "editor",
			width = win_width,
			height = win_height,
			row = math.floor((vim.api.nvim_get_option_value("lines", {}) - win_height) / 2),
			col = math.floor((vim.api.nvim_get_option_value("columns", {}) - win_width) / 2),
			style = "minimal",
			border = "rounded",
			title = "Ollama Output",
			title_pos = "center",
		}, win_opts)
	)

	-- vim.api.nvim_buf_set_name(out_buf, "OllamaOutput")
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
	vim.api.nvim_set_option_value("wrap", true, { win = out_win })
	vim.api.nvim_set_option_value("linebreak", true, { win = out_win })

	return out_win
end

-- Get the current selection range, if any, adjusting for 0-based indexing.
-- Useful for replacing text in a buffer based on a selection range.
---@return number[]|nil { start_line, start_col, end_line, end_col }
function util.get_selection_pos()
	local sel_start = vim.fn.getpos("'<")
	local sel_end = vim.fn.getpos("'>")
	local mode = vim.fn.visualmode()

	if
		sel_start == nil
		or sel_end == nil
		or sel_start[2] == 0
		or sel_start[3] == 0
		or sel_end[2] == 0
		or sel_end[3] == 0
	then
		-- no selection range found
		return nil
	end

	local start_line, start_col, end_line, end_col

	-- assign positions based on visual or visual-line mode
	if mode == "v" then
		start_line = sel_start[2]
		start_col = sel_start[3]
		end_line = sel_end[2]
		end_col = sel_end[3]
	elseif mode == "V" then
		start_line = sel_start[2]
		start_col = 1
		end_line = sel_end[2]
		end_col = #vim.fn.getline(sel_end[2]) + 1
	end

	-- validate and adjust positions
	if start_line > end_line or (start_line == end_line and start_col > end_col) then
		start_line, end_line = end_line, start_line
		start_col, end_col = end_col, start_col
	end

	-- adjust for 0-based indexing
	start_line = start_line - 1
	start_col = start_col - 1
	end_line = end_line - 1
	end_col = end_col - 1

	return { start_line, start_col, end_line, end_col }
end

return util
