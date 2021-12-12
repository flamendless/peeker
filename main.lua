local Peeker = require("peeker")

local timer = 0
local circles = {}

function love.load()
	local ww, wh = love.graphics.getDimensions()
	for i = 1, 16 do
		local c = {
			fill = love.math.random() <= 0.5 and "fill" or "line",
			x = love.math.random(ww * 0.25, ww * 0.75),
			y = love.math.random(wh * 0.25, wh * 0.75),
			radius = love.math.random(8, 32),
			dir = love.math.random() <= 0.5 and -1 or 1,
		}
		table.insert(circles, c)
	end
end

function love.update(dt)
	timer = timer + dt
	Peeker.update(dt)
end

function love.draw()
	Peeker.attach()
		love.graphics.clear(0, 0, 0, 1)
		love.graphics.setColor(1, 0, 0, 1)
		for _, c in ipairs(circles) do
			love.graphics.circle(c.fill,
				c.x + math.sin(timer) * 64 * c.dir,
				c.y + math.cos(timer) * 64 * c.dir,
				c.radius)
		end
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.print("Frame recorded: " .. tostring(Peeker.get_current_frame()), 32, 64)
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
				scale = 0.5, --this overrides w, h above, this is preferred to keep aspect ratio
				-- n_threads = 2,
				fps = 15,
				out_dir = string.format("awesome_video"), --optional
				-- format = "mkv", --optional
				overlay = "circle", --or "text"
				post_clean_frames = true,
			})
		end
	end
end
