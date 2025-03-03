#!/usr/bin/env zsh

# ======================================================= #
# Logging Setup
# Configurare il logging all'inizio per catturare tutti i log, compresi quelli generati dalle funzioni chiamate tramite argomenti.

# Ottieni il percorso assoluto della directory dello script
SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
logFile="${SCRIPT_DIR}/script.log"
exec > >(tee -a "$logFile") 2>&1

# ======================================================= #
# Exit immediately if a command exits with a non-zero status,
# Treat unset variables as an error, and prevent errors in a pipeline from being masked.
set -euo pipefail

# Miglioramento: Salva la directory corrente all'inizio
INITIAL_PWD="$(pwd)"

# Gestione degli errori migliorata
cleanup() {
    # Ritorna alla directory originale in caso di errore o al termine dello script
    cd "$INITIAL_PWD" 2>/dev/null || true
    log "Script terminato. Log salvato in $logFile"
}

error_exit() {
    echo "[ERROR] $1" >&2
    cleanup
    exit 1
}

# Trap migliorato per catturare segnali di interruzione
trap 'error_exit "An unexpected error occurred. Check the log for details."' ERR
trap 'cleanup' EXIT

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

# Miglioramento: Aggiunto escape per spazi nei percorsi
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
repo_path="${REPO_PATH:-/Volumes/LCS.Data/Blog}"
myrepo="${MY_REPO:-git@github.com:XtremeXSPC/LCS.Dev-Blog.git}"

# ======================================================= #
# Logging

