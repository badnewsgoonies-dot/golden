#!/bin/bash
# Web App Deployment Script for Golden Battle Tower

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Golden Battle Tower - Web App Deployment${NC}"
echo "========================================"

# Configuration
EXPORT_PATH="exports/html5"
APP_PATH="app"

# Build the web export
build_web_export() {
    echo -e "\n${BLUE}Building web export...${NC}"
    
    mkdir -p "$EXPORT_PATH"
    
    # Export with custom HTML shell
    godot --headless --export-release "HTML5" "$EXPORT_PATH/index.html"
    
    if [ -f "$EXPORT_PATH/index.html" ]; then
        echo -e "${GREEN}Web export successful!${NC}"
    else
        echo -e "${RED}Error: Web export failed${NC}"
        exit 1
    fi
}

# Copy PWA assets
setup_pwa() {
    echo -e "\n${BLUE}Setting up PWA assets...${NC}"
    
    # Copy custom HTML if it exists
    if [ -f "$APP_PATH/index.html" ]; then
        cp "$APP_PATH/index.html" "$EXPORT_PATH/"
        echo "- Custom HTML copied"
    fi
    
    # Copy manifest
    if [ -f "$APP_PATH/manifest.json" ]; then
        cp "$APP_PATH/manifest.json" "$EXPORT_PATH/"
        echo "- Manifest copied"
    fi
    
    # Copy service worker
    if [ -f "$APP_PATH/service-worker.js" ]; then
        cp "$APP_PATH/service-worker.js" "$EXPORT_PATH/"
        echo "- Service worker copied"
    fi
    
    # Copy icons
    if [ -d "$APP_PATH/icons" ]; then
        cp -r "$APP_PATH/icons" "$EXPORT_PATH/"
        echo "- Icons copied"
    fi
    
    # Copy splash screens
    if [ -d "$APP_PATH/splash" ]; then
        cp -r "$APP_PATH/splash" "$EXPORT_PATH/"
        echo "- Splash screens copied"
    fi
    
    echo -e "${GREEN}PWA setup complete!${NC}"
}

# Generate icons if needed
generate_icons() {
    if [ ! -d "$APP_PATH/icons" ] || [ -z "$(ls -A $APP_PATH/icons)" ]; then
        echo -e "\n${BLUE}Generating app icons...${NC}"
        
        if command -v python3 &> /dev/null && python3 -c "import PIL" 2>/dev/null; then
            cd "$APP_PATH"
            python3 generate_icons.py
            cd ..
            echo -e "${GREEN}Icons generated!${NC}"
        else
            echo -e "${YELLOW}Warning: Python PIL not installed. Skipping icon generation.${NC}"
            echo "Install with: pip3 install Pillow"
        fi
    fi
}

# Create deployment package
create_package() {
    echo -e "\n${BLUE}Creating deployment package...${NC}"
    
    # Create zip file
    cd "$EXPORT_PATH"
    zip -r ../GoldenBattleTower_WebApp.zip . -x "*.DS_Store"
    cd ../..
    
    echo -e "${GREEN}Deployment package created: exports/GoldenBattleTower_WebApp.zip${NC}"
}

# Deploy to various platforms
deploy_menu() {
    echo -e "\n${BLUE}Deployment Options:${NC}"
    echo "1) Local testing server"
    echo "2) Deploy to Netlify"
    echo "3) Deploy to Vercel"
    echo "4) Deploy to GitHub Pages"
    echo "5) Deploy to itch.io"
    echo "6) Generate deployment instructions"
    echo "7) Back to main menu"
    
    read -p "Select option (1-7): " choice
    
    case $choice in
        1)
            start_local_server
            ;;
        2)
            deploy_netlify
            ;;
        3)
            deploy_vercel
            ;;
        4)
            deploy_github_pages
            ;;
        5)
            deploy_itchio
            ;;
        6)
            generate_instructions
            ;;
        7)
            return
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            deploy_menu
            ;;
    esac
}

# Start local server
start_local_server() {
    echo -e "\n${BLUE}Starting local server...${NC}"
    
    cd "$EXPORT_PATH"
    
    # Get IP address
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        IP=$(hostname -I | awk '{print $1}')
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        IP=$(ipconfig getifaddr en0 || ipconfig getifaddr en1)
    else
        IP="localhost"
    fi
    
    echo -e "${GREEN}Server starting...${NC}"
    echo -e "Local: ${BLUE}http://localhost:8000${NC}"
    echo -e "Network: ${BLUE}http://$IP:8000${NC}"
    echo -e "\nPress Ctrl+C to stop"
    
    python3 -m http.server 8000
}

# Deploy to Netlify
deploy_netlify() {
    echo -e "\n${BLUE}Deploying to Netlify...${NC}"
    
    if command -v netlify &> /dev/null; then
        cd "$EXPORT_PATH"
        netlify deploy --prod --dir=.
    else
        echo -e "${YELLOW}Netlify CLI not installed.${NC}"
        echo "Install with: npm install -g netlify-cli"
        echo -e "\nManual deployment:"
        echo "1. Go to https://app.netlify.com/drop"
        echo "2. Drag and drop the '$EXPORT_PATH' folder"
    fi
}

