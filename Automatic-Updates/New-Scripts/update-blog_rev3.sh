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
# Check for dry-run mode
DRY_RUN=false
for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then
        DRY_RUN=true
        echo "[INFO] Running in dry-run mode. No changes will be made."
        break
    fi
done

# ======================================================= #
# Function to show script usage

usage() {
    echo "Usage: $0 [options] [command]"
    echo ""
    echo "Options:"
    echo "  --dry-run                 Run without making actual changes"
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

# Check if LCS_Data is defined
if [ -z "${LCS_Data:-}" ] && [ "$DRY_RUN" != "true" ]; then
    echo "[ERROR] LCS_Data environment variable is not set"
    echo "Please set it with: export LCS_Data=/path/to/your/data"
    echo "Or use --dry-run to test the script"
    exit 1
fi

# Use LCS_Data if not in dry-run mode, otherwise use a temporary path
if [ "$DRY_RUN" = "true" ] && [ -z "${LCS_Data:-}" ]; then
    LCS_Data="/tmp/LCS_Data_temp"
    echo "[INFO] Using temporary LCS_Data path for dry-run: $LCS_Data"
fi

blog_dir="${BLOG_DIR:-$LCS_Data/Blog/CS-Topics}"
sourcePath="${SOURCE_PATH:-$HOME/Documents/Obsidian-Vault/XSPC-Vault/Blog/posts}"
blog_images="${BLOG_IMAGES:-$HOME/Documents/Obsidian-Vault/XSPC-Vault/Blog/images}"
destinationPath="${DESTINATION_PATH:-$LCS_Data/Blog/CS-Topics/content/posts}"
images_script="${IMAGES_SCRIPT_PATH:-$LCS_Data/Blog/Automatic-Updates/images.py}"

# Generate hashes for files in the destination directory and update frontmatter
hash_file="${HASH_FILE_PATH:-$LCS_Data/Blog/Automatic-Updates/.file_hashes}"
hash_generator_script="${HASH_GENERATOR_SCRIPT:-$LCS_Data/Blog/Automatic-Updates/generate_hashes.py}"
update_post_frontmatter="${UPDATE_POST_FRONTMATTER:-$LCS_Data/Blog/Automatic-Updates/update_frontmatter.py}"

# GitHub repository variables
repo_path="${REPO_PATH:-$LCS_Data/Blog}"
myrepo="${MY_REPO:-git@github.com:XtremeXSPC/LCS.Dev-Blog.git}"

# Directory for temporary backups
BACKUP_DIR="${BACKUP_DIR:-/tmp/blog_backup_$(date +%Y%m%d_%H%M%S)}"

# ======================================================= #
# Logging

log() {
    echo "[INFO] $1"
}

log_warning() {
    echo "[WARNING] $1"
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
    local create_if_missing=${3:-false}
    
    if [ ! -d "$dir" ]; then
        if [ "$create_if_missing" = "true" ]; then
            log "Creating $type directory: $dir"
            if [ "$DRY_RUN" != "true" ]; then
                mkdir -p "$dir" || error_exit "Failed to create $type directory: $dir"
            else
                log "[DRY-RUN] Would create directory: $dir"
            fi
        else
            error_exit "$type directory does not exist: $dir"
        fi
    fi
}

# ======================================================= #
# Create a backup of a directory

create_backup() {
    local dir=$1
    local name=$2
    
    if [ ! -d "$dir" ] || [ "$DRY_RUN" = "true" ]; then
        return 0
    fi
    
    local backup_path="$BACKUP_DIR/$name"
    log "Creating backup of $dir to $backup_path"
    mkdir -p "$backup_path" || log_warning "Failed to create backup directory: $backup_path"
    cp -r "$dir/." "$backup_path/" || log_warning "Failed to backup $dir"
}

# ======================================================= #
# Initialize the Git repository

initialize_git() {
    log "Changing to repository directory: $repo_path"
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would change to directory: $repo_path"
    else
        cd "$repo_path" || error_exit "Failed to change directory to $repo_path"
    fi

    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would check if Git repository exists and initialize if needed"
        return 0
    fi

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
            # Check if the origin matches our expected repository
            local current_remote=$(git remote get-url origin)
            if [ "$current_remote" != "$myrepo" ]; then
                log_warning "Remote origin is set to $current_remote, expected $myrepo"
                log "Updating remote origin..."
                git remote set-url origin "$myrepo" || error_exit "Failed to update remote origin."
            else
                log "Remote origin already correctly set to $myrepo"
            fi
        fi
    fi
}

# ======================================================= #
# Sync posts from source to destination

sync_posts() {
    log "Syncing posts from source to destination..."
    check_dir "$sourcePath" "Source"
    check_dir "$destinationPath" "Destination" true
    
    # Create backup of destination before syncing
    create_backup "$destinationPath" "posts_backup"
    
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would sync from $sourcePath/ to $destinationPath/"
        return 0
    fi
    
    # Count files before sync
    local before_count=$(find "$destinationPath" -type f | wc -l)
    
    # Perform the sync
    rsync -av --delete "${sourcePath}/" "${destinationPath}/" || error_exit "rsync failed."
    
    # Count files after sync
    local after_count=$(find "$destinationPath" -type f | wc -l)
    log "Files in destination: $after_count (was $before_count before sync)"
}

# ======================================================= #
# Get the creation date of a file

get_creation_date() {
    local file="$1"
    if [ ! -f "$file" ]; then
        log_warning "File not found for get_creation_date: $file"
        echo "$(date +%Y-%m-%d)"  # Fallback date
        return
    }
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        stat -f "%Sm" -t "%Y-%m-%d" "$file"
    else
        # Linux - use mtime if ctime is not available
        local date=$(stat --format="%w" "$file" 2>/dev/null)
        if [ -z "$date" ] || [[ "$date" == "-" ]]; then
            stat --format="%y" "$file" | cut -d' ' -f1
        else
            echo "$date" | cut -d' ' -f1
        fi
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

    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would generate hashes using: python3 $hash_generator_script $destinationPath"
    else
        python3 "$hash_generator_script" "$destinationPath" || error_exit "Failed to generate file hashes."
        log "File hashes successfully updated."
    fi
}

