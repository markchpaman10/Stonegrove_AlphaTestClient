# Bag overhaul 0.3.63.23

STONEGROVE 0.3.63.23 - Six-bag progression and interchangeable slots

The supplied 32x48 atlas replaces the old bag artwork. Leather is the left column and linen is the right; rows are Small, Medium, Large. Equipped HUD slots and separate inventory windows draw the actual equipped bag. Hovering shows material, size, grade, base slots, grade bonus, Strength bonus and final capacity.
Combined Bags moved from the bag context menu into Options. The toggle persists per character. The bag bar grows to four slots at Strength99 and stays inside the screen; separate/combined windows, resizing, drag/drop, hover and bag scans support the fourth slot.
New characters have three interchangeable equipment slots and start with Medium Leather Bag D (5 inventory slots), two empty bag slots and the existing copper starter items/bank tools. Strength99 unlocks the fourth slot. Strength adds floor(level/10) slots to every equipped bag: +9 at99, replacing the previous +10 rule. Four Large Leather A bags at99 provide76 slots.
Six standard bags: Small/Medium/Large Linen bases2/4/6 and Leather bases3/5/7. Bag grades add D0/C1/B2/A3 slots rather than multiplying capacity. Each physical bag carries its own qualityGrade. Bag crafting levels are10/20/30. Linen recipes use2/4/6 Linen Cloth plus2/4/6 Wool Thread; leather recipes use2/4/6 Leather plus2/4/6 Rawhide String. Needle required. Tailoring XP18/36/54; Leatherworking XP22/44/66 before race bonuses. Linen shop prices are lower than same-size leather bags. Old Linen Bag recipe and obsolete graded aliases are removed from standard recipe/generated shop lists; aliases remain readable for old saved/world items.
Drag an inventory bag onto any unlocked equipment slot to equip/replace it. Swaps and removals use a trial inventory and commit only if contents and the replaced/removed bag fit safely. The starter slot follows the same rules. Failed operations preserve all objects. Removing the final bag requires safe remaining inventory storage and is rejected when none exists.
Existing Small/Large Leather bags retain their size category and quality; old Linen Bag becomes Large Linen Bag. Capacity is recalculated. Overflow items go into available inventory/bank storage without deletion; a full bank gains accessible migration overflow slots when necessary. Existing bag grades, contents, bank items, copper bank tools and other equipment are preserved. Save/load serializes all four sparse bag slots and quality metadata. Both client and server migrate legacy saves. Server checks canonical equipped bag IDs, grade, capacity, item positions, Strength XP and the level99 slot gate instead of accepting arbitrary client size or level fields.
Bag grade odds are configurable in game/bag_system.lua: uniform roll1-100 + min(skillLevel,35); thresholds C55/B85/A115. Defaults: skill10 D44% C30% B26% A0%; skill20 D34% C30% B30% A6%; skill30 D24% C30% B30% A16%; skill35+ D19% C30% B30% A21%. Other crafted equipment and food keep the previous quality rules.

Tests and verification limits
PASS 611 bag-system checks: all six types, four grades, all four interchangeable slots, level/Strength formulas and99 gate, 76 maximum slots, starter removal with contents, safe replacement, failed swap rollback, legacy overflow and full-bank overflow, prices, six actual recipes/skill XP and configurable grade odds.
PASS 849 quality checks across170 implemented recipes, including inventory/bank/merchant stacks, weapons, armor, food, potions and direct item-use crafting.
PASS19 Slime King targeting/bag regression checks and75 content/fishing/camp/bonfire checks.
PASS authenticated isolated HTTP: forged capacity/locked fourth-slot rejection; all six bag recipes at10/20/30, below-level rejection, exact ingredient consumption, correct XP, timed cast and replay protection; all advanced recipes and existing tailoring/station proximity; legacy save migration with26 rated tools preserved,7 overflow bank items, persistence and second login.
PASS native LOVE QA: exact six atlas quads, icons, actual equipped-bag hover, fourth-slot save/load, dynamic inventory window and Combined Bags option click; screenshots visually inspected.
PASS root/alpha Lua syntax, shared module byte parity, original uploaded artwork bytes and both ZIP CRC checks.
Verification limits: used isolated QA accounts/saves and local server/native client; did not modify or test the user's live production accounts, hosted deployment, or every possible resolution/third-party authored world.

Modified implementation/test files
- game/bag_system.lua
- game/crafting.lua
- game/fieldcraft_ui.lua
- game/help.lua
- game/hide_processing.lua
- game/inventory.lua
- game/launcher.lua
- game/logger.lua
- game/options_menu.lua
- game/quality.lua
- game/religion.lua
- game/resizable.lua
- game/rune_inventory.lua
- game/save.lua
- game/shop.lua
- game/skills.lua
- game/sprites.lua
- game/tailoring_content.lua
- game/ui.lua
- game/unlocks.lua
- game/vendor_catalog.lua
- LevelEditor/conf.lua
- LevelEditor/editor_ui.lua
- Server/bag_rules.py
- Server/camp_rules.lua
- Server/camps.py
- Server/shared_world.lua
- Server/test_advanced_http.py
- Server/test_bag_overhaul.py
- Server/test_balance_content.py
- Server/test_quality.py
- Server/test_slime_bags.py
