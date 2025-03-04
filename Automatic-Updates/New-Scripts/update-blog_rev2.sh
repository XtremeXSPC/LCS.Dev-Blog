#!/usr/bin/env zsh

# ======================================================= #
# Blog Deployment Script
# Questo script automatizza il processo di sincronizzazione, build e deploy di un blog Hugo
# Autore: XtremeXSPC
# Data: 2025-03-03
# ======================================================= #

# ======================================================= #
# Configurazione iniziale
# ======================================================= #

# Definizione dello script attuale e directory di base
if [[ -n "${ZSH_VERSION}" ]]; then
    # Utilizzo di Zsh
    SCRIPT_PATH="${(%):-%x}"
elif [[ -n "${BASH_VERSION}" ]]; then
    # Utilizzo di Bash
    SCRIPT_PATH="${BASH_SOURCE[0]}"
else
    # Fallback generico
    SCRIPT_PATH="$0"
fi

SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd 2>/dev/null)" || {
    echo "ERRORE: Impossibile determinare la directory dello script"
    exit 1
}
CONFIG_FILE="${SCRIPT_DIR}/blog_deploy.conf"
CHECKPOINT_FILE="${SCRIPT_DIR}/.checkpoint"
START_TIME=$(date +%s)
VERSION="1.0.0"

# ======================================================= #
# Sistema di logging strutturato
# ======================================================= #

# Definizione dei livelli di log
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARNING=2
LOG_LEVEL_ERROR=3
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO  # Livello predefinito

# Configurazione del file di log assoluto
LOG_FILE="${SCRIPT_DIR}/script_$(date +%Y%m%d_%H%M%S).log"

# Funzione log migliorata con livelli
log() {
    local level=$1
    local message=$2
    local level_str=""
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    case $level in
        $LOG_LEVEL_DEBUG)
            [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ] || return
            level_str="DEBUG"
            ;;
        $LOG_LEVEL_INFO)
            [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ] || return
            level_str="INFO"
            ;;
        $LOG_LEVEL_WARNING)
            [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARNING ] || return
            level_str="WARNING"
            ;;
        $LOG_LEVEL_ERROR)
            [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ] || return
            level_str="ERROR"
            ;;
    esac
    
    echo "[$timestamp] [$level_str] $message" | tee -a "$LOG_FILE"
}

# Shortcuts per i diversi livelli di log
log_debug() { log $LOG_LEVEL_DEBUG "$1"; }
log_info() { log $LOG_LEVEL_INFO "$1"; }
log_warning() { log $LOG_LEVEL_WARNING "$1"; }
log_error() { log $LOG_LEVEL_ERROR "$1"; }

# Configurazione iniziale del logging
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || {
    echo "AVVISO: Impossibile creare la directory per i log: $(dirname "$LOG_FILE")"
    # Fallback a /tmp per i log se non possiamo creare la directory originale
    LOG_FILE="/tmp/blog_script_$(date +%Y%m%d_%H%M%S).log"
    echo "I log verranno scritti in: $LOG_FILE"
}
touch "$LOG_FILE" 2>/dev/null || {
    echo "ERRORE: Impossibile creare il file di log: $LOG_FILE"
    LOG_FILE="/dev/stdout"  # Fallback a stdout
    echo "I log verranno mostrati solo a schermo"
}

# ======================================================= #
# Gestione degli errori migliorata
# ======================================================= #

# Esci immediatamente se un comando termina con stato non zero,
# tratta le variabili non impostate come errore e previene il mascheramento degli errori in una pipeline
set -euo pipefail

# Trap per errori inaspettati
error_handler() {
    local line_no=$1
    local error_code=$2
    log_error "Errore alla riga $line_no (codice di errore: $error_code)"
    exit $error_code
}

# Registra il trap per i comandi che falliscono in Zsh
trap 'error_handler ${LINENO} $?' ERR

# Trap per l'uscita
exit_handler() {
    local exit_code=$?
    local duration=$(($(date +%s) - START_TIME))
    
    if [ $exit_code -eq 0 ]; then
        log_info "Script completato con successo in ${duration}s"
    else
        log_error "Script terminato con errore (codice: $exit_code) dopo ${duration}s"
    fi
    
    # Cleanup temporaneo se necessario
    if [ -n "${TEMP_BACKUP_DIR:-}" ] && [ -d "$TEMP_BACKUP_DIR" ] && [ "$PRESERVE_BACKUP" != "true" ]; then
        log_debug "Pulizia della directory di backup temporanea: $TEMP_BACKUP_DIR"
        rm -rf "$TEMP_BACKUP_DIR"
    fi
}

trap exit_handler EXIT

# ======================================================= #
# Gestione timeout
# ======================================================= #

