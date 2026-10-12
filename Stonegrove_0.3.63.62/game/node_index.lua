-- Resource positions are static; depletion/kind changes stay live through references.
-- Each node covers every point that can hit it, so a query visits one 64px bucket.
-- Insertion order preserves the original first-hit and equal-distance behavior.
local N={}
local EMPTY={}
local SIZE=64
local PAD=20
function N.invalidate(world) world._nodePerfCache=nil end
function N.at(world,x,y)
 local nodes=world.nodes
 if not world._nodeIndexEnabled then return nodes end
 local c=world._nodePerfCache
 if not c or c.nodes~=nodes or c.count~=#nodes then
  c={nodes=nodes,count=#nodes,rows={}}
  for _,n in ipairs(nodes) do
   for by=math.floor((n.y-PAD)/SIZE),math.floor((n.y+PAD)/SIZE) do
    local row=c.rows[by];if not row then row={};c.rows[by]=row end
    for bx=math.floor((n.x-PAD)/SIZE),math.floor((n.x+PAD)/SIZE) do
     local bucket=row[bx];if not bucket then bucket={};row[bx]=bucket end
     bucket[#bucket+1]=n
    end
   end
  end
  world._nodePerfCache=c
 end
 local row=c.rows[math.floor(y/SIZE)]
 return row and row[math.floor(x/SIZE)] or EMPTY
end
return N
