#!/bin/bash
set -euo pipefail
trap 'error_exit "An unexpected error occurred. Check the log for details."' ERR

# Project variables
sourcePath="${SOURCE_PATH:-$HOME/Documents/Obsidian-Vault/XSPC-Vault/Blog/posts}"
destinationPath="${DESTINATION_PATH:-$HOME/04_LCS.Blog/CS-Topics/content/posts}"
images_script="${IMAGES_SCRIPT_PATH:-$HOME/04_LCS.Blog/Automatic_Updates/images.py}"

# GitHub repository for the blog variables
repo_base="${REPO_BASE:-/Users/lcs-dev/04_LCS.Blog/}"
myrepo="${MY_REPO:-git@github.com:XtremeXSPC/LCS.Dev-Blog.git}"
logFile="./script.log"

# Enable logging (append to log for history)
exec > >(tee -a "$logFile") 2>&1

log() {
    echo "[INFO] $1"
}

error_exit() {
    echo "[ERROR] $1" >&2
    exit 1
}

check_command() {
    local cmd=$1
    if ! command -v "$cmd" &>/dev/null; then
        error_exit "$cmd is not installed or not in PATH. Install it and try again."
    fi
}

check_dir() {
    local dir=$1
    local type=$2
    if [ ! -d "$dir" ]; then
        error_exit "$type directory does not exist: $dir"
    fi
}

initialize_git() {
    if [ ! -d ".git" ]; then
        log "Initializing Git repository..."
        git init
        git remote add origin "$myrepo"
    else
        log "Git repository already initialized."
        if ! git remote get-url origin &>/dev/null; then
            log "Adding remote origin..."
            git remote add origin "$myrepo"
        fi
    fi
}

sync_posts() {
    log "Syncing posts from Obsidian to Hugo content folder..."
    check_dir "$sourcePath" "Source"
    check_dir "$destinationPath" "Destination"
    rsync -av --delete "${sourcePath}/" "${destinationPath}/"
}

process_markdown() {
    log "Processing Markdown files with images.py..."
    if [ ! -f "$images_script" ]; then
        error_exit "Python script images.py not found."
    fi
    python3 "$images_script"
}

build_hugo_site() {
    log "Building the Hugo site..."
    local blog_dir="/Users/lcs-dev/04_LCS.Blog/CS-Topics/"
    if ! hugo --source "$blog_dir"; then
        error_exit "Hugo build failed."
    fi
}

stage_and_commit_changes() {
    log "Staging changes for Git..."
    # Controllo se ci sono cambiamenti
    if git diff --quiet && git diff --cached --quiet; then
        log "No changes to stage or commit."
    else
        git add .
        local commit_message="New Blog Post on $(date +'%Y-%m-%d %H:%M:%S')"
        log "Committing changes with message: $commit_message"
        git commit -m "$commit_message"
    fi
}

push_to_main() {
    log "Pushing changes to the main branch on GitHub..."
    # Assicuriamoci di essere su main
    if git rev-parse --verify main &>/dev/null; then
        git checkout main
    else
        error_exit "Main branch does not exist locally."
    fi

    # Facoltativo: git pull --rebase origin main
    git push origin main
}

deploy_to_hostinger() {
    log "Deploying the public folder to the hostinger branch..."
    if git rev-parse --verify hostinger-deploy &>/dev/null; then
        git branch -D hostinger-deploy
    fi

    git subtree split --prefix public -b hostinger-deploy
    git push origin hostinger-deploy:hostinger --force
    git branch -D hostinger-deploy
}

# Main script
log "Starting script..."

for cmd in git rsync python3 hugo; do
    check_command "$cmd"
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

initialize_git
sync_posts
process_markdown
build_hugo_site
stage_and_commit_changes
push_to_main
deploy_to_hostinger

log "All done! Site synced, processed, committed, built, and deployed successfully."

