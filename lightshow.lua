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

local g = grid.connect()
local a = arc.connect()

local duration_sect = 0
local track_pct = 0.0
local duration = "00:00"
local track = "by RPLKTR"
local message = "LIGHTSHOW"
local is_kick = false
local is_beat = false
local is_bar = false
local screen_dirty = false
local redraw_metro = metro.init()
local grid = {}

-- map in milliseconds
local cue_sheet = {}
cue_sheet[R.d2m(0,0,0)] = "Tempora M1"
cue_sheet[R.d2m(3,30,234)] = "Tempora M2"
cue_sheet[R.d2m(5,29,300)] = "Modular #4"
cue_sheet[R.d2m(8,53,944)] = "Tempora M3"
cue_sheet[R.d2m(11,22,777)] = "Iridium Acid"
cue_sheet[R.d2m(14,10,214)] = "Keith's Fire"
cue_sheet[R.d2m(16,45,745)] = "Challenger"
cue_sheet[R.d2m(19,15,418)] = "Amen, bracia"

-- dense map in tenths of a second
local cue_map = nil

function init()
  for x=1,16 do
    grid[x] = {}
    for y=1,8 do
      grid[x][y] = 0
    end
  end

	a:all(0)
  g:all(0)

  redraw_metro.event = redraw_event
  redraw_metro:start(1 / 30)

  Timber.add_params()
  Timber.add_sample_params(0)
  Timber.play_positions_changed_callback = play_position
  Timber.meta_changed_callback = sample_meta
  Timber.load_sample(0, "/home/we/dust/audio/lightshow/sound.flac")
  engine.noteKillAll()
end

function enc(e, d)
  print("Enc", e, d)
  if e == 2 then
    if d > 0 then next_track() end
    if d < 0 then prev_track() end
  end
end

function key(k, z)
  print("Key", k, z)
  if z == 0 then return end
  if k == 2 then press_reset(0) end
  if k == 3 then play_pause() end
end

function a.delta(n, d)
  local now
  local delta
  local new
  if n == 1 then
    return
  elseif n == 2 then
    now = params:get("filter_freq_0")
    delta = 100
    if now < 1111 then
      delta = 8
    elseif now < 2222 then
      delta = 12
    elseif now < 4444 then
      delta = 25
    end
    new = now + delta * d
    if new > 200 then
      params:set("filter_freq_0", new)
    end
  elseif n == 3 then
    now = params:get("filter_resonance_0")
    params:set("filter_resonance_0", now + 0.01 * d)
  elseif n == 4 then
    now = params:get("amp_0")
    delta = 0.02
    new = now + delta * d
    if new < -12.0 then
      new = -12.0
    elseif new > 0.0 then
      new = 0.0
    end
    params:set("amp_0", new)
  end
end

function g.key(x, y, z)
  if z == 0 then
    return
  end
  grid[x][y] = 16
end

function set_sample_params()
  local meta = Timber.samples_meta[0]
  if meta.streaming == 1 then
    params:set("play_mode_0", 2)
  else
    params:set("play_mode_0", 3)
  end
  params:set("amp_env_release_0", 1.0)
  params:set("start_frame_0", math.floor(duration_sect * meta.sample_rate / 10))
end

function next_track()
  local i = duration_sect
  local track = cue_map[i].track
  local new = cue_map[i].next
  if new then
    i = math.floor(0.5 + new / 100)
    while track == cue_map[i].track do
      i = i + 1
    end
    press_reset(i)
  end
end

function prev_track()
  local i = duration_sect
  local start = cue_map[i].start

  -- intuitive UX: when jumping back, first jump to the start of the current track
  if i - start > 10 then
    press_reset(start)
    return
  end

  local track = cue_map[i].track
  local new = cue_map[i].prev
  if new then
    i = math.floor(new / 100)
    while track == cue_map[i].track do
      i = i - 1
    end
    press_reset(i)
  else
    press_reset(0)
  end
end

