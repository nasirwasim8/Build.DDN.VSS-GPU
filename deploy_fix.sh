#!/bin/bash
# ============================================================
#  DDN Semantic Search — Deploy Frontend Fix
#
#  ROOT CAUSE FIXED:
#    The production frontend was served by `serve` (a static file
#    server) on port 5175.  Static servers have NO proxy, so all
#    browser requests to /api/... were returning 404.
#
#    Fix: api.ts now reads VITE_API_URL at build time and uses it
#    as the absolute base URL to reach the FastAPI backend on port
#    8001 directly, bypassing the need for any proxy.
#
#  Usage (run from your Windows machine / WSL):
#    chmod +x deploy_fix.sh
#    ./deploy_fix.sh
#  You will be prompted for the SSH password once per connection.
# ============================================================

set -euo pipefail

SERVER="nwasim@172.20.146.6"
REMOTE_DIR="$HOME/projects/Build.DDN.Semantic_Search"
BACKEND_PORT=8001
FRONTEND_PORT=5175

echo "🚀 Deploying DDN Semantic Search frontend fix..."
echo "   Server : $SERVER"
echo "   Fix    : VITE_API_URL → http://localhost:${BACKEND_PORT}"
echo ""

ssh "$SERVER" bash -s <<EOF
set -euo pipefail

INSTALL_DIR="\$HOME/projects/Build.DDN.Semantic_Search"

echo "📥 Pulling latest code from GitHub..."
git -C "\$INSTALL_DIR" pull --rebase origin main

echo ""
echo "🔨 Rebuilding frontend with correct VITE_API_URL..."
cd "\$INSTALL_DIR/frontend"

# Write .env.production so VITE_API_URL bakes into the JS bundle
cat > .env.production <<ENVEOF
VITE_API_URL=http://localhost:${BACKEND_PORT}
ENVEOF

npm install --silent
npm run build

echo ""
echo "♻️  Restarting PM2 services..."
pm2 restart ddn-vss-frontend || pm2 start "\$INSTALL_DIR/ecosystem.config.js" --only ddn-vss-frontend

pm2 save

echo ""
echo "✅ Deployment complete!"
echo "   Frontend → http://$(hostname -I | awk '{print \$1}'):${FRONTEND_PORT}"
echo "   Backend  → http://$(hostname -I | awk '{print \$1}'):${BACKEND_PORT}"
EOF

echo ""
echo "✅ Remote deploy finished. Access the app at:"
echo "   http://172.20.146.6:${FRONTEND_PORT}"
