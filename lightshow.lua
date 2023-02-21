-- /// Lightshow ///
-- >> k1: exit
-- >> k2:
-- >> k3:
-- >> e1:
-- >> e2:
-- >> e3:

MusicUtil = require "musicutil"
Timber = include("timber/lib/timber_engine")
engine.name = "Timber"

duration_sec = 0
message = "LIGHTSHOW"
local screen_dirty = false
redraw_metro = metro.init()

function init()
  redraw_metro.event = redraw_event
  redraw_metro:start(1 / 10)
  redraw_duration_display()

  Timber.add_params()
  Timber.add_sample_params(0)
  Timber.play_positions_changed_callback = play_position
  Timber.load_sample(0, "/home/we/dust/audio/lightshow/sound.flac")
  engine.noteKillAll()
end

function enc(e, d)
  screen_dirty = true
end

function key(k, z)
  if z == 0 then return end
  if k == 2 then press_reset() end
  if k == 3 then play_pause() end
end

function set_sample_params()
  local sr = Timber.samples_meta[0].sample_rate

  params:set("play_mode_0", 2)
  params:set("amp_env_release_0", 1.0)
  params:set("start_frame_0", duration_sec * sr)
end

function press_reset()
  if Timber.samples_meta[0].playing then
    return
  end
  message = "reset"
  duration_sec = 0
  set_sample_params()
  redraw_duration_display()
  screen_dirty = true
end

function play_pause()
  if Timber.samples_meta[0].playing then
    message = "paused"
    engine.noteOff(0)
  else
    message = "playing"
    set_sample_params()
    engine.noteOn(
      0, -- voice
      MusicUtil.note_num_to_freq(60), -- frequency
      1.0, -- velocity
      0 -- sample
    )
  end
  screen_dirty = true
end

function play_position(id)
  local meta = Timber.samples_meta[0]
  local percentage = meta.positions[0] or 0
  local seconds_total = meta.num_frames / meta.sample_rate
  local seconds_now
  if meta.playing then
    seconds_now = math.floor(percentage * seconds_total)
  else
    seconds_now = duration_sec
  end
  if duration_sec ~= seconds_now then
    duration_sec = seconds_now
    redraw_duration_display()
  end
end

function redraw_duration_display()
  local minutes_now = math.floor(duration_sec / 60)
  local seconds_now = duration_sec - 60 * minutes_now
  if seconds_now < 10 then
    seconds_now = "0" .. seconds_now
  end
  if minutes_now < 10 then
    minutes_now = "0" .. minutes_now
  end
  duration = minutes_now .. ":" .. seconds_now
  screen_dirty = true
end

function redraw_event()
  if screen_dirty then
    redraw_screen()
    screen_dirty = false
  end
end

function redraw_screen()
  screen.clear()
  screen.aa(0)
  screen.font_face(1)
  screen.font_size(32)
  screen.level(16)
  screen.move(64, 32)
  screen.text_center(duration)
  screen.font_size(16)
  screen.level(4)
  screen.move(64, 48)
  screen.text_center(message)
  screen.fill()
  screen.update()
end

function r()
  norns.script.load(norns.state.script)
end

function printable(tbl)
  for k, v in pairs(tbl) do
    print(k, v)
  end
end

function cleanup()
  engine.
  redraw_metro:stop()
end