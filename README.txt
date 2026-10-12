Stonegrove 0.3.63.49 - Launcher automatic client installation

Added an Install latest client button that downloads and verifies the correct Alpha/developer package, stages it outside the installed client, waits for the running client to exit, replaces files with backups and reopens Stonegrove. Failure during replacement restores the previous files. Installation blocks launcher actions until handoff; download/validation failures leave the current client unchanged and allow retry. Previous helper errors are visible on subsequent startup.

Added explicit package/build metadata, Windows process detection and a hidden PowerShell installation helper. Update archives must match the release version and installed distribution. SHA-256, size, required files, staged-file hashes, safe paths, duplicate paths, symlinks and extraction limits are checked. Developer updates exclude Server/account files and preserve existing authored world/item/NPC/monster/quest/event definitions. LOVE saves, credentials, settings and imported worlds are outside replacement scope.

GitHub release assets: Alpha Stonegrove_VERSION.zip; developer Stonegrove_Developer_VERSION.zip. Matching .zip.sha256 sidecars are supplied, supporting repositories without a GitHub release digest and root-file fallback. Earlier clients require a one-time manual installation of .49; subsequent versions can install from the launcher.

Validation: 55 Windows helper checks covering both distributions, checksum/path/build/version rejection, altered staged files, waiting for the parent process, file-lock rollback, backups and protected files. 54 metadata/handoff checks and 20 actual LOVE launcher checks across both builds. Actual Windows helper replacement and LOVE restart, plus native hidden ShellExecute handoff passed. All Lua files compile; Python syntax and unchanged artwork/gameplay/server source comparisons pass. ZIP CRC and packaged-file contents verified. GitHub download/metadata responses were simulated for update tests; the .49 assets still need to be published to the repository for live player downloads.

Stonegrove automatic client updates - 0.3.63.49

Install this build manually once: extract its ZIP into a normal writable folder and launch it. Builds 0.3.63.48 and earlier do not contain the installer.

Publishing updates:
1. Open https://github.com/markchpaman10/Stonegrove_AlphaTestClient/releases/new
2. Create and publish a normal release with a four-part tag, for example v0.3.63.49. Do not mark it draft or prerelease.
3. Upload Stonegrove_0.3.63.49.zip from the Alpha_Testers folder and its matching Stonegrove_0.3.63.49.zip.sha256. This is the player client with its Windows runtime.
4. For developer-client updates also upload Stonegrove_Developer_0.3.63.49.zip and its matching .zip.sha256 file. Do not upload the full developer ZIP under the Alpha filename: its contents are different.
5. Future releases use the next version in both their tag and ZIP names. The ZIP must contain main.lua and client_package.json directly at its root, not inside another folder. Use the supplied packages rather than GitHub's automatic source-code ZIP.

The launcher checks before login. When a newer matching client is available, click Install latest client. It downloads in the background, verifies SHA-256 against the release asset digest (or the matching .zip.sha256 file), validates the package, closes Stonegrove, installs the files, then reopens it. If the repository has no published release, versioned ZIPs and matching checksum files at its root are also supported.

Keep the checksum paired with the exact ZIP: do not edit or repack a ZIP after generating its checksum. A release without a matching ZIP cannot install. Network, verification and staging failures leave the current client unchanged and allow retry/login. Close other Stonegrove/editor windows before installation. Stop a server using the developer folder before updating that folder.

Character saves, remembered login details, imported worlds and settings stay in the LOVE save folder and are not replaced. Developer updates preserve existing authored current.lua and item/npc/monster/quest/event definition files; Server files and account databases are never installed by this client updater. Server updates remain a separate manual deployment.

Replaced files are backed up under the LOVE save folder's client-updates/job-* /backup directory. Failed file replacements roll back before reopening the previous client. Backups are retained for recovery; completed staging ZIPs and extracted temporary files are removed. After confirming the new client works, old completed job folders can be removed manually. A power interruption may require restoring that job's backup; no updater can guarantee uninterrupted disk writes.

Windows automatic installation requires PowerShell and an extracted writable client folder. No administrator access is required.

Previous notes:
Stonegrove 0.3.63.48 - Bone stacks, tool equipment and world-state repair

