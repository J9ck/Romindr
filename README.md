# Romindr

Romindr is a cute, local-only iOS app that helps you remember all the dates that matter. Track anniversaries, birthdays, Valentine's Day, and other special partner holidays—all offline, all on your device. Never miss a moment!

**✨ Now Production-Ready for App Store Submission!**


---

## Features
- 🎨 Pastel, card-style UI  
- ⏰ Toggleable reminders for any special date
- ➕ Add custom reminders for any occasion
- 🗑️ Swipe to delete reminders you no longer need
- ⏳ Countdown showing days until each event
- 🎊 Confetti animations, soft chimes, and haptic bounce effects  
- 📅 Automatic sorting by upcoming events  
- 🔒 100% offline – all data stays on your phone
- 🛡️ Privacy-first design with no data collection
- 📱 iPhone optimized (iOS 17.0+)


---

## Production Readiness

This app is now ready for App Store submission with:

**Technical Compliance:**
- ✅ Privacy Manifest (PrivacyInfo.xcprivacy) for iOS 17+ compliance
- ✅ Proper notification permission handling with user alerts
- ✅ App Store metadata (display name, category)
- ✅ Comprehensive error handling and logging
- ✅ iOS 17.0+ deployment target for wide compatibility
- ✅ iPhone-only optimization

**Bug Fixes:**
- ✅ Fixed hardcoded dates (now use dynamic year calculation)
- ✅ Fixed force unwrap crashes in date sorting
- ✅ Fixed data mutation preventing user data loss
- ✅ Added validation for date components

**User Experience:**
- ✅ Days-until countdown for each reminder
- ✅ Add custom reminders functionality
- ✅ Swipe-to-delete reminders
- ✅ Visual highlighting of upcoming events (within 7 days)
- ✅ Alert when notification permissions are denied

See [APP_STORE_GUIDE.md](APP_STORE_GUIDE.md) for complete submission instructions.

---

## How to Use
1. Clone or download the repo  
2. Open `Romindr.xcodeproj` in Xcode  
3. Build and run on your iPhone (iOS 17.0 or later)
4. Grant notification permissions when prompted
5. Toggle on the reminders you want to track
6. Tap the + button to add custom reminders
7. Swipe left on any reminder to delete it
8. See countdown showing days until each special date!   

---

## Technical Details

**Requirements:**
- Xcode 15.0 or later
- iOS 17.0 or later
- iPhone only

**Key Technologies:**
- SwiftUI
- UserNotifications framework
- AVFoundation for audio
- Local data persistence with UserDefaults

---

## Goal
Celebrate love, remember every special moment, and never forget an important date again!  

---

## Contributing
Fork, tweak, and share your love for Romindr! Pull requests welcome, but **please no selling the code**.  

---

## License
© 2025 Jack Doyle. All rights reserved.  
You may view and modify this code for personal use only. Commercial use is prohibited.
