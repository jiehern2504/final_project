# Upload dual-angle tutorial videos to Firebase Storage.
#
# Recommended encoding (faster in-app load / initialize):
#   - Resolution: 720p max
#   - Target size: under 5 MB per mp4
#   - H.264 + AAC, reasonable CRF (e.g. ffmpeg -crf 23)
#
# Prerequisites:
#   - Firebase CLI: npm install -g firebase-tools && firebase login
#   - firebase use <your-project-id>
#   - Local folder layout matching Storage paths (see below)
#
# Expected local layout (42 files):
#   tutorial_videos/
#     arms/bench_dips_chair/front.mp4
#     arms/bench_dips_chair/side.mp4
#     ... (one folder per exercise_id under each muscle)
#
# Usage:
#   .\tools\upload_tutorial_videos.ps1 -SourceDir "C:\path\to\tutorial_videos"
#
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir
)

$ErrorActionPreference = 'Stop'

$paths = @(
    'tutorial_videos/arms/bench_dips_chair/front.mp4',
    'tutorial_videos/arms/bench_dips_chair/side.mp4',
    'tutorial_videos/arms/diamond_knee_push_ups/front.mp4',
    'tutorial_videos/arms/diamond_knee_push_ups/side.mp4',
    'tutorial_videos/arms/triceps_extensions/front.mp4',
    'tutorial_videos/arms/triceps_extensions/side.mp4',
    'tutorial_videos/chest/push_ups/front.mp4',
    'tutorial_videos/chest/push_ups/side.mp4',
    'tutorial_videos/chest/incline_push_ups/front.mp4',
    'tutorial_videos/chest/incline_push_ups/side.mp4',
    'tutorial_videos/chest/decline_push_ups/front.mp4',
    'tutorial_videos/chest/decline_push_ups/side.mp4',
    'tutorial_videos/abs/crunches/front.mp4',
    'tutorial_videos/abs/crunches/side.mp4',
    'tutorial_videos/abs/laying_leg_raises/front.mp4',
    'tutorial_videos/abs/laying_leg_raises/side.mp4',
    'tutorial_videos/abs/hand_plank/front.mp4',
    'tutorial_videos/abs/hand_plank/side.mp4',
    'tutorial_videos/legs/bodyweight_squats/front.mp4',
    'tutorial_videos/legs/bodyweight_squats/side.mp4',
    'tutorial_videos/legs/forward_lunges/front.mp4',
    'tutorial_videos/legs/forward_lunges/side.mp4',
    'tutorial_videos/legs/bulgarian_split_squats/front.mp4',
    'tutorial_videos/legs/bulgarian_split_squats/side.mp4',
    'tutorial_videos/shoulders/pike_push_ups/front.mp4',
    'tutorial_videos/shoulders/pike_push_ups/side.mp4',
    'tutorial_videos/shoulders/forward_arm_circles/front.mp4',
    'tutorial_videos/shoulders/forward_arm_circles/side.mp4',
    'tutorial_videos/shoulders/backward_arm_circle/front.mp4',
    'tutorial_videos/shoulders/backward_arm_circle/side.mp4',
    'tutorial_videos/back/plate_superman_hold/front.mp4',
    'tutorial_videos/back/plate_superman_hold/side.mp4',
    'tutorial_videos/back/superman/front.mp4',
    'tutorial_videos/back/superman/side.mp4',
    'tutorial_videos/back/superman_pull/front.mp4',
    'tutorial_videos/back/superman_pull/side.mp4',
    'tutorial_videos/glutes/glute_bridges/front.mp4',
    'tutorial_videos/glutes/glute_bridges/side.mp4',
    'tutorial_videos/glutes/good_mornings/front.mp4',
    'tutorial_videos/glutes/good_mornings/side.mp4',
    'tutorial_videos/glutes/hip_abduction/front.mp4',
    'tutorial_videos/glutes/hip_abduction/side.mp4'
)

$uploaded = 0
$missing = @()

foreach ($storagePath in $paths) {
  $localPath = Join-Path $SourceDir ($storagePath -replace '^tutorial_videos/', '')
  if (-not (Test-Path $localPath)) {
    $missing += $storagePath
    continue
  }
  Write-Host "Uploading $storagePath ..."
  firebase storage:upload $localPath $storagePath --content-type video/mp4
  $uploaded++
}

Write-Host ""
Write-Host "Uploaded: $uploaded / $($paths.Count)"
if ($missing.Count -gt 0) {
  Write-Host "Missing local files ($($missing.Count)):"
  $missing | ForEach-Object { Write-Host "  $_" }
  exit 1
}
