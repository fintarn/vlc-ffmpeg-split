function descriptor()
  return {
    title = "Split: Mark In/Out and Create Clip",
    version = "1.4",
    author = "fintarn",
    url = "https://github.com/fintarn/vlc-ffmpeg-split",
    shortdesc = "Split: Mark In/Out and Create Clip",
    description = "Mark in and out points (-ss, -t) and split a video/audio clip using ffmpeg."
  }
end

local mark_in = nil
local mark_out = nil
local input_file_path = nil
local command_input
local checkbox_copyts

-- Utility: Check if file exists
function file_exists(name)
  vlc.msg.dbg("Checking if file exists: " .. name)
  local f = vlc.io.open(name, "r")
  if f then 
    f:close()  -- Close the file handle if it was successfully opened
    vlc.msg.dbg("file exists: " .. name)
    return true
  else
    vlc.msg.dbg("file doesnt exist")
    return false
  end
end

-- Utility: Generate unique output filename to avoid overwrite
function get_unique_output_filename(base, extension)
  local filename = base .. "_edit" .. extension
  local counter = 1
  while file_exists(filename) do
    counter = counter + 1
    filename = base .. "_edit" .. counter .. extension
  end
  return filename
end

-- Execute ffmpeg via PowerShell for Unicode-safe fallback
function run_ffmpeg_via_powershell(cmd)
  local temp_dir = os.getenv("TEMP") or "."
  local ps1_path = temp_dir .. "\\vlc_ffmpeg_temp.ps1"

  -- Write UTF-8 with BOM
  local ps1_file = io.open(ps1_path, "wb")
  if not ps1_file then
    vlc.msg.err("Failed to create PowerShell script file.")
    return -1
  end
  ps1_file:write(string.char(0xEF, 0xBB, 0xBF)) -- BOM
  ps1_file:write(cmd .. "\n")
  -- ps1_file:write("pause\n") -- Keep for debug; remove in production
  ps1_file:close()

  vlc.msg.dbg("PowerShell script written to: " .. ps1_path)

  local exec_result = os.execute('powershell -ExecutionPolicy Bypass -File "' .. ps1_path .. '"')
  if exec_result ~= 0 then
    vlc.msg.err("ffmpeg PowerShell execution failed with exit code: " .. tostring(exec_result))
  else
    vlc.msg.dbg("ffmpeg command executed successfully via PowerShell.")
  end

  os.remove(ps1_path) -- Optional: clean up temp file
  return exec_result
end

function activate()
  create_dialog()
end

function deactivate() end
function close() vlc.msg.dbg("Dialog closed") end
function meta_changed() end

-- Clear all marks
function clear_marks(mark_in_label, mark_out_label)
  mark_in = nil
  mark_out = nil
  mark_in_label:set_text("Mark In: -")
  mark_out_label:set_text("Mark Out: -")
  command_input:set_text("")
  vlc.msg.dbg("Marks cleared.")
end

-- Generate ffmpeg command with overwrite protection
function generate_ffmpeg_command()
  if not mark_in then
    vlc.msg.err("Mark In not set.")
    return nil
  end
  if not mark_out then
    vlc.msg.err("Mark Out not set.")
    return nil
  end
  if not input_file_path then
    vlc.msg.err("Input file path is not available.")
    return nil
  end

  local base = input_file_path:match("([^\\/]+)%..+$") or "output"
  local ext = input_file_path:match("^.+(%..+)$") or ".mp4"
  local input_dir = input_file_path:match("^(.*)[/\\]") or "."

  local output = get_unique_output_filename(input_dir .. "/" .. base, ext)

  local mark_in_fmt = string.format("%02d:%02d:%06.3f", math.floor(mark_in / 3600),
    math.floor(mark_in / 60) % 60, mark_in % 60)
  local duration = mark_out - mark_in
  local duration_fmt = string.format("%02d:%02d:%06.3f", math.floor(duration / 3600),
    math.floor(duration / 60) % 60, duration % 60)

  local copyts_flag = ""
  if checkbox_copyts and checkbox_copyts:get_checked() then
    copyts_flag = "-copyts"
  end

  local cmd = string.format('ffmpeg -y -i "%s" %s -ss %s -t %s -c copy "%s"',
    input_file_path, copyts_flag, mark_in_fmt, duration_fmt, output)


  command_input:set_text(cmd)
  return cmd
