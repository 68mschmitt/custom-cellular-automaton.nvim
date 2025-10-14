local Items = require("custom-cellular-automaton.animations.snowtown.items")

local S = {}

-- Basic sequential spawner:
-- - Enable/disable items by name
-- - One spawn attempt every interval seconds
-- - Respects per-item max_instances

function S.new(opts)
  local o = {
    enabled = {},
    interval = (opts and opts.interval) or 6.0,
    next_time = 0.0,
    counts = {},
    order = {},
    cursor = 1,
  }

  for i, it in ipairs(require("custom-cellular-automaton.animations.snowtown.items").catalog) do
    o.enabled[it.name] = true
    table.insert(o.order, i)
    o.counts[it.name] = 0
  end

  return setmetatable(o, { __index = S })  -- <-- add this
end

function S.enable(o, name)   o.enabled[name] = true  end
function S.disable(o, name)  o.enabled[name] = false end

-- Try to spawn the next enabled item (round-robin)
-- `placer` is a callback(item) -> true/false
function S.tick(o, time_now, placer)
  if time_now < o.next_time then return end

  local n = #o.order
  for _ = 1, n do
    local idx = o.order[o.cursor]
    o.cursor = (o.cursor % n) + 1

    local item = Items.catalog[idx]
    if o.enabled[item.name] then
      local count = o.counts[item.name] or 0
      local cap   = item.max_instances or math.huge
      if count < cap then
        if placer(item) then
          o.counts[item.name] = count + 1
          break
        end
      end
    end
  end

  o.next_time = time_now + o.interval
end

return S
