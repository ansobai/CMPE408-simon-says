$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$generatedAssetsDir = Join-Path $repoRoot 'presentation_assets\generated_5min'
$screenAssetsDir = Join-Path $repoRoot 'presentation_assets'
$outputPath = Join-Path $repoRoot 'presentation_assets\CMPE408_Neural_Recall_5min_Presentation.pptx'

$requiredAssets = @(
  '01_auth_sign_in.png',
  '02_auth_sign_up.png',
  '03_auth_invalid_input.png',
  '05_stats_leaderboard.png',
  '09_game_over.png',
  '10_no_data_state.png',
  '11_backend_warning.png'
) | ForEach-Object { Join-Path $generatedAssetsDir $_ }

$requiredAssets += @(
  '01_main_menu.png',
  '02_stats.png',
  '03_settings.png',
  '04_focus_mode.png',
  '05_overdrive_mode.png'
) | ForEach-Object { Join-Path $screenAssetsDir $_ }

foreach ($asset in $requiredAssets) {
  if (-not (Test-Path $asset)) {
    throw "Missing capture asset: $asset"
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
  $panel.Line.ForeColor.RGB = OfficeRgb 42 60 66
  $panel.Line.Transparency = 0.18
  return $panel
}

function Add-ImageFrame(
  $slide,
  [string]$path,
  [double]$left,
  [double]$top,
  [double]$maxWidth,
  [double]$maxHeight
) {
  $frame = Add-Panel $slide ($left - 6) ($top - 6) ($maxWidth + 12) ($maxHeight + 12) (OfficeRgb 15 20 24) 0.0
  $frame.Line.ForeColor.RGB = OfficeRgb 40 58 64
  $picture = $slide.Shapes.AddPicture($path, 0, -1, $left, $top, -1, -1)
  $scale = [Math]::Min($maxWidth / $picture.Width, $maxHeight / $picture.Height)
  $picture.Width = $picture.Width * $scale
  $picture.Height = $picture.Height * $scale
  $picture.Left = $left + (($maxWidth - $picture.Width) / 2)
  $picture.Top = $top + (($maxHeight - $picture.Height) / 2)
  return $picture
}

function Add-AccentDots($slide, [int]$cyan, [int]$purple) {
  $dot1 = $slide.Shapes.AddShape(9, 734, -68, 210, 210)
  $dot1.Fill.Visible = -1
  $dot1.Fill.Solid()
  $dot1.Fill.ForeColor.RGB = $cyan
  $dot1.Fill.Transparency = 0.82
  $dot1.Line.Visible = 0

  $dot2 = $slide.Shapes.AddShape(9, -56, 430, 176, 176)
  $dot2.Fill.Visible = -1
  $dot2.Fill.Solid()
  $dot2.Fill.ForeColor.RGB = $purple
  $dot2.Fill.Transparency = 0.86
  $dot2.Line.Visible = 0
}

function Add-TitleBlock($slide, [string]$title, [string]$subtitle, [int]$cyan, [int]$white) {
  Add-TextBox $slide 52 34 560 34 $title 24 $cyan $true | Out-Null
  Add-TextBox $slide 52 66 760 28 $subtitle 11 $white $false | Out-Null
  $line = $slide.Shapes.AddShape(1, 52, 102, 124, 4)
  $line.Fill.Visible = -1
  $line.Fill.Solid()
  $line.Fill.ForeColor.RGB = $cyan
  $line.Line.Visible = 0
}

function Add-Footer($slide, [int]$index, [int]$muted) {
  Add-TextBox $slide 52 508 840 18 'CMPE 408 | Neural Recall | 5-minute final presentation' 8 $muted $false | Out-Null
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

  $authSignIn = Join-Path $generatedAssetsDir '01_auth_sign_in.png'
  $authSignUp = Join-Path $generatedAssetsDir '02_auth_sign_up.png'
  $authInvalid = Join-Path $generatedAssetsDir '03_auth_invalid_input.png'
  $mainMenu = Join-Path $screenAssetsDir '01_main_menu.png'
  $statsScreen = Join-Path $screenAssetsDir '02_stats.png'
  $leaderboard = Join-Path $generatedAssetsDir '05_stats_leaderboard.png'
  $settings = Join-Path $screenAssetsDir '03_settings.png'
  $focusMode = Join-Path $screenAssetsDir '04_focus_mode.png'
  $overdriveMode = Join-Path $screenAssetsDir '05_overdrive_mode.png'
  $gameOver = Join-Path $generatedAssetsDir '09_game_over.png'
  $noData = Join-Path $generatedAssetsDir '10_no_data_state.png'
  $backendWarning = Join-Path $generatedAssetsDir '11_backend_warning.png'

  # Slide 1
  $slide = $presentation.Slides.Add(1, 12)
  Set-SlideBackground $slide $bg
  Add-AccentDots $slide $cyan $purple
  Add-TextBox $slide 52 52 470 38 'Neural Recall' 30 $cyan $true | Out-Null
  Add-TextBox $slide 52 98 520 24 'CMPE 408 final demo deck' 16 $white $false | Out-Null
  Add-TextBox $slide 52 140 460 126 (
    Join-Lines @(
      'This presentation is limited to five minutes and focuses on the rubric items:'
      ''
      '- implemented proposal features'
      '- UI design and custom widgets'
      '- error and empty-state handling'
      '- remaining work'
    )
  ) 16 $white $false | Out-Null
  Add-TextBox $slide 52 320 420 92 (
    Join-Lines @(
      'Team members: Anas Alsakkar, Bara Amro, Abdallah Ali'
      'Project: Flutter mobile memory game with shared sign-in and leaderboard support'
    )
  ) 13 $muted $false | Out-Null
  Add-ImageFrame $slide $authSignIn 596 44 126 432 | Out-Null
  Add-ImageFrame $slide $mainMenu 746 44 126 432 | Out-Null
  Add-Footer $slide 1 $muted

  # Slide 2
  $slide = $presentation.Slides.Add(2, 12)
  Set-SlideBackground $slide $bg
  Add-TitleBlock $slide 'Proposal Features Implemented' 'All core features promised in the proposal are now working in the build.' $cyan $muted
  Add-TextBox $slide 52 132 420 272 (
    Join-Lines @(
      '- Shared auth flow: sign in and sign up screens are functional.'
      '- Main menu, bottom navigation, and settings access are wired.'
      '- Focus Mode uses a 2x2 board; Overdrive Mode uses a 3x3 board.'
      '- Score, streak, round progression, reset flow, and game-over overlay all work.'
      '- Persistent stats, synced profile score, recent runs, and leaderboard ranking are displayed.'
    )
  ) 15 $white $false | Out-Null
  Add-TextBox $slide 52 430 420 42 'The screenshots on the right were captured from the current app build.' 12 $muted $false | Out-Null
  Add-ImageFrame $slide $authSignUp 500 128 118 340 | Out-Null
  Add-ImageFrame $slide $mainMenu 634 128 118 340 | Out-Null
  Add-ImageFrame $slide $focusMode 768 128 118 340 | Out-Null
  Add-Footer $slide 2 $muted

  # Slide 3
  $slide = $presentation.Slides.Add(3, 12)
  Set-SlideBackground $slide $bg
  Add-TitleBlock $slide 'UI Design, Widgets, and Motion' 'The UI uses custom dashboard cards, animated tiles, and clear transitions between states.' $cyan $muted
  Add-TextBox $slide 52 132 420 188 (
    Join-Lines @(
      '- Custom widgets: mode cards, leaderboard rows, settings cards, metric tiles, and dialogs.'
      '- Motion: AnimatedContainer, AnimatedOpacity, and AnimatedSwitcher keep interactions visible.'
      '- Gameplay transitions: route push into the board, phase labels, timer bars, and glow feedback.'
      '- The app also includes in-game instruction text through training hints and status labels like WATCH and REPEAT.'
    )
  ) 14 $white $false | Out-Null
  $callout = Add-Panel $slide 52 344 420 104 $panel 0.03
  Add-TextBox $slide 70 362 384 66 (
    Join-Lines @(
      'Instruction example shown in the app:'
      '"Repeat the pattern before the timer burns down."'
    )
  ) 15 $amber $false | Out-Null
  $callout | Out-Null
  Add-ImageFrame $slide $focusMode 500 126 118 344 | Out-Null
  Add-ImageFrame $slide $overdriveMode 634 126 118 344 | Out-Null
  Add-ImageFrame $slide $settings 768 126 118 344 | Out-Null
  Add-Footer $slide 3 $muted

  # Slide 4
  $slide = $presentation.Slides.Add(4, 12)
  Set-SlideBackground $slide $bg
  Add-TitleBlock $slide 'Leaderboard, Stats, and Persistence' 'The app now keeps player state beyond a single run and exposes it in dedicated screens.' $cyan $muted
  Add-TextBox $slide 52 140 410 230 (
    Join-Lines @(
      '- The stats screen shows global rank, profile score, best streak, best score, and recent runs.'
      '- The leaderboard ranks registered players by best saved score and highlights the current user.'
      '- The settings screen exposes theme, sound, haptics, motion, pace, and overdrive timing controls.'
      '- Account state is visible in the UI with signed-in status and sign-out support.'
    )
  ) 14 $white $false | Out-Null
  Add-TextBox $slide 52 402 410 56 'This is beyond the original game loop and makes the app feel like a complete product instead of a single board screen.' 12 $muted $false | Out-Null
  Add-ImageFrame $slide $statsScreen 520 124 150 348 | Out-Null
  Add-ImageFrame $slide $leaderboard 692 124 186 348 | Out-Null
  Add-Footer $slide 4 $muted

  # Slide 5
  $slide = $presentation.Slides.Add(5, 12)
  Set-SlideBackground $slide $bg
  Add-TitleBlock $slide 'Errors and Non-Ideal Scenarios' 'The build handles invalid input, empty datasets, backend failures, and game-over states explicitly.' $cyan $muted
  Add-TextBox $slide 52 130 410 200 (
    Join-Lines @(
      '- Invalid input: auth form validation blocks short usernames and passwords.'
      '- No data: the stats screen shows placeholder cards instead of blank space.'
      '- Service issues: the app shows a recovery notice when shared data cannot be loaded.'
      '- Gameplay failure: the game-over dialog explains why the run ended and offers replay or exit.'
    )
  ) 14 $white $false | Out-Null
  Add-ImageFrame $slide $authInvalid 494 120 118 160 | Out-Null
  Add-ImageFrame $slide $noData 628 120 118 160 | Out-Null
  Add-ImageFrame $slide $backendWarning 762 120 118 160 | Out-Null
  Add-ImageFrame $slide $gameOver 628 300 118 170 | Out-Null
  Add-TextBox $slide 52 368 410 78 'This slide covers the rubric requirement for network issues, invalid user input, and empty-state presentation.' 13 $mint $false | Out-Null
  Add-Footer $slide 5 $muted

  # Slide 6
  $slide = $presentation.Slides.Add(6, 12)
  Set-SlideBackground $slide $bg
  Add-TitleBlock $slide 'Remaining Work' 'The core proposal scope is complete; the rest is polish and extension work.' $cyan $muted
  $left = Add-Panel $slide 52 148 388 288 $panel 0.03
  $right = Add-Panel $slide 476 148 388 288 $panel 0.03
  Add-TextBox $slide 76 172 330 22 'Already complete' 16 $mint $true | Out-Null
  Add-TextBox $slide 76 208 330 170 (
    Join-Lines @(
      '- Two gameplay modes'
      '- Shared auth flow'
      '- Leaderboard and stats screen'
      '- Settings, persistence, and sign-out'
      '- Game-over and recovery states'
    )
  ) 14 $white $false | Out-Null
  Add-TextBox $slide 500 172 330 22 'Still worth finishing' 16 $amber $true | Out-Null
  Add-TextBox $slide 500 208 330 178 (
    Join-Lines @(
      '- More leaderboard filtering or per-mode ranking views'
      '- Additional backend hardening and deployment polish'
      '- More presentation/demo polish and broader test coverage'
      '- Optional history reset and extra UX refinements'
    )
  ) 14 $white $false | Out-Null
  Add-TextBox $slide 52 458 812 30 'Bottom line: the foundation is complete and functional; the remaining items are improvements, not missing core features.' 15 $white $false | Out-Null
  $left | Out-Null
  $right | Out-Null
  Add-Footer $slide 6 $muted

  if (Test-Path $outputPath) {
    Remove-Item -LiteralPath $outputPath -Force
  }

  $presentation.SaveAs($outputPath)
}
finally {
  if ($presentation -ne $null) {
    $presentation.Close()
  }
  if ($powerPoint -ne $null) {
    $powerPoint.Quit()
  }
}
