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

local thread_code = [[
require("love.image")
local image_data, i, out_dir = ...
local filename = string.format("%04d.png", i)

if out_dir then
	filename = out_dir .. "/" .. filename
end

image_data:encode("png", filename)
love.thread.getChannel("status"):push(i)
]]

local threads = {}
local canvas
local timer, cur_frame = 0, 0
local is_recording = false

local supported_formats = {"mp4", "mkv", "webm"}
local OPT

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
	assert(type(opt.out_dir) == "string")
	sassert(opt.w, type(opt.w) == "number" and opt.w > 0,
		"opt.w must be a positive integer")
	sassert(opt.h, type(opt.h) == "number" and opt.h > 0,
		"opt.h must be a positive integer")
	assert(type(opt.n_threads) == "number" and opt.n_threads > 0,
		"opt.n_threads must be a positive integer")
	assert(opt.n_threads <= MAX_N_THREAD,
		"opt.n_threads should not be > " .. MAX_N_THREAD .. " max available threads")
	sassert(opt.fps, type(opt.fps) == "number" and opt.fps > 0,
		"opt.fps must be a positive integer")
	sassert(opt.format, type(opt.format) == "string"
		and within_itable(opt.format, supported_formats),
		"opt.format must be either: " .. table.concat(supported_formats))

	local ww, wh = love.graphics.getDimensions()
	OPT = opt
	OPT.w = OPT.w or ww
	OPT.h = OPT.h or wh
	OPT.fps = OPT.fps or 15
	OPT.format = OPT.format or "mp4"

	canvas = love.graphics.newCanvas(OPT.w, OPT.h)

	if OPT.out_dir then
		local info = love.filesystem.getInfo(OPT.out_dir)
		if not info then
			love.filesystem.createDirectory(OPT.out_dir)
		end
	end

	for i = 1, OPT.n_threads do
		threads[i] = love.thread.newThread(thread_code)
	end

	cur_frame = 0
	timer = 0
	is_recording = true
end

function Peeker.stop()
	is_recording = false
end

function Peeker.finalize()
	Peeker.stop()
	local path = love.filesystem.getSaveDirectory()
	if OPT.out_dir then
		path = path .. "/" .. OPT.out_dir
	end

	if OS == "Linux" then
		local cmd_cd = string.format("cd '%s'", path)
		local cmd_ffmpeg = string.format("ffmpeg -framerate '%d' -i '%%04d.png' output.%s;",
			OPT.fps, OPT.format)
		local cmd = string.format("bash -c '%s && %s'", cmd_cd, cmd_ffmpeg)
		os.execute(cmd)
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
	love.graphics.setCanvas(canvas)
	love.graphics.clear()
end

function Peeker.detach()
	if not is_recording then return end
	love.graphics.setCanvas()
	love.graphics.draw(canvas)
end

function Peeker.get_status()
	return is_recording
end

function Peeker.get_current_frame()
	return cur_frame
end

return Peeker
