-- quarto-livefigures: render editable figure sources inside quarto render.
-- Two entry points share one pipeline: Image elements targeting supported
-- source files, and fenced code blocks carrying a backend class
-- (```{.nomnoml #fig-x fig-cap="..."}). Rendered assets land in a
-- content-addressed cache and flow through Quarto's native figure pipeline.
-- See docs/ARCHITECTURE.md and docs/adr/ for the decisions behind this.

local VERSION = "0.8.0"

local path = pandoc.path
local ext_dir = path.directory(PANDOC_SCRIPT_FILE)

-- Backend registry (ADR 0010, 0011, 0012, 0013). dark_css: theme=auto
-- restyles via CSS filter (right for hand-drawn content, wrong for
-- data-encoded chart colors). dark_ok/scene_ok: whether theme=dark /
-- background=scene are supported; unsupported values hard-fail rather than
-- silently rendering wrong. block/ext: code-block class and canonical file
-- extension for inline sources. Absent flags default to false.
local BACKENDS = {
  { pattern = "%.excalidraw$", name = "excalidraw", renderer = "renderer.mjs",
    dark_css = true, dark_ok = true, scene_ok = true, block = "excalidraw", ext = "excalidraw" },
  { pattern = "%.vl%.json$", name = "vega", renderer = "renderer-vega.mjs",
    dark_ok = true, scene_ok = true, block = "vega-lite", ext = "vl.json" },
  { pattern = "%.vg%.json$", name = "vega", renderer = "renderer-vega.mjs",
    dark_ok = true, scene_ok = true, block = "vega", ext = "vg.json" },
  { pattern = "%.noml$", name = "nomnoml", renderer = "renderer-text.mjs", block = "nomnoml", ext = "noml" },
  { pattern = "%.nomnoml$", name = "nomnoml", renderer = "renderer-text.mjs" },
  { pattern = "%.wavedrom$", name = "wavedrom", renderer = "renderer-text.mjs", block = "wavedrom", ext = "wavedrom" },
  { pattern = "%.wavedrom%.json$", name = "wavedrom", renderer = "renderer-text.mjs" },
  { pattern = "%.bytefield$", name = "bytefield", renderer = "renderer-text.mjs", block = "bytefield", ext = "bytefield" },
  { pattern = "%.dot$", name = "graphviz", renderer = "renderer-graphviz.mjs", block = "dot", ext = "dot" },
  { pattern = "%.gv$", name = "graphviz", renderer = "renderer-graphviz.mjs" },
  { pattern = "%.dbml$", name = "dbml", renderer = "renderer-dbml.mjs", block = "dbml", ext = "dbml" },
  -- kroki-backed formats (ADR 0012): network-rendered, endpoint configurable.
  -- Batch enabled per the 2026-07-20 kroki survey; blockdiag family excluded
  -- (broken server-side), umlet/bpmn/symbolator/wireviz excluded (not
  -- agent-authorable or deep-niche).
  { pattern = "%.puml$", name = "plantuml", renderer = "renderer-kroki.mjs", kroki = true, block = "plantuml", ext = "puml" },
  { pattern = "%.plantuml$", name = "plantuml", renderer = "renderer-kroki.mjs", kroki = true },
  { pattern = "%.d2$", name = "d2", renderer = "renderer-kroki.mjs", kroki = true, block = "d2", ext = "d2" },
  { pattern = "%.c4$", name = "c4plantuml", renderer = "renderer-kroki.mjs", kroki = true, block = "c4", ext = "c4" },
  { pattern = "%.structurizr$", name = "structurizr", renderer = "renderer-kroki.mjs", kroki = true, block = "structurizr", ext = "structurizr" },
  { pattern = "%.erd$", name = "erd", renderer = "renderer-kroki.mjs", kroki = true, block = "erd", ext = "erd" },
  { pattern = "%.ditaa$", name = "ditaa", renderer = "renderer-kroki.mjs", kroki = true, block = "ditaa", ext = "ditaa" },
  { pattern = "%.pikchr$", name = "pikchr", renderer = "renderer-kroki.mjs", kroki = true, block = "pikchr", ext = "pikchr" },
  { pattern = "%.svgbob$", name = "svgbob", renderer = "renderer-kroki.mjs", kroki = true, block = "svgbob", ext = "svgbob" },
  { pattern = "%.tikz$", name = "tikz", renderer = "renderer-kroki.mjs", kroki = true, block = "tikz", ext = "tikz" },
}

local function backend_for(src)
  for _, b in ipairs(BACKENDS) do
    if src:match(b.pattern) then return b end
  end
end

local function backend_for_block(classes)
  for _, b in ipairs(BACKENDS) do
    if b.block and classes:includes(b.block) then return b end
  end
end

local opts = { theme = nil, background = "transparent", kroki_url = "https://kroki.io" }
local node_checked = false
local css_added = false

local function fail(msg)
  -- error() alone is caught by quarto's filter machinery and the render
  -- continues; exiting pandoc is the only reliable hard failure (ADR 0006).
  io.stderr:write("ERROR (livefigures): " .. msg .. "\n")
  os.exit(1)
end

local function check_node()
  if node_checked then return end
  local proc = io.popen("node --version 2>&1")
  local out = proc and proc:read("*a") or ""
  local ok = proc and proc:close()
  local major = tonumber(out:match("^v(%d+)"))
  if not ok or not major then
    fail("Node.js was not found on PATH. quarto-livefigures requires Node >= 18 " ..
      "to render live figures. Install it from https://nodejs.org/")
  end
  if major < 18 then
    fail("Node " .. out:gsub("%s+$", "") .. " is too old; quarto-livefigures requires Node >= 18.")
  end
  node_checked = true
end

local function cache_dir()
  local base = quarto.project.directory
  if not base then
    base = path.directory(quarto.doc.input_file)
  end
  local dir = path.join({ base, "_livefigures" })
  pandoc.system.make_directory(dir, true)
  return dir
end

local function read_file(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

local function write_file(p, content)
  local f = io.open(p, "wb")
  if not f then fail("cannot write " .. p) end
  f:write(content)
  f:close()
end

local function resolve_options(attributes, backend, label)
  local format = quarto.doc.is_format("latex") and "png" or "svg"
  local theme = attributes["theme"] or opts.theme
    or (quarto.doc.is_format("html") and "auto" or "light")
  local background = attributes["background"] or opts.background
  if theme ~= "light" and theme ~= "dark" and theme ~= "auto" then
    fail('invalid theme "' .. theme .. '" on ' .. label .. ' (use light, dark, or auto)')
  end
  if background ~= "transparent" and background ~= "scene" then
    fail('invalid background "' .. background .. '" on ' .. label .. ' (use transparent or scene)')
  end
  if theme == "dark" and not backend.dark_ok then
    fail('theme=dark is not supported for ' .. backend.name .. ' figures (' .. label .. ')')
  end
  if background == "scene" and not backend.scene_ok then
    fail('background=scene is not supported for ' .. backend.name .. ' figures (' .. label .. ')')
  end
  return format, theme, background
end

-- Render `scene` (source text) through `backend` into the cache; returns the
-- output path. `src_file` is the on-disk source when one exists (Image path);
-- inline sources get written into the cache on a miss.
local function ensure_rendered(scene, src_file, stem, backend, format, theme, background, label)
  local render_theme = theme == "dark" and "dark" or "light"
  local extra = ""
  local key_extra = ""
  if backend.kroki then
    extra = string.format(' --type %s --endpoint "%s"', backend.name, opts.kroki_url)
    key_extra = opts.kroki_url
  end

  local key = pandoc.utils.sha1(scene .. backend.name .. format .. render_theme .. background .. key_extra .. VERSION)
  local out = path.join({ cache_dir(), stem .. "-" .. key:sub(1, 8) .. "." .. format })

  if not read_file(out) then
    check_node()
    local input = src_file
    if not input then
      input = path.join({ cache_dir(), stem .. "-" .. key:sub(1, 8) .. ".in." .. backend.ext })
      write_file(input, scene)
    end
    local cmd = string.format(
      'node "%s" --input "%s" --output "%s" --format %s --theme %s --background %s%s',
      path.join({ ext_dir, backend.renderer }), input, out, format, render_theme, background, extra)
    if not os.execute(cmd) then
      fail("rendering failed for " .. label .. " (see error above)")
    end
  end
  return out
end

local function decorate(img, theme, backend)
  img.classes:insert("livefigure")
  if theme == "auto" and backend.dark_css then
    img.classes:insert("livefigure-auto")
  end
  if quarto.doc.is_format("html") and not css_added then
    quarto.doc.add_html_dependency({
      name = "livefigures",
      version = VERSION,
      stylesheets = { "livefigures.css" },
    })
    css_added = true
  end
  return img
end

local function input_directory()
  local dir = path.directory(quarto.doc.input_file)
  if not path.is_absolute(dir) then
    -- project renders can hand us a relative input path; make_relative
    -- against a relative root mangles subdirectory documents
    dir = path.join({ pandoc.system.get_working_directory(), dir })
  end
  return dir
end

-- pandoc.path.make_relative never synthesizes ".." segments, so cache
-- paths above the document's directory (project subdir docs) come out
-- wrong. Compute the relative path ourselves. POSIX separators only —
-- Windows support is a documented fast-follow.
local function relative_to(target, from)
  local t, f = {}, {}
  for seg in target:gmatch("[^/]+") do t[#t + 1] = seg end
  for seg in from:gmatch("[^/]+") do f[#f + 1] = seg end
  local i = 1
  while t[i] and f[i] and t[i] == f[i] do i = i + 1 end
  local parts = {}
  for _ = i, #f do parts[#parts + 1] = ".." end
  for j = i, #t do parts[#parts + 1] = t[j] end
  return table.concat(parts, "/")
end

local function render_image(img, backend)
  local input_dir = input_directory()
  local src = img.src
  if not path.is_absolute(src) then
    src = path.join({ input_dir, src })
  end

  local scene = read_file(src)
  if not scene then
    fail(img.src .. " does not exist (referenced from " .. quarto.doc.input_file .. ")")
  end

  local format, theme, background = resolve_options(img.attributes, backend, img.src)
  local stem = path.split_extension(path.filename(src)):gsub("%.v[lg]$", ""):gsub("%.wavedrom$", "")
  local out = ensure_rendered(scene, src, stem, backend, format, theme, background, img.src)

  img.src = relative_to(out, input_dir)
  img.attributes["theme"] = nil
  img.attributes["background"] = nil
  return decorate(img, theme, backend)
end

local function render_block(cb, backend)
  local input_dir = input_directory()
  local label = "inline " .. backend.name .. " block"
    .. (cb.identifier ~= "" and (" #" .. cb.identifier) or "")
  local format, theme, background = resolve_options(cb.attributes, backend, label)
  local stem = cb.identifier ~= "" and cb.identifier or ("inline-" .. backend.name)
  local out = ensure_rendered(cb.text, nil, stem, backend, format, theme, background, label)

  local img = decorate(pandoc.Image({}, relative_to(out, input_dir)), theme, backend)
  local cap = cb.attributes["fig-cap"]
  if cap or cb.identifier ~= "" then
    local cap_inlines = cap
      and pandoc.utils.blocks_to_inlines(pandoc.read(cap, "markdown").blocks)
      or pandoc.Inlines({})
    return pandoc.Figure(pandoc.Plain({ img }),
      { long = { pandoc.Plain(cap_inlines) } },
      pandoc.Attr(cb.identifier))
  end
  return pandoc.Para({ img })
end

return {
  {
    Meta = function(meta)
      local lf = meta.livefigures
      if lf then
        if lf.theme then opts.theme = pandoc.utils.stringify(lf.theme) end
        if lf.background then opts.background = pandoc.utils.stringify(lf.background) end
        if lf["kroki-url"] then opts.kroki_url = pandoc.utils.stringify(lf["kroki-url"]):gsub("/$", "") end
      end
    end,
  },
  {
    Image = function(img)
      local backend = backend_for(img.src)
      if backend then
        return render_image(img, backend)
      end
    end,
    CodeBlock = function(cb)
      local backend = backend_for_block(cb.classes)
      if backend then
        return render_block(cb, backend)
      end
    end,
  },
}
