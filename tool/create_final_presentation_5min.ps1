$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$assetsDir = Join-Path $repoRoot 'presentation_assets'
$finalOutput = 'C:\Users\barae\OneDrive\Desktop\408\Neural_Recall_Final_5min_Bara_Amro_SUBMIT.pptx'

$mainImage = Join-Path $assetsDir 'final_main_menu.jpeg'
$statsImage = Join-Path $assetsDir 'final_stats.jpeg'
$settingsImage = Join-Path $assetsDir 'final_settings.jpeg'
$demoVideo = Join-Path $assetsDir 'demo_recording.mkv'

$requiredAssets = @($mainImage, $statsImage, $settingsImage, $demoVideo)
foreach ($asset in $requiredAssets) {
  if (-not (Test-Path $asset)) {
    throw "Missing asset: $asset"
  }
}

function OfficeRgb([int]$r, [int]$g, [int]$b) {
  return $r + ($g -shl 8) + ($b -shl 16)
}

function Join-Lines([string[]]$lines) {
  return ($lines -join [Environment]::NewLine)
}

function Set-SlideBackground($slide, [int]$color) {
  $slide.FollowMasterBackground = $false
  $slide.Background.Fill.Visible = -1
  $slide.Background.Fill.Solid()
  $slide.Background.Fill.ForeColor.RGB = $color
}

function Add-TextBox(
  $slide,
  [double]$left,
  [double]$top,
  [double]$width,
  [double]$height,
  [string]$text,
  [int]$fontSize,
  [int]$color,
  [bool]$bold = $false
) {
  $shape = $slide.Shapes.AddTextbox(1, $left, $top, $width, $height)
  $shape.TextFrame.TextRange.Text = $text
  $shape.TextFrame.TextRange.Font.Name = 'Segoe UI'
  $shape.TextFrame.TextRange.Font.Size = $fontSize
  $shape.TextFrame.TextRange.Font.Color.RGB = $color
  $shape.TextFrame.TextRange.Font.Bold = $(if ($bold) { -1 } else { 0 })
  $shape.TextFrame.WordWrap = -1
  $shape.TextFrame.MarginLeft = 0
  $shape.TextFrame.MarginRight = 0
  $shape.TextFrame.MarginTop = 0
  $shape.TextFrame.MarginBottom = 0
  return $shape
}

function Add-Panel(
  $slide,
  [double]$left,
  [double]$top,
  [double]$width,
  [double]$height,
  [int]$fillColor,
  [double]$fillTransparency = 0.0
) {
  $panel = $slide.Shapes.AddShape(5, $left, $top, $width, $height)
  $panel.Fill.Visible = -1
  $panel.Fill.Solid()
  $panel.Fill.ForeColor.RGB = $fillColor
  $panel.Fill.Transparency = $fillTransparency
  $panel.Line.Visible = -1
  $panel.Line.ForeColor.RGB = OfficeRgb 36 52 58
  $panel.Line.Transparency = 0.15
  return $panel
}

function Add-ImageFrame($slide, [string]$path, [double]$left, [double]$top, [double]$maxWidth, [double]$maxHeight) {
  $frame = Add-Panel $slide ($left - 6) ($top - 6) ($maxWidth + 12) ($maxHeight + 12) (OfficeRgb 15 20 24) 0.0
  $frame.Line.ForeColor.RGB = OfficeRgb 42 60 66
  $picture = $slide.Shapes.AddPicture($path, 0, -1, $left, $top, -1, -1)
  $scale = [Math]::Min($maxWidth / $picture.Width, $maxHeight / $picture.Height)
  $picture.Width = $picture.Width * $scale
  $picture.Height = $picture.Height * $scale
  $picture.Left = $left + (($maxWidth - $picture.Width) / 2)
  $picture.Top = $top + (($maxHeight - $picture.Height) / 2)
  return $picture
}

function Add-AccentDots($slide, [int]$cyan, [int]$purple) {
  $dot1 = $slide.Shapes.AddShape(9, 730, -70, 210, 210)
  $dot1.Fill.Visible = -1
  $dot1.Fill.Solid()
  $dot1.Fill.ForeColor.RGB = $cyan
  $dot1.Fill.Transparency = 0.82
  $dot1.Line.Visible = 0

  $dot2 = $slide.Shapes.AddShape(9, -60, 430, 180, 180)
  $dot2.Fill.Visible = -1
  $dot2.Fill.Solid()
  $dot2.Fill.ForeColor.RGB = $purple
  $dot2.Fill.Transparency = 0.86
  $dot2.Line.Visible = 0
}

function Add-TitleBlock($slide, [string]$title, [string]$subtitle, [int]$cyan, [int]$white) {
  Add-TextBox $slide 52 34 560 34 $title 24 $cyan $true | Out-Null
  Add-TextBox $slide 52 66 640 30 $subtitle 11 $white $false | Out-Null
  $line = $slide.Shapes.AddShape(1, 52, 104, 120, 4)
  $line.Fill.Visible = -1
  $line.Fill.Solid()
  $line.Fill.ForeColor.RGB = $cyan
  $line.Line.Visible = 0
}