# Funzione per eseguire comandi con timeout
run_with_timeout() {
    local timeout=$1
    local cmd=$2
    shift 2
    
    log_debug "Esecuzione comando con timeout di ${timeout}s: $cmd $*"
    
    # Verifica se 'timeout' è disponibile
    if command -v timeout &>/dev/null; then
        timeout ${timeout}s $cmd "$@"
        return $?
    else
        # Fallback se 'timeout' non è disponibile
        local pid
        $cmd "$@" &
        pid=$!
        
        (
            sleep $timeout
            kill -0 $pid 2>/dev/null && {
                log_warning "Timeout raggiunto ($timeout secondi) per il comando: $cmd"
                kill -TERM $pid 2>/dev/null
                sleep 2
                kill -KILL $pid 2>/dev/null
            }
        ) &
        local timeout_pid=$!
        
        wait $pid
        local cmd_exit=$?
        kill $timeout_pid 2>/dev/null
        wait $timeout_pid 2>/dev/null
        
        return $cmd_exit
    fi
}

# ======================================================= #
# Gestione configurazione
# ======================================================= #

# Valori predefiniti delle variabili (possono essere sovrascritti dal file di configurazione)
DRY_RUN=false
VERBOSE=false
PRESERVE_BACKUP=false
DEFAULT_TIMEOUT=300  # 5 minuti
DEFAULT_GIT_TIMEOUT=600  # 10 minuti per operazioni Git

# Carica configurazione da file se esiste, altrimenti crea un file template
if [[ -f "$CONFIG_FILE" ]]; then
    log_info "Caricamento configurazione da $CONFIG_FILE"
    source "$CONFIG_FILE"
    log_debug "Configurazione caricata con successo"
else
    log_warning "File di configurazione non trovato: $CONFIG_FILE"
    
    # Crea la directory se non esiste
    mkdir -p "$(dirname "$CONFIG_FILE")" 2>/dev/null
    
    # Crea un template del file di configurazione
    if [ "$DRY_RUN" != "true" ]; then
        log_info "Creazione file di configurazione template: $CONFIG_FILE"
        cat > "$CONFIG_FILE" << EOF
# Blog Deployment - File di configurazione
# Generato automaticamente il $(date +'%Y-%m-%d %H:%M:%S')

# Impostazioni generali
DRY_RUN=false
VERBOSE=false
PRESERVE_BACKUP=false

# Directory e percorsi
# BLOG_DIR="\$LCS_Data/Blog/CS-Topics"
# SOURCE_PATH="\$HOME/Documents/Obsidian-Vault/XSPC-Vault/Blog/posts"
# BLOG_IMAGES="\$HOME/Documents/Obsidian-Vault/XSPC-Vault/Blog/images"
# DESTINATION_PATH="\$LCS_Data/Blog/CS-Topics/content/posts"
# IMAGES_SCRIPT_PATH="\$LCS_Data/Blog/Automatic-Updates/images.py"
# HASH_FILE_PATH="\$LCS_Data/Blog/Automatic-Updates/.file_hashes"
# HASH_GENERATOR_SCRIPT="\$LCS_Data/Blog/Automatic-Updates/generate_hashes.py"
# UPDATE_POST_FRONTMATTER="\$LCS_Data/Blog/Automatic-Updates/update_frontmatter.py"
# REPO_PATH="\$LCS_Data/Blog"
# MY_REPO="git@github.com:XtremeXSPC/LCS.Dev-Blog.git"

# Timeout (in secondi)
DEFAULT_TIMEOUT=300
DEFAULT_GIT_TIMEOUT=600
EOF
        log_info "File di configurazione template creato. Personalizzalo secondo le tue esigenze."
    else
        log_info "[DRY-RUN] Verrebbe creato un file di configurazione template"
    fi
fi

# Funzione per verificare variabili d'ambiente critiche e impostare valori predefiniti
check_env_var() {
    local var_name=$1
    local default_value=$2
    local is_critical=${3:-false}
    
    if [[ -z "${(P)var_name}" ]]; then
        if [[ "$is_critical" == "true" ]]; then
            if [[ -n "$default_value" ]]; then
                log_warning "Variabile critica $var_name non impostata, utilizzo valore predefinito: $default_value"
                eval "$var_name=\"$default_value\""
            else
                log_error "Variabile critica $var_name non impostata e non ha un valore predefinito"
                exit 1
            fi
        else
            log_debug "Variabile $var_name non impostata, utilizzo valore predefinito: $default_value"
            eval "$var_name=\"$default_value\""
        fi
    else
        log_debug "Variabile $var_name impostata a: ${(P)var_name}"
    fi
}

