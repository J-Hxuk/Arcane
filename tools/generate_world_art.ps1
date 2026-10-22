# Original temporary art for Arcane Legacy. No third-party images or runtime dependencies.
# Run from the project root with PowerShell. Every shape is on an integer pixel grid.
param([string]$ProjectRoot = (Get-Location).Path)
$ErrorActionPreference = 'Stop'
$out = Join-Path $ProjectRoot 'data/world_art'
New-Item -ItemType Directory -Force $out | Out-Null
function Begin-Art($w, $h) {
    $script:svg = [System.Text.StringBuilder]::new()
    [void]$script:svg.Append("<svg xmlns='http://www.w3.org/2000/svg' width='$w' height='$h' viewBox='0 0 $w $h'>")
}
function Pixel($x,$y,$w,$h,$c) { [void]$script:svg.Append("<rect x='$x' y='$y' width='$w' height='$h' fill='#$c'/>") }
function P($points,$c) { [void]$script:svg.Append("<polygon points='$points' fill='#$c'/>") }
function Save-Art($name) {
    [void]$script:svg.Append('</svg>')
    [IO.File]::WriteAllText((Join-Path $out "$name.svg"), $script:svg.ToString(), [Text.UTF8Encoding]::new($false))
}

# Four directions, three animation frames each; 32x40 cell, feet on row 39.
foreach ($knight in @($false,$true)) {
    Begin-Art 96 160
    for ($direction=0; $direction -lt 4; $direction++) {
        for ($frame=0; $frame -lt 3; $frame++) {
            $x=$frame*32; $y=$direction*40; $step=if($frame -eq 1){1}elseif($frame -eq 2){-1}else{0}
            $cloth=if($knight){'647d88'}else{'428f9a'}
            $light=if($knight){'b6c3bf'}else{'76c6bd'}
            $dark=if($knight){'344853'}else{'234852'}
            Pixel ($x+8) ($y+34+$step) 7 5 '172c37'; Pixel ($x+18) ($y+34-$step) 7 5 '172c37'
            Pixel ($x+9) ($y+29+$step) 5 7 '46505b'; Pixel ($x+18) ($y+29-$step) 5 7 '46505b'
            P "$($x+7),$($y+15) $($x+25),$($y+15) $($x+27),$($y+31) $($x+5),$($y+31)" '172e39'
            P "$($x+9),$($y+16) $($x+23),$($y+16) $($x+24),$($y+29) $($x+8),$($y+29)" $cloth
            Pixel ($x+9) ($y+18) 3 9 $light; Pixel ($x+21) ($y+19) 3 11 $dark
            Pixel ($x+8) ($y+28) 16 3 'b59660'; Pixel ($x+15) ($y+28) 3 3 'e3cc85'
            Pixel ($x+4) ($y+19-$step) 4 10 $dark; Pixel ($x+24) ($y+19+$step) 4 10 $dark
            Pixel ($x+4) ($y+27-$step) 4 4 'dfb18b'; Pixel ($x+24) ($y+27+$step) 4 4 'dfb18b'
            Pixel ($x+10) ($y+2) 12 3 '1d2c38'; Pixel ($x+7) ($y+5) 18 11 '1d2c38'
            Pixel ($x+9) ($y+4) 14 8 '5a4341'; Pixel ($x+10) ($y+3) 10 3 '89634d'
            if ($direction -eq 3) {
                Pixel ($x+8) ($y+7) 16 9 '5a4341'; Pixel ($x+10) ($y+5) 4 8 '89634d'
                Pixel ($x+10) ($y+18) 12 10 $dark; Pixel ($x+12) ($y+18) 2 9 $cloth
            } else {
                $faceX=if($direction -eq 1){8}elseif($direction -eq 2){14}else{10}
                Pixel ($x+$faceX) ($y+9) 12 8 'e6bc92'; Pixel ($x+$faceX+2) ($y+15) 8 2 'b47d67'
                if ($direction -eq 0) {
                    Pixel ($x+11) ($y+10) 2 3 '203240'; Pixel ($x+19) ($y+10) 2 3 '203240'; Pixel ($x+15) ($y+14) 2 1 '8b5c56'
                } else {
                    $eye=if($direction -eq 1){9}else{22}; Pixel ($x+$eye) ($y+10) 2 3 '203240'
                    Pixel ($x+$(if($direction -eq 1){6}else{24})) ($y+12) 3 3 'e6bc92'
                }
            }
            if ($knight) {
                Pixel ($x+7) ($y+4) 18 6 '91a7ad'; Pixel ($x+10) ($y+2) 12 3 'c0ccbf'
                Pixel ($x+8) ($y+10) 16 3 '243b4b'; Pixel ($x+14) ($y+4) 3 12 'd1d4bd'
                Pixel ($x+15) ($y+0) 3 3 'bd765f'
                P "$($x+1),$($y+19) $($x+9),$($y+18) $($x+9),$($y+29) $($x+5),$($y+33) $($x+1),$($y+29)" 'b5a777'
                Pixel ($x+3) ($y+21) 4 7 '506976'; Pixel ($x+27) ($y+14) 2 17 'd8dbc7'; Pixel ($x+25) ($y+27) 6 2 'ac8b58'
            }
        }
    }
    Save-Art $(if($knight){'guardian'}else{'traveller'})
}