function Add-Footer($slide, [int]$index, [int]$muted) {
  Add-TextBox $slide 52 508 840 18 'CMPE 408 | Neural Recall | Bara Amro | Anas Alsakkar | Abdallah Jama' 8 $muted $false | Out-Null
  $num = Add-TextBox $slide 892 508 20 18 "$index" 9 $muted $false
  $num.TextFrame.TextRange.ParagraphFormat.Alignment = 3
}

$powerPoint = $null
$presentation = $null

try {
  $powerPoint = New-Object -ComObject PowerPoint.Application
  $powerPoint.Visible = -1
  $presentation = $powerPoint.Presentations.Add()
  $presentation.PageSetup.SlideWidth = 960
  $presentation.PageSetup.SlideHeight = 540

  $bg = OfficeRgb 10 14 18
  $panel = OfficeRgb 17 23 28
  $cyan = OfficeRgb 24 221 255
  $white = OfficeRgb 236 240 244
  $muted = OfficeRgb 176 188 194
  $purple = OfficeRgb 123 84 255
  $amber = OfficeRgb 255 191 87
  $mint = OfficeRgb 91 242 197

  # Slide 1
  $slide = $presentation.Slides.Add(1, 12)
  Set-SlideBackground $slide $bg
  Add-AccentDots $slide $cyan $purple
  Add-TextBox $slide 52 56 460 46 'Neural Recall' 30 $cyan $true | Out-Null
  Add-TextBox $slide 52 104 460 26 'CMPE 408 project update' 16 $white $false | Out-Null
  Add-TextBox $slide 52 138 440 34 'Prepared by Bara Amro, Anas Alsakkar, and Abdallah Jama' 12 $muted $false | Out-Null
  Add-TextBox $slide 52 168 430 150 (
    Join-Lines @(
      'Neural Recall is a Flutter memory game with two play modes,'
      'persistent local data, a stats screen, and a customizable settings screen.'
      ''
      'This presentation focuses on the current working build,'
      'the data source and CRUD flow, the main Flutter tools we used,'
      'the biggest technical challenge, and the features still left to complete.'
    )
  ) 16 $white $false | Out-Null
  Add-ImageFrame $slide $mainImage 650 44 222 432 | Out-Null
  Add-Footer $slide 1 $muted

  # Slide 2
  $slide = $presentation.Slides.Add(2, 12)
  Set-SlideBackground $slide $bg
  Add-TitleBlock $slide 'What I have working now' 'This slide matches the features I promised in the proposal.' $cyan $muted
  Add-TextBox $slide 52 142 392 220 (
    Join-Lines @(
      '- We implemented Focus Mode with a 2x2 board and Overdrive Mode with a 3x3 board.'
      '- The app tracks score, streak, round progression, and the game-over overlay.'
      '- The stats screen summarizes completed sessions saved on the device.'
      '- The settings screen supports theme, sound, motion, pace, and overdrive tuning.'
      '- Bottom navigation connects the main menu, stats, and settings screens.'
    )
  ) 15 $white $false | Out-Null
  Add-TextBox $slide 52 392 392 54 'These screenshots are taken directly from the current build.' 13 $muted $false | Out-Null
  Add-ImageFrame $slide $mainImage 490 128 118 340 | Out-Null
  Add-ImageFrame $slide $statsImage 626 128 118 340 | Out-Null
  Add-ImageFrame $slide $settingsImage 762 128 118 340 | Out-Null
  Add-Footer $slide 2 $muted

  # Slide 3
  $slide = $presentation.Slides.Add(3, 12)
  Set-SlideBackground $slide $bg
  Add-TitleBlock $slide 'Working build demo' 'Embedded screen recording of the current application build.' $cyan $muted
  $videoPanel = Add-Panel $slide 52 126 270 360 $panel 0.02
  $video = $slide.Shapes.AddMediaObject2($demoVideo, 0, -1, 94, 136, 158, 352)
  $video.MediaFormat.SetDisplayPictureFromFile($mainImage)
  $video.Line.Visible = -1
  $video.Line.ForeColor.RGB = OfficeRgb 43 61 66
  Add-TextBox $slide 350 156 530 160 (
    Join-Lines @(
      'This recording shows the current build running on an Android emulator.'
      ''
      '- The main menu and mode selection'
      '- Gameplay interaction'
      '- Score and streak flow'
      '- The game-over overlay at the end of a round'
    )
  ) 16 $white $false | Out-Null
  Add-TextBox $slide 350 350 530 92 (
    Join-Lines @(
      'The recording is included directly in the slide and can be played during the presentation.'
      ''
      'It covers the main functionality requested in the proposal without depending on a live connection.'
    )
  ) 14 $muted $false | Out-Null
  Add-TextBox $slide 90 454 170 16 'Click the poster to play the video.' 10 $muted $false | Out-Null
  $videoPanel | Out-Null
  Add-Footer $slide 3 $muted

  # Slide 4
  $slide = $presentation.Slides.Add(4, 12)
  Set-SlideBackground $slide $bg
  Add-TitleBlock $slide 'Data source and CRUD example' 'The current build uses a local data source instead of a cloud backend.' $cyan $muted
  Add-TextBox $slide 52 146 470 210 (
    Join-Lines @(
      'The current data source is SharedPreferences on the device.'
      ''
      '- Create: after each completed game, the app saves a new GameSession record.'
      '- Read: when the app opens, it loads saved stats and saved settings.'
      '- Update: when a setting changes, the new value is saved immediately.'
      '- Delete: a full reset of saved history is one of the remaining features still planned.'
    )
  ) 15 $white $false | Out-Null
  Add-TextBox $slide 52 384 470 58 'The clearest CRUD example in the UI is Update, because every settings change is saved and still appears after reopening the app.' 13 $muted $false | Out-Null
  Add-ImageFrame $slide $settingsImage 640 132 210 340 | Out-Null
  Add-Footer $slide 4 $muted

  # Slide 5
  $slide = $presentation.Slides.Add(5, 12)
  Set-SlideBackground $slide $bg
  Add-TitleBlock $slide 'Key Flutter pieces we used' 'These are the main Flutter components and packages behind the app.' $cyan $muted
  $leftPanel = Add-Panel $slide 52 144 390 320 $panel 0.03
  $rightPanel = Add-Panel $slide 476 144 390 320 $panel 0.03
  Add-TextBox $slide 76 170 320 20 'Flutter components' 16 $cyan $true | Out-Null
  Add-TextBox $slide 76 206 330 210 (
    Join-Lines @(
      '- MaterialApp, Scaffold, SafeArea, Stack, and SingleChildScrollView'
      '- PageView and PageController for the tab-style navigation'
      '- ValueNotifier and ValueListenableBuilder for updating stats and settings in the UI'
      '- Timer, HapticFeedback, and SystemChrome for gameplay timing and mobile behavior'
    )
  ) 14 $white $false | Out-Null
  Add-TextBox $slide 500 170 320 20 'Packages and structure' 16 $cyan $true | Out-Null
  Add-TextBox $slide 500 206 330 210 (
    Join-Lines @(
      '- shared_preferences for local persistence'
      '- audioplayers with AudioPool for tap sounds and sequence sounds'
      '- repository classes to keep storage logic out of the screen widgets'
      '- model classes for sessions, stats, and settings'
    )
  ) 14 $white $false | Out-Null
  $leftPanel | Out-Null
  $rightPanel | Out-Null
  Add-Footer $slide 5 $muted

  # Slide 6
  $slide = $presentation.Slides.Add(6, 12)
  Set-SlideBackground $slide $bg
  Add-TitleBlock $slide 'Biggest challenge and what is left' 'Final summary of the main technical issue and the remaining work.' $cyan $muted
  $challengePanel = Add-Panel $slide 52 150 396 300 $panel 0.03
  $remainingPanel = Add-Panel $slide 500 150 376 300 $panel 0.03
  Add-TextBox $slide 76 176 330 22 'Biggest technical challenge' 16 $amber $true | Out-Null
  Add-TextBox $slide 76 214 332 190 (
    Join-Lines @(
      'The biggest challenge was keeping the game loop synchronized while the rounds got faster.'
      ''
      'The implementation had to coordinate sequence playback, user taps, score updates,'
      'audio feedback, timers, and the game-over transition without letting the app'
      'fall into an invalid state.'
      ''
      'The final approach used repository-based storage and careful session guards'
      'to keep the logic stable as the pace increased.'
    )
  ) 14 $white $false | Out-Null
  Add-TextBox $slide 524 176 310 22 'Remaining features' 16 $mint $true | Out-Null
  Add-TextBox $slide 524 214 314 180 (
    Join-Lines @(
      '- full leaderboard with named entries'
      '- delete or reset flow for saved history'
      '- optional backend expansion in a future version'
      '- more testing and a final polish pass on the user experience'
    )
  ) 14 $white $false | Out-Null
  Add-TextBox $slide 500 414 340 40 'Overall, the core app is working, and the remaining work is mostly feature expansion rather than fixing the foundation.' 13 $muted $false | Out-Null
  $challengePanel | Out-Null
  $remainingPanel | Out-Null
  Add-Footer $slide 6 $muted

  if (Test-Path $finalOutput) {
    Remove-Item -LiteralPath $finalOutput -Force
  }

  $presentation.SaveAs($finalOutput)
}
finally {
  if ($presentation -ne $null) {
    $presentation.Close()
  }
  if ($powerPoint -ne $null) {
    $powerPoint.Quit()
  }
}
