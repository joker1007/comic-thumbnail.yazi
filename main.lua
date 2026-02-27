local M = {}

local function is_image(filename)
  local lower = filename:lower()
  return lower:match "%.jpe?g$" or lower:match "%.png$" or lower:match "%.webp$"
end

local function find_image_in_archive(job)
  ya.dbg("execute: lsar -j " .. tostring(job.file.url))
  local child, err = Command("lsar")
    :arg({ "-j", tostring(job.file.url) })
    :stdout(Command.PIPED)
    :stderr(Command.PIPED)
    :spawn()

  if err ~= nil then
    return nil, Err("lsar error: " .. tostring(err))
  end

  local output, wait_err = child:wait_with_output()
  if wait_err ~= nil then
    return nil, Err("lsar error: " .. tostring(wait_err))
  end

  local json = ya.json_decode(output.stdout)
  if not json or not json.lsarContents then
    ya.dbg("Failed to parse lsar JSON output")
    return nil, Err("Failed to parse lsar JSON output")
  end

  -- Collect image entries
  local images = {}
  for _, entry in ipairs(json.lsarContents) do
    local name = entry.XADFileName
    if name and is_image(name) then
      images[#images + 1] = { name = name, index = entry.XADIndex }
    end
  end

  if #images == 0 then
    ya.dbg("No image file found in archive")
    return nil, nil
  end

  -- Sort by filename
  table.sort(images, function(a, b) return a.name < b.name end)

  local first = images[1]
  ya.dbg("Found image: " .. first.name .. " at index " .. tostring(first.index))
  return first.index, nil
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
      local _, err = ya.image_show(cache, job.area)
      ya.preview_widget(job, err)
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