# Verifica la presenza della variabile base LCS_Data
if [ -z "${LCS_Data:-}" ]; then
    # In modalità dry-run, non blocchiamo l'esecuzione
    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "[WARNING] La variabile LCS_Data non è definita. Continuiamo in modalità dry-run."
        # Impostiamo un valore temporaneo per LCS_Data
        LCS_Data="/tmp/LCS_Data"
    else
        echo "[ERROR] La variabile LCS_Data non è definita. Impostala prima di eseguire lo script."
        echo "Ad esempio: export LCS_Data=/percorso/alla/directory/dati"
        echo "Oppure esegui con --dry-run per testare lo script."
        exit 1
    fi
fi

# Impostazione e verifica delle variabili di progetto
check_env_var "BLOG_DIR" "$LCS_Data/Blog/CS-Topics"
check_env_var "SOURCE_PATH" "$HOME/Documents/Obsidian-Vault/XSPC-Vault/Blog/posts"
check_env_var "BLOG_IMAGES" "$HOME/Documents/Obsidian-Vault/XSPC-Vault/Blog/images"
check_env_var "DESTINATION_PATH" "$LCS_Data/Blog/CS-Topics/content/posts"
check_env_var "IMAGES_SCRIPT_PATH" "$LCS_Data/Blog/Automatic-Updates/images.py"
check_env_var "HASH_FILE_PATH" "$LCS_Data/Blog/Automatic-Updates/.file_hashes"
check_env_var "HASH_GENERATOR_SCRIPT" "$LCS_Data/Blog/Automatic-Updates/generate_hashes.py"
check_env_var "UPDATE_POST_FRONTMATTER" "$LCS_Data/Blog/Automatic-Updates/update_frontmatter.py"
check_env_var "REPO_PATH" "$LCS_Data/Blog"
check_env_var "MY_REPO" "git@github.com:XtremeXSPC/LCS.Dev-Blog.git"

# Variabile di riferimento per file degli hash
hash_file="$HASH_FILE_PATH"

# Directory temporanea per backup
TEMP_BACKUP_DIR="${SCRIPT_DIR}/backup_$(date +%Y%m%d_%H%M%S)"

# ======================================================= #
# Sistema di checkpoint
# ======================================================= #

# Inizializza il file di checkpoint se non esiste
if [ ! -f "$CHECKPOINT_FILE" ]; then
    echo "LAST_SUCCESSFUL_STEP=" > "$CHECKPOINT_FILE"
    log_debug "File di checkpoint inizializzato"
fi

# Funzione per aggiornare lo stato del checkpoint
update_checkpoint() {
    local step=$1
    log_debug "Aggiornamento checkpoint: $step"
    sed -i.bak "s/^LAST_SUCCESSFUL_STEP=.*/LAST_SUCCESSFUL_STEP=$step/" "$CHECKPOINT_FILE"
    rm -f "${CHECKPOINT_FILE}.bak"
}

# Funzione per ottenere l'ultimo checkpoint completato
get_last_checkpoint() {
    source "$CHECKPOINT_FILE"
    echo "${LAST_SUCCESSFUL_STEP:-none}"
}

# Funzione per verificare se un passaggio è già stato completato
is_step_completed() {
    local step=$1
    local last_step=$(get_last_checkpoint)
    
    local steps=("initialize_git" "sync_posts" "generate_file_hashes" "update_frontmatter" 
                "process_markdown" "build_hugo_site" "stage_and_commit_changes" 
                "push_to_main" "deploy_to_hostinger")
    
    # Se l'ultimo passaggio è "none", nessun passaggio è stato completato
    if [[ "$last_step" == "none" ]]; then
        return 1
    fi
    
    # Trova la posizione dell'ultimo passaggio completato
    local last_pos=0
    local cur_pos=0
    for s in "${steps[@]}"; do
        if [[ "$s" == "$last_step" ]]; then
            last_pos=$cur_pos
        fi
        if [[ "$s" == "$step" ]]; then
            cur_pos=$cur_pos
        fi
        ((cur_pos++))
    done
    
    # Se il passaggio corrente è dopo l'ultimo passaggio completato, non è stato completato
    if [[ $cur_pos -le $last_pos ]]; then
        return 0
    else
        return 1
    fi
}

# Funzione per resettare il checkpoint
reset_checkpoint() {
    log_info "Resettando il checkpoint"
    echo "LAST_SUCCESSFUL_STEP=" > "$CHECKPOINT_FILE"
}

# ======================================================= #
# Utilità di verifica
# ======================================================= #

# Controlla se un comando esiste
check_command() {
    local cmd=$1
    if ! command -v "$cmd" &>/dev/null; then
        log_error "$cmd non è installato o non è nel PATH. Installalo e riprova."
        exit 1
    fi
    log_debug "Comando trovato: $cmd"
}

