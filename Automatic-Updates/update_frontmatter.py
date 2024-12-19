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
    """Calcola l'hash SHA256 di un file."""
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
    """Carica gli hash esistenti dal file degli hash."""
    hashes = {}
    if os.path.exists(hash_file):
        with open(hash_file, "r", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split("\t")
                if len(parts) != 2:
                    print(f"[WARNING] Linea malformata nello hash file: {line.strip()}")
                    continue  # Salta le linee malformate
                file_path, file_hash = parts
                abs_path = os.path.abspath(file_path)
                hashes[abs_path] = file_hash
    else:
        print(f"[INFO] Hash file non trovato. Verranno processati tutti i file.")
    return hashes

def save_hashes(hashes, hash_file):
    """Salva gli hash aggiornati nel file degli hash."""
    try:
        with open(hash_file, "w", encoding="utf-8") as f:
            for file_path, file_hash in hashes.items():
                f.write(f"{file_path}\t{file_hash}\n")
    except Exception as e:
        print(f"[ERROR] Salvataggio degli hash fallito: {e}")

def update_frontmatter(file_path):
    """Aggiorna il frontmatter di un file Markdown."""
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        print(f"[ERROR] Lettura del file fallita per {file_path}: {e}")
        return False  # Nessuna modifica

    if not content.startswith("---"):
        print(f"[INFO] Saltato {file_path}: No frontmatter trovato.")
        return False  # Nessuna modifica

    # Dividi il contenuto in frontmatter e corpo
    parts = content.split("---", 2)
    if len(parts) < 3:
        print(f"[INFO] Saltato {file_path}: Delimitatore del frontmatter non trovato correttamente.")
        return False  # Nessuna modifica

    frontmatter_text = parts[1]
    body = parts[2]

    yaml = YAML()
    yaml.preserve_quotes = True
    try:
        data = yaml.load(frontmatter_text)
    except Exception as e:
        print(f"[ERROR] Parsing YAML fallito per {file_path}: {e}")
        return False  # Nessuna modifica

    if data is None:
        data = {}

    modified = False

    # Verifica e aggiorna il campo 'title'
    if "title" not in data or not data["title"]:
        default_title = os.path.basename(file_path).replace(".md", "").replace("_", " ").title()
        data["title"] = DoubleQuotedScalarString(default_title)
        modified = True
        print(f"[INFO] Aggiunto 'title' a {file_path}: {default_title}")

    # Verifica e aggiorna il campo 'date'
    if "date" not in data or not data["date"]:
        current_date = datetime.now().isoformat()
        data["date"] = DoubleQuotedScalarString(current_date)
        modified = True
        print(f"[INFO] Aggiunto 'date' a {file_path}: {current_date}")

    # **Gestione delle categorie vuote o malformate**
    if "categories" in data:
        original_categories = data["categories"]
        if isinstance(original_categories, list):
            # Rimuovi categorie vuote
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
            # 'categories' è None, rimuovilo
            del data["categories"]
            modified = True
            print(f"[INFO] Rimosso campo 'categories' impostato a None da {file_path}.")
        else:
            # 'categories' non è una lista, rimuovilo
            del data["categories"]
            modified = True
            print(f"[INFO] Rimosso campo 'categories' non valido da {file_path}.")

    # **Aggiungi una categoria predefinita se manca**
    if "categories" not in data:
        data["categories"] = DoubleQuotedScalarString("Uncategorized")
        modified = True
        print(f"[INFO] Aggiunta categoria predefinita a {file_path}: Uncategorized")

    if not modified:
        # Nessuna modifica necessaria
        return False

    # Dump del frontmatter aggiornato
    try:
        stream = StringIO()
        yaml.dump(data, stream)
        updated_frontmatter = stream.getvalue().rstrip()
    except Exception as e:
        print(f"[ERROR] Dumping YAML fallito per {file_path}: {e}")
        return False

    # Ricostruisci il contenuto del file
    if body.startswith('\n'):
        updated_content = f"---\n{updated_frontmatter}\n---{body}"
    else:
        updated_content = f"---\n{updated_frontmatter}\n---\n{body}"

    # Scrivi il contenuto aggiornato nel file
    try:
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(updated_content)
    except Exception as e:
        print(f"[ERROR] Scrittura del file fallita per {file_path}: {e}")
        return False

    return True  # Modifica effettuata

def main(directory, hash_file):
    """Funzione principale che processa i file nella directory specificata."""
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
                    continue  # Salta i file con errori di hash

                previous_hash = hashes.get(file_path)

                if previous_hash != current_hash:
                    print(f"[INFO] Processando: {file_path}")
                    modified = update_frontmatter(file_path)
                    if modified:
                        modified_files.append(file_path)
                        # Ricalcola l'hash dopo la modifica
                        new_hash = calculate_hash(file_path)
                        if new_hash:
                            updated_hashes[file_path] = new_hash
                        print(f"[INFO] Frontmatter aggiornato per: {file_path}")
                    else:
                        print(f"[INFO] Nessuna modifica necessaria per: {file_path}")
                        # Aggiorna l'hash corrente
                        updated_hashes[file_path] = current_hash
                else:
                    # Nessuna modifica rilevata
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
