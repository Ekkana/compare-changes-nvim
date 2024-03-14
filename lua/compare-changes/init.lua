local Path = require("plenary.path")
local popup = require("plenary.popup")

local M = {}
WIN_ID = nil
BUF_NUM = nil

local function close_menu()
	vim.api.nvim_win_close(WIN_ID, true)

	WIN_ID = nil
end

-- git diff --word-diff 4c984102b7c9621afc5d35c403c5c3981c44d0c2 bf9d0c9c677a3c5b8f4a77045402229dca760ba7 -- README.md
local function get_changes_between_commits(commit_1, commit_2, file_name)
	local cmd = string.format("git diff --word-diff %s %s -- %s", commit_1, commit_2, file_name)
	local output = vim.fn.systemlist(cmd)
	local changes = {}
	local current_change = {}

	for _, line in ipairs(output) do
		print("line:", line)

		if line:sub(1, 3) == "+++" then
			if current_change[1] ~= nil then
				table.insert(changes, current_change)
			end
			current_change = {}
		end
		table.insert(current_change, line)
	end

	table.insert(changes, current_change)
	return changes
end

local function prepare_output_table(cmd)
	local handle = io.popen(cmd)
	local result

	if handle then
		result = handle:read("*a")
		handle:close()
	end
	return vim.split(result, "\\n")
end

local function get_commit_history(file_name)
	-- local output = prepare_output_table("git status")
	print("file_name: " .. file_name)
	local filename = vim.fn.expand("%:t")
	local absolute_filepath = vim.fn.expand("%:p")
	local relative_filepath = vim.fn.expand("%:.")
	print("filename: " .. filename)
	print("absolute_filepath: " .. absolute_filepath)
	print("relative_filepath: " .. relative_filepath)
	local output = prepare_output_table("git log --oneline " .. file_name .. " | awk '{print $1}'")
	local commits = {}
	print(output)
	print("1: " .. output[1])
	-- print("2: " .. output[2])
	print(output[3])
	--
	-- for _, line in ipairs(output) do
	-- 	table.insert(commits, line)
	-- 	print("commit:", line)
	-- end

	return commits
end

-- TODO: update readme with plenary install instructions
local function create_window()
	local width = 60
	local height = 10
	local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
	local buf_num = vim.api.nvim_create_buf(false, false)

	local win_id, _ = popup.create(buf_num, {
		title = "Changes",
		highlight = "ChangesWindow",
		line = math.floor(((vim.o.lines - height) / 2) - 1),
		col = math.floor((vim.o.columns - width) / 2),
		minwidth = width,
		minheight = height,
		borderchars = borderchars,
	})

	return {
		buf_num = buf_num,
		win_id = win_id,
	}
end

local function normalize_path(item)
	return Path:new(item):make_relative(vim.loop.cwd())
end

local function toggle_window()
	if WIN_ID ~= nil then
		close_menu()
		return
	end

	local curr_file = normalize_path(vim.api.nvim_buf_get_name(0))
	vim.cmd(
		string.format(
			"autocmd Filetype compare-changes "
				.. "let path = '%s' | call clearmatches() | "
				-- move the cursor to the line containing the current filename
				.. "call search('\\V'.path.'\\$') | "
				-- add a hl group to that line
				.. "call matchadd('CompareChangesCurrent', '\\V'.path.'\\$')",
			curr_file:gsub("\\", "\\\\")
		)
	)

	local contents = {}
	local new_window = create_window()
	WIN_ID = new_window.win_id
	BUF_NUM = new_window.buf_num

	for i = 1, 5 do
		contents[i] = "hello"
	end

	vim.api.nvim_win_set_option(WIN_ID, "number", true)
	vim.api.nvim_buf_set_name(BUF_NUM, "compare-changes-window")
	vim.api.nvim_buf_set_lines(BUF_NUM, 0, #contents, false, contents)
	vim.api.nvim_buf_set_option(BUF_NUM, "filetype", "compare-changes")
	vim.api.nvim_buf_set_option(BUF_NUM, "buftype", "acwrite")
	vim.api.nvim_buf_set_option(BUF_NUM, "bufhidden", "delete")
	vim.api.nvim_buf_set_keymap(
		BUF_NUM,
		"n",
		"q",
		"<Cmd>lua require('compare-changes').toggle_window()<CR>",
		{ silent = true }
	)
	vim.api.nvim_buf_set_keymap(
		BUF_NUM,
		"n",
		"<ESC>",
		"<Cmd>lua require('compare-changes').toggle_window()<CR>",
		{ silent = true }
	)
end

function M.health()
	vim.keymap.set("n", "<leader>bn", function()
		local filename = vim.fn.expand("%:.")
		print("Start")
		get_commit_history(filename)
		print("End")
		-- toggle_window()
	end)
end

return M