# Controlla se una directory esiste
check_dir() {
    local dir=$1
    local type=$2
    local create=${3:-false}
    
    if [ ! -d "$dir" ]; then
        if [[ "$create" == "true" ]]; then
            log_warning "Directory $type non esiste: $dir - Creazione..."
            mkdir -p "$dir" || {
                log_error "Impossibile creare la directory $type: $dir"
                exit 1
            }
            log_info "Directory $type creata: $dir"
        else
            log_error "Directory $type non esiste: $dir"
            exit 1
        fi
    else
        log_debug "Directory $type trovata: $dir"
    fi
}

# Controlla se un file esiste
check_file() {
    local file=$1
    local type=$2
    
    if [ ! -f "$file" ]; then
        log_error "File $type non trovato: $file"
        return 1
    fi
    log_debug "File $type trovato: $file"
    return 0
}

# ======================================================= #
# Visualizza l'utilizzo dello script
# ======================================================= #

usage() {
    echo "Blog Deployment Script v$VERSION"
    echo ""
    echo "Utilizzo: $0 [opzioni] [comando]"
    echo ""
    echo "Opzioni:"
    echo "  --dry-run                 Esegue lo script senza apportare modifiche reali"
    echo "  --verbose                 Attiva output verboso (debug)"
    echo "  --preserve-backup         Conserva i file di backup dopo l'esecuzione"
    echo "  --config <file>           Utilizza un file di configurazione specifico"
    echo "  --reset-checkpoint        Resetta il file di checkpoint"
    echo "  --help, -h                Mostra questo messaggio di aiuto"
    echo ""
    echo "Comandi:"
    echo "  generate_file_hashes      Genera hash per i file nella directory di destinazione"
    echo "  initialize_git            Inizializza repository Git"
    echo "  sync_posts                Sincronizza i post da origine a destinazione"
    echo "  update_frontmatter        Aggiorna il frontmatter nella directory di destinazione"
    echo "  process_markdown          Processa file Markdown con images.py"
    echo "  build_hugo_site           Compila il sito Hugo"
    echo "  stage_and_commit_changes  Prepara e commit le modifiche in Git"
    echo "  push_to_main              Invia le modifiche al branch main su GitHub"
    echo "  deploy_to_hostinger       Distribuisce la cartella public al branch hostinger"
    echo "  all                       Esegue tutti i comandi in sequenza"
    echo "  help                      Mostra questo messaggio di aiuto"
    echo ""
    echo "Configurazione ambiente:"
    echo "  Il file di configurazione predefinito è: $CONFIG_FILE"
    echo "  Puoi impostare le variabili d'ambiente richieste nel file di configurazione"
    exit 1
}

# ======================================================= #
# Caricamento degli hash
# ======================================================= #

typeset -A file_hashes

load_file_hashes() {
    log_info "Caricamento degli hash dei file..."
    
    # Inizializza l'array associativo vuoto
    file_hashes=()
    
    if [[ -f "$hash_file" ]]; then
        while IFS=$'\t' read -r file hash; do
            file_hashes["$file"]=$hash
        done < "$hash_file"
        log_info "Caricati ${#file_hashes[@]} hash dal file $hash_file"
    else
        log_warning "File degli hash non trovato: $hash_file"
    fi
    
    # Debug: mostra alcuni hash caricati (max 5)
    local count=0
    for key in ${(k)file_hashes}; do
        log_debug "Hash caricato: $key: ${file_hashes[$key]}"
        ((count++))
        if [ $count -ge 5 ]; then
            log_debug "... e altri ${#file_hashes[@]} hash"
            break
        fi
    done
}

# ======================================================= #
# Funzioni per operazioni principali
# ======================================================= #

# Inizializza il repository Git
initialize_git() {
    if is_step_completed "initialize_git" && [ "$FORCE_RERUN" != "true" ]; then
        log_info "Il passaggio initialize_git è già stato completato. Saltando..."
        return 0
    fi
    
    log_info "Passaggio a directory del repository: $REPO_PATH"
    cd "$REPO_PATH" || {
        log_error "Impossibile cambiare directory in $REPO_PATH"
        return 1
    }
    
    # Controlla se il repository è già inizializzato
    if [ -d ".git" ]; then
        log_info "Repository Git già inizializzato"
        
        # Verifica l'origine remota
        if ! git remote get-url origin &>/dev/null; then
            log_info "Aggiungendo origine remota..."
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY-RUN] Eseguo: git remote add origin $MY_REPO"
            else
                run_with_timeout $DEFAULT_GIT_TIMEOUT git remote add origin "$MY_REPO" || {
                    log_error "Impossibile aggiungere origine remota"
                    return 1
                }
            fi
        else
            # Verifica che l'origine remota sia corretta
            local current_remote=$(git remote get-url origin)
            if [ "$current_remote" != "$MY_REPO" ]; then
                log_warning "L'origine remota attuale è diversa: $current_remote"
                log_info "Aggiornando origine remota a $MY_REPO..."
                
                if [ "$DRY_RUN" = "true" ]; then
                    log_info "[DRY-RUN] Eseguo: git remote set-url origin $MY_REPO"
                else
                    run_with_timeout $DEFAULT_GIT_TIMEOUT git remote set-url origin "$MY_REPO" || {
                        log_error "Impossibile aggiornare origine remota"
                        return 1
                    }
                }
            else
                log_info "Origine remota già configurata correttamente"
            fi
        fi
    else
        log_info "Inizializzando repository Git..."
        if [ "$DRY_RUN" = "true" ]; then
            log_info "[DRY-RUN] Eseguo: git init"
            log_info "[DRY-RUN] Eseguo: git remote add origin $MY_REPO"
        else
            run_with_timeout $DEFAULT_GIT_TIMEOUT git init || {
                log_error "Inizializzazione Git fallita"
                return 1
            }
            run_with_timeout $DEFAULT_GIT_TIMEOUT git remote add origin "$MY_REPO" || {
                log_error "Impossibile aggiungere origine remota"
                return 1
            }
        fi
    fi
    
    # Aggiorna il file di checkpoint
    if [ "$DRY_RUN" != "true" ]; then
        update_checkpoint "initialize_git"
    fi
    
    log_info "Inizializzazione Git completata con successo"
    return 0
}