Bone stacking: the previous physical stacks stayed separate because each credited kill carried a unique boneToken. Piles and separated bones now stack to 15 when type, original kill owner, blessing state and substantive item metadata match. Each stack retains a per-token quantity map; different players' kill credit stays separate. Bought/uncredited bones cannot acquire credited-kill Religion eligibility. Legacy single-token items remain supported. Inventory stacking, drag merges, bank deposits, partial withdrawals, shop transfers and save serialization preserve these per-kill quantities.

Pile separation: Separate Bone Pile Stack processes every pile in the selected stack. Each credited pile uses its original private 1-4-bone roll. Uncredited/bought piles also produce 1-4 bones per pile and cannot award borrowed-kill Religion XP. Separation is atomic: insufficient output space leaves all piles and private claims available. Cursed blessing updates the entire selected stack and awards XP per item; burying still consumes one bone and one log, preserving remaining token quantities. The 0.5-second server cast, damage/movement interruption and database-failure rollback continue to apply.

Rune materials: verified all graded rune bank quantities, grade/blessing separation, per-item blessing XP, carving stacks and conservation through save/server restart. No graded rune deletion reproduced. Existing same-grade normalization continues to combine equivalent legacy false/empty metadata without mixing different grades, blessed state or substantive metadata.

Tools: restored the normal Equip menu entry for axes, picks and knives. Equip uses the weapon slot and displays/holds the actual tool; Equip Tool still stores a single utility tool in the existing dedicated slot. Both slots remain independent. Grade metadata, swaps, weapon state and serialization are preserved. The inventory tool button remains available.

Old-world backup audit: shared_world_backup.json was 164,326,194 bytes with only one saved area. Eight goblin camp records used 162,555,679 bytes, almost all under cage.enemy references (162,547,677 bytes). Runtime actor references beneath caged enemies were being copied recursively into camp snapshots. This is a serialization problem, not normal save age. Public camp snapshots now include explicit scalar scenery fields, tents, decoration and cage state, excluding enemy/runtime references. Live server cage/enemy references continue to drive actual behavior.

World persistence schema 2: save only durable recovery state: unexpired ground items and metadata, gravestones/protected contents, burial markers, player-created temporary fires/pending rune drops, private bone redemption records, grave recovery ledger and day time. Generated enemies, resource/depletion snapshots, enemy camps, caves/interior masks/chests, projectiles, particles, popups, NPC AI and generated scenery no longer persist. The configured .sgworld still supplies authored terrain, structures and spawn-zone definitions. Generated camp/cave seeds change each server startup; authored placements remain defined by the world file. Accounts, skill levels, banks, equipment and player saves remain in their existing permanent account database.

Migration and cave recovery: old world JSON is filtered before transfer into Lua; older layouts are normalized to schema 2 on the next checkpoint. Only saves matching the configured world fingerprint are restored. Unsupported newer schemas fail instead of being downgraded. Startup restore errors release the Lua runtime. Recovery records from previous cave instances move to the old overworld entrance, keeping protected grave contents, grades, ownership and ground-item expiry deadlines. Reconnecting to a changed cave starts at its fresh arrival; missing caves return the player to the overworld. Old cave geometry is not reloaded. Recovery footprints clear procedural resource obstructions while preserving authored and quest resources. A new server session forces a full client snapshot, including reconnects that did not observe the brief shutdown. This avoids trapping recovery items behind regenerated cave walls.

Isolated verification on the user's old backup: 164,326,194-byte input -> 35,971-byte filtered data -> 34,722-byte durable save, with recovery records, bone claims and grave ledger retained. The original backup, current production shared_world.json and production account database were not modified. Future save size depends on live recovery contents; these measurements are not a long-running population benchmark.

