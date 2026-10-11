-- Player magic/spell system intentionally stripped in 0.2.47 rebuild baseline.
-- This compatibility shell keeps unrelated systems/loaders from failing while magic is rebuilt.
local M={runes={},order={},spells={}}
function M.isRune() return false end
function M.bag() return nil end
function M.costText() return '' end
function M.check() return false,'Magic system is not implemented.' end
function M.consume() return false end
function M.learn() return false end
function M.count() return 0 end
return M