# Sincronizza i post dalla sorgente alla destinazione
sync_posts() {
    if is_step_completed "sync_posts" && [ "$FORCE_RERUN" != "true" ]; then
        log_info "Il passaggio sync_posts è già stato completato. Saltando..."
        return 0
    fi
    
    log_info "Sincronizzazione dei post da origine a destinazione..."
    check_dir "$SOURCE_PATH" "Origine" false
    check_dir "$DESTINATION_PATH" "Destinazione" true
    
    # Crea un backup prima della sincronizzazione
    local backup_dir="${TEMP_BACKUP_DIR}/posts_backup_$(date +%Y%m%d_%H%M%S)"
    log_info "Creazione backup in $backup_dir"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY-RUN] Eseguo: mkdir -p $backup_dir"
        log_info "[DRY-RUN] Eseguo: cp -r $DESTINATION_PATH $backup_dir"
        log_info "[DRY-RUN] Eseguo: rsync -av --delete $SOURCE_PATH/ $DESTINATION_PATH/"
    else
        mkdir -p "$backup_dir" || {
            log_error "Impossibile creare directory di backup: $backup_dir"
            return 1
        }
        
        if [ -d "$DESTINATION_PATH" ] && [ "$(ls -A "$DESTINATION_PATH" 2>/dev/null)" ]; then
            cp -r "$DESTINATION_PATH/." "$backup_dir/" || {
                log_warning "Impossibile creare backup completo. Continuando comunque..."
            }
        else
            log_warning "Directory di destinazione vuota, nessun backup necessario"
        fi
        
        log_info "Esecuzione sincronizzazione con rsync..."
        run_with_timeout $DEFAULT_TIMEOUT rsync -av --delete "${SOURCE_PATH}/" "${DESTINATION_PATH}/" || {
            log_error "Sincronizzazione rsync fallita"
            
            # Tentativo di recupero da backup in caso di errore
            log_warning "Tentativo di recupero dal backup..."
            rm -rf "$DESTINATION_PATH"/*
            cp -r "$backup_dir/." "$DESTINATION_PATH/" || {
                log_error "Recupero dal backup fallito"
                return 1
            }
            log_info "Recupero dal backup completato"
            return 1
        }
    fi
    
    # Verifica l'integrità dopo la sincronizzazione
    if [ "$DRY_RUN" != "true" ]; then
        local src_files=$(find "$SOURCE_PATH" -type f -name "*.md" | wc -l)
        local dest_files=$(find "$DESTINATION_PATH" -type f -name "*.md" | wc -l)
        
        log_info "File trovati - Origine: $src_files, Destinazione: $dest_files"
        
        if [ $src_files -ne $dest_files ]; then
            log_warning "Numero di file diverso dopo la sincronizzazione"
        fi
        
        update_checkpoint "sync_posts"
    fi
    
    log_info "Sincronizzazione posts completata con successo"
    return 0
}

# Ottieni la data di creazione di un file
get_creation_date() {
    local file="$1"
    if [ ! -f "$file" ]; then
        log_warning "File non trovato per get_creation_date: $file"
        echo "$(date +%Y-%m-%d)"  # Data di fallback
        return
    }
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        stat -f "%Sm" -t "%Y-%m-%d" "$file"
    else
        # Linux - usa mtime se ctime non è disponibile
        local date=$(stat --format="%w" "$file" 2>/dev/null)
        if [ -z "$date" ] || [[ "$date" == "-" ]]; then
            stat --format="%y" "$file" | cut -d' ' -f1
        else
            echo "$date" | cut -d' ' -f1
        fi
    fi
}

# Trova un file immagine nella directory di origine
find_image() {
    local post_name="$1"
    find "$SOURCE_PATH" -type f -regex ".*/${post_name}\..*" | head -n 1
}