log() {
    echo "[INFO] $1"
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

# Miglioramento: Aggiungi funzione per verificare se i file esistono
check_file() {
    local file=$1
    local type=$2
    if [ ! -f "$file" ]; then
        error_exit "$type file does not exist: $file"
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
            # Miglioramento: verifica connessione al repository remoto
            log "Remote origin already exists. Checking connection..."
            if ! git ls-remote --exit-code origin &>/dev/null; then
                log "Warning: Unable to connect to remote repository. Check your network connection and SSH keys."
            else
                log "Connection to remote repository verified."
            fi
        fi
    fi
}

# ======================================================= #
# Sync posts from source to destination

sync_posts() {
    log "Syncing posts from source to destination..."
    check_dir "$sourcePath" "Source"
    check_dir "$destinationPath" "Destination"
    
    # Miglioramento: creazione di backup prima della sincronizzazione
    local backup_dir="${destinationPath}_backup_$(date +%Y%m%d_%H%M%S)"
    if [ -d "$destinationPath" ] && [ "$(ls -A "$destinationPath" 2>/dev/null)" ]; then
        log "Creating backup of destination directory to $backup_dir"
        cp -r "$destinationPath" "$backup_dir" || log "Warning: Backup creation failed, continuing anyway"
    fi
    
    rsync -av --delete "${sourcePath}/" "${destinationPath}/" || error_exit "rsync failed."
    log "Sync completed successfully."
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
    check_file "$hash_generator_script" "Hash generator script"
    check_dir "$destinationPath" "Destination"

    # Miglioramento: Backup del file hash precedente
    if [ -f "$hash_file" ]; then
        cp "$hash_file" "${hash_file}.backup" || log "Warning: Could not create backup of hash file"
    fi

    python3 "$hash_generator_script" "$destinationPath" || error_exit "Failed to generate file hashes."
    
    # Verifica che il file hash sia stato generato correttamente
    if [ ! -f "$hash_file" ]; then
        error_exit "Hash file was not created at $hash_file"
    fi
    
    log "File hashes successfully updated."
}

# ======================================================= #
# Load hashes from the hash_file

load_file_hashes() {
    typeset -gA file_hashes
    
    if [[ -f "$hash_file" ]]; then
        log "Loading file hashes from $hash_file"
        while IFS=$'\t' read -r file hash || [ -n "$file" ]; do
            if [[ -n "$file" && -n "$hash" ]]; then
                file_hashes["$file"]=$hash
            fi
        done < "$hash_file"
        
        # Add log to check the loading of hashes
        log "Loaded ${#file_hashes} file hashes."
    else
        log "Hash file not found at $hash_file. Will be created during the generation step."
        file_hashes=()
    fi
}

# ======================================================= #
# Main logic for updating frontmatter

update_frontmatter() {
    log "Updating frontmatter for files in $destinationPath"
    check_command python3
    check_file "$update_post_frontmatter" "Update frontmatter script"
    check_dir "$destinationPath" "Destination"
    
    # Verify hash file exists before proceeding
    if [ ! -f "$hash_file" ]; then
        log "Hash file not found. Generating hashes first..."
        generate_file_hashes
    fi
    
    # Send the hash file path as an argument
    python3 "$update_post_frontmatter" "$destinationPath" "$hash_file" || error_exit "Failed to update frontmatter."
    log "Frontmatter update completed."
}

# ======================================================= #
# Process Markdown files with images.py

process_markdown() {
    log "Processing Markdown files with images.py..."
    check_file "$images_script" "Python script images.py"
    
    python3 "$images_script" || error_exit "Failed to process Markdown files with images.py."
    log "Markdown processing completed."
}

# ======================================================= #
# Build the Hugo site

build_hugo_site() {
    log "Building the Hugo site..."
    check_command hugo
    check_dir "$blog_dir" "Blog"
    
    # Salvataggio della directory corrente
    local current_dir="$(pwd)"
    
    # Cambio alla directory del blog
    cd "$blog_dir" || error_exit "Failed to change directory to $blog_dir"
    
    if ! hugo; then
        cd "$current_dir" || true  # Ritorna alla directory originale in caso di errore
        error_exit "Hugo build failed."
    fi
    
    if [ ! -d "public" ]; then
        cd "$current_dir" || true
        error_exit "Hugo build completed, but 'public' directory was not created."
    fi
    
    # Ritorno alla directory originale
    cd "$current_dir" || error_exit "Failed to return to original directory"
    
    log "Hugo site built successfully."
}

# ======================================================= #
# Stage and commit changes in Git

stage_and_commit_changes() {
    log "Staging changes for Git..."
    
    # Cambio alla directory del repository
    cd "$repo_path" || error_exit "Failed to change directory to $repo_path"
    
    # Verifica se il repository è inizializzato
    if [ ! -d ".git" ]; then
        error_exit "Git repository not initialized. Run initialize_git first."
    fi
    
    # Check if there are changes
    if git status --porcelain | grep -q .; then
        git add . || error_exit "Failed to stage changes."
        local commit_message="New blog update on $(date +'%Y-%m-%d %H:%M:%S')"
        log "Committing changes with message: $commit_message"
        git commit -m "$commit_message" || error_exit "Git commit failed."
        log "Changes committed successfully."
    else
        log "No changes to stage or commit."
    fi
}

# ======================================================= #
# Push changes to the main branch on GitHub

push_to_main() {
    log "Pushing changes to the main branch on GitHub..."
    
    # Cambio alla directory del repository
    cd "$repo_path" || error_exit "Failed to change directory to $repo_path"
    
    # Verifica la presenza del branch main
    if ! git show-ref --verify --quiet refs/heads/main; then
        log "Main branch does not exist locally. Creating it..."
        # Crea il branch main se non esiste
        git checkout -b main || error_exit "Failed to create main branch."
    else
        git checkout main || error_exit "Failed to checkout main branch."
    fi

    # Verifica connessione al repository remoto prima di tentare il push
    if ! git ls-remote --exit-code origin &>/dev/null; then
        error_exit "Cannot connect to remote repository. Check your network connection and SSH keys."
    fi
    
    git push origin main || error_exit "Failed to push to main branch."
    log "Changes pushed to main branch successfully."
}

# ======================================================= #
# Deploy the public folder to the hostinger branch

deploy_to_hostinger() {
    log "Deploying the public folder to the hostinger branch..."
    
    # Cambio alla directory del repository
    cd "$repo_path" || error_exit "Failed to change directory to $repo_path"
    
    # Verifica esistenza della directory public
    local public_dir="CS-Topics/public"
    if [ ! -d "$public_dir" ]; then
        error_exit "Public directory '$public_dir' does not exist. Run build_hugo_site first."
    fi
    
    # Check if 'hostinger-deploy' branch exists and delete it
    if git rev-parse --verify hostinger-deploy &>/dev/null; then
        git branch -D hostinger-deploy || error_exit "Failed to delete existing hostinger-deploy branch."
    fi

    # Create a new 'hostinger-deploy' branch from 'public' directory
    git subtree split --prefix "$public_dir" -b hostinger-deploy || error_exit "git subtree split failed."

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
        generate_file_hashes)
            load_file_hashes
            generate_file_hashes
            exit 0
            ;;
        initialize_git)
            initialize_git
            exit 0
            ;;
        sync_posts)
            sync_posts
            exit 0
            ;;
        update_frontmatter)
            load_file_hashes
            update_frontmatter
            exit 0
            ;;
        process_markdown)
            process_markdown
            exit 0
            ;;
        build_hugo_site)
            build_hugo_site
            exit 0
            ;;
        stage_and_commit_changes)
            stage_and_commit_changes
            exit 0
            ;;
        push_to_main)
            push_to_main
            exit 0
            ;;
        deploy_to_hostinger)
            deploy_to_hostinger
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

# Carica gli hash dei file
load_file_hashes

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