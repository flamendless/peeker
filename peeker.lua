--[[
MIT License

Copyright (c) 2021 Brandon Blanker Lim-it

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

local Peeker = {}

local DEF_FPS = 30
local OS = love.system.getOS()

local thread_code = [[
require("love.image")
local ch, out_dir = ...
local i = 0
while true do
    i = i + 1
    local image_data = ch:demand()
    if image_data == "stop" then
        break
    end
    local filename = string.format("%04d.png", i)
    filename = out_dir .. "/" .. filename
    local res = image_data:encode("png", filename)
    if res then
        love.thread.getChannel("status"):push(i)
    else
        print("peeker error", i, res)
    end
end
love.thread.getChannel("status"):push("done")
]]

local worker = {}
local timer, cur_frame = 0, 0
local is_recording = false

local supported_formats = {"mp4", "mkv", "webm"}
local str_supported_formats = table.concat(supported_formats)
local OPT = {}

local function sassert(var, cond, msg)
	if var == nil then return end
	if not cond then error(msg) end
end

local function within_itable(v, t)
	for _, v2 in ipairs(t) do
		if v == v2 then return true end
	end
	return false
end

local function unique_filename(filepath, format)
	local orig = filepath
	if format then
		format = ".".. format
	else
		format = ""
	end
	filepath = orig .. format
	local n = 0
	while love.filesystem.getInfo(filepath) do
		n = n + 1
		filepath = orig .. n .. format
	end
	return filepath
end

function Peeker.start(opt)
	assert(type(opt) == "table")
	sassert(opt.fps, type(opt.fps) == "number" and opt.fps > 0,
		"opt.fps must be a positive integer")
	sassert(opt.out_dir, type(opt.out_dir) == "string",
		"opt.out_dir must be a string")
	sassert(opt.format, type(opt.format) == "string"
		and within_itable(opt.format, supported_formats),
		"opt.format must be either: " .. str_supported_formats)
	sassert(opt.post_clean_frames, type(opt.post_clean_frames) == "boolean")

	OPT = opt

	OPT.fps = OPT.fps or DEF_FPS
	OPT.period = 1/OPT.fps
	OPT.format = OPT.format or "mp4"
	OPT.out_dir = OPT.out_dir or string.format("recording_" .. os.time())

	OPT.out_dir = unique_filename(OPT.out_dir)
	love.filesystem.createDirectory(OPT.out_dir)

	worker.thread = love.thread.newThread(thread_code)
	worker.ch = love.thread.newChannel()
	worker.thread:start(worker.ch, OPT.out_dir)

	cur_frame = 0
	timer = 0
	is_recording = true
end

function Peeker.stop(finalize)
	sassert(finalize, type(finalize) == "boolean")
	is_recording = false
	if not finalize then return end

	-- Wait for frames to finish writing.
	local status
	repeat
		worker.ch:push("stop")
		status = love.thread.getChannel("status"):demand()
	until status == "done"

	local path = Peeker.get_out_dir()
	local flags = ""
	local cmd

	if OPT.format == "mp4" then
		flags = "-filter:v format=yuv420p -movflags +faststart"
	end

	local out_file = "../".. unique_filename(OPT.out_dir, OPT.format)

	if OS == "Linux" then
		local cmd_ffmpeg = string.format("ffmpeg -framerate %d -i '%%04d.png' %s %s;",
			OPT.fps, flags, out_file)
		local cmd_cd = string.format("cd '%s'", path)
		cmd = string.format("bash -c '%s && %s'", cmd_cd, cmd_ffmpeg)
	elseif OS == "Windows" then
		local cmd_ffmpeg = string.format("ffmpeg -framerate %d -i %%04d.png %s %s",
			OPT.fps, flags, out_file)
		local cmd_cd = string.format("cd /d %q", path)
		cmd = string.format("%s && %s", cmd_cd, cmd_ffmpeg)
	end

	if cmd then
		print(cmd)
		local res = os.execute(cmd)
		local msg = res == 0 and "OK" or "PROBLEM ENCOUNTERED"
		print("Video creation status: " .. msg)

		if res == 0 and OPT.post_clean_frames then
			print("cleaning: " .. OPT.out_dir)
			for _, file in ipairs(love.filesystem.getDirectoryItems(OPT.out_dir)) do
				love.filesystem.remove(OPT.out_dir .. "/" .. file)
			end

			local res_rmd = love.filesystem.remove(OPT.out_dir)
			print("removed dir: " .. tostring(res_rmd))
		end
	end
end

function Peeker.update(dt)
	if not is_recording then return end
	timer = timer + dt
	if timer >= OPT.period then
		timer = 0
		love.graphics.captureScreenshot(worker.ch)
	end

	local status = love.thread.getChannel("status"):pop()
	if status then cur_frame = cur_frame + 1 end
end

function Peeker.get_status() return is_recording end
function Peeker.get_current_frame() return cur_frame end
function Peeker.get_out_dir()
	return love.filesystem.getSaveDirectory() .."/".. OPT.out_dir
end

return Peeker