Validation: 148 new bone stack/bank/provenance/conservation/failure checks; 198 existing bone rules; authenticated eight-pile separation, all-eight-token database-failure rollback, timed actions, cursed blessing/burial, damage interruption, replay and restart ownership; 810 rune bank conservation checks, 34 authenticated graded bank/save/restart checks, 136 Religion/carving checks and 940 quality checks across 191 recipes; actual fresh-world restarts, cave-escrow relocation, changed/missing-cave reconnect and ground deadlines; 11 native hand/utility tool equip/swap/grade/save checks in each distribution; 11,124 level-zone and full resource-generation checks; live enemy chasing/damage; authenticated shop transaction rollback; 3,047 native skill-shop/double-buy/sell checks and 353 cooking-tab checks; ground lifetime/restart/bonfire regressions. Both builds compile; Python syntax, unchanged artwork and ZIP CRC/content checks pass.

Install both clients and the updated server, keeping the AccountServer directory and account database. Restart the server. Existing world-state files migrate automatically; no manual production-file reset is required.

Previous notes:
Stonegrove 0.3.63.47 — Shop skill tabs, double-click selling and ground-item lifetime

Town Supplies: added skill tabs populated from item recipes, ingredients, tools and item categories. All shows the whole stock; Other contains items without a matching skill. Items relevant to multiple skills appear in each relevant tab. Filtered views retain original server stock indices, reset scroll on tab changes and preserve both single/double-click buying and Buy Max. Other vendors retain their existing layout. Cooking food and graded linen/leather bags are included in their appropriate tabs. Works with resized/scaled windows; automatically fits the window at both the default 1100x700 size and minimum 800x500 size.

Double-click selling: while a shop is open, double-click an accepted inventory item to perform its existing Sell action. This sells the selected stack, using existing shop prices, acceptance checks, metadata handling and online transaction paths. The first click selects an accepted item without eating food or starting a drag. Nonaccepted items keep their normal behavior. Currency is excluded. Expired clicks, another vendor, another slot or a replaced object do not trigger a sale. Right-click menus remain available.

Ground items: every newly dropped item receives a 300-second wall-clock expiry. Includes ordinary drops, bone piles, bags and loot scattered from broken gravestones. Offline worlds and all server areas, including empty areas, remove expired items. Server saves retain the deadline across restarts; old ground items with no deadline receive five minutes when loaded. Pickup checks cannot take expired items. Charred Wood deadlines survive the offline bonfire save/restore path. Intact corpse protection and broken-gravestone decoration lifetimes retain their existing separate rules. The online client follows the server's removals.

World-state audit: the current live shared_world.json was read without altering it and measured approximately 1.85 MB, with two saved areas, 4,093 resource nodes, 149 enemies and 27 ground items. Resource nodes dominate its contents. The server checkpoints replace the file atomically rather than append to it. More visited areas increase normal save size; age by itself does not explain the historical 164 MB file. The deleted old file was not available for a before/after comparison, so its original growth cause is unconfirmed. Five-minute loot expiry bounds one accumulation source; unused bone-claim records and retained world areas are separate possible growth sources, so this release does not claim a full long-running save migration/compaction solution. No production files or account data were deleted or modified. Keep permanent account/player databases when changing server builds.

Validation: native LOVE skill-tab coverage, original filtered purchase/context indices, double-click purchases, scroll limits and three window scales; real accepted/rejected food/tool inventory double-click selling and stale/replaced-object checks; authenticated bulk transaction tests for affordability, loaded containers, proximity, replay, durable state and forced-write rollback; actual shared-world enemy chase and damage regression; 810 bank/grade/blessing quantity checks; 82 corpse/gravestone rules; 353 native cooking-tab checks; ground deadline, grave scatter, empty server area, export/restore and offline bonfire expiry tests. Lua and server Python syntax, unchanged artwork, and ZIP CRC/content verification pass.

Update both clients and the server, then restart the server to activate authoritative online expiry.

Previous notes:
Stonegrove 0.3.63.46 — Enemy navigation, Religion and feather fixes

Enemy movement: failed or exhausted navigation routes now wait one second before retrying. Previously the first blocked enemies could consume the entire two-route budget every frame, starving subsequent enemies and preventing chasing/attacking. Regression reproduced zero movement in 0.3.63.45 versus movement in this build. Actual shared-world tests confirm chasing and damage with blocked enemies ahead of the attacker. Replace and restart the server as well as updating the client for online play.

