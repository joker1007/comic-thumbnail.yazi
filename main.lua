local M = {}

math.randomseed(os.time())

function M:peek(job)
  local cache = ya.file_cache(job)
  if cache then
    ya.image_show(cache, job.area)
    ya.preview_widgets(job, {})
  end

  local child = Command("lsar")
      :args({
        tostring(job.file.url),
      })
      :stdout(Command.PIPED)
      :stderr(Command.PIPED)
      :spawn()

  if code then
    ya.err("lsar error: " .. code)
    return
  end

  local i, current = -1, ""
  repeat
    local next, event = child:read_line()
    if event ~= 0 then
      break
    end

    current = next:gsub("\n", "")

    if current:find("%.*%.[jJ][pP][gG]") or current:find("%.*%.[pP][nN][gG]") then
      break
    end

    i = i + 1
  until i > 10

  child:start_kill()

  local random = math.random(1000000, 9999999)
  local outdir = "/tmp/yazi-" .. random

  child, err = Command("unar")
      :args({
        "-f",
        "-D",
        "-o",
        outdir,
        "-i",
        tostring(job.file.url),
        tostring(i),
      })
      :stdout(Command.PIPED)
      :stderr(Command.PIPED)
      :spawn()

  local status = child:wait()

  if status.success then
    local extracted = outdir .. "/" .. current
    child = Command("magick")
        :args({
          extracted,
          "-resize",
          "480",
          tostring(cache),
        })
        :stdout(Command.PIPED)
        :stderr(Command.PIPED)
        :spawn()
    status = child:wait()
    if not status.success then
      ya.err("convert error: " .. extracted)
      local data = nil
      repeat
        data = child:read_line()
        ya.err(data)
      until data
      return
    end

    ya.image_show(cache, job.area)
    ya.preview_widgets(job, {})

    child = Command("rm")
        :args({
          "-r",
          outdir,
        })
        :spawn()
    child:wait()
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