function press_reset(to)
  if Timber.samples_meta[0].playing then
    return
  end
  message = "stopped"
  duration_sect = to
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
  local sect_now
  if meta.playing then
    sect_now = math.floor(10 * percentage * seconds_total)
  else
    sect_now = duration_sect
  end
  if duration_sect ~= sect_now then
    duration_sect = sect_now
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
    if (10 * meta.num_frames / meta.sample_rate) - duration_sect <= 1 then
      message = "stopped"
      duration_sect = 0
      redraw_duration_display()
    else
      message = "paused"
    end
    screen_dirty = true
  end
end

function redraw_duration_display()
  local minutes_now = math.floor(duration_sect / 600)
  local seconds_now = math.floor((duration_sect - 600 * minutes_now) / 10)

  local track_cue = cue_map[duration_sect]
  track = track_cue.track
  track_pct = (duration_sect - track_cue.start) / (track_cue.finish - track_cue.start)
  is_beat = track_cue.beat
  is_bar = track_cue.bar
  is_kick = track_cue.kick

  if seconds_now < 10 then
    seconds_now = "0" .. seconds_now
  end
  if minutes_now < 10 then
    minutes_now = "0" .. minutes_now
  end
  duration = minutes_now .. ":" .. seconds_now
  screen_dirty = true

  local old = 0
  for x=1,16 do
    for y=1,8 do
      old = grid[x][y]
      if old > 0 then
        grid[x][y] = old - 1
      end
    end
  end

  local x
  local y
  if is_beat then
    x = 8 + math.floor(0.5 + math.random() * 8)
    y = math.floor(0.5 + math.random() * 8)
    grid[x][y] = 16
  end

  if is_bar then
    for i=1,4 do
      x = 8 + math.floor(0.5 + math.random() * 8)
      y = math.floor(0.5 + math.random() * 8)
      grid[x][y] = 16
    end
  end
end

function redraw_event()
  if screen_dirty then
    redraw()
    screen_dirty = false
  end
  grid_redraw()
  arc_redraw()
end

function grid_redraw()
  if is_bar then
    g:all(2)
  elseif is_beat then
    g:all(1)
  else
    g:all(0)
  end
  local percentage = math.floor(16 * track_pct)
  for i=1,16 do
    if percentage >= i then
      g:led(i, 1, 15)
    end
  end

  for x=1,16 do
    for y=3,8 do
      if grid[x][y] > 0 then
        g:led(x, y, grid[x][y])
      end
    end
  end
  g:refresh()
end

function arc_redraw()
  if is_bar then
    a:all(2)
  elseif is_beat then
    a:all(1)
  else
    a:all(0)
  end
  -- ARC 1
  local percentage = math.floor(64 * track_pct)
  for i=1,64 do
    if percentage >= i then
      a:led(1, i, 15)
    end
  end
  -- ARC 2
  percentage = math.floor(64 * params:get("filter_freq_0") / 20000)
  for i=1,64 do
    if percentage >= i then
      a:led(2, i, 15)
    end
  end
  -- ARC 3
  percentage = math.floor(64 * params:get("filter_resonance_0"))
  for i=1,64 do
    if percentage >= i then
      a:led(3, i, 15)
    end
  end
  -- ARC 4
  percentage = math.floor(64 * (params:get("amp_0") + 24) / 12 - 64)
  for i=1,64 do
    if percentage >= i then
      a:led(4, i, 15)
    end
  end
  a:refresh()
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

  local progress = math.floor(track_pct * 128.0)
  screen.level(16)
  screen.rect(0, 46, progress, 18)
  screen.fill()
  if is_bar then
    screen.level(2)
  else
    screen.level(1)
  end
  screen.rect(progress+1, 46, 128, 18)
  screen.fill()

  screen.level(0)
  screen.move(64, 58)
  screen.text_center(track)
  screen.fill()
  screen.update()
end

function cleanup()
  engine.noteKillAll()
  redraw_metro:stop()
end