# ======================================================= #
# Load hashes from the hash_file

load_file_hashes() {
    typeset -A file_hashes
    
    if [[ -f "$hash_file" ]]; then
        while IFS=$'\t' read -r file hash; do
            file_hashes["$file"]=$hash
        done < "$hash_file"
    fi
    
    # Add log to check the loading of hashes
    log "Loaded file hashes:"
    local count=0
    for key in ${(k)file_hashes}; do
        if [ $count -lt 5 ]; then
            log "$key: ${file_hashes[$key]}"
            ((count++))
        else
            log "... and $(( ${#file_hashes[@]} - 5 )) more"
            break
        fi
    done
    
    return 0
}

# Load hashes
load_file_hashes

# ======================================================= #
# Main logic for updating frontmatter (example placeholder)

update_frontmatter() {
    log "Updating frontmatter for files in $destinationPath"
    check_command python3
    if [ ! -f "$update_post_frontmatter" ]; then
        error_exit "Update frontmatter script not found at $update_post_frontmatter"
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would update frontmatter using: python3 $update_post_frontmatter $destinationPath $hash_file"
    else
        # Send the hash file path as an argument
        python3 "$update_post_frontmatter" "$destinationPath" "$hash_file" || error_exit "Failed to update frontmatter."
        log "Frontmatter update completed."
    fi
}

# ======================================================= #
# Process Markdown files with images.py

process_markdown() {
    log "Processing Markdown files with images.py..."
    if [ ! -f "$images_script" ]; then
        error_exit "Python script images.py not found at $images_script"
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would process markdown using: python3 $images_script"
    else
        python3 "$images_script" || error_exit "Failed to process Markdown files with images.py."
        log "Markdown processing completed."
    fi
}

# ======================================================= #
# Build the Hugo site

build_hugo_site() {
    log "Building the Hugo site..."
    check_dir "$blog_dir" "Blog"
    
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would build Hugo site using: hugo --source $blog_dir"
    else
        if ! hugo --source "$blog_dir"; then
            error_exit "Hugo build failed."
        fi
        if [ ! -d "$blog_dir/public" ]; then
            error_exit "Hugo build completed, but 'public' directory was not created."
        fi
        
        # Check if public directory has content
        local public_files=$(find "$blog_dir/public" -type f | wc -l)
        log "Public directory contains $public_files files"
        
        if [ $public_files -eq 0 ]; then
            log_warning "Public directory is empty after Hugo build"
        fi
        
        log "Hugo site built successfully."
    fi
}

# ======================================================= #
# Stage and commit changes in Git

stage_and_commit_changes() {
    log "Staging changes for Git..."
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would stage and commit changes"
        return 0
    fi
    
    # First, make sure we're in the repo directory
    cd "$repo_path" || error_exit "Failed to change directory to $repo_path"
    
    # Check if there are changes
    if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
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
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would push to main branch"
        return 0
    fi
    
    # First, make sure we're in the repo directory
    cd "$repo_path" || error_exit "Failed to change directory to $repo_path"
    
    # Check if main branch exists
    if git rev-parse --verify main &>/dev/null; then
        git checkout main || error_exit "Failed to checkout main branch."
    else
        log "Main branch does not exist locally. Creating it..."
        git checkout -b main || error_exit "Failed to create main branch."
    fi

    # Try to pull first to avoid conflicts
    if git pull origin main --rebase; then
        log "Successfully pulled latest changes from main"
    else
        log_warning "Failed to pull from main. This might be the first push or there might be conflicts."
    fi

    git push origin main || error_exit "Failed to push to main branch."
    log "Changes pushed to main branch successfully."
}

# ======================================================= #
# Deploy the public folder to the hostinger branch

deploy_to_hostinger() {
    log "Deploying the public folder to the hostinger branch..."
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would deploy to hostinger branch"
        return 0
    fi
    
    # First, make sure we're in the repo directory
    cd "$repo_path" || error_exit "Failed to change directory to $repo_path"
    
    # Check if the public directory exists
    check_dir "$blog_dir/public" "Public" false
    
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

COMMAND=""
for arg in "$@"; do
    # Skip options that start with --
    if [[ "$arg" == --* ]]; then
        continue
    fi
    COMMAND="$arg"
    break
done

if [[ -n "$COMMAND" ]]; then
    case "$COMMAND" in
        generate_file_hashes|initialize_git|sync_posts|update_frontmatter|process_markdown|build_hugo_site|stage_and_commit_changes|push_to_main|deploy_to_hostinger)
            "$COMMAND"
            exit 0
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown command '$COMMAND'"
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

# Create backup directory if needed
if [ "$DRY_RUN" != "true" ]; then
    mkdir -p "$BACKUP_DIR" || log_warning "Failed to create backup directory: $BACKUP_DIR"
fi

# Execute all functions in order
if [ "$DRY_RUN" = "true" ]; then
    log "[DRY-RUN] Would execute all functions in sequence"
    initialize_git
    sync_posts
    generate_file_hashes
    update_frontmatter
    process_markdown
    build_hugo_site
    stage_and_commit_changes
    push_to_main
    deploy_to_hostinger
else
    # Ensure script is running from the correct directory
    SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)" || error_exit "Failed to determine script directory"
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
fi

# ======================================================= #
# Log and exit
log "All done! Site synced, processed, committed, built, and deployed successfully."