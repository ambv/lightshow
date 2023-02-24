local R = {}

-- print a table
function R.p(tbl)
  for k, v in pairs(tbl) do
    print(k, v)
  end
end

-- print a table of tables
function R.pp(tbl)
	for k, v in pairs(tbl) do
		print(k)
		for kk, vv in pairs(v) do
			print(" ", kk, vv)
		end
	end
end

-- reload script
function R.r()
  norns.script.load(norns.state.script)
end

-- human duration to milliseconds
function R.d2m(minutes, seconds, millis)
	return 60000 * minutes + 1000 * seconds + millis
end

-- given a table of millis -> track name, return
-- a dense lookup table for each tenth of a second
-- `up_to` also in millis
function R.cue_lookup_from(cue_sheet, up_to)
	local result = {}
	local tracks = {}
	local track = nil
	local last_track = nil

	-- overcome Lua's inability to iterate in a sorted manner
	local cues = {}
	for cue in pairs(cue_sheet) do
		table.insert(cues, cue)
	end
	table.sort(cues)
	R.p(cues)

	-- gather track metadata
	for _, cue in ipairs(cues) do
		track = cue_sheet[cue]
		tracks[track] = {}
		tracks[track].start_ms = cue
		tracks[track].prev = last_track

		if last_track ~= nil then
			tracks[last_track].next = track
			tracks[last_track].finish = cue
		end

		last_track = track
	end

	tracks[last_track].next = nil
	tracks[last_track].finish = up_to

	R.pp(tracks)

	for _, cue in ipairs(cues) do
		name = cue_sheet[cue]
		local track = tracks[name]
		local start = math.floor(cue / 100)
		local finish = math.floor(0.5 + track.finish / 100)
		local meta = {}
		meta.track = name
		meta.start = start
		meta.finish = finish
		if track.prev then
			meta.prev = tracks[track.prev].start_ms
		else
			meta.prev = nil
		end
		if track.next then
			meta.next = tracks[track.next].start_ms
		else
			meta.next = nil
		end
		meta.bar = false
		meta.beat = false
		meta.kick = false
		for i=start, finish do
			result[i] = R.copy(meta)
		end
	end

	R.beatfile_in(result)

	-- Note that the resulting table contains a `0` index which
	-- isn't treated as a numerical index by Lua; it's omitted by
	-- ipairs() and the `0` key is stored in the hash part of the
	-- table.

	-- The following checks can be removed when I'm comfortable
	-- enough with Lua but for now I'm afraid it's too easy to do
	-- something wrong.
	local expected_count = math.floor(up_to / 100)
	local check=0
	for i=0, expected_count do
		if result[i] == nil then
			check = check + 1
			print("Missing key " .. i)
		end
	end
	if check > 0 then
		error("Check failed.")
	end

	check = 0
	for i in ipairs(result) do
		check = check + 1
	end
	if check ~= expected_count then
		error("Check should be " .. expected_count .. " but is " .. check)
	end
	return result
end

function R.copy(obj, seen)
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[R.copy(k, s)] = R.copy(v, s) end
  return res
end

function R.beatfile_in(cue_map)
	local fd=io.open(norns.state.data .. "beatfile", "r")
	if fd then
		io.input(fd)
		local i = 1
		for line in io.lines() do
			if string.find(line, "B") ~= nil then
				cue_map[i].bar = true
			end
			if string.find(line, "b") ~= nil then
				cue_map[i].beat = true
			end
			if string.find(line, "k") ~= nil then
				cue_map[i].kick = true
			end
			i = i + 1
		end
		io.close(fd)
	end
end

return R
