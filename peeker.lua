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
local MAX_N_THREAD = love.system.getProcessorCount()
local OS = love.system.getOS()

local thread_code = [[
require("love.image")
local image_data, i, out_dir = ...
local filename = string.format("%04d.png", i)
filename = out_dir .. "/" .. filename
local res = image_data:encode("png", filename)
if res then
	love.thread.getChannel("status"):push(i)
else
	print(i, res)
end
]]

local threads = {}
local canvas
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

function Peeker.start(opt)
	assert(type(opt) == "table")
	sassert(opt.w, type(opt.w) == "number" and opt.w > 0,
		"opt.w must be a positive integer")
	sassert(opt.h, type(opt.h) == "number" and opt.h > 0,
		"opt.h must be a positive integer")
	sassert(opt.scale, type(opt.scale) == "number")
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
	sassert(opt.post_clean_frames, type(opt.post_clean_frames) == "boolean")

	OPT = opt

	local ww, wh = love.graphics.getDimensions()
	OPT.w = OPT.w or ww
	OPT.h = OPT.h or wh
	if OPT.scale then
		OPT.orig_sx, OPT.orig_sy = 1/OPT.scale, 1/OPT.scale
		OPT.sx, OPT.sy = OPT.scale, OPT.scale
	else
		OPT.orig_sx, OPT.orig_sy = ww/OPT.w, wh/OPT.h
		OPT.sx, OPT.sy = OPT.w/ww, OPT.h/wh
	end

	OPT.n_threads = OPT.n_threads or MAX_N_THREAD
	OPT.fps = OPT.fps or DEF_FPS
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

	for i = 1, OPT.n_threads do
		threads[i] = love.thread.newThread(thread_code)
	end

	canvas = love.graphics.newCanvas(OPT.w, OPT.h)
	cur_frame = 0
	timer = 0
	is_recording = true
end

function Peeker.stop(finalize)
	sassert(finalize, type(finalize) == "boolean")
	is_recording = false
	if not finalize then return end

	local path = love.filesystem.getSaveDirectory() .. "/" .. OPT.out_dir
	local flags, cmd = "", ""

	if OPT.format == "mp4" then
		flags = "-filter:v format=yuv420p -movflags +faststart"
	end

	local out_file = string.format("../%s.%s", OPT.out_dir, OPT.format)

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
	local image_data = canvas:newImageData()
	local found = false
	for _, thread in ipairs(threads) do
		if not thread:isRunning() then
			thread:start(image_data, cur_frame, OPT.out_dir)
			found = true
			break
		end

		local err = thread:getError()
		if err then
			print(err)
		end
	end

	if not found then
		for _, thread in ipairs(threads) do
			thread:wait()
			break
		end
	end

	local status = love.thread.getChannel("status"):pop()
	if status then cur_frame = cur_frame + 1 end
end

function Peeker.attach()
	if not is_recording then return end
	love.graphics.setCanvas({
		canvas,
		stencil = OPT.flags.stencil,
		depth = OPT.flags.depth,
	})
	love.graphics.clear()
	love.graphics.push()
	love.graphics.scale(OPT.sx, OPT.sy)
end

function Peeker.detach()
	if not is_recording then return end
	local r, g, b, a = love.graphics.getColor()
	love.graphics.pop()
	love.graphics.setCanvas()
	love.graphics.setColor(1, 1, 1)

	love.graphics.push()
	love.graphics.scale(OPT.orig_sx, OPT.orig_sy)
	love.graphics.draw(canvas)
	love.graphics.pop()

	if OPT.overlay then
		love.graphics.setColor(1, 0, 0, 1)
		if OPT.overlay == "text" then
			love.graphics.print("RECORDING", 4, 4)
		elseif OPT.overlay == "circle" then
			love.graphics.circle("fill", 12, 12, 8)
		end
	end
end

function Peeker.get_status() return is_recording end
function Peeker.get_current_frame() return cur_frame end

return Peeker
