#!/usr/bin/env python3

import sys
import os
from datetime import datetime
import hashlib
from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import DoubleQuotedScalarString
from io import StringIO

# ================================ #
# Funzioni Utili

def calculate_hash(file_path):
    # Calculate the SHA256 hash of a file
    sha256 = hashlib.sha256()
    try:
        with open(file_path, "rb") as f:
            for block in iter(lambda: f.read(65536), b""):
                sha256.update(block)
        return sha256.hexdigest()
    except Exception as e:
        print(f"[ERROR] Calcolo hash fallito per {file_path}: {e}")
        return None

def load_hashes(hash_file):
    # Load existing hashes from a file
    hashes = {}
    if os.path.exists(hash_file):
        with open(hash_file, "r", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split("\t")
                if len(parts) != 2:
                    print(f"[WARNING] Linea malformata nello hash file: {line.strip()}")
                    continue  # Jump malformed lines
                file_path, file_hash = parts
                abs_path = os.path.abspath(file_path)
                hashes[abs_path] = file_hash
    else:
        print(f"[INFO] Hash file non trovato. Verranno processati tutti i file.")
    return hashes

def save_hashes(hashes, hash_file):
    # Save updated hashes to a file for future comparison
    try:
        with open(hash_file, "w", encoding="utf-8") as f:
            for file_path, file_hash in hashes.items():
                f.write(f"{file_path}\t{file_hash}\n")
    except Exception as e:
        print(f"[ERROR] Salvataggio degli hash fallito: {e}")

def update_frontmatter(file_path):
    # Update the frontmatter of a Markdown file if necessary
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        print(f"[ERROR] Lettura del file fallita per {file_path}: {e}")
        return False

    if not content.startswith("---"):
        print(f"[INFO] Saltato {file_path}: No frontmatter trovato.")
        return False

    # Dividi il contenuto in frontmatter e corpo
    parts = content.split("---", 2)
    if len(parts) < 3:
        print(f"[INFO] Saltato {file_path}: Delimitatore del frontmatter non trovato correttamente.")
        return False

    frontmatter_text = parts[1]
    body = parts[2]

    yaml = YAML()
    yaml.preserve_quotes = True
    try:
        data = yaml.load(frontmatter_text)
    except Exception as e:
        print(f"[ERROR] Parsing YAML fallito per {file_path}: {e}")
        return False

    if data is None:
        data = {}

    modified = False

    # Check and update the 'title' field
    if "title" not in data or not data["title"]:
        default_title = os.path.basename(file_path).replace(".md", "").replace("_", " ").title()
        data["title"] = DoubleQuotedScalarString(default_title)
        modified = True
        print(f"[INFO] Aggiunto 'title' a {file_path}: {default_title}")

    # Verify and update the 'date' field
    if "date" not in data or not data["date"]:
        current_date = datetime.now().isoformat()
        data["date"] = DoubleQuotedScalarString(current_date)
        modified = True
        print(f"[INFO] Aggiunto 'date' a {file_path}: {current_date}")

    # ** Manage empty or malformed 'categories' field **
    if "categories" in data:
        original_categories = data["categories"]
        if isinstance(original_categories, list):
            # Remove empty categories
            new_categories = [cat for cat in original_categories if isinstance(cat, str) and cat.strip()]
            if not new_categories:
                del data["categories"]
                modified = True
                print(f"[INFO] Rimosse categorie vuote da {file_path}.")
            else:
                data["categories"] = new_categories
                if new_categories != original_categories:
                    modified = True
                    print(f"[INFO] Aggiornate categorie per {file_path}.")
        elif original_categories is None:
            # 'categories' is None, remove it
            del data["categories"]
            modified = True
            print(f"[INFO] Rimosso campo 'categories' impostato a None da {file_path}.")
        else:
            # 'categories' is not a list, remove it
            del data["categories"]
            modified = True
            print(f"[INFO] Rimosso campo 'categories' non valido da {file_path}.")

    # ** If 'categories' is still not present or empty, add a default category **
    if "categories" not in data:
        data["categories"] = DoubleQuotedScalarString("Uncategorized")
        modified = True
        print(f"[INFO] Aggiunta categoria predefinita a {file_path}: Uncategorized")

    if not modified:
        # No modification needed
        return False

    # Dump the updated frontmatter
    try:
        stream = StringIO()
        yaml.dump(data, stream)
        updated_frontmatter = stream.getvalue().rstrip()
    except Exception as e:
        print(f"[ERROR] Dumping YAML fallito per {file_path}: {e}")
        return False

    # Rebuild the content with updated frontmatter
    if body.startswith('\n'):
        updated_content = f"---\n{updated_frontmatter}\n---{body}"
    else:
        updated_content = f"---\n{updated_frontmatter}\n---\n{body}"

    # Write the updated content to the file
    try:
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(updated_content)
    except Exception as e:
        print(f"[ERROR] Scrittura del file fallita per {file_path}: {e}")
        return False

    return True  # Modifications were made

def main(directory, hash_file):
    # Primary function to process files in the specified directory
    directory = os.path.abspath(directory)
    print(f"[INFO] Processando la directory: {directory}")

    hashes = load_hashes(hash_file)
    updated_hashes = {}
    modified_files = []

    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".md"):
                file_path = os.path.abspath(os.path.join(root, file))
                current_hash = calculate_hash(file_path)
                if current_hash is None:
                    # Skip files with hash errors
                    continue

                previous_hash = hashes.get(file_path)

                if previous_hash != current_hash:
                    print(f"[INFO] Processando: {file_path}")
                    modified = update_frontmatter(file_path)
                    if modified:
                        modified_files.append(file_path)
                        # Re-calculate the hash after modification
                        new_hash = calculate_hash(file_path)
                        if new_hash:
                            updated_hashes[file_path] = new_hash
                        print(f"[INFO] Frontmatter aggiornato per: {file_path}")
                    else:
                        print(f"[INFO] Nessuna modifica necessaria per: {file_path}")
                        # Update the current hash
                        updated_hashes[file_path] = current_hash
                else:
                    # No modification detected
                    updated_hashes[file_path] = current_hash

    save_hashes(updated_hashes, hash_file)
    print("[INFO] Aggiornamento degli hash completato.")

    if modified_files:
        print("\n[INFO] File modificati:")
        for file in modified_files:
            print(f" - {file}")
    else:
        print("\n[INFO] Nessun file è stato modificato.")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: update_frontmatter.py <directory> <hash_file>", file=sys.stderr)
        sys.exit(1)

    target_directory = sys.argv[1]
    hash_file = sys.argv[2]
    if not os.path.isdir(target_directory):
        print(f"[ERROR] La directory specificata non esiste: {target_directory}", file=sys.stderr)
        sys.exit(1)

    main(target_directory, hash_file)
