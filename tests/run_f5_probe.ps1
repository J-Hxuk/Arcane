param([string]$Godot = 'C:/Users/jh030/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe', [string]$ProjectRootOverride = '', [switch]$WorldMain)
$ErrorActionPreference = 'Stop'
$projectRoot = if ($ProjectRootOverride) { $ProjectRootOverride } else { Split-Path -Parent $PSScriptRoot }
$artifactRelative = if ($WorldMain) { '.task002_artifacts/phase3a' } else { '.task002_artifacts/fusion_ux2' }
$probeRoot = Join-Path $projectRoot ($artifactRelative + '/f5_project_' + [DateTime]::UtcNow.Ticks)
$utf8 = New-Object Text.UTF8Encoding($false)
New-Item -ItemType Directory -Force $probeRoot | Out-Null
foreach ($folder in @('scripts','data','scenes')) {
    $destination = Join-Path $probeRoot $folder
    New-Item -ItemType Directory -Force $destination | Out-Null
    Copy-Item -Path (Join-Path $projectRoot "$folder/*") -Destination $destination -Recurse -Force
}
$config = [IO.File]::ReadAllText((Join-Path $projectRoot 'project.godot'))
$config = $config.Replace('Arcane Legacy - Prototype','Arcane Legacy - isolated editor probe')
$config = [regex]::Replace($config, 'run/main_scene="[^"]+"', 'run/main_scene="res://entry.tscn"')
[IO.File]::WriteAllText((Join-Path $probeRoot 'project.godot'), $config, $utf8)
$fixture = Join-Path $projectRoot '.task002_artifacts/fusion/developer_original.json.v3.bak'
if (-not (Test-Path -LiteralPath $fixture)) { throw 'Run test_fusion_d.gd once to create the isolated v3 fixture.' }
Copy-Item -LiteralPath $fixture -Destination (Join-Path $probeRoot 'fixture.json') -Force
Copy-Item -LiteralPath $fixture -Destination (Join-Path $probeRoot 'original.json') -Force
$pluginDirectory = Join-Path $probeRoot 'addons/f5_probe'
New-Item -ItemType Directory -Force $pluginDirectory | Out-Null
$pluginConfig = @'
[plugin]
name="UX2 isolated F5 probe"
description="Uses the actual editor main-scene run path with fixture-only storage."
author="Arcane Legacy tests"
version="1.0"
script="plugin.gd"
'@
[IO.File]::WriteAllText((Join-Path $pluginDirectory 'plugin.cfg'), $pluginConfig, $utf8)
$plugin = @'
@tool
extends EditorPlugin
var elapsed := 0.0
func _enter_tree() -> void:
    call_deferred("start_probe")
func start_probe() -> void:
    EditorInterface.play_main_scene()
func _process(delta: float) -> void:
    elapsed += delta
    if FileAccess.file_exists("res://probe_done.json"):
        set_process(false)
        var report = JSON.parse_string(FileAccess.get_file_as_string("res://probe_done.json"))
        print("F5_EDITOR_PROBE ", JSON.stringify(report))
        EditorInterface.stop_playing_scene()
        get_tree().quit(0 if report.get("success", false) else 1)
    elif elapsed > 45.0:
        push_error("F5 editor probe timed out")
        EditorInterface.stop_playing_scene()
        get_tree().quit(1)
'@
[IO.File]::WriteAllText((Join-Path $pluginDirectory 'plugin.gd'), $plugin, $utf8)
$entry = @'
extends "res://scripts/main.gd"
func _init() -> void:
    save_path = "res://fixture.json"
func _ready() -> void:
    super._ready()
    set_process(false)
    call_deferred("probe")
func probe() -> void:
    await get_tree().create_timer(0.35).timeout
    var result := {"editor_runtime": OS.has_feature("editor_runtime"), "debug": OS.is_debug_build(), "explicit_flag": OS.get_cmdline_user_args().has("--dev-lab"), "panel": developer_panel != null}
    result["v3_exact_backup"] = FileAccess.get_file_as_bytes("res://fixture.json.v3.bak") == FileAccess.get_file_as_bytes("res://original.json")
    result["schema"] = CharacterSave.load_file(save_path).get("version")
    var event := InputEventKey.new()
    event.keycode = KEY_F2; event.physical_keycode = KEY_F2; event.pressed = true
    Input.parse_input_event(event)
    await get_tree().process_frame
    event.pressed = false
    Input.parse_input_event(event)
    await get_tree().process_frame
    result["F2_visible"] = developer_panel != null and developer_panel.panel.visible
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png("res://f5_editor_runtime.png")
    var disk := FileAccess.get_file_as_bytes(save_path)
    var document := _character_document()
    var entered := _start_developer_test("WATER_METAL", "LAB")
    result["temporary_isolation"] = entered and _end_developer_test() and _character_document() == document and FileAccess.get_file_as_bytes(save_path) == disk
    result["success"] = result["editor_runtime"] and result["debug"] and not result["explicit_flag"] and result["panel"] and result["F2_visible"] and result["v3_exact_backup"] and result["schema"] == 4 and result["temporary_isolation"]
    var file := FileAccess.open("res://probe_done.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(result)); file.close()
    get_tree().quit(0 if result["success"] else 1)
'@
if ($WorldMain) {
    $entry = $entry.Replace('extends "res://scripts/main.gd"','extends "res://scripts/world/world_main.gd"')
    $entry = $entry.Replace('var event := InputEventKey.new()', 'result["town"] = world_enabled and layout.region(player_pos) == "TOWN" and world_camera.enabled' + "`n    " + 'var event := InputEventKey.new()')
    $entry = $entry.Replace('var file := FileAccess.open(', 'result["success"] = result["success"] and result["town"]' + "`n    " + 'var file := FileAccess.open(')
}
[IO.File]::WriteAllText((Join-Path $probeRoot 'entry.gd'), $entry, $utf8)
$scene = @'
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://entry.gd" id="1"]
[node name="F5Fixture" type="Node2D"]
script = ExtResource("1")
'@
[IO.File]::WriteAllText((Join-Path $probeRoot 'entry.tscn'), $scene, $utf8)
$donePath = Join-Path $probeRoot 'probe_done.json'
# Fresh clones now contain sprite textures. Import them before the probe plugin
# launches F5, otherwise the child game can race the editor's initial asset scan.
& $Godot --headless --editor --import --quit --path $probeRoot --log-file (Join-Path $probeRoot 'asset_import.log') | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Probe asset import failed: $LASTEXITCODE" }
$config += "`r`n[editor_plugins]`r`nenabled=PackedStringArray(`"res://addons/f5_probe/plugin.cfg`")`r`n"
[IO.File]::WriteAllText((Join-Path $probeRoot 'project.godot'), $config, $utf8)
& $Godot --editor --path $probeRoot --log-file (Join-Path $probeRoot 'editor_probe.log')
if ($LASTEXITCODE -ne 0) { throw "Editor probe process failed: $LASTEXITCODE" }
Get-Content -Encoding UTF8 -LiteralPath $donePath
Copy-Item -LiteralPath $donePath -Destination (Join-Path $projectRoot "$artifactRelative/f5_editor_result.json") -Force
Copy-Item -LiteralPath (Join-Path $probeRoot 'f5_editor_runtime.png') -Destination (Join-Path $projectRoot "$artifactRelative/f5_editor_runtime.png") -Force
