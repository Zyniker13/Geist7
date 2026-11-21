#!/bin/bash
# S2.5: capture the 60-second slice recording of a full auto-pilot
# match vs Sailor (seed 7) on the game's iPad simulator, then transcode
# it to docs/media/slice.mp4. Runs the whole sequence under one
# sim-lock session: recordVideo and the test service share the device.
set -o pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "$(dirname "$0")/../../06-mattang" || exit 1

SCRATCH=/Users/agent/.hermes/profiles/geist7/cache/scratch
LOG=$SCRATCH/mattang-s25-record.log
RAW=$SCRATCH/mattang-slice-raw.mov
MP4=/Users/agent/.hermes/profiles/geist7/work/Geist7/games/06-mattang/docs/media/slice.mp4
SIM="zGeist7_bot-iPad-Pro-13"
LOCK=~/.hermes/bin/sim-lock
TESTCASE=MattangUITests-iOS/SliceRecordingUITests/testSliceRecordingFlow

echo "=== boot"
$LOCK xcrun simctl bootstatus "$SIM" -b || exit 1

echo "=== build-for-testing"
xcodebuild -project Mattang.xcodeproj -scheme Mattang-iOS \
  -destination "platform=iOS Simulator,name=$SIM" \
  -configuration Debug build-for-testing > "$LOG" 2>&1
if ! grep -q "BUILD SUCCEEDED" "$LOG"; then
  grep -E "error:" "$LOG" | head -20
  exit 1
fi
grep "BUILD SUCCEEDED" "$LOG"

echo "=== locate products"
APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Mattang-*/Build/Products/Debug-iphonesimulator/Mattang-iOS.app 2>/dev/null | head -1)
RUNNER=$(ls -d ~/Library/Developer/Xcode/DerivedData/Mattang-*/Build/Products/Debug-iphonesimulator/MattangUITests-iOS-Runner.app 2>/dev/null | head -1)
echo "APP=$APP"
echo "RUNNER=$RUNNER"
[ -n "$APP" ] && [ -n "$RUNNER" ] || { echo "products missing"; exit 1; }

echo "=== install"
$LOCK xcrun simctl install "$SIM" "$APP" "$RUNNER" || exit 1

echo "=== record (background) + run the flow test"
$LOCK xcrun simctl io "$SIM" recordVideo --codec h264 --force "$RAW" &
RECORDER=$!
sleep 2

xcodebuild -project Mattang.xcodeproj -scheme Mattang-iOS \
  -destination "platform=iOS Simulator,name=$SIM" \
  -configuration Debug \
  -only-testing:$TESTCASE test-without-building > "$LOG" 2>&1
TEST_STATUS=$?
grep -E "Test Case|Executed|TEST (SUCCEEDED|FAILED)" "$LOG" | tail -5
echo "test-status=$TEST_STATUS"

echo "=== stop recorder"
sleep 2
# SIGINT the actual simctl recorder process (the sim-lock wrapper does
# not forward job-control signals to it).
REC_PID=$(pgrep -f "simctl io .* recordVideo" | head -1)
[ -n "$REC_PID" ] && kill -INT "$REC_PID"
wait $RECORDER 2>/dev/null

echo "=== raw file"
ls -la "$RAW" || exit 1

echo "=== transcode (trim to 60 s, AAC audio track for QuickTime/PB compatibility)"
mkdir -p "$(dirname "$MP4")"
rm -f "$MP4"
/Users/agent/.hermes/tools/ffmpeg-9.0.1-darwin-arm64/ffmpeg -y -hide_banner -loglevel error \
  -i "$RAW" -t 60 -r 30 \
  -c:v libx264 -preset fast -crf 23 -pix_fmt yuv420p \
  -c:a aac -b:a 128k \
  "$MP4"
if [ $? -ne 0 ]; then echo "transcode failed"; exit 1; fi

echo "=== verify"
ls -la "$MP4"
F=$(which ffprobe || echo /Users/agent/.hermes/tools/ffmpeg-9.0.1-darwin-arm64/ffprobe)
$F -v error -show_entries format=duration,size -show_entries stream=codec_name,width,height,r_frame_rate -of default=noprint_wrappers=1 "$MP4"
echo "=== done"
