$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$assetsDir = Join-Path $repoRoot 'presentation_assets'
$outputPath = Join-Path $assetsDir 'simon_says_presentation.pptx'

if (-not (Test-Path $assetsDir)) {
  throw "Missing assets directory: $assetsDir"
}

$images = @(
  @{ Title = 'Main Menu'; Path = Join-Path $assetsDir '01_main_menu.png' },
  @{ Title = 'Stats Screen'; Path = Join-Path $assetsDir '02_stats.png' },
  @{ Title = 'Settings Screen'; Path = Join-Path $assetsDir '03_settings.png' },
  @{ Title = 'Focus Mode'; Path = Join-Path $assetsDir '04_focus_mode.png' },
  @{ Title = 'Overdrive Mode'; Path = Join-Path $assetsDir '05_overdrive_mode.png' }
)

foreach ($image in $images) {
  if (-not (Test-Path $image.Path)) {
    throw "Missing screenshot: $($image.Path)"
  }
}

$powerPoint = $null
$presentation = $null

try {
  $powerPoint = New-Object -ComObject PowerPoint.Application
  $powerPoint.Visible = -1
  $presentation = $powerPoint.Presentations.Add()

  $presentation.PageSetup.SlideWidth = 540
  $presentation.PageSetup.SlideHeight = 960

  $titleSlide = $presentation.Slides.Add(1, 12)
  $titleShape = $titleSlide.Shapes.AddTextbox(1, 36, 72, 468, 120)
  $titleShape.TextFrame.TextRange.Text = 'Simon Says App Screens'
  $titleShape.TextFrame.TextRange.Font.Size = 28
  $titleShape.TextFrame.TextRange.Font.Bold = -1
  $titleShape.TextFrame.TextRange.Font.Color.RGB = 0xF0F0F0

  $subtitleShape = $titleSlide.Shapes.AddTextbox(1, 36, 180, 468, 120)
  $subtitleShape.TextFrame.TextRange.Text = 'Generated slides for the demo presentation'
  $subtitleShape.TextFrame.TextRange.Font.Size = 16
  $subtitleShape.TextFrame.TextRange.Font.Color.RGB = 0xC8C8C8

  $slideNumber = 2
  foreach ($image in $images) {
    $slide = $presentation.Slides.Add($slideNumber, 12)

    $heading = $slide.Shapes.AddTextbox(1, 24, 18, 492, 36)
    $heading.TextFrame.TextRange.Text = $image.Title
    $heading.TextFrame.TextRange.Font.Size = 20
    $heading.TextFrame.TextRange.Font.Bold = -1
    $heading.TextFrame.TextRange.Font.Color.RGB = 0xF0F0F0

    $picture = $slide.Shapes.AddPicture($image.Path, 0, -1, 24, 72, -1, -1)
    $maxWidth = 492
    $maxHeight = 840
    $scale = [Math]::Min($maxWidth / $picture.Width, $maxHeight / $picture.Height)
    $picture.Width = $picture.Width * $scale
    $picture.Height = $picture.Height * $scale
    $picture.Left = (540 - $picture.Width) / 2
    $picture.Top = 84 + (($maxHeight - $picture.Height) / 2)

    $slideNumber++
  }

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
