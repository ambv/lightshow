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

		if last_track ~= nil then
			tracks[last_track].finish = cue
		end

		last_track = track
	end

	tracks[last_track].finish = up_to

	for _, cue in ipairs(cues) do
		track = cue_sheet[cue]
		local start = math.floor(cue / 100)
		local finish = math.floor(0.5 + tracks[track].finish / 100)
		for i=start, finish do
			result[i] = {}
			result[i].track = track
			result[i].percentage = (i - start) / (finish - start)
		end
	end

	print(up_to)
	for i=0, math.floor(up_to / 100) do
		if result[i] == nil then
			print("Missing key", i)
		end
	end

	return result
end

return R