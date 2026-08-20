-- Load palette from noctalia foot theme if available, else hardcoded fallback

local function read_foot_noctalia()
  local path = os.getenv("HOME") .. "/.config/foot/themes/noctalia"
  local f = io.open(path, "r")
  if not f then return nil end

  local colors = {}
  for line in f:lines() do
    local key, val = line:match("^(%S+)%s*=%s*(%S+)")
    if key and val then colors[key] = val end
  end
  f:close()

  if not colors.background then return nil end

  local function hex(c) return "#" .. c end

  return {
    bg      = hex(colors.background),
    fg      = hex(colors.foreground),
    black   = hex(colors.regular0),
    red     = hex(colors.regular1),
    green   = hex(colors.regular2),
    yellow  = hex(colors.regular3),
    blue    = hex(colors.regular4),
    magenta = hex(colors.regular5),
    cyan    = hex(colors.regular6),
    white   = hex(colors.regular7),
    gray    = hex(colors.bright0),
  }
end

local palette = read_foot_noctalia()
if palette then return palette end

return {
  bg       = "#121214",
  fg       = "#af9a91",
  black    = "#572100",
  red      = "#ba3934",
  green    = "#91773f",
  yellow   = "#b55600",
  blue     = "#5f63b4",
  magenta  = "#a17c7b",
  cyan     = "#8faea9",
  white    = "#af9a91",
  gray     = "#4e4b61",
}