end

-- Build the dialog UI
function create_dialog()
  vlc.msg.dbg("Dialog created")
  local dlg = vlc.dialog("Split: Mark In/Out")

  local mark_in_label = dlg:add_label("Mark In: -", 1, 1, 1, 1)
  local mark_out_label = dlg:add_label("Mark Out: -", 3, 1, 1, 1)
  checkbox_copyts = dlg:add_check_box("Use -copyts", false, 1, 2, 2, 1)

  dlg:add_button("Mark In", function()
    local input = vlc.object.input()
    if not input then return end
    mark_in = vlc.var.get(input, "time") / 1000000
    local formatted = string.format("%02d:%02d:%06.3f", math.floor(mark_in / 3600),
      math.floor(mark_in / 60) % 60, mark_in % 60)
    mark_in_label:set_text("Mark In: " .. formatted)

    local input_item = vlc.input.item()
    if input_item then
      local uri = input_item:uri()
      if uri then
        input_file_path = vlc.strings.decode_uri(uri):gsub("file:///", "")
        vlc.msg.dbg("Input file path set to: " .. input_file_path)
      end
    end
  end, 2, 1, 1, 1)

  dlg:add_button("Mark Out", function()
    local input = vlc.object.input()
    if not input then return end
    mark_out = vlc.var.get(input, "time") / 1000000
    local formatted = string.format("%02d:%02d:%06.3f", math.floor(mark_out / 3600),
      math.floor(mark_out / 60) % 60, mark_out % 60)
    mark_out_label:set_text("Mark Out: " .. formatted)
  end, 4, 1, 1, 1)

  dlg:add_button("Split", function()
    local cmd = generate_ffmpeg_command()
    if cmd then
      vlc.msg.dbg("Executing: " .. cmd)
      local result = os.execute(cmd)
      if result ~= 0 then
        vlc.msg.err("ffmpeg command failed with exit code: " .. tostring(result))
        vlc.msg.warn("Trying PowerShell fallback.")
        result = run_ffmpeg_via_powershell(cmd)
      end
      if result == 0 then
        vlc.msg.dbg("ffmpeg command executed successfully.")
        clear_marks(mark_in_label, mark_out_label)
      end
    end
  end, 1, 3, 2, 1)

  dlg:add_button("Split at End", function()
    if not mark_in then
      vlc.msg.err("Mark In must be set for 'Split at End'.")
      return
    end
    if not input_file_path then
      vlc.msg.err("Input file path is not set.")
      return
    end
    local input = vlc.input.item()
    if input then
      mark_out = input:duration()
      vlc.msg.dbg("Mark Out set to full duration: " .. tostring(mark_out))
      local cmd = generate_ffmpeg_command()
      if cmd then
        vlc.msg.dbg("Executing: " .. cmd)
        local result = os.execute(cmd)
        if result ~= 0 then
          vlc.msg.err("ffmpeg command failed with exit code: " .. tostring(result))
          vlc.msg.warn("Trying PowerShell fallback.")
          result = run_ffmpeg_via_powershell(cmd)
        end
        if result == 0 then
          vlc.msg.dbg("ffmpeg command executed successfully.")
          clear_marks(mark_in_label, mark_out_label)
        end
      end
    else
      vlc.msg.err("Failed to get input duration for 'Split at End'.")
    end
  end, 3, 3, 2, 1)

  dlg:add_button("Show ffmpeg cmd", function()
    local cmd = generate_ffmpeg_command()
    if cmd then
      vlc.msg.dbg("ffmpeg command generated for preview.")
    end
  end, 1, 4, 4, 1)

  dlg:add_button("Clear Marks", function()
    clear_marks(mark_in_label, mark_out_label)
  end, 1, 5, 4, 1)

  command_input = dlg:add_text_input("", 1, 6, 4, 1)

  dlg:show()
end
