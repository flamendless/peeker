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
not passed) that contains the captured frames and the output video in the [save
directory](https://love2d.org/wiki/love.filesystem) of your game.

## CONFIGS

Here are the options/flags you can pass in `Peeker.start`:

* w - **width** of the output. Defaults to size of the window.
* h - **height** of the output. Defaults to size of the window.
* scale - this overrides the `w` and `h` flags and is preferred to keep the aspect ratio of the output.
* fps - **fps** of the output video. Defaults to `30`.
* out_dir = name of the directory where the frames will be saved. Refer to the [wiki](https://love2d.org/wiki/love.filesystem) for the save directory location. Defaults to `recorder_xxxx` where `xxxx` is `os.time`.
* format - either `"mp4"`, `"mkv"`, or `"webm"` for the format of the output video. Defaults to `mp4`
* overlay - either `"text"` or `"circle"` to display when recording status is on.
* post_clean_frames - if **true**, the `out_dir` will be deleted after the vide output is successfully encoded.

## DEPENDENCIES

[FFMPEG](https://ffmpeg.org/) is required.

* For now Linux is fully supported.
* Windows is partially supported (requires testing as I do not have a Windows machine)
* PR for other OS is welcome
