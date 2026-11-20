# Focus Check-in

A simple iPhone app to plan focus sessions around how you feel today.

## What it does

- **Check in:** press and hold the ring on the Home screen for one second. Turn it to choose your energy: Low, Steady or Charged. Release to set it.
- **Pick the time:** keep turning. One full turn is 60 minutes, up to 3 turns (15 to 180 minutes). Release to start the session.
- **Focus:** an orange countdown runs. You can pause it, or end early with the X (the app asks you to confirm).
- **Break:** when a session ends, the app suggests a break of a quarter of your focus time, between 3 and 15 minutes. Turn the ring to change it.
- **Check out:** answer a few quick questions: was the length right, and how did it go? If you stopped early, tell us why.
- **Insights:** charts of your daily focus minutes, and of planned versus completed minutes by week. Open them with the chart button at the top right.
- **Light and dark mode:** the app follows the iPhone setting.

## Privacy

Everything stays on your iPhone. There is no account, no sync and no cloud.

## Not in this version

- Sleep from Apple Health is in the code, but it is off by default and the app has no switch for it yet.
- There is no Apple Watch app yet.
- The app does not read Screen Time or block other apps.

## Requirements

- Xcode with the iOS 26 SDK
- An iPhone or simulator running iOS 26 or later

## Run it

1. Open `FocusCheckIn/FocusCheckIn.xcodeproj` in Xcode.
2. Select the **FocusCheckIn** scheme and an iPhone simulator, then press **Run**.
3. To run on your own iPhone, choose your own team in **Signing & Capabilities**.

To run the tests, use **Product → Test** in Xcode.
