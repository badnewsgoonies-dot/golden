# 📱 Mobile App Conversion Guide

## Overview

Golden Battle Tower can be deployed as:
1. **Progressive Web App (PWA)** - Works on all platforms through browsers
2. **Android App (APK/AAB)** - Native Android experience
3. **iOS App** - Through PWA or native (requires Mac)

## 🌐 Quick Start: Web App (PWA)

The easiest way to get your game on mobile devices:

```bash
# Build and deploy as web app
./deploy_web_app.sh

# Choose option 1 for full build and deploy
```

### Benefits:
- ✅ Works on all devices (iOS, Android, Desktop)
- ✅ No app store approval needed
- ✅ Instant updates
- ✅ Can be installed like a native app
- ✅ Offline support

## 🤖 Android App

Convert to a native Android app:

```bash
# Build Android APK
./build_android_app.sh

# Choose option 2 to build and install on device
```

### Requirements:
- Android SDK installed
- Java JDK 11+
- Godot Android export templates

### Publishing to Google Play:
1. Build AAB (Android App Bundle) using option 3
2. Create Google Play Developer account ($25 one-time)
3. Upload AAB to Play Console
4. Fill in store listing details

## 🍎 iOS App Options

### Option 1: PWA on iOS
- Users add to home screen from Safari
- Works without App Store
- Some limitations (no push notifications)

### Option 2: Native iOS (Requires Mac)
1. Export Godot project for iOS
2. Open in Xcode
3. Configure signing
4. Build and submit to App Store

## 🚀 Deployment Scripts

### Web App Deployment
```bash
./deploy_web_app.sh
```
Features:
- Automatic PWA setup
- Icon generation
- Multiple deployment options (Netlify, Vercel, etc.)
- Local testing server

### Android Build
```bash
./build_android_app.sh
```
Features:
- Automatic keystore creation
- APK and AAB generation
- Direct device installation
- Play Store ready builds

## 📦 File Structure

```
/workspace/
├── app/                    # PWA assets
│   ├── manifest.json      # PWA configuration
│   ├── service-worker.js  # Offline support
│   ├── index.html        # Custom HTML shell
│   ├── icons/            # App icons
│   └── splash/           # Splash screens
├── exports/
│   ├── html5/            # Web build output
│   └── android/          # Android build output
├── deploy_web_app.sh     # Web deployment script
└── build_android_app.sh  # Android build script
```

## 🎨 Customization

### App Icons
Replace generated icons in `app/icons/` with your custom artwork:
- Required sizes: 192x192, 512x512 (minimum)
- Format: PNG with transparency
- Use `app/generate_icons.py` to generate all sizes

### App Name & Details
Edit `app/manifest.json`:
```json
{
  "name": "Your Game Name",
  "short_name": "YGN",
  "theme_color": "#yourcolor",
  "background_color": "#yourcolor"
}
```

### Android Package
Edit in `build_android_app.sh`:
```bash
PACKAGE_NAME="com.yourcompany.yourgame"
APP_NAME="Your Game Name"
```

## 📱 Testing on Mobile

### Local Network Testing
1. Run `./test_mobile.sh`
2. Open provided URL on mobile device
3. Both devices must be on same network

### Public Testing
Deploy to Netlify for quick public URL:
```bash
./deploy_web_app.sh
# Choose Netlify option
```

## ✅ Best Practices

### Performance
- Optimize textures for mobile
- Test on low-end devices
- Monitor load times
- Use PWA caching effectively

### User Experience
- Implement touch controls
- Handle different screen sizes
- Test landscape/portrait modes
- Add loading indicators

### Distribution
- **PWA**: Best for quick distribution
- **Play Store**: Best for discoverability
- **Direct APK**: Best for testing

## 🔧 Troubleshooting

### PWA Not Installing
- Ensure HTTPS (required for PWA)
- Check manifest.json validity
- Clear browser cache

### Android Build Fails
- Check Android SDK path
- Verify export templates installed
- Check keystore configuration

### Performance Issues
- Reduce texture sizes
- Disable unnecessary effects
- Profile on actual devices

## 📊 Analytics & Monitoring

Add to your PWA for insights:
```javascript
// In index.html
gtag('event', 'level_complete', {
  'level': currentLevel,
  'score': playerScore
});
```

## 🎮 Game-Specific Features

### Save Data
- PWA: Uses localStorage
- Android: Internal app storage
- Sync saves across devices (optional)

### In-App Purchases
- PWA: Web payment APIs
- Android: Google Play Billing
- iOS: Apple IAP (native only)

## 🚀 Next Steps

1. **Test locally**: Run `./test_mobile.sh`
2. **Deploy as PWA**: Run `./deploy_web_app.sh`
3. **Build Android**: Run `./build_android_app.sh`
4. **Gather feedback**: Test with real users
5. **Iterate**: Update based on feedback

## 📞 Support

- Godot Discord: https://discord.gg/godot
- PWA Documentation: https://web.dev/progressive-web-apps/
- Android Development: https://developer.android.com/games