Bone piles: anyone may pick up and separate a pile. Original kill ownership stays attached to the bones. Only the credited killer can bless or bury them for Religion XP. Tooltips now explain public pickup. Authenticated two-account checks verify foreign pile pickup/separation without transferring kill credit or permitting borrowed-bone blessing XP.

Blessing XP: removed the 50-base-XP action cap. Each eligible newly blessed rune material awards its full per-item XP; Religion Altars retain their 2x multiplier. Already blessed items never award duplicate XP. Skill race and hallowed-ground bonuses continue to apply. Rune blessing Religion requirements match the associated spell Magic level: Charred Wood 1, Fish Bones 2, Stone Gravel / legacy Stone Pieces 3, Carved Feather 4, Carved Onyx 5, Green Slime Tube 6. Locked materials remain unblessed. Tooltips and the Religion skill guide expose these requirements.

Feather carving: automatically continues one feather at a time, with a separate 0.5-second cast per feather. Online batches wait for each authoritative server reply before queuing the next cast; the server rejects untimed/early completions. Moving, Escape, missing ingredients/tool, full bags or a failed command stop the batch. The equipped knife slot works. Each successful feather still awards 4 base Religion XP and rolls its own output grade.

Stacking: Carved Feather is explicitly stackable to 100. Same-grade rune stacks treat equivalent legacy unblessed/empty-socket metadata consistently, while different grades, blessed state and substantive custom metadata remain separate. Inventory and bank quantity/metadata tests pass. No input or XP is consumed when output space prevents carving.

Validation: 136 Religion/unit-XP/level-gate/carving/stack/full-bag checks; 165 native LOVE equipment, tool, offline/online ten-feather cast-chain, movement/Escape and save checks; actual shared-world chase/attack test; authenticated ten-cast server and public foreign-pile tests; bone cast interruption, restart, replay and forced DB-failure rollback; Religion/bonfire persistence and forced-write rollback; 353 native cooking-tab and 3,169 fish checks. Broader regressions pass for snapshots/JSON, banking (810), bags (611), crafted quality across 191 recipes (940), rune spells (113), starter/Religion/bonfires (50), shellfish (68), seafood (85), graves (82), Bag Keeper editor (15), and fishing/shop (1,500). Lua compiles, server Python syntax, unchanged artwork and ZIP CRC/content verification pass.

Previous notes:
Stonegrove 0.3.63.45 — Startup client update check

Both clients automatically check https://github.com/markchpaman10/Stonegrove_AlphaTestClient before login. The check uses the latest published GitHub Release with a four-part version tag (v0.3.63.45), or, when there is no Release, the highest Stonegrove_X.X.X.X.zip in the repository root. Versions compare numerically, including 99 to 100. Draft and prerelease releases are not accepted as stable releases.

Sign-in and account creation wait for the check. A newer version displays a Download latest client button and prevents online login with the outdated client. The button opens the matching ZIP download, or the release/repository page when a direct ZIP is unavailable. Download and extract the client and open the new version. This is a startup update notice/download flow; it does not automatically overwrite or restart the running client.

A failed request, unavailable repository or 12-second timeout displays an explicit notice and permits login. Check client updates retries. Checks do not send account credentials to GitHub. The existing world-update link remains independent. Saves, credentials and character progress remain in their existing LOVE save directory.

Publishing: upload the alpha client ZIP into the repository root using its exact versioned filename, e.g. Stonegrove_0.3.63.45.zip. Alternatively publish a stable Release tagged v0.3.63.45 with that client ZIP asset. Each client embeds its own version. To change the source, edit game/client_update_source.lua before shipping or place client_update_config.json containing {"repository":"https://github.com/owner/repository"} in the LOVE save folder.

Validation: 63 update checks cover numeric comparisons, URL/source validation, Releases, root ZIP fallback, stale callbacks, timeouts and failure paths. Native LOVE tests pass for both real launchers: startup gating, download button and login/register fallback (14 checks each). Public repository/API verified: main branch, no Release and Stonegrove_0.3.63.43.zip. The native WinHTTP live request could not connect in this environment; its failure notice and continued login behavior were verified, while Python HTTPS successfully read the repository. All Lua compiles, server Python syntax, unchanged artwork and ZIP CRC/content checks pass.