# Building footprint is unchanged. The 52-pixel elevation projects north of it.
foreach ($b in @(@('laboratory',170,120,'536d86','8caab7','b9c4b2'),@('library',150,110,'74745b','b9ad78','c1baa0'),@('smith',150,115,'815d50','b78d68','aaa78f'),@('rest',150,110,'5c7865','92b59a','c6bba0'))) {
    $name=$b[0]; $w=[int]$b[1]; $h=[int]$b[2]; $roof=$b[3]; $roofLight=$b[4]; $wall=$b[5]
    $bottom=$h+52; $eave=$bottom-38
    Begin-Art ($w+16) ($h+64)
    P "8,$bottom $($w+8),$bottom $($w+16),$($bottom+9) 18,$($bottom+9)" '24362f'
    Pixel 8 36 $w $h '34443e'
    Pixel 8 $eave $w 38 $wall
    P "$($w+8),$eave $($w+14),$($eave-12) $($w+14),$($bottom-8) $($w+8),$bottom" '4d625c'
    Pixel ($w-5) $eave 13 38 '777f75'
    Pixel 8 ($bottom-6) $w 6 '666c64'
    Pixel 8 $eave $w 5 '3b4a47'
    for ($xx=10; $xx -lt $w; $xx+=22) { Pixel $xx ($bottom-17) 18 1 '9a9e8d'; Pixel ($xx+8) ($bottom-30) 12 1 '9a9e8d' }
    P "4,$eave 24,12 $($w-15),12 $($w+12),$eave" '283b40'
    P "8,$($eave-4) 27,15 $($w-17),15 $($w+6),$($eave-4)" $roof
    for ($yy=23; $yy -lt ($eave-4); $yy+=8) {
        $inset=[int](19*($eave-$yy)/($eave-15)); $left=9+$inset; $right=$w+5-$inset
        Pixel $left $yy ($right-$left) 2 $roofLight
        for ($xx=$left+$(if(($yy/8)%2 -lt 1){8}else{0}); $xx -lt $right-3; $xx+=16) { Pixel $xx ($yy+2) 2 5 '3e535b' }
    }
    Pixel 27 11 ($w-44) 4 $roofLight; Pixel 27 15 ($w-44) 2 '3a4a4c'
    Pixel 4 ($eave-4) ($w+8) 5 '36474a'; Pixel 5 ($eave-4) ($w+5) 2 $roofLight
    $door=[int]($w/2)-4
    Pixel $door ($bottom-33) 26 33 '46504b'; Pixel ($door+3) ($bottom-30) 20 30 '604f43'
    Pixel ($door+5) ($bottom-29) 2 27 'a18965'; Pixel ($door+11) ($bottom-29) 1 27 '443e36'
    Pixel ($door+18) ($bottom-16) 2 3 'f0d594'; Pixel ($door-3) $bottom 32 3 'd0c2a3'; Pixel ($door-5) ($bottom+3) 36 3 '898b77'
    foreach ($wx in @(23,($w-40))) {
        Pixel $wx ($bottom-29) 22 19 '656e66'; Pixel ($wx+2) ($bottom-27) 18 15 '283e48'
        Pixel ($wx+3) ($bottom-26) 6 11 'a0c6c1'; Pixel ($wx+11) ($bottom-26) 6 11 '6d969a'
        Pixel ($wx+9) ($bottom-27) 2 15 'b4ad88'; Pixel ($wx+1) ($bottom-19) 20 2 'b4ad88'; Pixel ($wx-2) ($bottom-10) 26 3 '6b796b'
    }
    Pixel ($door-10) ($bottom-26) 3 8 'd6be79'; Pixel ($door-11) ($bottom-26) 5 3 'ffe2a1'
    if($name -eq 'laboratory') {
        Pixel 38 35 34 24 '344e5c'; Pixel 41 38 28 18 'abc6be'; Pixel 44 41 22 12 '4b7183'
        P '53,41 59,41 59,45 63,51 49,51 53,45' 'b3e4d0'
        Pixel ($w-24) 5 13 32 '535e64'; Pixel ($w-27) 4 19 5 '8d9b99'; Pixel ($w-22) 8 4 19 '737c7b'
    } elseif($name -eq 'library') {
        Pixel 36 32 43 24 '35474a'; Pixel 39 35 37 18 'baad80'; Pixel 56 36 2 16 '615940'
        Pixel 42 38 11 2 '6e7056'; Pixel 61 38 11 2 '6e7056'; Pixel 42 44 11 2 '6e7056'; Pixel 61 44 11 2 '6e7056'
    } elseif($name -eq 'smith') {
        Pixel ($w-37) 3 22 47 '585a53'; Pixel ($w-40) 2 28 6 '9b9986'; Pixel ($w-34) 10 5 34 '868879'
        P '39,36 63,36 60,42 55,44 55,48 63,51 38,51 46,46 46,42 39,41' 'd2b888'
        Pixel ($w-11) ($bottom-29) 16 23 '382e2c'; Pixel ($w-9) ($bottom-21) 12 12 'bd673d'; Pixel ($w-6) ($bottom-18) 6 9 'efbd6a'
    } else {
        Pixel 38 35 39 22 '3c5951'; P '48,39 54,43 63,37 67,41 57,48 50,48' 'ebdca6'
        Pixel 20 ($eave-2) ($w-25) 5 'd0bd87'; Pixel 20 ($eave+3) ($w-25) 5 '617f68'
    }
    Save-Art $name
}

