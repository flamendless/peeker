local Peeker = require("peeker")

local timer = 0

function love.update(dt)
	timer = timer + dt
	Peeker.update(dt)
end

function love.draw()
	Peeker.attach()
		love.graphics.setColor(1, 0, 0, 1)
		love.graphics.circle("fill",
			160 + math.sin(timer) * 64,
			160 + math.cos(timer) * 64, 20)
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
				-- format = "mkv", --optional
			})
		end
	elseif key == "s" then
		Peeker.finalize()
	end
end