Previous notes:
Stonegrove 0.3.63.44 — Equipped utility tool

One separate tool slot holds a knife, pickaxe, or axe. Right-click a tool and select Equip Tool, or drag it onto the tool slot/button. Copper Dagger also works as a utility knife. Swapping tools preserves their grade and metadata and leaves the combat weapon equipped.

Separate bags and combined inventory show an inventory Tool button with the actual equipped tool and its tooltip. Left-click selects the tool for use on an item; right-click offers use or unequip. Compatible item menus also offer Use Equipped Tool. Gathering, skinning and recipes recognize equipped tools without a duplicate in the inventory. Knife processing and breaking crab/lobster retain their existing behavior.

Equipment includes the tool slot. Saves, multiplayer profiles, death and grave recovery preserve the tool and its metadata. A full bag prevents unequipping without losing the tool; swapping uses the vacated inventory slot. Utility tool enchantments do not add combat weapon bonuses.

Validation: 214 simulation checks; 60 native LOVE checks including save/reload, separate and combined inventory at three scales, swaps, full bags, processing and grave recovery; authenticated multiplayer tool actions and persistence; cooking tabs regression; 3,169 high-tier fish checks; existing bank, bags, crafting quality, rune, starter, Religion, bonfire, shellfish, seafood, gravestone, editor and shop regressions. All Lua compiles and server Python syntax checks pass. Existing artwork is unchanged. ZIP CRC and byte checks pass.

Previous notes:
Stonegrove 0.3.63.43 — Cooking menu tabs

Cooking menus at stoves and campfires now have Fish, Meat and Meals tabs.
Fish includes whole fish, prepared raw fish, fish fillets, shrimp, crab meat, lobster meat and lobster tail.
Meat includes chicken, small/large meat and jerky recipes.
Meals includes Surf and Turf. Recipes combining multiple ingredients are categorized as meals.
Each tab filters the visible list and resets that station's scroll offset when selected. Recipe counts and scrolling reflect the selected category. Tabs and rows remain aligned when resizing the panel. Cooking panels are 32 pixels taller to fit the tabs without reducing the four visible recipe rows.
Recipe ordering and authoritative indices remain unchanged: left-click, Make 1/All/X, hover information and active cooking batches continue to refer to the actual recipe. Switching tabs does not change or cancel an active batch. Other crafting station menus are unchanged.

Validation: 353 native LOVE checks cover both stations, every cooking recipe appearing exactly once, classification, scaled tab/recipe clicks, per-tab scrolling, left/right recipe selection, Make 1 and active-batch preservation. Three-tab screenshot inspected. All 3,169 high-fish fishing/processing/cooking regression checks pass. Lua and server Python syntax, unchanged previous artwork and ZIP CRC/content checks pass. Includes the previous server GitHub world-link support and guard-bone fix.

Previous notes:
Stonegrove 0.3.63.42 — Server GitHub world links

Start Launch_Account_Server.bat. When Server/world.sgworld is missing and no remembered link exists, the console asks for a world link. Paste:
worldLink = "https://github.com/OWNER/REPOSITORY/blob/main/world.sgworld"
You may also paste the URL alone. Press Enter to retain the bundled-world behavior.

Supported public GitHub sources:
- GitHub file pages (blob/raw): converted to the raw file URL.
- raw.githubusercontent.com file links.
- GitHub release download links.
- Repository URLs: resolve the default branch and download latest.sgworld, matching the client repository-link convention.

Hosted or unattended startup:
python Server/server.py --world-link "https://github.com/OWNER/REPOSITORY/blob/main/world.sgworld"
Or set the WORLD_LINK environment variable. This explicit setting overrides a local world file. --world still accepts a local file path; it also accepts a GitHub URL, so passing a URL to Launch_Account_Server.bat works.

