#!/bin/bash
# Android App Build Script for Golden Battle Tower

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Golden Battle Tower - Android App Builder${NC}"
echo "========================================"

# Configuration
PACKAGE_NAME="com.goldenbattletower.game"
APP_NAME="Golden Battle Tower"
VERSION_CODE=1
VERSION_NAME="1.0.0"
KEYSTORE_PATH="android/keystore.jks"
KEYSTORE_ALIAS="goldenbattletower"

# Check prerequisites
check_requirements() {
    echo -e "\n${BLUE}Checking requirements...${NC}"
    
    # Check for Godot
    if ! command -v godot &> /dev/null; then
        echo -e "${RED}Error: Godot not found in PATH${NC}"
        exit 1
    fi
    
    # Check for Java
    if ! command -v java &> /dev/null; then
        echo -e "${RED}Error: Java not found. Please install JDK 11 or higher${NC}"
        exit 1
    fi
    
    # Check for Android SDK
    if [ -z "$ANDROID_SDK_ROOT" ] && [ -z "$ANDROID_HOME" ]; then
        echo -e "${RED}Error: Android SDK not found. Please set ANDROID_SDK_ROOT or ANDROID_HOME${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All requirements met!${NC}"
}

# Create keystore if it doesn't exist
create_keystore() {
    if [ ! -f "$KEYSTORE_PATH" ]; then
        echo -e "\n${BLUE}Creating keystore...${NC}"
        mkdir -p android
        
        keytool -genkey -v -keystore "$KEYSTORE_PATH" \
            -alias "$KEYSTORE_ALIAS" \
            -keyalg RSA -keysize 2048 -validity 10000 \
            -dname "CN=Golden Battle Tower, OU=Games, O=Your Company, L=City, S=State, C=US" \
            -storepass "android" -keypass "android"
        
        echo -e "${GREEN}Keystore created!${NC}"
    fi
}

# Update export presets
update_export_presets() {
    echo -e "\n${BLUE}Updating export configuration...${NC}"
    
    # Create a temporary Python script to update the config
    cat > update_android_config.py << 'EOF'
import re

# Read the export presets
with open('export_presets.cfg', 'r') as f:
    content = f.read()

# Update Android configuration
updates = {
    'package/unique_name=': f'package/unique_name="{PACKAGE_NAME}"',
    'package/name=': f'package/name="{APP_NAME}"',
    'version/code=': f'version/code={VERSION_CODE}',
    'version/name=': f'version/name="{VERSION_NAME}"',
    'keystore/release=': f'keystore/release="{KEYSTORE_PATH}"',
    'keystore/release_user=': f'keystore/release_user="{KEYSTORE_ALIAS}"',
    'keystore/release_password=': 'keystore/release_password="android"'
}

for key, value in updates.items():
    pattern = f'^{re.escape(key)}.*$'
    content = re.sub(pattern, value, content, flags=re.MULTILINE)

# Write back
with open('export_presets.cfg', 'w') as f:
    f.write(content)

print("Export configuration updated!")
EOF

    python3 update_android_config.py
    rm update_android_config.py
}

# Build the APK
build_apk() {
    echo -e "\n${BLUE}Building Android APK...${NC}"
    
    mkdir -p exports/android
    
    # Export with Godot
    godot --headless --export-release "Android" "exports/android/GoldenBattleTower.apk"
    
    if [ -f "exports/android/GoldenBattleTower.apk" ]; then
        echo -e "${GREEN}APK built successfully!${NC}"
        echo -e "Location: ${BLUE}exports/android/GoldenBattleTower.apk${NC}"
        
        # Show APK info
        echo -e "\n${BLUE}APK Information:${NC}"
        ls -lh exports/android/GoldenBattleTower.apk
    else
        echo -e "${RED}Error: APK build failed${NC}"
        exit 1
    fi
}

# Build AAB (Android App Bundle) for Google Play
build_aab() {
    echo -e "\n${BLUE}Building Android App Bundle (AAB)...${NC}"
    
    # Modify export to create AAB
    sed -i 's/export_path=".*"/export_path="exports\/android\/GoldenBattleTower.aab"/' export_presets.cfg
    
    godot --headless --export-release "Android" "exports/android/GoldenBattleTower.aab"
    
    if [ -f "exports/android/GoldenBattleTower.aab" ]; then
        echo -e "${GREEN}AAB built successfully!${NC}"
        echo -e "Location: ${BLUE}exports/android/GoldenBattleTower.aab${NC}"
    fi
    
    # Restore APK export path
    sed -i 's/export_path=".*"/export_path="exports\/android\/GoldenBattleTower.apk"/' export_presets.cfg
}

# Install on connected device
install_on_device() {
    if command -v adb &> /dev/null; then
        echo -e "\n${BLUE}Checking for connected devices...${NC}"
        
        if adb devices | grep -q "device$"; then
            echo -e "${BLUE}Installing on device...${NC}"
            adb install -r exports/android/GoldenBattleTower.apk
            
            echo -e "${GREEN}App installed!${NC}"
            echo -e "${BLUE}Launching app...${NC}"
            adb shell am start -n "$PACKAGE_NAME/com.godot.game.GodotApp"
        else
            echo -e "${RED}No devices connected${NC}"
        fi
    fi
}

# Main menu
show_menu() {
    echo -e "\n${BLUE}What would you like to do?${NC}"
    echo "1) Build APK only"
    echo "2) Build APK and install on device"
    echo "3) Build both APK and AAB (for Google Play)"
    echo "4) Setup only (create keystore and update config)"
    echo "5) Exit"
    
    read -p "Select option (1-5): " choice
    
    case $choice in
        1)
            check_requirements
            create_keystore
            update_export_presets
            build_apk
            ;;
        2)
            check_requirements
            create_keystore
            update_export_presets
            build_apk
            install_on_device
            ;;
        3)
            check_requirements
            create_keystore
            update_export_presets
            build_apk
            build_aab
            ;;
        4)
            check_requirements
            create_keystore
            update_export_presets
            echo -e "${GREEN}Setup complete!${NC}"
            ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            show_menu
            ;;
    esac
}

# Run the script
show_menu

echo -e "\n${GREEN}Done!${NC}"