param([string]$ProjectRoot = (Get-Location).Path)
$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path $ProjectRoot 'docs/design/M1_기초마법_15종.md'
$source = [IO.File]::ReadAllText($sourcePath)
$integrated = [IO.File]::ReadAllText((Join-Path $ProjectRoot 'docs/design/Arcane_Legacy_75종_Codex_통합명세_v05.md'))
$allSheets = [IO.File]::ReadAllText((Join-Path $ProjectRoot 'docs/design/Arcane_Legacy_75종_전체시트_v05.md'))
$elements = @{ '木'='WOOD'; '火'='FIRE'; '土'='EARTH'; '金'='METAL'; '水'='WATER' }
$legacy = @{ 'OH-001'='wood_bind'; 'OH-016'='fire_ember'; 'OH-031'='earth_barrier'; 'OH-046'='metal_lance'; 'OH-061'='water_push' }
$runtime = @{
    'OH-002'=@{ effect='cone'; status_effect='slow'; duration=0.7; radius=85.0; damage=8.0; mana_cost=8.0; visual_style='ROOT_FLICK' }
    'OH-003'=@{ effect='projectile'; projectile_speed=500.0; lifetime=0.9; visual_style='SPLINTER' }
    'OH-017'=@{ effect='cone'; status_effect='burn'; damage_per_second=3.0; duration=2.0; radius=110.0; visual_style='CINDER_SWEEP' }
    'OH-018'=@{ effect='point'; radius=14.0; placement_distance=160.0; visual_style='FLASHPOINT' }
    'OH-032'=@{ effect='projectile'; projectile_speed=430.0; lifetime=1.0; visual_style='FLINTSHOT' }
    'OH-033'=@{ effect='cone'; status_effect='stagger'; duration=0.45; radius=95.0; visual_style='FAULTSTEP' }
    'OH-047'=@{ effect='projectile'; projectile_speed=575.0; lifetime=0.8; visual_style='SHARDSHOT' }
    'OH-048'=@{ effect='projectile'; projectile_speed=460.0; lifetime=0.5; knockback=-85.0; visual_style='LODESTONE' }
    'OH-062'=@{ effect='projectile'; projectile_speed=440.0; lifetime=1.0; visual_style='DROPLET' }
    'OH-063'=@{ effect='shockwave'; radius=95.0; duration=0.45; knockback=110.0; visual_style='EBBPULSE' }
}
$entries = @()
foreach($part in [regex]::Matches($source, '(?ms)^### (OH-\d{3}) — ([^\r\n]+)\r?\n(.*?)(?=^### OH-|\z)')) {
    $id = $part.Groups[1].Value; $name = $part.Groups[2].Value
    $fields = [ordered]@{}
    foreach($field in [regex]::Matches($part.Groups[3].Value, '(?m)^- \*\*([^*]+)\*\*: (.+)$')) {
        $key=$field.Groups[1].Value; if(-not $fields.Contains($key)) { $fields[$key]=$field.Groups[2].Value.Trim() }
    }
    if($fields['등급'] -ne '기초') { throw "Wrong explicit rank for $id" }
    if(-not $integrated.Contains("$id — $name") -or -not $allSheets.Contains("$id — $name")) { throw "ID/name mismatch: $id" }
    $entries += [ordered]@{ id=$id; english_name=$name; element=$elements[$fields['오행']]; rank='basic'; mana_cost=[double]$fields['마나 비용']; damage=[double]$fields['대표 직접피해']; legacy_resource=$legacy[$id]; runtime=$runtime[$id]; original_fields=$fields }
}
if($entries.Count -ne 15) { throw 'Expected exactly fifteen basic spells.' }
$document = [ordered]@{ version='0.5'; milestone='M1'; source='docs/design/M1_기초마법_15종.md'; runtime_status='prototype_not_final'; unresolved=@('P01 root diminishing/reset','P02 interruptible boss attacks','P03 poise','P05 wall HP/count','P06 status stacks','P11 displacement formula','projectile speed and narrow widths absent from source'); spells=$entries }
$json=$document | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText((Join-Path $ProjectRoot 'data/m1_spells_v05.json'), $json, [Text.UTF8Encoding]::new($false))
Write-Output "Imported $($entries.Count) M1 entries; source status and unresolved text preserved."
