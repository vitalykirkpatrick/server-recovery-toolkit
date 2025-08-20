#!/bin/bash
set -e

# Load environment variables
source /root/.env

BACKUP_NAME="n8n_backup_$(date +'%Y%m%d_%H%M%S').tar.gz"
BACKUP_PATH="/root/${BACKUP_NAME}"
MANIFEST_PATH="/root/backup_MANIFEST.txt"

echo "📦 Creating backup at $BACKUP_PATH..."
tar -czvf "$BACKUP_PATH" --absolute-names \
    /etc/nginx \
    /etc/systemd/system \
    /root/.n8n \
    /var/lib/docker \
    --exclude='*.log' \
    --exclude='node_modules' \
    --exclude='/proc' \
    --exclude='/sys' \
    --exclude='/dev' \
    --exclude='/run' \
    --exclude='/tmp' \
    --exclude='/mnt' \
    --exclude='/media' \
    --exclude='/lost+found' || echo "⚠️ Some paths skipped if not found."

echo "🔍 Listing backup contents to $MANIFEST_PATH"
tar -tvf "$BACKUP_PATH" > "$MANIFEST_PATH"

# Prepare temp repo
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

echo "🔄 Initializing git repository..."
git init
git config user.email "backup@n8n.local"
git config user.name "n8n Backup Bot"

echo "🔗 Adding remote repository..."
git remote add origin https://${GITHUB_PAT}@github.com/${GITHUB_REPO}.git

echo "📥 Fetching remote repository..."
if git fetch origin ${GITHUB_BRANCH} 2>/dev/null; then
    echo "✅ Remote branch exists, checking out..."
    git checkout -B ${GITHUB_BRANCH} origin/${GITHUB_BRANCH}
else
    echo "⚠️ Remote branch doesn't exist, creating new branch..."
    git checkout -B ${GITHUB_BRANCH}
fi

echo "📋 Copying backup files..."
cp "$BACKUP_PATH" .
cp "$MANIFEST_PATH" .

if [ "$USE_GIT_LFS" = "true" ]; then
    echo "🔧 Setting up Git LFS..."
    git lfs install
    git lfs track "*.tar.gz"
    git add .gitattributes
fi

echo "📝 Adding files to git..."
git add .

echo "💾 Committing backup..."
git commit -m "Backup on $(date +'%Y-%m-%d %H:%M:%S')" || echo "⚠️ Nothing to commit"

echo "🚀 Pushing to GitHub..."
if git push origin ${GITHUB_BRANCH}; then
    echo "✅ Backup successfully pushed to GitHub!"
else
    echo "❌ GitHub push failed, trying force push..."
    if git push --force origin ${GITHUB_BRANCH}; then
        echo "✅ Force push successful!"
    else
        echo "❌ Force push also failed. Manual intervention required."
        echo "📍 Backup files are available locally:"
        echo "   - Backup: $BACKUP_PATH"
        echo "   - Manifest: $MANIFEST_PATH"
        echo "   - Temp repo: $TMP_DIR"
        exit 1
    fi
fi

echo "🧹 Cleaning up temporary directory..."
rm -rf "$TMP_DIR"

echo "✅ Backup process completed successfully!"
echo "📦 Backup file: $BACKUP_PATH"
echo "📋 Manifest file: $MANIFEST_PATH"
