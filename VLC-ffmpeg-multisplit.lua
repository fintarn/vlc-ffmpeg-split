function descriptor()
  return {
    title = "Split: Mark In/Out (Multiple) and Create Clip",
    version = "1.0",
    author = "fintarn",
    url = "https://github.com/fintarn/vlc-ffmpeg-split",
    shortdesc = "Split and concat multiple clips with ffmpeg",
    description = "Mark multiple in/out pairs, extract clips and concatenate them into one file."
  }
end

local input_file_path = nil
local command_input
local checkbox_copyts
local mark_points = {}
local ffmpeg_temp_dir = nil
local temp_files = {}

for i = 1, 10 do
  mark_points[i] = { mark_in = nil, mark_out = nil }
end

function file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true else return false end
end

function create_temp_dir(base_path)
  local temp_path = base_path .. "/ffmpeg_temp"
  os.execute('mkdir "' .. temp_path .. '" >nul 2>&1')
  return temp_path
end

function format_time(t)
  local hrs = math.floor(t / 3600)
  local mins = math.floor((t % 3600) / 60)
  local secs = t % 60
  return string.format("%02d:%02d:%06.3f", hrs, mins, secs):gsub(",", ".")
end

function get_unique_output_filename(base, extension)
  local filename = base .. "_concat" .. extension
  local counter = 1
  while file_exists(filename) do
    counter = counter + 1
    filename = base .. "_concat" .. counter .. extension
  end
  return filename
end

function check_overlap_ranges(points)
  local ranges = {}
  for i, seg in ipairs(points) do
    if seg.mark_in and seg.mark_out then
      table.insert(ranges, {start = seg.mark_in, stop = seg.mark_out})
    end
  end

  table.sort(ranges, function(a, b) return a.start < b.start end)

  for i = 2, #ranges do
    if ranges[i].start < ranges[i - 1].stop then
      return true, ranges[i - 1], ranges[i]
    end
  end
  return false
end

function ensure_input_path()
  if input_file_path then return end

  local input_item = vlc.input.item()
  local uri = input_item and input_item:uri()
  if uri then
    input_file_path = vlc.strings.decode_uri(uri):gsub("file:///", "")
    vlc.msg.dbg("Input file path set to: " .. input_file_path)
  else
    vlc.msg.err("Unable to get input file path.")
  end
end

function activate()
  create_dialog()
end

function deactivate() end
function close() vlc.msg.dbg("Dialog closed") end
function meta_changed() end