# Deploy to Vercel
deploy_vercel() {
    echo -e "\n${BLUE}Deploying to Vercel...${NC}"
    
    if command -v vercel &> /dev/null; then
        cd "$EXPORT_PATH"
        vercel --prod
    else
        echo -e "${YELLOW}Vercel CLI not installed.${NC}"
        echo "Install with: npm install -g vercel"
    fi
}

# Deploy to GitHub Pages
deploy_github_pages() {
    echo -e "\n${BLUE}Setting up GitHub Pages deployment...${NC}"
    
    # Create gh-pages branch setup script
    cat > setup_github_pages.sh << 'EOF'
#!/bin/bash
# This script sets up GitHub Pages deployment

# Ensure we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not a git repository"
    exit 1
fi

# Create gh-pages branch
git checkout --orphan gh-pages
git rm -rf .
cp -r exports/html5/* .
echo "goldenbattletower.com" > CNAME  # Optional: add your custom domain
git add .
git commit -m "Deploy Golden Battle Tower to GitHub Pages"
git push origin gh-pages
git checkout main

echo "Deployed to GitHub Pages!"
echo "Your app will be available at: https://[YOUR-USERNAME].github.io/[REPO-NAME]"
EOF
    
    chmod +x setup_github_pages.sh
    echo -e "${GREEN}GitHub Pages setup script created: setup_github_pages.sh${NC}"
    echo "Run this script to deploy to GitHub Pages"
}

# Deploy to itch.io
deploy_itchio() {
    echo -e "\n${BLUE}Deploying to itch.io...${NC}"
    
    if command -v butler &> /dev/null; then
        read -p "Enter your itch.io username: " ITCH_USER
        read -p "Enter your game name on itch.io: " ITCH_GAME
        
        butler push "$EXPORT_PATH" "$ITCH_USER/$ITCH_GAME:html5"
    else
        echo -e "${YELLOW}Butler (itch.io CLI) not installed.${NC}"
        echo "Download from: https://itch.io/docs/butler/"
        echo -e "\nManual upload:"
        echo "1. Create a zip of '$EXPORT_PATH' contents"
        echo "2. Upload to your itch.io game page"
        echo "3. Set 'This file will be played in the browser'"
    fi
}

# Generate deployment instructions
generate_instructions() {
    cat > DEPLOYMENT_GUIDE.md << 'EOF'
# Web App Deployment Guide

## Quick Deploy Options

### 1. Netlify (Recommended for Quick Deploy)
- Go to https://app.netlify.com/drop
- Drag and drop the `exports/html5` folder
- Your app will be live in seconds!

### 2. Vercel
```bash
npm install -g vercel
cd exports/html5
vercel --prod
```

### 3. GitHub Pages
```bash
# Run the generated setup_github_pages.sh script
./setup_github_pages.sh
```

### 4. Your Own Server
Upload the contents of `exports/html5` to your web server's public directory.

### 5. itch.io
- Create a game on itch.io
- Zip the contents of `exports/html5`
- Upload as HTML5 game

## PWA Installation

Once deployed, users can install the app:

### On Android:
1. Open Chrome/Edge
2. Navigate to your app
3. Tap "Add to Home screen" in menu

### On iOS:
1. Open Safari
2. Navigate to your app
3. Tap Share → Add to Home Screen

### On Desktop:
1. Open Chrome/Edge
2. Navigate to your app
3. Click install icon in address bar

## Custom Domain Setup

### Netlify:
1. Go to Site settings → Domain management
2. Add custom domain

### Vercel:
1. Go to Project settings → Domains
2. Add custom domain

## Performance Tips

1. Enable GZIP compression on your server
2. Use a CDN for global distribution
3. Enable browser caching headers
4. Consider using Cloudflare for free CDN

## Analytics

Add analytics to track usage:
```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"></script>
```

EOF
    
    echo -e "${GREEN}Deployment guide created: DEPLOYMENT_GUIDE.md${NC}"
}

# Main menu
main_menu() {
    echo -e "\n${BLUE}What would you like to do?${NC}"
    echo "1) Full build and deploy"
    echo "2) Build web export only"
    echo "3) Generate app icons"
    echo "4) Deploy existing build"
    echo "5) Create deployment package (zip)"
    echo "6) Exit"
    
    read -p "Select option (1-6): " choice
    
    case $choice in
        1)
            generate_icons
            build_web_export
            setup_pwa
            deploy_menu
            ;;
        2)
            build_web_export
            setup_pwa
            ;;
        3)
            generate_icons
            ;;
        4)
            if [ -d "$EXPORT_PATH" ]; then
                deploy_menu
            else
                echo -e "${RED}No build found. Please build first.${NC}"
            fi
            ;;
        5)
            if [ -d "$EXPORT_PATH" ]; then
                create_package
            else
                echo -e "${RED}No build found. Please build first.${NC}"
            fi
            ;;
        6)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            main_menu
            ;;
    esac
}

# Run the script
main_menu

echo -e "\n${GREEN}Done!${NC}"