#!/usr/bin/env python3

import sys
import os
from datetime import datetime
import hashlib
from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import DoubleQuotedScalarString
from io import StringIO

# ================================ #
# Useful functions

def calculate_hash(file_path):
    """
    Calculate the SHA-256 hash of a file.
    Args:
        file_path (str): The path to the file for which the hash is to be calculated.
    Returns:
        str: The SHA-256 hash of the file in hexadecimal format if successful.
        None: If an error occurs during the hash calculation.
    Raises:
        Exception: If an error occurs while reading the file or calculating the hash, 
                   an error message is printed and None is returned.
    """
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
    """
    Loads file hashes from a specified hash file.
    This function reads a hash file where each line contains a file path and its corresponding hash,
    separated by a tab character. It returns a dictionary mapping absolute file paths to their hashes.
    Args:
        hash_file (str): The path to the hash file.
    Returns:
        dict: A dictionary where the keys are absolute file paths and the values are their corresponding hashes.
    Raises:
        None
    Notes:
        - If the hash file does not exist, an informational message is printed and an empty dictionary is returned.
        - If a line in the hash file is malformed (i.e., does not contain exactly two tab-separated values),
          a warning message is printed and the line is skipped.
    """
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
        print("[INFO] Hash file non trovato. Verranno processati tutti i file.")
    return hashes

def save_hashes(hashes, hash_file):
    """
    Saves the given dictionary of file paths and their corresponding hashes to a specified file.
    Args:
        hashes (dict): A dictionary where keys are file paths (str) and values are their corresponding hashes (str).
        hash_file (str): The path to the file where the hashes will be saved.
    Raises:
        Exception: If there is an error while writing to the file, an exception is caught and an error message is printed.
    """
    try:
        with open(hash_file, "w", encoding="utf-8") as f:
            for file_path, file_hash in hashes.items():
                f.write(f"{file_path}\t{file_hash}\n")
    except Exception as e:
        print(f"[ERROR] Salvataggio degli hash fallito: {e}")

def read_markdown_file(file_path):
    """
    Reads the content of a markdown file.
    Args:
        file_path (str): The path to the markdown file.
    Returns:
        str: The content of the file if read successfully, otherwise None.
    Raises:
        Exception: If there is an error reading the file, an error message is printed and None is returned.
    """
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
        return content
    except Exception as e:
        print(f"[ERROR] Lettura del file fallita per {file_path}: {e}")
        return None

def split_frontmatter(content, file_path):
    """
    Splits the frontmatter from the content of a file.
    Args:
        content (str): The content of the file as a string.
        file_path (str): The path to the file being processed.
    Returns:
        tuple: A tuple containing the frontmatter and the remaining content.
               If no valid frontmatter is found, returns (None, None).
    Notes:
        - The function expects the frontmatter to be delimited by "---" at the beginning and end.
        - If the content does not start with "---", it is considered to have no frontmatter.
        - If the frontmatter delimiters are not found correctly, it returns (None, None) and logs an informational message.
    """
    if not content.startswith("---"):
        print(f"[INFO] Saltato {file_path}: No frontmatter trovato.")
        return None, None
    
    parts = content.split("---", 2)
    if len(parts) < 3:
        print(f"[INFO] Saltato {file_path}: Delimitatore del frontmatter non trovato correttamente.")
        return None, None
    
    return parts[1], parts[2]

def parse_yaml_frontmatter(frontmatter_text, file_path):
    """
    Parses the YAML frontmatter from a given text.
    Args:
        frontmatter_text (str): The text containing the YAML frontmatter to be parsed.
        file_path (str): The path of the file being processed, used for error reporting.
    Returns:
        dict: A dictionary containing the parsed YAML data if successful.
        None: If parsing fails, returns None and prints an error message.
    """
    yaml = YAML()
    yaml.preserve_quotes = True
    try:
        data = yaml.load(frontmatter_text) or {}
        return data
    except Exception as e:
        print(f"[ERROR] Parsing YAML fallito per {file_path}: {e}")
        return None

def update_title_and_date(data, file_path):
    """
    Updates the 'title' and 'date' fields in the provided data dictionary if they are missing or empty.
    Args:
        data (dict): The frontmatter data of a markdown file.
        file_path (str): The path to the markdown file.
    Returns:
        bool: True if either the 'title' or 'date' fields were added or modified, False otherwise.
    The function performs the following actions:
    - If the 'title' field is missing or empty, it sets the 'title' to the file name (without extension) 
      with underscores replaced by spaces and capitalized.
    - If the 'date' field is missing or empty, it sets the 'date' to the current date and time in ISO format.
    - Prints an informational message indicating the changes made to the 'title' and 'date' fields.
    """
    modified = False
    if "title" not in data or not data["title"]:
        default_title = os.path.basename(file_path).replace(".md", "").replace("_", " ").title()
        data["title"] = DoubleQuotedScalarString(default_title)
        modified = True
        print(f"[INFO] Aggiunto 'title' a {file_path}: {default_title}")

    if "date" not in data or not data["date"]:
        current_date = datetime.now().isoformat()
        data["date"] = DoubleQuotedScalarString(current_date)
        modified = True
        print(f"[INFO] Aggiunto 'date' a {file_path}: {current_date}")
    
    return modified

