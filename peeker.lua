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

local MAX_N_THREAD = love.system.getProcessorCount()
local OS = love.system.getOS()

local FILENAME = "%04d.png"

local THREAD_CODE = [[
require("love.filesystem")
require("love.image")

local chan = ...

while true do
	local data = chan:demand()

	if not data then
		break
	elseif type(data[1]) == "string" then
		-- copy frame
		if love.filesystem.getInfo(data[1], "file") then
			love.filesystem.write(data[2], love.filesystem.read(data[1]))
		else
			-- requeue
			chan:push(data)
		end
	else
		-- encode
		data[1]:encode("png", data[2])
	end
end
]]

local threads = {}
local canvas, channel
local timer, cur_frame, last_frame = 0, 0, 0
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

local function get_filename(i)
	return string.format("%s/%s", OPT.out_dir, string.format(FILENAME, i))
end

function Peeker.start(opt)
	assert(type(opt) == "table")
	sassert(opt.w, type(opt.w) == "number" and opt.w > 0,
		"opt.w must be a positive integer")
	sassert(opt.h, type(opt.h) == "number" and opt.h > 0,
		"opt.h must be a positive integer")
	sassert(opt.n_threads, type(opt.n_threads) == "number" and opt.n_threads > 0,
		"opt.n_threads must be a positive integer")
	sassert(opt.n_threads, opt.n_threads and opt.n_threads <= MAX_N_THREAD,
		"opt.n_threads should not be > " .. MAX_N_THREAD .. " max available threads")
	sassert(opt.fps, type(opt.fps) == "number" and opt.fps > 0,
		"opt.fps must be a positive integer")
	sassert(opt.out_dir, type(opt.out_dir) == "string",
		"opt.out_dir must be a string")
	sassert(opt.format, type(opt.format) == "string"
		and within_itable(opt.format, supported_formats),
		"opt.format must be either: " .. str_supported_formats)
	sassert(opt.overlay, type(opt.overlay) == "string"
		and (opt.overlay == "circle" or opt.overlay == "text"))

	local ww, wh = love.graphics.getDimensions()
	OPT = opt
	OPT.w = OPT.w or ww
	OPT.h = OPT.h or wh
	OPT.n_threads = OPT.n_threads or MAX_N_THREAD
	OPT.fps = OPT.fps or 15
	OPT.format = OPT.format or "mp4"
	OPT.out_dir = OPT.out_dir or string.format("recording_" .. os.time())
	OPT.flags = select(3, love.window.getMode())

	local n = 0
	local orig = OPT.out_dir
	while (love.filesystem.getInfo(OPT.out_dir)) do
		n = n + 1
		OPT.out_dir = orig .. n
	end
	love.filesystem.createDirectory(OPT.out_dir)

	channel = love.thread.newChannel()

	for i = 1, OPT.n_threads do
		if not threads[i] then
			threads[i] = love.thread.newThread(THREAD_CODE)
		end

		threads[i]:start(channel)
	end

	canvas = love.graphics.newCanvas(OPT.w, OPT.h)
	cur_frame = 0
	timer = 0
	last_frame = 0
	is_recording = true
end

function Peeker.stop(finalize)
	sassert(finalize, type(finalize) == "boolean")
	is_recording = false
	if not finalize then return end

	-- Send quit command
	for _ = 1, OPT.n_threads do
		channel:push(false)
	end

	-- Wait thread to finish
	for i = 1, OPT.n_threads do
		threads[i]:wait()
	end

	local path = love.filesystem.getSaveDirectory() .. "/" .. OPT.out_dir
	local flags, cmd = "", ""

	if OPT.format == "mp4" then
		flags = "-filter:v format=yuv420p -movflags +faststart"
	end

	if OS == "Linux" then
		local cmd_ffmpeg = string.format("ffmpeg -framerate %d -i '%%04d.png' %s output.%s;",
			OPT.fps, flags, OPT.format)
		local cmd_cd = string.format("cd '%s'", path)
		cmd = string.format("bash -c '%s && %s'", cmd_cd, cmd_ffmpeg)
	elseif OS == "Windows" then
		local cmd_ffmpeg = string.format("ffmpeg -framerate %d -i %%04d.png %s output.%s",
			OPT.fps, flags, OPT.format)
		local cmd_cd = string.format("cd /d %q", path)
		cmd = string.format("%s && %s", cmd_cd, cmd_ffmpeg)
	end

	if cmd then
		print(cmd)
		local res = os.execute(cmd)
		local msg = res == 0 and "OK" or "PROBLEM ENCOUNTERED"
		print("Video creation status: " .. msg)
	end
end

function Peeker.update(dt)
	if not is_recording then return end
	local first = true
	timer = timer + dt

	-- There are some considerations needs to be taken care of
	-- 1. If the encoding thread can't keep up with lots of the command sent:
	-- 1a. If there are 4x thread amount of commands, duplicate frames
	-- 1b. If there are 8x thread amount of commands, ignore frames completely
	-- 2. If the delta time is larger than the target FPS (game lagging), duplicate frames
	-- CAVEAT: With the 1st point edge case handling, command queue may filled entirely with
	-- copy commands. This can happen if the copy command comes faster than the thread can process.
	while timer >= 1/OPT.fps do
		local count = channel:getCount()

		if count >= OPT.n_threads * 8 then
			-- YELL!
			print("CAN'T KEEP UP! IGNORING FRAMES INSTEAD!")
		else
			cur_frame = cur_frame + 1

			if count >= OPT.n_threads * 4 then
				print("Can't keep up. Duplicating frames instead!")
				channel:push({get_filename(last_frame), get_filename(cur_frame)})
			else
				if first then
					local image_data = canvas:newImageData()
					print(cur_frame)
					channel:push({image_data, get_filename(cur_frame)})
					last_frame = cur_frame
					first = false
				else
					-- Looks like the game lags. Just send copy command.
					channel:push({get_filename(last_frame), get_filename(cur_frame)})
				end
			end
		end

		timer = timer - 1/OPT.fps
	end
end

function Peeker.attach()
	if not is_recording then return end
	love.graphics.setCanvas({
		canvas,
		stencil = OPT.flags.stencil,
		depth = OPT.flags.depth,
	})
	love.graphics.clear()
end

function Peeker.detach()
	if not is_recording then return end
	love.graphics.setCanvas()
	love.graphics.draw(canvas)

	if OPT.overlay then
		love.graphics.setColor(1, 0, 0, 1)
		if OPT.overlay == "text" then
			love.graphics.print("RECORDING", 4, 4)
		elseif OPT.overlay == "circle" then
			love.graphics.circle("fill", 12, 12, 8)
		end
	end
end

function Peeker.get_status()
	return is_recording
end

function Peeker.get_current_frame()
	return cur_frame
end

return Peeker
