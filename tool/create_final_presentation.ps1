$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$assetsDir = Join-Path $repoRoot 'presentation_assets'
$outputPath = Join-Path $assetsDir 'Neural_Recall_Project_Update_Bara_Amro.pptx'
$desktopCopyPath = Join-Path $repoRoot 'Neural_Recall_Project_Update_Bara_Amro.pptx'

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

function Set-SlideBackground($slide, [int]$color) {
  $slide.FollowMasterBackground = $false
  $slide.Background.Fill.Visible = -1
  $slide.Background.Fill.Solid()
  $slide.Background.Fill.ForeColor.RGB = $color
}

function Add-AccentCircle($slide, [double]$left, [double]$top, [double]$size, [int]$color, [double]$transparency) {
  $circle = $slide.Shapes.AddShape(9, $left, $top, $size, $size)
  $circle.Fill.Visible = -1
  $circle.Fill.Solid()
  $circle.Fill.ForeColor.RGB = $color
  $circle.Fill.Transparency = $transparency
  $circle.Line.Visible = 0
  return $circle
}

function Add-TextBox($slide, [double]$left, [double]$top, [double]$width, [double]$height, [string]$text, [int]$fontSize, [int]$color, [bool]$bold = $false) {
  $shape = $slide.Shapes.AddTextbox(1, $left, $top, $width, $height)
  $shape.TextFrame.TextRange.Text = $text
  $shape.TextFrame.TextRange.Font.Name = 'Segoe UI'
  $shape.TextFrame.TextRange.Font.Size = $fontSize
  $shape.TextFrame.TextRange.Font.Color.RGB = $color
  if ($bold) {
    $shape.TextFrame.TextRange.Font.Bold = -1
  }
  $shape.TextFrame.WordWrap = -1
  $shape.TextFrame.MarginLeft = 0
  $shape.TextFrame.MarginRight = 0
  $shape.TextFrame.MarginTop = 0
  $shape.TextFrame.MarginBottom = 0
  return $shape
}

function Add-Title($slide, [string]$title, [string]$subtitle = '') {
  $titleColor = OfficeRgb 22 220 255
  $bodyColor = OfficeRgb 232 236 240
  Add-TextBox $slide 52 34 520 42 $title 26 $titleColor $true | Out-Null
  if ($subtitle) {
    Add-TextBox $slide 52 74 460 36 $subtitle 12 $bodyColor $false | Out-Null
  }
  $line = $slide.Shapes.AddShape(1, 52, 118, 120, 4)
  $line.Fill.Visible = -1
  $line.Fill.Solid()
  $line.Fill.ForeColor.RGB = $titleColor
  $line.Line.Visible = 0
}

function Add-Panel($slide, [double]$left, [double]$top, [double]$width, [double]$height, [int]$fillColor, [double]$fillTransparency = 0.0) {
  $panel = $slide.Shapes.AddShape(5, $left, $top, $width, $height)
  $panel.Fill.Visible = -1
  $panel.Fill.Solid()
  $panel.Fill.ForeColor.RGB = $fillColor
  $panel.Fill.Transparency = $fillTransparency
  $panel.Line.Visible = -1
  $panel.Line.ForeColor.RGB = OfficeRgb 40 58 64
  $panel.Line.Transparency = 0.2
  return $panel
}

function Add-PhoneImage($slide, [string]$path, [double]$left, [double]$top, [double]$maxWidth, [double]$maxHeight) {
  $frame = Add-Panel $slide ($left - 8) ($top - 8) ($maxWidth + 16) ($maxHeight + 16) (OfficeRgb 14 18 21) 0.0
  $frame.Line.ForeColor.RGB = OfficeRgb 35 51 57
  $frame.Line.Transparency = 0.1
  $picture = $slide.Shapes.AddPicture($path, 0, -1, $left, $top, -1, -1)
  $scale = [Math]::Min($maxWidth / $picture.Width, $maxHeight / $picture.Height)
  $picture.Width = $picture.Width * $scale
  $picture.Height = $picture.Height * $scale
  $picture.Left = $left + (($maxWidth - $picture.Width) / 2)
  $picture.Top = $top + (($maxHeight - $picture.Height) / 2)
  return $picture
}