Begin-Art 72 100
P '11,91 19,85 53,85 67,91 63,97 17,97' '243a31'
P '28,88 31,52 44,48 45,87 52,92 22,92' '493d31'
Pixel 32 56 6 33 '8b6945'; Pixel 38 63 4 26 '644b34'; P '34,72 16,56 20,52 37,62' '795d3f'
P '5,47 12,28 23,28 24,15 34,9 46,13 51,25 61,28 68,45 64,58 58,59 54,72 38,76 22,70 12,61 5,60' '203d39'
P '7,44 15,27 27,25 30,14 39,12 47,24 58,30 64,45 58,57 49,67 34,70 20,64 14,55 7,56' '39634c'
P '12,37 19,28 30,29 33,17 41,17 48,29 57,34 59,43 48,44 43,54 31,50 20,54 13,46' '54815a'
P '17,34 23,30 31,32 33,24 41,22 46,32 38,37 28,35 24,43 17,43' '81a56b'
P '34,55 43,57 51,50 59,49 54,61 43,66 32,63' '648a59'
foreach($point in @(@(13,46),@(27,19),@(50,32),@(22,59),@(44,43),@(53,58))) { Pixel $point[0] $point[1] 4 2 '8dab6f' }
Save-Art 'tree'

foreach($vertical in @($false,$true)) {
    $w=if($vertical){20}else{32}; $d=if($vertical){32}else{20}; $h=$d+24
    Begin-Art $w $h
    Pixel 0 24 $w $d '5a6868'; Pixel 0 ($h-4) $w 4 '3c5052'
    for($yy=25;$yy -lt $h-4;$yy+=7) {
        Pixel 0 $yy $w 1 '84928a'
        for($xx=$(if(($yy%2) -eq 0){0}else{9});$xx -lt $w;$xx+=16) { Pixel $xx ($yy+1) 1 6 '394e52' }
    }
    Pixel 0 2 $w 23 '8d9c92'; Pixel 1 4 ($w-2) 17 '6a7e7a'; Pixel 0 21 $w 4 'b4b9a0'
    for($xx=1;$xx -lt $w;$xx+=12) { Pixel $xx 0 7 6 'b1b79e'; Pixel ($xx+1) 1 5 2 'd0ccb0'; Pixel $xx 5 7 2 '536c6b' }
    Pixel 1 8 2 11 'a8b29a'
    Save-Art $(if($vertical){'wall_v'}else{'wall_h'})
}

