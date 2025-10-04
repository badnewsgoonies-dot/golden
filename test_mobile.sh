#!/bin/bash
# Quick mobile test script for Golden Battle Tower

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Golden Battle Tower - Mobile Preview Setup${NC}"
echo "=========================================="

# Create export directory if it doesn't exist
mkdir -p exports/html5

# Check if Godot is in PATH
if ! command -v godot &> /dev/null; then
    echo "Error: Godot not found in PATH"
    echo "Please ensure Godot is installed and in your PATH"
    exit 1
fi

# Export HTML5
echo -e "\n${GREEN}Exporting project to HTML5...${NC}"
godot --headless --export-release "HTML5" exports/html5/index.html

# Check if export was successful
if [ ! -f "exports/html5/index.html" ]; then
    echo "Error: Export failed. Please check your Godot configuration."
    exit 1
fi

# Get local IP address
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    IP=$(hostname -I | awk '{print $1}')
elif [[ "$OSTYPE" == "darwin"* ]]; then
    IP=$(ipconfig getifaddr en0 || ipconfig getifaddr en1)
else
    IP="localhost"
fi

# Start server
echo -e "\n${GREEN}Starting web server...${NC}"
cd exports/html5

# Try Python 3 first, then Python 2, then Node.js
if command -v python3 &> /dev/null; then
    echo "Using Python 3 server..."
    python3 -m http.server 8000 &
elif command -v python &> /dev/null; then
    echo "Using Python 2 server..."
    python -m SimpleHTTPServer 8000 &
elif command -v npx &> /dev/null; then
    echo "Using Node.js server..."
    npx http-server -p 8000 &
else
    echo "Error: No suitable web server found (Python or Node.js required)"
    exit 1
fi

SERVER_PID=$!

# Display access information
echo -e "\n${GREEN}Server started successfully!${NC}"
echo "=============================="
echo -e "Local access: ${BLUE}http://localhost:8000${NC}"
echo -e "Mobile access: ${BLUE}http://$IP:8000${NC}"
echo ""
echo "To test on mobile:"
echo "1. Ensure your mobile device is on the same network"
echo "2. Open your mobile browser"
echo "3. Navigate to the mobile access URL above"
echo ""
echo "Press Ctrl+C to stop the server"

# Wait for interrupt and cleanup
trap "echo -e '\n${GREEN}Stopping server...${NC}'; kill $SERVER_PID 2>/dev/null" INT
wait $SERVER_PID