def update_categories(data, file_path):
    """
    Updates the 'categories' field in the provided data dictionary based on certain conditions.
    Args:
        data (dict): The dictionary containing the frontmatter data.
        file_path (str): The path to the file being processed.
    Returns:
        bool: True if the data was modified, False otherwise.
    The function performs the following operations:
    1. If the 'categories' field exists and is a list:
        - Removes any empty or non-string categories.
        - If the resulting list is empty, the 'categories' field is removed.
        - If the list is modified, updates the 'categories' field with the new list.
    2. If the 'categories' field does not exist or is removed:
        - Adds a default category 'Uncategorized'.
    Prints information messages about the modifications made to the 'categories' field.
    """
    modified = False
    if "categories" in data:
        original_categories = data["categories"]
        if isinstance(original_categories, list):
            new_categories = [cat for cat in original_categories if isinstance(cat, str) and cat.strip()]
            if not new_categories:
                del data["categories"]
                modified = True
                print(f"[INFO] Rimosse categorie vuote da {file_path}.")
            elif new_categories != original_categories:
                data["categories"] = new_categories
                modified = True
                print(f"[INFO] Aggiornate categorie per {file_path}.")
        else:
            del data["categories"]
            modified = True
            print(f"[INFO] Rimosso campo 'categories' non valido da {file_path}.")

    if "categories" not in data:
        data["categories"] = DoubleQuotedScalarString("Uncategorized")
        modified = True
        print(f"[INFO] Aggiunta categoria predefinita a {file_path}: Uncategorized")
    
    return modified

def save_frontmatter(data, body, file_path):
    """
    Save the frontmatter and body content to a specified file.
    This function takes YAML frontmatter data and a body of text, formats them
    appropriately, and writes the combined content to a file at the given file path.
    Args:
        data (dict): The frontmatter data to be written in YAML format.
        body (str): The body content to be appended after the frontmatter.
        file_path (str): The path to the file where the content should be saved.
    Returns:
        bool: True if the file was saved successfully, False otherwise.
    Raises:
        Exception: If an error occurs during the file writing process, it will be caught
                   and an error message will be printed.
    """
    try:
        stream = StringIO()
        yaml = YAML()
        yaml.preserve_quotes = True
        yaml.dump(data, stream)
        updated_frontmatter = stream.getvalue().rstrip()
        
        updated_content = f"---\n{updated_frontmatter}\n---{''+body if body.startswith('\n') else '\n'+body}"
        
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(updated_content)
        return True
    except Exception as e:
        print(f"[ERROR] Salvataggio del file fallito per {file_path}: {e}")
        return False

def update_frontmatter(file_path):
    """
    Updates the frontmatter of a markdown file.
    This function reads the content of a markdown file, parses its frontmatter,
    updates the title, date, and categories if necessary, and then saves the
    updated frontmatter back to the file.
    Args:
        file_path (str): The path to the markdown file to be updated.
    Returns:
        bool: True if the frontmatter was successfully updated and saved, 
              False otherwise.
    """
    content = read_markdown_file(file_path)
    if content is None:
        return False

    frontmatter_text, body = split_frontmatter(content, file_path)
    if frontmatter_text is None:
        return False

    data = parse_yaml_frontmatter(frontmatter_text, file_path)
    if data is None:
        return False

    modified = update_title_and_date(data, file_path)
    modified = update_categories(data, file_path) or modified

    if not modified:
        return False

    return save_frontmatter(data, body, file_path)

def process_markdown_file(file_path, previous_hash):
    """
    Processes a markdown file to update its frontmatter if necessary.
    Args:
        file_path (str): The path to the markdown file to be processed.
        previous_hash (str): The hash of the file content before processing.
    Returns:
        tuple: A tuple containing:
            - current_hash (str): The hash of the file content after processing.
            - file_path (str or None): The file path if the frontmatter was updated, otherwise None.
            - modified (bool): True if the frontmatter was updated, otherwise False.
    """
    current_hash = calculate_hash(file_path)
    if current_hash is None:
        return None, None, False

    if previous_hash == current_hash:
        return current_hash, None, False

    print(f"[INFO] Processando: {file_path}")
    modified = update_frontmatter(file_path)
    
    if modified:
        new_hash = calculate_hash(file_path)
        print(f"[INFO] Frontmatter aggiornato per: {file_path}")
        return new_hash, file_path, True
    
    print(f"[INFO] Nessuna modifica necessaria per: {file_path}")
    return current_hash, None, False

def get_markdown_files(directory):
    """
    Generator function to yield the absolute paths of all markdown files in a given directory.
    Args:
        directory (str): The root directory to search for markdown files.
    Yields:
        str: The absolute path of each markdown file found in the directory.
    """
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".md"):
                yield os.path.abspath(os.path.join(root, file))

def print_results(modified_files):
    if modified_files:
        print("\n[INFO] File modificati:")
        for file in modified_files:
            print(f" - {file}")
    else:
        print("\n[INFO] Nessun file è stato modificato.")

def main(directory, hash_file):
    """
    Main function to process markdown files in a directory, update their hashes, and print the results.
    Args:
        directory (str): The path to the directory containing markdown files.
        hash_file (str): The path to the file where hashes are stored.
    Returns:
        None
    """
    directory = os.path.abspath(directory)
    print(f"[INFO] Processando la directory: {directory}")

    hashes = load_hashes(hash_file)
    updated_hashes = {}
    modified_files = []

    for file_path in get_markdown_files(directory):
        new_hash, modified_file, was_modified = process_markdown_file(file_path, hashes.get(file_path))
        if new_hash:
            updated_hashes[file_path] = new_hash
        if was_modified and modified_file:
            modified_files.append(modified_file)

    save_hashes(updated_hashes, hash_file)
    print("[INFO] Aggiornamento degli hash completato.")
    print_results(modified_files)

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