Begin-Art 64 64
P '4,48 13,17 30,6 51,14 60,39 52,59 16,61' '293e3e'
P '7,46 17,19 31,10 50,16 57,38 49,55 18,57' '5a6e70'
P '17,19 31,10 50,16 43,32 23,35 7,46' '89968b'
P '23,35 43,32 49,55 18,57' '677a76'
P '43,32 50,16 57,38 49,55' '435a60'
P '17,19 31,13 41,16 24,22' 'b0b19a'; Pixel 19 39 8 2 '8d9a89'; Pixel 28 48 7 2 '8d9a89'
Save-Art 'rock'

# Repeatable 64px ground tiles: subdued detail under the readable silhouettes.
foreach($kind in @('grass','cobble','dirt','ruin')) {
    Begin-Art 64 64
    $base=@{grass='3b5144';cobble='7d8170';dirt='6b6d50';ruin='535f5e'}[$kind]
    Pixel 0 0 64 64 $base
    if($kind -eq 'cobble' -or $kind -eq 'ruin') {
        for($yy=0;$yy -lt 64;$yy+=16) {
            for($xx=-16;$xx -lt 64;$xx+=32) {
                $bx=$xx+$(if(($yy/16)%2 -eq 0){0}else{16})
                Pixel ($bx+1) ($yy+1) 29 13 $(if($kind -eq 'ruin'){'68736b'}else{'93957b'})
                Pixel ($bx+2) ($yy+2) 27 2 $(if($kind -eq 'ruin'){'808779'}else{'b0ad8a'})
                Pixel ($bx+2) ($yy+12) 27 2 $(if($kind -eq 'ruin'){'475653'}else{'6c7464'})
                if(($xx+$yy)%3 -eq 0) { Pixel ($bx+19) ($yy+4) 2 6 $(if($kind -eq 'ruin'){'465b54'}else{'858b72'}) }
            }
        }
    } else {
        $density=if($kind -eq 'grass'){21}else{44}
        for($i=0;$i -lt $density;$i++) {
            $xx=($i*23+7)%62; $yy=($i*37+11)%62
            if($kind -eq 'grass') {
                Pixel $xx $yy 2 3 $(if($i%3 -eq 0){'5d7553'}else{'45634b'})
                if($i%4 -eq 0) { Pixel ($xx+2) ($yy+1) 2 2 '748460' }
            } else { Pixel $xx $yy $(if($i%3 -eq 0){4}else{2}) 2 $(if($i%2 -eq 0){'899073'}else{'5b634c'}) }
        }
    }
    Save-Art $kind
}
Write-Output "Created original SVG sprite atlases and world tiles in $out"
