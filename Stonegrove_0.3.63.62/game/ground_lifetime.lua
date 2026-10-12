local G={seconds=300}
function G.stamp(item,now)
 if type(item.expiresAt)~='number' then item.expiresAt=(now or os.time())+G.seconds end
 return item
end
function G.update(w,now)
 if not SG_SERVER and w.onlineShared then return end
 now=now or os.time()
 for i=#(w.groundItems or{}),1,-1 do
  local item=G.stamp(w.groundItems[i],now)
  if item.expiresAt<=now then table.remove(w.groundItems,i);w._snapshotRows=nil end
 end
end
return G
