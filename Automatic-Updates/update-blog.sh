#!/usr/bin/env zsh

# ======================================================= #
# Logging Setup
# Configurare il logging all'inizio per catturare tutti i log, compresi quelli generati dalle funzioni chiamate tramite argomenti.

logFile="./script.log"
exec > >(tee -a "$logFile") 2>&1

# ======================================================= #
# Exit immediately if a command exits with a non-zero status,
# Treat unset variables as an error, and prevent errors in a pipeline from being masked.
set -euo pipefail

trap 'error_exit "An unexpected error occurred. Check the log for details."' ERR

# ======================================================= #
# Function to show script usage

usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  generate_file_hashes      Generate hashes for files in the destination directory"
    echo "  initialize_git            Initialize Git repository"
    echo "  sync_posts                Sync posts from source to destination"
    echo "  update_frontmatter        Update frontmatter in destination directory"
    echo "  process_markdown          Process Markdown files with images.py"
    echo "  build_hugo_site           Build the Hugo site"
    echo "  stage_and_commit_changes  Stage and commit changes in Git"
    echo "  push_to_main              Push changes to the main branch on GitHub"
    echo "  deploy_to_hostinger       Deploy the public folder to the hostinger branch"
    echo "  help                      Show this help message"
    exit 1
}

# ======================================================= #
# Project variables

blog_dir="${BLOG_DIR:-$LCS_Data/Blog/CS-Topics}"
sourcePath="${SOURCE_PATH:-$HOME/Documents/Obsidian-Vault/XSPC-Vault/Blog/posts}"
blog_images="${BLOG_IMAGES:-$HOME/Documents/Obsidian-Vault/XSPC-Vault/Blog/images}"
destinationPath="${DESTINATION_PATH:-$LCS_Data/Blog/CS-Topics/content/posts}"
images_script="${IMAGES_SCRIPT_PATH:-$LCS_Data/Blog/Automatic-Updates/images.py}"
hash_file=".file_hashes"

# Generate hashes for files in the destination directory and update frontmatter
hash_file="${HASH_FILE_PATH:-$LCS_Data/Blog/Automatic-Updates/.file_hashes}"
hash_generator_script="${HASH_GENERATOR_SCRIPT:-$LCS_Data/Blog/Automatic-Updates/generate_hashes.py}"
update_post_frontmatter="${UPDATE_POST_FRONTMATTER:-$LCS_Data/Blog/Automatic-Updates/update_frontmatter.py}"

# GitHub repository variables

repo_path="${REPO_PATH:-/Volumes/LCS.Data/Blog}"
myrepo="${MY_REPO:-git@github.com:XtremeXSPC/LCS.Dev-Blog.git}"

# ======================================================= #
# Logging

log() {
    echo "[INFO] $1"
}

# ======================================================= #
# Error handling

error_exit() {
    echo "[ERROR] $1" >&2
    exit 1
}

# ======================================================= #
# Check if a command exists

check_command() {
    local cmd=$1
    if ! command -v "$cmd" &>/dev/null; then
        error_exit "$cmd is not installed or not in PATH. Install it and try again."
    fi
}

# ======================================================= #
# Check if a directory exists

check_dir() {
    local dir=$1
    local type=$2
    if [ ! -d "$dir" ]; then
        error_exit "$type directory does not exist: $dir"
    fi
}

# ======================================================= #
# Initialize the Git repository

initialize_git() {
    log "Changing to repository directory: $repo_path"
    cd "$repo_path" || error_exit "Failed to change directory to $repo_path"

    if [ ! -d ".git" ]; then
        log "Initializing Git repository..."
        git init || error_exit "Git initialization failed."
        git remote add origin "$myrepo" || error_exit "Failed to add remote origin."
    else
        log "Git repository already initialized."
        if ! git remote get-url origin &>/dev/null; then
            log "Adding remote origin..."
            git remote add origin "$myrepo" || error_exit "Failed to add remote origin."
        else
            log "Remote origin already exists."
        fi
    fi
}

# ======================================================= #
# Sync posts from source to destination

sync_posts() {
    log "Syncing posts from source to destination..."
    check_dir "$sourcePath" "Source"
    check_dir "$destinationPath" "Destination"
    rsync -av --delete "${sourcePath}/" "${destinationPath}/" || error_exit "rsync failed."
}

# ======================================================= #
# Get the creation date of a file

get_creation_date() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        stat -f "%Sm" -t "%Y-%m-%d" "$1"
    else
        # Linux
        stat --format="%w" "$1" | awk '{print $1}'
    fi
}

# ======================================================= #
# Find an image file in the source directory

find_image() {
    local post_name="$1"
    find "$sourcePath" -type f -regex ".*/${post_name}\..*" | head -n 1
}

# ======================================================= #
# Generate hashes for files in the destination directory

