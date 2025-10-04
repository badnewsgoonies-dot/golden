# Mobile Preview Guide for Golden Battle Tower

This guide explains how to preview your Godot game on mobile devices.

## Option 1: HTML5 Export (Easiest)

### Steps:
1. **Export the game:**
   - Open your project in Godot
   - Go to Project → Export
   - Select "HTML5" preset (already configured in export_presets.cfg)
   - Click "Export Project"
   - Choose the export path: `exports/html5/`
   - Uncheck "Export With Debug" for better performance

2. **Host locally:**
   ```bash
   # Navigate to the export directory
   cd exports/html5/
   
   # Start a local web server (Python 3)
   python3 -m http.server 8000
   
   # Or with Node.js
   npx http-server -p 8000
   ```

3. **Access on mobile:**
   - Find your computer's IP address: `ip addr` or `ifconfig`
   - On your mobile device, open browser
   - Navigate to: `http://YOUR_IP:8000`
   - The game should load in your mobile browser

### Tips for HTML5:
- Enable PWA in export settings for app-like experience
- Test in both portrait and landscape modes
- Chrome/Firefox work best on mobile

## Option 2: Android APK Export

### Prerequisites:
1. **Install Android Export Templates:**
   - In Godot: Editor → Manage Export Templates
   - Download Android templates for Godot 4.5

2. **Install Android SDK:**
   - Download Android Studio or Command Line Tools
   - Set up ANDROID_SDK_ROOT environment variable

3. **Configure keystore (for signed APK):**
   ```bash
   keytool -genkey -v -keystore debug.keystore -alias androiddebugkey \
     -keyalg RSA -keysize 2048 -validity 10000
   ```

### Export Steps:
1. **Configure export:**
   - Open Project → Export
   - Select "Android" preset
   - Configure package name: `com.yourdomain.goldenbattletower`
   - Set up keystore path and passwords

2. **Export APK:**
   - Click "Export Project"
   - Choose path: `exports/android/golden_battle_tower.apk`
   - Select "Export"

3. **Install on device:**
   ```bash
   # Using ADB
   adb install exports/android/golden_battle_tower.apk
   
   # Or transfer APK to device and install manually
   ```

## Option 3: Remote Debugging

### Setup:
1. **Enable remote debugging in Godot:**
   - Project → Project Settings
   - Network → Debug → Remote Host
   - Set to your computer's IP

2. **Run on mobile:**
   - Deploy to device with one-click deploy
   - Or use remote debug feature

## Option 4: Testing Services

### Using Godot's built-in server:
1. In Godot editor: Editor → Editor Settings
2. Network → Debug → Remote Port: 6007
3. Run the project
4. Access: `http://YOUR_IP:6007` on mobile

### Using ngrok for public URL:
```bash
# Install ngrok
# Run your HTML5 export locally
python3 -m http.server 8000

# In another terminal
ngrok http 8000

# Share the ngrok URL with mobile devices
```

## Responsive Design Tips

1. **Handle different screen sizes:**
   - Use stretch modes in Project Settings
   - Test with different aspect ratios

2. **Touch controls:**
   - Implement touch input for mobile
   - Add on-screen buttons if needed

3. **Performance:**
   - Reduce texture sizes for mobile
   - Optimize particle effects
   - Test on lower-end devices

## Quick Test Script

Create `test_mobile.sh`:
```bash
#!/bin/bash
# Quick mobile test script

# Export HTML5
echo "Exporting HTML5..."
godot --export "HTML5" exports/html5/index.html

# Start server
echo "Starting server..."
cd exports/html5
python3 -m http.server 8000 &
SERVER_PID=$!

# Get IP
IP=$(hostname -I | awk '{print $1}')
echo "Game available at: http://$IP:8000"
echo "Press Ctrl+C to stop server"

# Wait for interrupt
trap "kill $SERVER_PID" INT
wait
```

Make it executable: `chmod +x test_mobile.sh`

## Troubleshooting

- **Black screen:** Check browser console for errors
- **Performance issues:** Reduce graphics quality, disable shadows
- **Touch not working:** Ensure input events are properly configured
- **Audio issues:** Some mobile browsers require user interaction to play audio

## Next Steps

1. Set up continuous deployment for easier testing
2. Implement mobile-specific UI adjustments
3. Add analytics to track mobile performance
4. Consider platform-specific features