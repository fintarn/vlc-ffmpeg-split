function descriptor()
  return {
    title = "Split: Mark In/Out and Create Clip",
    version = "1.3",
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

function file_exists(name)
  local f = io.open(name, "r")
  if f then f:close() return true else return false end
end

function get_unique_output_filename(base, extension)
  local filename = base .. "_edit" .. extension
  local counter = 1
  while file_exists(filename) do
    counter = counter + 1
    filename = base .. "_edit" .. counter .. extension
  end
  return filename
end

function activate()
  create_dialog()
end

function deactivate() end
function close() vlc.msg.dbg("Dialog closed") end
function meta_changed() end

function clear_marks(mark_in_label, mark_out_label)
  mark_in = nil
  mark_out = nil
  mark_in_label:set_text("Mark In: -")
  mark_out_label:set_text("Mark Out: -")
  command_input:set_text("")
  vlc.msg.dbg("Marks cleared.")
end

function create_dialog()
  vlc.msg.dbg("Dialog created")
  local dlg = vlc.dialog("Split: Mark In/Out")

  local mark_in_label = dlg:add_label("Mark In: -", 1, 1, 1, 1)
  local mark_out_label = dlg:add_label("Mark Out: -", 3, 1, 1, 1)

  checkbox_copyts = dlg:add_check_box("Use -copyts", false, 1, 2, 2, 1)

  dlg:add_button("Mark In", function()
    local input = vlc.object.input()
    if not input then
      vlc.msg.err("No input found for Mark In.")
      return
    end
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

    if not input_file_path then
      vlc.msg.err("Failed to retrieve the file path for the current input.")
    end
  end, 2, 1, 1, 1)

  dlg:add_button("Mark Out", function()
    local input = vlc.object.input()
    if not input then
      vlc.msg.err("No input found for Mark Out.")
      return
    end
    mark_out = vlc.var.get(input, "time") / 1000000
    local formatted = string.format("%02d:%02d:%06.3f", math.floor(mark_out / 3600),
      math.floor(mark_out / 60) % 60, mark_out % 60)
    mark_out_label:set_text("Mark Out: " .. formatted)
  end, 4, 1, 1, 1)

  local function generate_ffmpeg_command()
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

    local base = input_file_path:match("(.+)%..+$")
    local ext = input_file_path:match("^.+(%..+)$")

    local mark_in_fmt = string.format("%02d:%02d:%06.3f", math.floor(mark_in / 3600),
      math.floor(mark_in / 60) % 60, mark_in % 60)
    local duration = mark_out - mark_in
    local duration_fmt = string.format("%02d:%02d:%06.3f", math.floor(duration / 3600),
      math.floor(duration / 60) % 60, duration % 60)

    local output = get_unique_output_filename(base, ext)
    local copyts_flag = ""
    if checkbox_copyts and checkbox_copyts.checked then
      copyts_flag = checkbox_copyts:checked() and " -copyts" or ""
    end
    local cmd = string.format('ffmpeg -y -i "%s" -ss %s -t %s -c copy%s "%s"',
      input_file_path, mark_in_fmt, duration_fmt, copyts_flag, output)

    command_input:set_text(cmd)
    return cmd
  end

  dlg:add_button("Split", function()
    local cmd = generate_ffmpeg_command()
    if cmd then
      vlc.msg.dbg("Executing: " .. cmd)
      local result = os.execute(cmd)
      if result ~= 0 then
        vlc.msg.err("ffmpeg command failed with exit code: " .. tostring(result))
      else
        vlc.msg.dbg("ffmpeg command executed successfully.")
      end
      clear_marks(mark_in_label, mark_out_label)
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
        else
          vlc.msg.dbg("ffmpeg command executed successfully.")
        end
        clear_marks(mark_in_label, mark_out_label)
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