Default precedence: local Server/world.sgworld first, then remembered GitHub link, then interactive prompt, then bundled world. Explicit --world-link or WORLD_LINK selects the remote world even if a local file exists. An explicitly named missing local --world path is an error.
The link is saved in world-link.json inside the permanent account data directory after successful download. The downloaded package is cached in world-cache/world.sgworld there, not in the server folder. On subsequent starts without a local file, it downloads from the remembered link again. To change the link, launch with --world-link. To clear it, stop the server and remove world-link.json from its data directory.
Downloads happen during startup, before accepting players. Link input is a startup setting; it does not replace a live session's world. Download/network/validation failures stop startup with an error, preserving the previous cache and saved link. Existing account and character data are preserved. No silent fallback to a different world after a failed configured download.
HTTP timeout is 30 seconds; compressed packages are limited to 16 MB and decompressed content to 64 MB. Package format/version, JSON and imported PNG metadata are validated by the same decoder used by local simulation loads. Redirects remain on HTTPS GitHub hosts. No third-party Python dependencies.

Validation: 52 tests cover assignment syntax, GitHub file/raw/repository/release URLs, default branch resolution, bounded download, corrupt/truncated/oversized files, network errors, redirects, atomic cache/config preservation, local priority, remembered fallback, actual downloaded-cache simulation boot and real server main startup/restart. GitHub network responses are controlled fixtures for repeatable tests; no user-provided live world URL was available. Authenticated two-player bone HTTP and 279 bone/guard regression checks pass. All Lua/server Python syntax and ZIP CRC/content checks pass; previous artwork/world are unchanged.

Previous notes:
Stonegrove 0.3.63.41 — Guard kills do not produce bones

Town guard killing blows do not produce regular or cursed bone piles, including Nagalians. This applies even if a player damaged the enemy earlier. The death is marked as handled so later death sweeps cannot create a pile or private bone claim.
Player and companion kills retain their existing bone rules. Respawn clears the handled marker for the next life. Other loot and the house editor Ctrl + right-click shortcut are preserved.

Validation: server simulation exercises real town guard lethal hits across normal/cursed enemy families, player-assisted guard kills, repeated/deferred drop attempts, respawn, and player-owned delayed drops. Existing cursed enemy, bone separation, kill ownership, purchases, burial, blessing, hallowed ground, persistence and rollback checks also pass. All Lua and server Python syntax checks and ZIP CRC/content checks pass; artwork is unchanged.

Previous notes:
Stonegrove 0.3.63.40 — House editor NPC controls

Ctrl + right-click toggles house interior/roof previews in the level editor.
Normal right-click opens the NPC inspector for NPCs inside houses, with the roof visible or hidden.
Shift + right-click retains erase. Placement, undo, save/reload and world export remain available.
Updated house placement and preview hints explain the new shortcut.
Gameplay right-click movement through house doors is unchanged.

Validation: native LOVE editor checks NPC inspection with roof visible/hidden, Ctrl preview without deletion, Shift erase, undo, saved house variants, reload and world export. Exported-world server checks house collisions and navigation. All Lua files compile; server Python syntax passes. Shared game files, assets and world match the previous release apart from version strings. ZIP CRC and content checks pass.

Previous notes:
STONEGROVE 0.3.63.39 — MID/HIGH FISH FOODS
See CHANGES-0.3.63.39.txt and VALIDATION-0.3.63.39.txt.
Manta/Tuna/Swordfish/Shark: slower catches, timed Process Fish, prepared raw recipes and graded cooked foods.

STONEGROVE 0.3.63.38 — HOUSING FIXES
See CHANGES-0.3.63.38.txt and VALIDATION-0.3.63.38.txt.
Every new house has a complete roof, random door placement and natural indoor light. Right-click a door to walk inside.

STONEGROVE 0.3.63.37 — CURSED ENEMIES AND BONES
See CHANGES-0.3.63.37.txt and VALIDATION-0.3.63.37.txt.
Hallowed ground requires at least five nearby burial markers.

STONEGROVE 0.3.63.36 — NEW MODULAR HOUSES
See CHANGES-0.3.63.36.txt and VALIDATION-0.3.63.36.txt.
New houses are in the editor Houses category. Right-click previews interiors; Shift + right-click erases.

STONEGROVE ALPHA 0.3.63.35
See CHANGES-0.3.63.35.txt and VALIDATION-0.3.63.35.txt.
Hold middle mouse for camera look. Select shop stock then Buy Max; Sell Inventory sells accepted carried goods.