# Genera hash per i file nella directory di destinazione
generate_file_hashes() {
    if is_step_completed "generate_file_hashes" && [ "$FORCE_RERUN" != "true" ]; then
        log_info "Il passaggio generate_file_hashes è già stato completato. Saltando..."
        return 0
    fi
    
    log_info "Generazione hash per i file nella directory di destinazione: $DESTINATION_PATH"
    check_command python3
    
    if ! check_file "$HASH_GENERATOR_SCRIPT" "Generatore di hash"; then
        return 1
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY-RUN] Eseguo: python3 $HASH_GENERATOR_SCRIPT $DESTINATION_PATH"
    else
        log_info "Esecuzione dello script di generazione hash..."
        run_with_timeout $DEFAULT_TIMEOUT python3 "$HASH_GENERATOR_SCRIPT" "$DESTINATION_PATH" || {
            log_error "Generazione hash fallita"
            return 1
        }
        
        # Ricarica gli hash dopo la generazione
        load_file_hashes
        
        update_checkpoint "generate_file_hashes"
    fi
    
    log_info "Hash dei file generati con successo"
    return 0
}

# Aggiorna il frontmatter
update_frontmatter() {
    if is_step_completed "update_frontmatter" && [ "$FORCE_RERUN" != "true" ]; then
        log_info "Il passaggio update_frontmatter è già stato completato. Saltando..."
        return 0
    fi
    
    log_info "Aggiornamento frontmatter per i file in $DESTINATION_PATH"
    check_command python3
    
    if ! check_file "$UPDATE_POST_FRONTMATTER" "Update frontmatter"; then
        return 1
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY-RUN] Eseguo: python3 $UPDATE_POST_FRONTMATTER $DESTINATION_PATH $hash_file"
    else
        log_info "Esecuzione dello script di aggiornamento frontmatter..."
        run_with_timeout $DEFAULT_TIMEOUT python3 "$UPDATE_POST_FRONTMATTER" "$DESTINATION_PATH" "$hash_file" || {
            log_error "Aggiornamento frontmatter fallito"
            return 1
        }
        
        update_checkpoint "update_frontmatter"
    fi
    
    log_info "Aggiornamento frontmatter completato con successo"
    return 0
}

# Processa i file Markdown con images.py
process_markdown() {
    if is_step_completed "process_markdown" && [ "$FORCE_RERUN" != "true" ]; then
        log_info "Il passaggio process_markdown è già stato completato. Saltando..."
        return 0
    fi
    
    log_info "Elaborazione file Markdown con images.py..."
    
    if ! check_file "$IMAGES_SCRIPT_PATH" "Script images.py"; then
        return 1
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY-RUN] Eseguo: python3 $IMAGES_SCRIPT_PATH"
    else
        log_info "Esecuzione dello script di elaborazione immagini..."
        run_with_timeout $DEFAULT_TIMEOUT python3 "$IMAGES_SCRIPT_PATH" || {
            log_error "Elaborazione Markdown fallita"
            return 1
        }
        
        update_checkpoint "process_markdown"
    fi
    
    log_info "Elaborazione Markdown completata con successo"
    return 0
}

# Compila il sito Hugo
build_hugo_site() {
    if is_step_completed "build_hugo_site" && [ "$FORCE_RERUN" != "true" ]; then
        log_info "Il passaggio build_hugo_site è già stato completato. Saltando..."
        return 0
    fi
    
    log_info "Compilazione del sito Hugo..."
    check_command hugo
    check_dir "$BLOG_DIR" "Blog" false
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY-RUN] Eseguo: hugo --source $BLOG_DIR"
    else
        log_info "Esecuzione della compilazione Hugo..."
        run_with_timeout $DEFAULT_TIMEOUT hugo --source "$BLOG_DIR" || {
            log_error "Compilazione Hugo fallita"
            return 1
        }
        
        # Verifica che la directory public sia stata creata
        if [ ! -d "$BLOG_DIR/public" ]; then
            log_error "Compilazione Hugo completata, ma la directory 'public' non è stata creata"
            return 1
        }
        
        # Verifica il contenuto della directory public
        local public_files=$(find "$BLOG_DIR/public" -type f | wc -l)
        log_info "Directory public contiene $public_files file"
        
        if [ $public_files -eq 0 ]; then
            log_warning "La directory public è vuota dopo la compilazione Hugo"
        fi
        
        update_checkpoint "build_hugo_site"
    fi
    
    log_info "Compilazione Hugo completata con successo"
    return 0
}

