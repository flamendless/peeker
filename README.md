# PEEKER

Multi-threaded screen recorder for [LOVE](https://love2d.org), made in LOVE, for LOVE.

## FEATURES

* Multi-threaded
* Can record multiple videos in a single launch of love
* Supports mp4, mkv, webm format
* No audio

## USAGE

Run [main.lua](main.lua) or the code below:

```lua
local Peeker = require("peeker")
local timer = 0

function love.update(dt)
	timer = timer + dt
	Peeker.update(dt)
end

function love.draw()
	Peeker.attach()
		love.graphics.setColor(1, 0, 0, 1)
		love.graphics.circle("fill", 160 + math.sin(timer) * 64, 160 + math.cos(timer) * 64, 20)
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.print("Is Recording: " .. tostring(Peeker.get_status()), 32, 32)
		love.graphics.print("I: " .. tostring(Peeker.get_current_frame()), 32, 64)
	Peeker.detach()
end

function love.keypressed(key)
	if key == "r" then
		if Peeker.get_status() then
			Peeker.stop()
		else
			Peeker.start({
				w = 320, --optional
				h = 320, --optional
				n_threads = 2,
				fps = 15,
				out_dir = string.format("awesome_video"), --optional
				format = "mkv", --optional
			})
		end
	elseif key == "s" then
		Peeker.finalize()
	end
end
```

This will create a folder `recorder_xxxx` that contains the captured frames
and the output video in the save directory of your game.

## DEPENDENCIES

For now, Linux + FFMPEG as dependecy is supported.
