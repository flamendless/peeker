# PEEKER

Multi-threaded screen recorder for [LOVE](https://love2d.org), made in LOVE, for LOVE.

## FEATURES

* Multi-threaded
* Can record multiple videos in a single launch of love
* Can use different resolution/quality for recorded output
* Supports mp4, mkv, webm formats
* No audio

## USAGE

Run [main.lua](main.lua).

This will create a folder `awesome_video` or `recorder_xxxx` (if `out_dir` is
not passed) that contains the captured frames and the output video in the save
directory of your game.

## DEPENDENCIES

[FFMPEG](https://ffmpeg.org/) is required.

* For now Linux is fully supported.
* Windows is partially supported (requires testing as I do not have a Windows machine)
* PR for other OS is welcome