# Prepara e commit le modifiche in Git
stage_and_commit_changes() {
    if is_step_completed "stage_and_commit_changes" && [ "$FORCE_RERUN" != "true" ]; then
        log_info "Il passaggio stage_and_commit_changes è già stato completato. Saltando..."
        return 0
    fi
    
    log_info "Preparazione delle modifiche per Git..."
    
    # Passa alla directory del repository
    cd "$REPO_PATH" || {
        log_error "Impossibile cambiare directory in $REPO_PATH"
        return 1
    }
    
    # Controlla se ci sono modifiche
    local has_changes=false
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY-RUN] Controllo delle modifiche Git..."
        log_info "[DRY-RUN] Eseguo: git add ."
        log_info "[DRY-RUN] Eseguo: git commit -m 'Aggiornamento blog del $(date +'%Y-%m-%d %H:%M:%S')'"
    else
        # Verifica se ci sono modifiche non tracciate o nell'area di staging
        if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
            has_changes=true
            log_info "Rilevate modifiche da committare"
            
            # Aggiungi tutte le modifiche all'area di staging
            run_with_timeout $DEFAULT_GIT_TIMEOUT git add . || {
                log_error "Impossibile preparare le modifiche"
                return 1
            }
            
            # Crea il commit
            local commit_message="Aggiornamento blog del $(date +'%Y-%m-%d %H:%M:%S')"
            log_info "Creazione commit con messaggio: $commit_message"
            
            run_with_timeout $DEFAULT_GIT_TIMEOUT git commit -m "$commit_message" || {
                log_error "Creazione commit fallita"
                return 1
            }
        else
            log_info "Nessuna modifica da committare"
        fi
        
        update_checkpoint "stage_and_commit_changes"
    fi
    
    log_info "Preparazione e commit delle modifiche completati con successo"
    return 0
}

# Invia le modifiche al branch main su GitHub
push_to_main() {
    if is_step_completed "push_to_main" && [ "$FORCE_RERUN" != "true" ]; then
        log_info "Il passaggio push_to_main è già stato completato. Saltando..."
        return 0
    fi
    
    log_info "Invio delle modifiche al branch main su GitHub..."
    
    # Passa alla directory del repository
    cd "$REPO_PATH" || {
        log_error "Impossibile cambiare directory in $REPO_PATH"
        return 1
    }
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY-RUN] Eseguo: git checkout main"
        log_info "[DRY-RUN] Eseguo: git pull origin main --rebase"
        log_info "[DRY-RUN] Eseguo: git push origin main"
    else
        # Verifica l'esistenza del branch main
        if git rev-parse --verify main &>/dev/null; then
            log_info "Passaggio al branch main..."
            run_with_timeout $DEFAULT_GIT_TIMEOUT git checkout main || {
                log_error "Impossibile passare al branch main"
                return 1
            }
        else
            # Se il branch main non esiste, crealo
            log_info "Il branch main non esiste, creazione in corso..."
            run_with_timeout $DEFAULT_GIT_TIMEOUT git checkout -b main || {
                log_error "Impossibile creare il branch main"
                return 1
            }
        fi
        
        # Tentativo di pull per evitare conflitti
        log_info "Pull dal repository remoto per aggiornamenti..."
        if run_with_timeout $DEFAULT_GIT_TIMEOUT git pull origin main --rebase; then
            log_info "Pull completato con successo"
        else
            log_warning "Pull fallito, potrebbe non esserci un branch remoto o potrebbero esserci conflitti"
            # Continuiamo comunque, potrebbe essere il primo push
        fi
        
        # Push al repository remoto
        log_info "Push al branch main..."
        run_with_timeout $DEFAULT_GIT_TIMEOUT git push origin main || {
            log_error "Push al branch main fallito"
            return 1
        }
        
        update_checkpoint "push_to_main"
    fi
    
    log_info "Push al branch main completato con successo"
    return 0
}

