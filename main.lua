local M = {}

local function find_image_in_archive(job)
  ya.dbg("execute: lsar " .. tostring(job.file.url))
  local child, err = Command("lsar")
    :arg({
      tostring(job.file.url),
    })
    :stdout(Command.PIPED)
    :stderr(Command.PIPED)
    :spawn()

  if err ~= nil then
    return nil, Err("lsar error: " .. tostring(err))
  end

  local i, current = -1, ""
  repeat
    local next, event = child:read_line()
    if event ~= 0 then
      break
    end

    current = next:gsub("\n", "")
    ya.dbg("lsar output: " .. tostring(current))

    if current:find "%.*%.[jJ][pP][gG]" or current:find "%.*%.[pP][nN][gG]" then
      ya.dbg("Found image: " .. tostring(current) .. " at index " .. tostring(i))
      child:start_kill()
      return i, nil
    end

    i = i + 1
  until i > 10

  child:start_kill()
  ya.dbg("No image file found in archive")
  return nil, nil
end

local function extract_and_convert_image(job, index, cache)
  ya.dbg("execute: unar -o - -i " .. tostring(job.file.url) .. " " .. tostring(index))
  local child, _ = Command("unar")
    :arg({
      "-o",
      "-",
      "-i",
      tostring(job.file.url),
      tostring(index),
    })
    :stdout(Command.PIPED)
    :stderr(Command.PIPED)
    :spawn()

  local output, err = child:wait_with_output()

  if err ~= nil then
    return false, Err("unar error: " .. tostring(err))
  end

  ya.dbg("execute: magick - -resize " .. tostring(rt.preview.max_width) .. " jpg:" .. tostring(cache))
  child = Command("magick")
    :arg({
      "-",
      "-resize",
      tostring(rt.preview.max_width),
      "jpg:" .. tostring(cache),
    })
    :stdin(Command.PIPED)
    :stderr(Command.PIPED)
    :spawn()
  child:write_all(output.stdout)
  child:flush()
  local magick_output, err = child:wait_with_output()

  if magick_output.stderr ~= "" then
    ya.err("magick output: " .. tostring(magick_output.stderr))
    return false, Err("magick failed to convert image: " .. tostring(magick_output.stderr))
  end

  if err ~= nil then
    ya.err("magick error: " .. tostring(err))
    return false, Err("magick error: " .. tostring(err))
  end

  return true, nil
end

function M:preload(job)
  local cache = ya.file_cache(job)
  if not cache then
    return false, Err("Failed to get cache path for file: " .. tostring(job.file.url))
  end

  local cache_cha, _ = fs.cha(cache)
  if cache_cha and cache_cha.len > 0 then
    ya.dbg("Preloader find cache file: " .. tostring(cache))
    return true, nil
  end

  local image_index, err = find_image_in_archive(job)
  if image_index == nil or err then
    return false, err
  end

  return extract_and_convert_image(job, image_index, cache)
end

function M:peek(job)
  local ok, err = self:preload(job)
  if not ok then
    ya.err("peek preload error: " .. tostring(err))
    return
  end

  local cache = ya.file_cache(job)
  if cache then
    local cha = fs.cha(cache)
    if cha then
      ya.dbg("Using cached image for peek: " .. tostring(cache))
      ya.image_show(cache, job.area)
      ya.preview_widgets(job, {})
      return
    end
  end
end

function M:seek(job)
  local h = cx.active.current.hovered
  if h and h.url == job.file.url then
    local step = math.floor(job.units * job.area.h / 10)
    ya.manager_emit("peek", {
      tostring(math.max(0, cx.active.preview.skip + step)),
      only_if = tostring(job.file.url),
    })
  end
end

return M
