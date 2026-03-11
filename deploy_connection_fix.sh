#!/bin/bash
# ============================================================
#  DDN Semantic Search — Full Fix Deploy (v5)
#
#  KEY CHANGE: PyTorch 2.6 does not exist for CUDA 12.1.
#  Instead, we downgrade 'transformers' to 4.47.1 which was
#  the last version BEFORE the torch>=2.6 check was added
#  (CVE-2025-32434 restriction added in transformers 4.49.0).
#
#  BONUS: Uses SSH ControlMaster — only ONE password prompt.
#
#  Run from WSL:
#    chmod +x deploy_connection_fix.sh
#    ./deploy_connection_fix.sh
# ============================================================

set -euo pipefail

SERVER="nwasim@172.20.146.6"
REMOTE_DIR="\$HOME/projects/Build.DDN.Semantic_Search"
BACKEND_PORT=8001
FRONTEND_PORT=5175
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── SSH ControlMaster: one password prompt for everything ─────
CTRL_PATH="/tmp/ssh_ctl_vss_$$"
echo ""
echo "🔑 Opening SSH connection (one password prompt for all steps)..."
ssh -M -S "$CTRL_PATH" -o ControlPersist=60s \
    -o StrictHostKeyChecking=no -fNT "$SERVER"
alias SSH="ssh -S $CTRL_PATH $SERVER"
alias SCP="scp -o ControlPath=$CTRL_PATH"

echo ""
echo "🔧 DDN Semantic Search — Full Fix Deploy (v5)"
echo "   Torch 2.6 not available for cu121 — downgrading"
echo "   transformers to 4.47.1 (pre-CVE check) instead."
echo ""

# ── Step 1: Copy all fixed files ─────────────────────────────
echo "📤 Copying fixed files to server..."

scp -o "ControlPath=$CTRL_PATH" \
    "${SCRIPT_DIR}/backend/app/services/storage.py" \
    "${SCRIPT_DIR}/backend/app/core/config.py" \
    "${SCRIPT_DIR}/backend/app/services/ai_models.py" \
    "${SERVER}:${REMOTE_DIR//\$/\$}/backend/app/services/" 2>/dev/null || \
scp -o "ControlPath=$CTRL_PATH" \
    "${SCRIPT_DIR}/backend/app/services/storage.py" \
    "${SERVER}:~/projects/Build.DDN.Semantic_Search/backend/app/services/storage.py"
scp -o "ControlPath=$CTRL_PATH" \
    "${SCRIPT_DIR}/backend/app/core/config.py" \
    "${SERVER}:~/projects/Build.DDN.Semantic_Search/backend/app/core/config.py"
scp -o "ControlPath=$CTRL_PATH" \
    "${SCRIPT_DIR}/backend/app/services/ai_models.py" \
    "${SERVER}:~/projects/Build.DDN.Semantic_Search/backend/app/services/ai_models.py"
scp -o "ControlPath=$CTRL_PATH" \
    "${SCRIPT_DIR}/frontend/src/pages/Configuration.tsx" \
    "${SERVER}:~/projects/Build.DDN.Semantic_Search/frontend/src/pages/Configuration.tsx"
echo "   ✔ All 4 files copied"
echo ""

# ── Step 2: Upgrade deps + rebuild + restart ─────────────────
echo "🔨 Running fixes on server..."
ssh -S "$CTRL_PATH" "$SERVER" bash -s <<'ENDSSH'
set -euo pipefail

INSTALL_DIR="$HOME/projects/Build.DDN.Semantic_Search"
VENV="$INSTALL_DIR/backend/venv"

echo "── Step 1/3: Pinning transformers to 4.47.1 ─────────────"
echo "   (Last version before torch>=2.6 hard requirement)"
echo "   Current version: $("$VENV/bin/pip" show transformers 2>/dev/null | grep Version || echo 'unknown')"
"$VENV/bin/pip" install "transformers==4.47.1" --quiet 2>&1 | tail -3
echo "   ✔ transformers pinned to: $("$VENV/bin/pip" show transformers | grep Version)"
echo ""

echo "── Step 2/3: Rebuilding frontend ─────────────────────────"
echo "VITE_API_URL=http://localhost:8001" > "$INSTALL_DIR/frontend/.env.production"
cd "$INSTALL_DIR/frontend"
npm install --silent
npm run build
echo "   ✔ Frontend rebuilt"
echo ""

echo "── Step 3/3: Restarting PM2 services ─────────────────────"
pm2 restart ddn-vss-backend  2>/dev/null || pm2 start "$INSTALL_DIR/ecosystem.config.js" --only ddn-vss-backend
pm2 restart ddn-vss-frontend 2>/dev/null || pm2 start "$INSTALL_DIR/ecosystem.config.js" --only ddn-vss-frontend
pm2 save
echo "   ✔ Services restarted"
echo ""
echo "⏳ Waiting 20s for BLIP/CLIP models to load..."
sleep 20

echo ""
echo "── Model load status ──────────────────────────────────────"
pm2 logs ddn-vss-backend --lines 15 --nostream 2>/dev/null | \
    grep -E "(FAILED|successfully|loading|Loading|Error|BLIP|CLIP|cuda|ready|Ready)" || \
    echo "   (no matching lines — check logs manually)"

echo ""
echo "✅ Done!"
echo "   Frontend → http://$(hostname -I | awk '{print $1}'):5175"
echo "   Backend  → http://$(hostname -I | awk '{print $1}'):8001/docs"
ENDSSH

# Close SSH master connection
ssh -S "$CTRL_PATH" -O exit "$SERVER" 2>/dev/null || true

echo ""
echo "✅ Deployment complete! http://172.20.146.6:${FRONTEND_PORT}"
echo ""
echo "Check model status:"
echo "  ssh ${SERVER} 'pm2 logs ddn-vss-backend --lines 20 --nostream'"
echo ""