generate_file_hashes() {
    log "Generating file hashes for destination directory: $destinationPath"
    check_command python3
    if [ ! -f "$hash_generator_script" ]; then
        error_exit "Hash generator script not found at $hash_generator_script"
    fi

    python3 "$hash_generator_script" "$destinationPath" || error_exit "Failed to generate file hashes."
    log "File hashes successfully updated."
}

# ======================================================= #
# Load hashes from the hash_file

typeset -A file_hashes

if [[ -f "$hash_file" ]]; then
    while IFS=$'\t' read -r file hash; do
        file_hashes["$file"]=$hash
    done < "$hash_file"
fi

# Add log to check the loading of hashes
log "Loaded file hashes:"
for key in ${(k)file_hashes}; do
    log "$key: ${file_hashes[$key]}"
done

# ======================================================= #
# Main logic for updating frontmatter (example placeholder)

update_frontmatter() {
    log "Updating frontmatter for files in $destinationPath"
    check_command python3
    if [ ! -f "$update_post_frontmatter" ]; then
        error_exit "Update frontmatter script not found at $update_post_frontmatter"
    fi
    # Send the hash file path as an argument
    python3 "$update_post_frontmatter" "$destinationPath" "$hash_file" || error_exit "Failed to update frontmatter."
    log "Frontmatter update completed."
}

# ======================================================= #
# Process Markdown files with images.py

process_markdown() {
    log "Processing Markdown files with images.py..."
    if [ ! -f "$images_script" ]; then
        error_exit "Python script images.py not found at $images_script"
    fi
    python3 "$images_script" || error_exit "Failed to process Markdown files with images.py."
    log "Markdown processing completed."
}

# ======================================================= #
# Build the Hugo site

build_hugo_site() {
    log "Building the Hugo site..."
    if ! hugo --source "$blog_dir"; then
        error_exit "Hugo build failed."
    fi
    if [ ! -d "$blog_dir/public" ]; then
        error_exit "Hugo build completed, but 'public' directory was not created."
    fi
    log "Hugo site built successfully."
}

# ======================================================= #
# Stage and commit changes in Git

stage_and_commit_changes() {
    log "Staging changes for Git..."
    # Check if there are changes
    if git diff --quiet && git diff --cached --quiet; then
        log "No changes to stage or commit."
    else
        git add . || error_exit "Failed to stage changes."
        local commit_message="New blog update on $(date +'%Y-%m-%d %H:%M:%S')"
        log "Committing changes with message: $commit_message"
        git commit -m "$commit_message" || error_exit "Git commit failed."
    fi
}

# ======================================================= #
# Push changes to the main branch on GitHub

push_to_main() {
    log "Pushing changes to the main branch on GitHub..."
    if git rev-parse --verify main &>/dev/null; then
        git checkout main || error_exit "Failed to checkout main branch."
    else
        error_exit "Main branch does not exist locally."
    fi

    git push origin main || error_exit "Failed to push to main branch."
    log "Changes pushed to main branch successfully."
}

# ======================================================= #
# Deploy the public folder to the hostinger branch

deploy_to_hostinger() {
    log "Deploying the public folder to the hostinger branch..."
    
    # Check if 'hostinger-deploy' branch exists and delete it
    if git rev-parse --verify hostinger-deploy &>/dev/null; then
        git branch -D hostinger-deploy || error_exit "Failed to delete existing hostinger-deploy branch."
    fi

    # Create a new 'hostinger-deploy' branch from 'public' directory
    git subtree split --prefix "CS-Topics/public" -b hostinger-deploy || error_exit "git subtree split failed."

    # Push the 'hostinger-deploy' branch to 'hostinger' branch on origin
    git push origin hostinger-deploy:hostinger --force || error_exit "Failed to push to hostinger branch."

    # Delete the temporary 'hostinger-deploy' branch
    git branch -D hostinger-deploy || error_exit "Failed to delete hostinger-deploy branch after deployment."

    log "Deployment to Hostinger completed successfully."
}

# ======================================================= #
# Parse arguments and call functions

if [[ $# -gt 0 ]]; then
    case "$1" in
        generate_file_hashes|initialize_git|sync_posts|update_frontmatter|process_markdown|build_hugo_site|stage_and_commit_changes|push_to_main|deploy_to_hostinger)
            "$1"
            exit 0
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown command '$1'"
            usage
            ;;
    esac
fi

# ======================================================= #
# Execute main logic if no arguments are provided

log "Starting script..."

# Check required commands
for cmd in git rsync python3 hugo; do
    check_command "$cmd"
done

# Ensure script is running from the correct directory
SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"  # Zsh-specific to get the script directory
cd "$SCRIPT_DIR" || error_exit "Failed to change to script directory"

# Execute all functions in order
initialize_git
sync_posts
generate_file_hashes
update_frontmatter
process_markdown
build_hugo_site
stage_and_commit_changes
push_to_main
deploy_to_hostinger

# ======================================================= #
# Log and exit
log "All done! Site synced, processed, committed, built, and deployed successfully."
