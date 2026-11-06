-- 1.0.0: Crystal-only. Forced onto another generation, main.lua stays off
-- before it reads a single file (the Gen 1 / Gen 3 paths are gone).
local entry = assert(loadfile('main.lua'))()
for _, generation in ipairs({ 1, 3 }) do
  local reads, warned = 0, nil
  local mod = {
    id = 'crystal-aio', generation = generation, path = '.',
    read = function() reads = reads + 1; return nil, 'must not read' end,
    log = { warn = function(_, fmt, ...) warned = string.format(fmt, ...) end },
  }
  entry(mod)
  assert(reads == 0, 'Gen ' .. generation .. ': read a file')
  assert(warned and warned:find('Crystal%-AiO runs on Gold/Silver/Crystal only'), 'Gen ' .. generation .. ': no warning')
end
-- the removed Gen 1 / Gen 3 files are not referenced by the files that remain
for _, path in ipairs({ 'main.lua', 'kim_main.lua', 'lib/asset_download_manager.lua' }) do
  local src = assert(io.open(path)):read('*a')
  for _, gone in ipairs({ 'gen3_frlg', 'modern_ui_integrated', 'integrated_krba', 'pokeball_colorfix',
      'battle_art_111', 'potato_voxel_', 'hgss_battle_hard_block', 'gen1_anims', 'title_player_red',
      'IS_GEN2', 'IS_GEN3' }) do
    assert(not src:find(gone, 1, true), path .. ' still mentions ' .. gone)
  end
end
print('Crystal only: Gen 1 / Gen 3 boots stay off without reading files; no references to removed code PASS')