function create_dialog()
  vlc.msg.dbg("Dialog created")
  local dlg = vlc.dialog("Split: Mark In/Out (Multiple)")

  local labels = {}

  local function refresh_labels()
    for idx = 1, 10 do
      local mi = mark_points[idx].mark_in
      local mo = mark_points[idx].mark_out
      labels[idx].in_label:set_text("Mark In " .. idx .. ": " .. (mi and format_time(mi) or "-"))
      labels[idx].out_label:set_text("Mark Out " .. idx .. ": " .. (mo and format_time(mo) or "-"))
    end
  end

  local function swap_marks(i, j)
    if i < 1 or i > 10 or j < 1 or j > 10 then return end
    mark_points[i], mark_points[j] = mark_points[j], mark_points[i]
    refresh_labels()
  end

  for i = 1, 10 do
    labels[i] = {}
    labels[i].in_label = dlg:add_label("Mark In " .. i .. ": -", 1, i, 1, 1)
    dlg:add_button("Mark In", function()
      ensure_input_path()
      local input = vlc.object.input()
      if not input then return end
      mark_points[i].mark_in = vlc.var.get(input, "time") / 1000000
      refresh_labels()
    end, 2, i, 1, 1)
  
    labels[i].out_label = dlg:add_label("Mark Out " .. i .. ": -", 3, i, 1, 1)
    dlg:add_button("Mark Out", function()
      ensure_input_path()
      local input = vlc.object.input()
      if not input then return end
      mark_points[i].mark_out = vlc.var.get(input, "time") / 1000000
      refresh_labels()
    end, 4, i, 1, 1)
  
    -- 🆕 Clear Button for each segment
    dlg:add_button("Clear", function()
      mark_points[i].mark_in = nil
      mark_points[i].mark_out = nil
      labels[i].in_label:set_text("Mark In " .. i .. ": -")
      labels[i].out_label:set_text("Mark Out " .. i .. ": -")
      vlc.msg.dbg("Cleared Mark In/Out for segment " .. i)
    end, 5, i, 1, 1)
    
    labels[i].up_btn = dlg:add_button("↑", function()
      swap_marks(i, i - 1)
    end, 6, i, 1, 1)

    labels[i].down_btn = dlg:add_button("↓", function()
      swap_marks(i, i + 1)
    end, 7, i, 1, 1)    
  
  end

  checkbox_copyts = dlg:add_check_box("Use -copyts", false, 1, 11, 2, 1)

  dlg:add_button("Create Clip", function()
    if not input_file_path then
      vlc.msg.err("Input file path is not set.")
      return
    end

    local valid_segments = {}
    for i, seg in ipairs(mark_points) do
      if seg.mark_in and seg.mark_out then
        if seg.mark_out <= seg.mark_in then
          vlc.msg.err(string.format(
            "Invalid segment %d: Mark Out (%s) is before or equal to Mark In (%s)",
            i, format_time(seg.mark_out), format_time(seg.mark_in)
          ))
          return
        end
        table.insert(valid_segments, seg)
      end
    end

    if #valid_segments == 0 then
      vlc.msg.err("No valid Mark In/Out pairs found.")
      return
    end

    local overlap, a, b = check_overlap_ranges(valid_segments)
    if overlap then
      vlc.msg.err(string.format("Overlap detected: %s–%s overlaps with %s–%s",
        format_time(a.start), format_time(a.stop), format_time(b.start), format_time(b.stop)))
      return
    end

    local input_file_dir = input_file_path:match("^(.*)[/\\][^/\\]+$") or "."
    local base_name = input_file_path:match("([^/\\]+)%.%w+$") or "output"
    local ext = input_file_path:match("^.+(%..+)$") or ".mp4"
    local base = input_file_dir .. "/" .. base_name
    ffmpeg_temp_dir = create_temp_dir(input_file_dir)
    temp_files = {}

    local list_path = ffmpeg_temp_dir .. "/list.txt"
    local list_file = io.open(list_path, "w")
    if not list_file then
      vlc.msg.err("Failed to open list.txt for writing.")
      return
    end


    for i, seg in ipairs(valid_segments) do
      local mark_in_fmt = format_time(seg.mark_in)
      local duration = seg.mark_out - seg.mark_in
      local duration_fmt = format_time(duration)
      local clip_path = ffmpeg_temp_dir .. "/part" .. i .. ext

      local copyts_flag = (checkbox_copyts and checkbox_copyts:get_checked()) and " -copyts" or ""

      local cmd = string.format('ffmpeg -y -i "%s" -ss %s -t %s -c copy%s "%s"',
        input_file_path, mark_in_fmt, duration_fmt, copyts_flag, clip_path)

      vlc.msg.dbg("Running: " .. cmd)
      os.execute(cmd)
      list_file:write('file \'' .. clip_path:gsub("\\", "/") .. "'\n")
      table.insert(temp_files, clip_path)
    end

    list_file:close()
    table.insert(temp_files, list_path)

    local output = get_unique_output_filename(base, ext)
    local concat_cmd = string.format('ffmpeg -y -f concat -safe 0 -i "%s" -c copy "%s"',
      list_path, output)
    vlc.msg.dbg("Concatenating: " .. concat_cmd)
    os.execute(concat_cmd)

    vlc.msg.dbg("Output file: " .. output)
    command_input:set_text(concat_cmd)
  end, 1, 12, 2, 1)

  dlg:add_button("Clean Temp Files", function()
    if temp_files then
      for _, path in ipairs(temp_files) do
        if file_exists(path) then
          os.remove(path)
          vlc.msg.dbg("Deleted temp file: " .. path)
        end
      end
    end
    if ffmpeg_temp_dir then
      os.execute('rmdir /S /Q "' .. ffmpeg_temp_dir .. '"')
      vlc.msg.dbg("Deleted temp directory: " .. ffmpeg_temp_dir)
    end
    temp_files = {}
    ffmpeg_temp_dir = nil
  end, 3, 12, 2, 1)

  dlg:add_button("Clear Marks", function()
    for i = 1, 10 do
      mark_points[i].mark_in = nil
      mark_points[i].mark_out = nil
      labels[i].in_label:set_text("Mark In " .. i .. ": -")
      labels[i].out_label:set_text("Mark Out " .. i .. ": -")
    end
    command_input:set_text("")
    vlc.msg.dbg("Cleared all marks.")
  end, 1, 13, 4, 1)

  command_input = dlg:add_text_input("", 1, 14, 4, 1)

  dlg:show()
end
