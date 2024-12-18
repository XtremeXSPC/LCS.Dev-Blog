#!/usr/bin/env python3

import sys
import os
from datetime import datetime
import hashlib
from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import DoubleQuotedScalarString
from io import StringIO

# ================================ #
# Initial Configuration

# Ensure HASH_FILE is in the same directory as the script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
HASH_FILE = os.path.join(SCRIPT_DIR, ".file_hashes")

# ================================ #
# Utility Functions

def calculate_hash(file_path):
    # Calculate SHA256 hash of a file
    sha256 = hashlib.sha256()
    try:
        with open(file_path, "rb") as f:
            for block in iter(lambda: f.read(65536), b""):
                sha256.update(block)
        return sha256.hexdigest()
    except Exception as e:
        print(f"[ERROR] Hash calculation failed for {file_path}: {e}")
        return None

def load_hashes():
    # Load existing hashes from hash file
    hashes = {}
    if os.path.exists(HASH_FILE):
        with open(HASH_FILE, "r", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split("\t")
                if len(parts) != 2:
                    print(f"[WARNING] Malformed line in hash file: {line.strip()}")
                    continue  # Skip malformed lines
                file_path, file_hash = parts
                abs_path = os.path.abspath(file_path)
                hashes[abs_path] = file_hash
    else:
        print(f"[INFO] Hash file non trovato. Verranno processati tutti i file.")
    return hashes

def save_hashes(hashes):
    # Save updated hashes to the hash file
    try:
        with open(HASH_FILE, "w", encoding="utf-8") as f:
            for file_path, file_hash in hashes.items():
                f.write(f"{file_path}\t{file_hash}\n")
    except Exception as e:
        print(f"[ERROR] Failed to save hashes: {e}")

def update_frontmatter(file_path):
    # Update the frontmatter of a Markdown file
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        print(f"[ERROR] Failed to read file {file_path}: {e}")
        return False

    if not content.startswith("---"):
        print(f"[INFO] Skipped {file_path}: No frontmatter found.")
        return False

    # Split content into frontmatter and body
    parts = content.split("---", 2)
    if len(parts) < 3:
        print(f"[INFO] Skipped {file_path}: Frontmatter delimiter not found correctly.")
        return False

    frontmatter_text = parts[1]
    body = parts[2]

    yaml = YAML()
    yaml.preserve_quotes = True
    try:
        data = yaml.load(frontmatter_text)
    except Exception as e:
        print(f"[ERROR] YAML parsing failed for {file_path}: {e}")
        return False

    if data is None:
        data = {}

    modified = False

    # Check and update 'title' field
    if "title" not in data or not data["title"]:
        default_title = os.path.basename(file_path).replace(".md", "").replace("_", " ").title()
        data["title"] = DoubleQuotedScalarString(default_title)
        modified = True
        print(f"[INFO] Added 'title' to {file_path}: {default_title}")

    # Check and update 'date' field
    if "date" not in data or not data["date"]:
        current_date = datetime.now().isoformat()
        data["date"] = DoubleQuotedScalarString(current_date)
        modified = True
        print(f"[INFO] Added 'date' to {file_path}: {current_date}")

    if not modified:
        # No modifications needed
        return False

    # Dump updated frontmatter
    try:
        stream = StringIO()
        yaml.dump(data, stream)
        updated_frontmatter = stream.getvalue().rstrip()
    except Exception as e:
        print(f"[ERROR] YAML dumping failed for {file_path}: {e}")
        return False

    # Rebuild file content
    if body.startswith('\n'):
        updated_content = f"---\n{updated_frontmatter}\n---{body}"
    else:
        updated_content = f"---\n{updated_frontmatter}\n---\n{body}"

    # Write updated content to file
    try:
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(updated_content)
    except Exception as e:
        print(f"[ERROR] Failed to write file {file_path}: {e}")
        return False

    return True

def process_file(file_path, hashes, updated_hashes, modified_files):
    current_hash = calculate_hash(file_path)
    if current_hash is None:
        return  # Skip files with hash errors

    previous_hash = hashes.get(file_path)

    if previous_hash != current_hash:
        print(f"[INFO] Processing: {file_path}")
        modified = update_frontmatter(file_path)
        if modified:
            modified_files.append(file_path)
            # Recalculate hash after modification
            new_hash = calculate_hash(file_path)
            if new_hash:
                updated_hashes[file_path] = new_hash
            print(f"[INFO] Frontmatter updated for: {file_path}")
        else:
            print(f"[INFO] No modifications needed for: {file_path}")
            # Update current hash
            updated_hashes[file_path] = current_hash
    else:
        # No changes detected
        updated_hashes[file_path] = current_hash
def main(directory):
    # Primary function that processes files in the specified directory.
    directory = os.path.abspath(directory)
    print(f"[INFO] Processando la directory: {directory}")

    hashes = load_hashes()
    updated_hashes = {}
    modified_files = []

    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".md"):
                file_path = os.path.abspath(os.path.join(root, file))
                current_hash = calculate_hash(file_path)
                if current_hash is None:
                    continue  # Jump to the next file if hash calculation fails

                previous_hash = hashes.get(file_path)

                if previous_hash != current_hash:
                    print(f"[INFO] Processando: {file_path}")
                    modified = update_frontmatter(file_path)
                    if modified:
                        modified_files.append(file_path)
                        # Recalculate hash after modification
                        new_hash = calculate_hash(file_path)
                        if new_hash:
                            updated_hashes[file_path] = new_hash
                        print(f"[INFO] Frontmatter aggiornato per: {file_path}")
                    else:
                        print(f"[INFO] Nessuna modifica necessaria per: {file_path}")
                        # Update current hash
                        updated_hashes[file_path] = current_hash
                else:

                    # No changes detected
                    updated_hashes[file_path] = current_hash

    save_hashes(updated_hashes)
    print("[INFO] Aggiornamento degli hash completato.")

    if modified_files:
        print("\n[INFO] File modificati:")
        for file in modified_files:
            print(f" - {file}")
    else:
        print("\n[INFO] Nessun file è stato modificato.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: update_frontmatter.py <directory>", file=sys.stderr)
        sys.exit(1)

    target_directory = sys.argv[1]
    if not os.path.isdir(target_directory):
        print(f"[ERROR] La directory specificata non esiste: {target_directory}", file=sys.stderr)
        sys.exit(1)

    main(target_directory)