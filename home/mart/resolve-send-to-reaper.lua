-- Launch ResolveLink Send to REAPER in Resolve's built-in Python 3 interpreter.
local py = os.getenv("HOME") .. "/.local/share/DaVinciResolve/Fusion/Scripts/Utility/send-to-reaper.py"
local escaped = py:gsub("\\", "\\\\"):gsub("'", "\\'")
local code = "exec(compile(open('" .. escaped .. "', 'rb').read(), '" .. escaped .. "', 'exec'))"
local ok, err = pcall(function()
  fusion:Execute("!Py3: " .. code)
end)
if not ok then
  print("Send to REAPER launcher ERROR: " .. tostring(err))
end