# Distribuisci la cartella public al branch hostinger
deploy_to_hostinger() {
    if is_step_completed "deploy_to_hostinger" && [ "$FORCE_RERUN" != "true" ]; then
        log_info "Il passaggio deploy_to_hostinger è già stato completato. Saltando..."
        return 0
    fi
    
    log_info "Distribuzione della cartella public al branch hostinger..."
    
    # Passa alla directory del repository
    cd "$REPO_PATH" || {
        log_error "Impossibile cambiare directory in $REPO_PATH"
        return 1
    }
    
    # Verifica l'esistenza della directory public
    if [ ! -d "$BLOG_DIR/public" ]; then
        log_error "Directory public non trovata: $BLOG_DIR/public"
        return 1
    }
    
    log_debug "Directory corrente: $(pwd)"
    log_debug "Contenuto directory public: $(find "$BLOG_DIR/public" -type f | wc -l) file"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY-RUN] Eliminazione branch temporaneo hostinger-deploy (se esiste)..."
        log_info "[DRY-RUN] Eseguo: git subtree split --prefix \"CS-Topics/public\" -b hostinger-deploy"
        log_info "[DRY-RUN] Eseguo: git push origin hostinger-deploy:hostinger --force"
        log_info "[DRY-RUN] Eseguo: git branch -D hostinger-deploy"
    else
        # Controlla ed elimina il branch temporaneo se esiste
        if git rev-parse --verify hostinger-deploy &>/dev/null; then
            log_info "Eliminazione branch temporaneo hostinger-deploy esistente..."
            run_with_timeout $DEFAULT_GIT_TIMEOUT git branch -D hostinger-deploy || {
                log_error "Impossibile eliminare il branch hostinger-deploy esistente"
                return 1
            }
        }
        
        # Crea un nuovo branch 'hostinger-deploy' dalla directory 'public'
        log_info "Creazione branch hostinger-deploy da CS-Topics/public..."
        run_with_timeout $DEFAULT_GIT_TIMEOUT git subtree split --prefix "CS-Topics/public" -b hostinger-deploy || {
            log_error "git subtree split fallito"
            return 1
        }
        
        # Push del branch 'hostinger-deploy' al branch 'hostinger' su origin
        log_info "Push del branch hostinger-deploy al branch hostinger su origin..."
        run_with_timeout $DEFAULT_GIT_TIMEOUT git push origin hostinger-deploy:hostinger --force || {
            log_error "Push al branch hostinger fallito"
            return 1
        }
        
        # Elimina il branch temporaneo 'hostinger-deploy'
        log_info "Eliminazione branch temporaneo hostinger-deploy..."
        run_with_timeout $DEFAULT_GIT_TIMEOUT git branch -D hostinger-deploy || {
            log_warning "Impossibile eliminare il branch hostinger-deploy dopo la distribuzione"
            # Non consideriamo questo un errore fatale
        }
        
        update_checkpoint "deploy_to_hostinger"
    fi
    
    log_info "Distribuzione al branch hostinger completata con successo"
    return 0
}

# ======================================================= #
# Esecuzione di tutti i passaggi in sequenza
# ======================================================= #

run_all_steps() {
    log_info "Esecuzione di tutti i passaggi in sequenza..."
    
    local failed=false
    
    # Array dei passaggi da eseguire
    local steps=(
        "initialize_git"
        "sync_posts"
        "generate_file_hashes"
        "update_frontmatter"
        "process_markdown"
        "build_hugo_site"
        "stage_and_commit_changes"
        "push_to_main"
        "deploy_to_hostinger"
    )
    
    # Esegui tutti i passaggi
    for step in "${steps[@]}"; do
        log_info "========== Inizio passaggio: $step =========="
        if $step; then
            log_info "========== Passaggio completato: $step =========="
        else
            log_error "========== Passaggio fallito: $step =========="
            failed=true
            break
        fi
    done
    
    if [ "$failed" = "true" ]; then
        log_error "Esecuzione interrotta a causa di un errore"
        return 1
    else
        log_info "Tutti i passaggi completati con successo"
        return 0
    fi
}

# ======================================================= #
# Analisi degli argomenti e chiamate delle funzioni
# ======================================================= #

FORCE_RERUN=false  # Forza la riesecuzione di passaggi già completati

# Analisi degli argomenti della riga di comando
DRY_RUN=false  # Definiamo DRY_RUN prima di analizzare gli argomenti

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
            shift
            ;;
        --preserve-backup)
            PRESERVE_BACKUP=true
            shift
            ;;
        --force)
            FORCE_RERUN=true
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --reset-checkpoint)
            reset_checkpoint
            shift
            ;;
        --help|-h)
            usage
            ;;
        -*)
            log_error "Opzione sconosciuta: $1"
            usage
            ;;
        *)
            break
            ;;
    esac
done

# Crea directory di backup se necessario
if [ "$DRY_RUN" != "true" ]; then
    mkdir -p "$TEMP_BACKUP_DIR" || {
        log_error "Impossibile creare directory di backup: $TEMP_BACKUP_DIR"
        exit 1
    }
fi

# Carica gli hash dei file
load_file_hashes

# Se ci sono argomenti rimanenti, esegui i comandi specificati
if [[ $# -gt 0 ]]; then
    case "$1" in
        generate_file_hashes|initialize_git|sync_posts|update_frontmatter|process_markdown|build_hugo_site|stage_and_commit_changes|push_to_main|deploy_to_hostinger)
            "$1"
            exit $?
            ;;
        all)
            run_all_steps
            exit $?
            ;;
        help)
            usage
            ;;
        *)
            log_error "Comando sconosciuto: $1"
            usage
            ;;
    esac
else
    # Se non sono stati specificati comandi, esegui tutti i passaggi
    run_all_steps
fi

# Log finale
log_info "Script completato. Controlla $LOG_FILE per i dettagli."