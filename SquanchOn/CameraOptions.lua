-- SPDX-License-Identifier: MIT
-- The camera settings are pages of the unified settings window, declared in
-- options/Camera.lua. This keeps the entry point used by /sqms camera options,
-- /squancher camera and the unit-frame window's "Camera" button.
local _, ns = ...

function ns:OpenCameraOptions()
    return ns:OpenOptions('camera')
end
