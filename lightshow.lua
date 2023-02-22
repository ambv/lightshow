-- /// Lightshow ///
-- >> k1: exit
-- >> k2:
-- >> k3:
-- >> e1:
-- >> e2:
-- >> e3:

MusicUtil = require "musicutil"
Timber = include("timber/lib/timber_engine")
R = include("lightshow/lib/rplktr_util")
engine.name = "Timber"

duration_sec = 0
duration = "00:00"
track = "by RPLKTR"
message = "LIGHTSHOW"
local screen_dirty = false
redraw_metro = metro.init()

-- map in milliseconds
cue_sheet = {}
cue_sheet[R.d2m(0,0,0)] = "Tempora M1"
cue_sheet[R.d2m(3,30,234)] = "Tempora M2"
cue_sheet[R.d2m(5,29,300)] = "Modular 1"
cue_sheet[R.d2m(11,22,777)] = "Iridium Acid"
cue_sheet[R.d2m(14,10,214)] = "Keith's Fire"
cue_sheet[R.d2m(16,45,745)] = "Challenger"
cue_sheet[R.d2m(19,15,418)] = "Amen, bracia"

-- dense map in tenths of a second
cue_map = nil

function init()
  redraw_metro.event = redraw_event
  redraw_metro:start(1 / 10)

  Timber.add_params()
  Timber.add_sample_params(0)
  Timber.play_positions_changed_callback = play_position
  Timber.meta_changed_callback = sample_meta
  Timber.load_sample(0, "/home/we/dust/audio/lightshow/sound.flac")
  engine.noteKillAll()
end

function enc(e, d)
  screen_dirty = true
end

function key(k, z)
  print("Key", k, z)
  if z == 0 then return end
  if k == 2 then press_reset() end
  if k == 3 then play_pause() end
end

function set_sample_params()
  local meta = Timber.samples_meta[0]
  if meta.streaming == 1 then
    params:set("play_mode_0", 2)
  else
    params:set("play_mode_0", 3)
  end
  params:set("amp_env_release_0", 1.0)
  params:set("start_frame_0", duration_sec * meta.sample_rate)
end

function press_reset()
  if Timber.samples_meta[0].playing then
    return
  end
  message = "stopped"
  duration_sec = 0
  set_sample_params()
  redraw_duration_display()
  screen_dirty = true
end

function play_pause()
  if Timber.samples_meta[0].playing then
    engine.noteOff(0)
  else
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
  if id ~= 0 then
    return
  end

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

function sample_meta(id)
  if id ~= 0 then
    return
  end

  local meta = Timber.samples_meta[0]
  if cue_map == nil then
    cue_map = R.cue_lookup_from(cue_sheet, 1000 * meta.num_frames / meta.sample_rate)
  end
  if meta.playing and message ~= "playing" then
    message = "playing"
    screen_dirty = true
  elseif not meta.playing and message == "playing" then
    if (meta.num_frames / meta.sample_rate) - duration_sec <= 1 then
      message = "stopped"
      duration_sec = 0
      redraw_duration_display()
    else
      message = "paused"
    end
    screen_dirty = true
  end
end

function redraw_duration_display()
  local minutes_now = math.floor(duration_sec / 60)
  local seconds_now = duration_sec - 60 * minutes_now

  track = cue_map[10 * duration_sec].track

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
    redraw()
    screen_dirty = false
  end
end

function redraw()
  screen.clear()
  screen.aa(0)
  screen.font_face(1)
  screen.font_size(32)
  screen.level(16)
  screen.move(64, 24)
  screen.text_center(duration)
  screen.font_size(16)
  screen.level(4)
  screen.move(64, 40)
  screen.text_center(message)
  screen.level(1)
  screen.move(64, 58)
  screen.text_center(track)
  screen.fill()
  screen.update()
end

function cleanup()
  engine.noteKillAll()
  redraw_metro:stop()
end