function Add-Footer($slide, [int]$index) {
  $footer = Add-TextBox $slide 52 506 860 18 "CMPE 408 | Neural Recall | Bara Amro" 9 (OfficeRgb 134 150 156) $false
  $num = Add-TextBox $slide 900 506 24 18 "$index" 9 (OfficeRgb 134 150 156) $false
  $num.TextFrame.TextRange.ParagraphFormat.Alignment = 3
  $footer | Out-Null
}

$powerPoint = $null
$presentation = $null

try {
  $powerPoint = New-Object -ComObject PowerPoint.Application
  $powerPoint.Visible = -1
  $presentation = $powerPoint.Presentations.Add()
  $presentation.PageSetup.SlideWidth = 960
  $presentation.PageSetup.SlideHeight = 540

  $bg = OfficeRgb 11 15 18
  $cyan = OfficeRgb 22 220 255
  $white = OfficeRgb 236 240 244
  $muted = OfficeRgb 180 194 200
  $purple = OfficeRgb 125 77 255
  $amber = OfficeRgb 255 186 82
  $teal = OfficeRgb 70 220 197
  $panel = OfficeRgb 18 24 29

  # Slide 1
  $slide = $presentation.Slides.Add(1, 12)
  Set-SlideBackground $slide $bg
  Add-AccentCircle $slide 668 -86 260 $cyan 0.76 | Out-Null
  Add-AccentCircle $slide -70 412 210 $purple 0.78 | Out-Null
  Add-TextBox $slide 52 54 360 66 'Neural Recall' 30 $cyan $true | Out-Null
  Add-TextBox $slide 52 102 360 48 'CMPE 408 progress presentation' 16 $white $false | Out-Null
  Add-TextBox $slide 52 176 360 185 "I built Neural Recall as a cyber-themed Flutter memory game with two play modes, persistent progress tracking, and a full settings flow.\r\n\r\nFor this milestone, I focused on getting the core gameplay loop, local data persistence, stats, and customization working end to end." 16 $white $false | Out-Null
  Add-TextBox $slide 52 422 300 28 'Prepared by: Bara Amro' 11 $muted $false | Out-Null
  Add-PhoneImage $slide $mainImage 640 54 232 424 | Out-Null
  Add-Footer $slide 1

  # Slide 2
  $slide = $presentation.Slides.Add(2, 12)
  Set-SlideBackground $slide $bg
  Add-Title $slide 'What I have working now' 'This is the current state of the project compared to my proposal.'
  Add-TextBox $slide 52 146 392 200 "• I implemented the two gameplay modes from my proposal: Focus Mode (2×2) and Overdrive Mode (3×3).\r\n• I finished the main menu, live gameplay loop, score tracking, streak tracking, and the game-over overlay.\r\n• I also added dedicated stats and settings screens so the app feels like a complete mobile product instead of a single gameplay screen." 15 $white $false | Out-Null
  Add-TextBox $slide 52 340 392 90 "The screenshots on the right show the exact build I am presenting: the home screen, the stats dashboard, and the settings screen." 14 $muted $false | Out-Null
  Add-PhoneImage $slide $mainImage 490 126 120 344 | Out-Null
  Add-PhoneImage $slide $statsImage 626 126 120 344 | Out-Null
  Add-PhoneImage $slide $settingsImage 762 126 120 344 | Out-Null
  Add-Footer $slide 2

  # Slide 3
  $slide = $presentation.Slides.Add(3, 12)
  Set-SlideBackground $slide $bg
  Add-Title $slide 'Working build demo' 'I recorded the actual application build so I can show the app reliably in under five minutes.'
  $video = $slide.Shapes.AddMediaObject2($demoVideo, 0, -1, 360, 54, 240, 426)
  $video.Line.Visible = -1
  $video.Line.ForeColor.RGB = OfficeRgb 35 51 57
  $leftPanel = Add-Panel $slide 52 150 250 190 $panel 0.06
  $rightPanel = Add-Panel $slide 660 150 248 190 $panel 0.06
  Add-TextBox $slide 72 170 210 24 'What the recording shows' 15 $cyan $true | Out-Null
  Add-TextBox $slide 72 205 210 116 "• I launch a real game session.\r\n• I interact with the tiles and audio feedback.\r\n• I reach the game-over state and show the working overlay." 14 $white $false | Out-Null
  Add-TextBox $slide 680 170 210 24 'Why I included it' 15 $cyan $true | Out-Null
  Add-TextBox $slide 680 205 210 126 "• It proves the build is running end to end.\r\n• It shows the same UI style as my screenshots.\r\n• It keeps the presentation stable even if a live demo is risky." 14 $white $false | Out-Null
  Add-TextBox $slide 350 490 260 18 'Click the embedded video during the presentation to play it.' 10 $muted $false | Out-Null
  $leftPanel | Out-Null
  $rightPanel | Out-Null
  Add-Footer $slide 3

  # Slide 4
  $slide = $presentation.Slides.Add(4, 12)
  Set-SlideBackground $slide $bg
  Add-Title $slide 'Data source integration and CRUD' 'For this milestone, I used local persistence instead of a cloud backend.'
  Add-TextBox $slide 52 146 400 66 "My data source is SharedPreferences on the device. I wrapped it behind repository classes so the UI reads and writes data cleanly." 15 $white $false | Out-Null

  $box1 = Add-Panel $slide 52 240 170 68 $panel 0.02
  Add-TextBox $slide 72 258 130 16 'UI + screens' 14 $cyan $true | Out-Null
  Add-TextBox $slide 72 278 130 24 'Main menu, stats, settings, gameplay' 10 $muted $false | Out-Null
  $box2 = Add-Panel $slide 248 240 170 68 $panel 0.02
  Add-TextBox $slide 268 258 130 16 'Repositories' 14 $cyan $true | Out-Null
  Add-TextBox $slide 268 278 130 24 'LocalStatsRepository and LocalSettingsRepository' 10 $muted $false | Out-Null
  $box3 = Add-Panel $slide 444 240 170 68 $panel 0.02
  Add-TextBox $slide 464 258 130 16 'Device storage' 14 $cyan $true | Out-Null
  Add-TextBox $slide 464 278 130 24 'SharedPreferences stores settings, sessions, and derived stats' 10 $muted $false | Out-Null
  $arrow1 = Add-TextBox $slide 224 256 24 20 '>' 18 $white $true
  $arrow2 = Add-TextBox $slide 420 256 24 20 '>' 18 $white $true
  $arrow1 | Out-Null
  $arrow2 | Out-Null

  Add-TextBox $slide 52 340 560 128 "CREATE: after every finished run, I save a new GameSession record.\r\nREAD: on app startup, I load saved settings and player stats.\r\nUPDATE: when I change theme, sound, or pace, I save the new settings immediately.\r\nDELETE: full reset/delete of stored history is still one of my remaining features." 14 $white $false | Out-Null
  Add-PhoneImage $slide $statsImage 708 138 180 340 | Out-Null
  Add-Footer $slide 4

  # Slide 5
  $slide = $presentation.Slides.Add(5, 12)
  Set-SlideBackground $slide $bg
  Add-Title $slide 'Key Flutter components and packages' 'These are the main pieces I used to implement the app.'
  $left = Add-Panel $slide 52 144 388 322 $panel 0.04
  $right = Add-Panel $slide 468 144 180 322 $panel 0.04
  Add-TextBox $slide 72 166 348 20 'Core Flutter components I used' 15 $cyan $true | Out-Null
  Add-TextBox $slide 72 200 338 186 "• MaterialApp, Scaffold, SafeArea, Stack, and SingleChildScrollView for the screen structure.\r\n• PageView and PageController for the bottom navigation flow.\r\n• ValueNotifier and ValueListenableBuilder for responsive UI updates.\r\n• Timer, HapticFeedback, and SystemChrome for gameplay timing and mobile behavior." 14 $white $false | Out-Null
  Add-TextBox $slide 72 342 348 20 'Packages and custom modules' 15 $cyan $true | Out-Null
  Add-TextBox $slide 72 376 338 112 "• shared_preferences for local persistence.\r\n• audioplayers / AudioPool for sequence sounds and tap feedback.\r\n• Repository and model classes to separate storage from UI logic." 14 $white $false | Out-Null
  Add-PhoneImage $slide $settingsImage 690 132 180 344 | Out-Null
  Add-Footer $slide 5

  # Slide 6
  $slide = $presentation.Slides.Add(6, 12)
  Set-SlideBackground $slide $bg
  Add-Title $slide 'Most significant technical challenge' 'The hardest part was keeping the gameplay loop synchronized while the difficulty changed from round to round.'
  $challenge = Add-Panel $slide 52 156 856 248 $panel 0.04
  Add-TextBox $slide 84 188 792 180 "I had to coordinate sequence playback, user taps, score progression, overdrive timing, audio feedback, haptics, and game-over transitions without leaving the app in a broken state.\r\n\r\nThe tricky part was that a single mistake or delayed timer could desynchronize the whole round. I solved that by guarding each session, separating persistence into repositories, and recalculating stats from saved sessions instead of mutating everything directly in the UI." 18 $white $false | Out-Null
  Add-TextBox $slide 84 424 792 42 "This made the code more stable and made it easier for me to reason about bugs when the gameplay speed increased." 13 $muted $false | Out-Null
  $challenge | Out-Null
  Add-Footer $slide 6

  # Slide 7
  $slide = $presentation.Slides.Add(7, 12)
  Set-SlideBackground $slide $bg
  Add-Title $slide 'Remaining features and current status' 'I am close to a complete core build, but there are still a few pieces I want to finish.'
  $remainPanel = Add-Panel $slide 52 154 404 276 $panel 0.04
  $donePanel = Add-Panel $slide 500 154 408 276 $panel 0.04
  Add-TextBox $slide 76 178 360 20 'What I still want to complete' 15 $amber $true | Out-Null
  Add-TextBox $slide 76 212 350 170 "• A fuller leaderboard experience with named entries instead of only derived stats.\r\n• Optional cloud/backend expansion if I extend the app beyond local storage.\r\n• A proper delete/reset flow for saved history.\r\n• More testing and a final polish pass on the presentation flow." 14 $white $false | Out-Null
  Add-TextBox $slide 524 178 360 20 'What is already solid' 15 $teal $true | Out-Null
  Add-TextBox $slide 524 212 352 170 "• The two game modes are working.\r\n• The recorded demo proves the build runs correctly.\r\n• Stats and settings persist locally across sessions.\r\n• The UI, audio feedback, and game-over flow are already in place." 14 $white $false | Out-Null
  Add-TextBox $slide 52 454 856 38 "Overall, I can already present Neural Recall as a working Flutter application, and the remaining work is mostly about extending features rather than fixing the foundation." 16 $white $false | Out-Null
  Add-Footer $slide 7

  if (Test-Path $outputPath) {
    Remove-Item -LiteralPath $outputPath -Force
  }
  if (Test-Path $desktopCopyPath) {
    Remove-Item -LiteralPath $desktopCopyPath -Force
  }

  $presentation.SaveAs($outputPath)
  $presentation.SaveAs($desktopCopyPath)
}
finally {
  if ($presentation -ne $null) {
    $presentation.Close()
  }
  if ($powerPoint -ne $null) {
    $powerPoint.Quit()
  }
}
