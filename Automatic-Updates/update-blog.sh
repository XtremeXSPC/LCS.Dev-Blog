#!/bin/bash
set -euo pipefail
trap 'error_exit "An unexpected error occurred. Check the log for details."' ERR

# Variabili di progetto
blog_dir="${BLOG_DIR:-$HOME/04_LCS.Blog/CS-Topics}"
sourcePath="${SOURCE_PATH:-$HOME/Documents/Obsidian-Vault/XSPC-Vault/Blog/posts}"
destinationPath="${DESTINATION_PATH:-$HOME/04_LCS.Blog/CS-Topics/content/posts}"
images_script="${IMAGES_SCRIPT_PATH:-$HOME/04_LCS.Blog/Automatic-Updates/images.py}"

# Variabili repository GitHub
repo_path="${REPO_PATH:-/Users/lcs-dev/04_LCS.Blog}"
myrepo="${MY_REPO:-git@github.com:XtremeXSPC/LCS.Dev-Blog.git}"
logFile="./script.log"

# Logging
exec > >(tee -a "$logFile") 2>&1

log() {
    echo "[INFO] $1"
}

# Error handling
error_exit() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Check if a command exists
check_command() {
    local cmd=$1
    if ! command -v "$cmd" &>/dev/null; then
        error_exit "$cmd is not installed or not in PATH. Install it and try again."
    fi
}

# Check if a directory exists
check_dir() {
    local dir=$1
    local type=$2
    if [ ! -d "$dir" ]; then
        error_exit "$type directory does not exist: $dir"
    fi
}

# Initialize Git repository
initialize_git() {
    log "Changing to repository directory: $repo_path"
    cd "$repo_path" || error_exit "Failed to change directory to $repo_path"
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

# Sync posts from source to destination
sync_posts() {
    log "Syncing posts from source to destination..."
    check_dir "$sourcePath" "Source"
    check_dir "$destinationPath" "Destination"
    rsync -av --delete "${sourcePath}/" "${destinationPath}/"
}

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

# Update frontmatter in destination directory
update_frontmatter() {
    log "Updating frontmatter in destination directory..."
    for file in "$destinationPath"/*.md; do
        if [[ -f "$file" ]]; then
            filename=$(basename -- "$file")
            title="${filename%.*}"
            creation_date=$(get_creation_date "$file")

            # Se la data di creazione non è disponibile, usa la data di modifica
            if [[ "$creation_date" == "-" || -z "$creation_date" ]]; then
                creation_date=$(date -r "$file" +"%Y-%m-%d")
            fi

            # Aggiorna frontmatter con AWK
            awk -v new_title="$title" -v new_date="$creation_date" '
            BEGIN { in_frontmatter = 0 }
            /^---$/ {
                if (in_frontmatter == 0) {
                    in_frontmatter = 1
                    print
                    next
                } else {
                    in_frontmatter = 0
                    print
                    next
                }
            }
            in_frontmatter && $1 == "title:" {
                print "title: \"" new_title "\""
                next
            }
            in_frontmatter && $1 == "date:" {
                print "date: \"" new_date "\""
                next
            }
            { print }
            ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

            log "Frontmatter updated for: $filename"
        fi
    done
}

# Process Markdown files with images.py
process_markdown() {
    log "Processing Markdown files with images.py..."
    if [ ! -f "$images_script" ]; then
        error_exit "Python script images.py not found."
    fi
    python3 "$images_script"
}

# Build the Hugo site
build_hugo_site() {
    log "Building the Hugo site..."
    if ! hugo --source "$blog_dir"; then
        error_exit "Hugo build failed."
    fi
    if [ ! -d "$blog_dir/public" ]; then
        error_exit "Hugo build completed, but 'public' directory was not created."
    fi
}

# Stage and commit changes in Git
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

# Push changes to the main branch on GitHub
push_to_main() {
    log "Pushing changes to the main branch on GitHub..."
    if git rev-parse --verify main &>/dev/null; then
        git checkout main
    else
        error_exit "Main branch does not exist locally."
    fi

    git push origin main
}

# Deploy the public folder to the hostinger branch
deploy_to_hostinger() {
    log "Deploying the public folder to the hostinger branch..."
    if git rev-parse --verify hostinger-deploy &>/dev/null; then
        git branch -D hostinger-deploy
    fi

    git subtree split --prefix "CS-Topics/public" -b hostinger-deploy
    git push origin hostinger-deploy:hostinger --force
    git branch -D hostinger-deploy
}

# Main logic of the script - calling functions
log "Starting script..."

for cmd in git rsync python3 hugo; do
    check_command "$cmd"
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

initialize_git
sync_posts
update_frontmatter
process_markdown
build_hugo_site
stage_and_commit_changes
push_to_main
deploy_to_hostinger

# Log and exit
log "All done! Site synced, processed, committed, built, and deployed successfully."
