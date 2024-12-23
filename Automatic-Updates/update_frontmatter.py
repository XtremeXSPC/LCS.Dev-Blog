#!/usr/bin/env python3

import sys
import os
import hashlib
from datetime import datetime
from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import DoubleQuotedScalarString
from io import StringIO

# ================================ #
# Utility Functions

def calculate_hash(file_path):
    """
    Calculate the SHA-256 hash of a file.

    Args:
        file_path (str): The path to the file for which the hash is to be calculated.

    Returns:
        str: The SHA-256 hash of the file in hexadecimal format if successful.
        None: If an error occurs during the hash calculation.
    """
    sha256 = hashlib.sha256()
    try:
        with open(file_path, "rb") as f:
            for block in iter(lambda: f.read(65536), b""):
                sha256.update(block)
        return sha256.hexdigest()
    except Exception as e:
        print(f"[ERROR] Failed to calculate hash for {file_path}: {e}")
        return None

def load_hashes(hash_file):
    """
    Load file hashes from a specified hash file.

    This function reads a hash file where each line contains a file path and its corresponding hash,
    separated by a tab character. It returns a dictionary mapping absolute file paths to their hashes.

    Args:
        hash_file (str): The path to the hash file.

    Returns:
        dict: A dictionary where the keys are absolute file paths and the values are their corresponding hashes.
    """
    hashes = {}
    if os.path.exists(hash_file):
        with open(hash_file, "r", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split("\t")
                if len(parts) != 2:
                    print(f"[WARNING] Malformed line in hash file: {line.strip()}")
                    continue
                file_path, file_hash = parts
                abs_path = os.path.abspath(file_path)
                hashes[abs_path] = file_hash
    else:
        print("[INFO] Hash file not found. All files will be processed.")
    return hashes

def save_hashes(hashes, hash_file):
    """
    Save the given dictionary of file paths and their corresponding hashes to a specified file.

    Args:
        hashes (dict): A dictionary where keys are file paths (str) and values are their corresponding hashes (str).
        hash_file (str): The path to the file where the hashes will be saved.
    """
    try:
        with open(hash_file, "w", encoding="utf-8") as f:
            for file_path, file_hash in hashes.items():
                f.write(f"{file_path}\t{file_hash}\n")
    except Exception as e:
        print(f"[ERROR] Failed to save hashes: {e}")

def read_markdown_file(file_path):
    """
    Read the content of a Markdown file.

    Args:
        file_path (str): The path to the Markdown file.

    Returns:
        str: The content of the file if read successfully, otherwise None.
    """
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
        return content
    except Exception as e:
        print(f"[ERROR] Failed to read file {file_path}: {e}")
        return None

def split_frontmatter(content, file_path):
    """
    Split the frontmatter from the content of a file.

    Args:
        content (str): The content of the file as a string.
        file_path (str): The path to the file being processed.

    Returns:
        tuple: A tuple containing the frontmatter and the remaining content.
               If no valid frontmatter is found, returns (None, content).
    """
    if content.startswith("---"):
        parts = content.split("---", 2)
        if len(parts) >= 3:
            return parts[1], parts[2]
        else:
            print(f"[WARNING] Frontmatter delimiter not found correctly in {file_path}.")
            return None, content
    else:
        return None, content

def parse_yaml_frontmatter(frontmatter_text, file_path):
    """
    Parse the YAML frontmatter from a given text.

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
        print(f"[ERROR] Failed to parse YAML for {file_path}: {e}")
        return None

def update_title_and_date(data, file_path):
    """
    Update the 'title' and 'date' fields in the provided data dictionary if they are missing or empty.

    Args:
        data (dict): The frontmatter data of a Markdown file.
        file_path (str): The path to the Markdown file.

    Returns:
        bool: True if either the 'title' or 'date' fields were added or modified, False otherwise.
    """
    modified = False
    if "title" not in data or not data["title"]:
        default_title = os.path.basename(file_path).replace(".md", "").replace("_", " ").title()
        data["title"] = DoubleQuotedScalarString(default_title)
        modified = True
        print(f"[INFO] Added 'title' to {file_path}: {default_title}")

    if "date" not in data or not data["date"]:
        # Ensure the date is in RFC3339 format
        current_date = datetime.utcnow().isoformat() + "Z"
        data["date"] = DoubleQuotedScalarString(current_date)
        modified = True
        print(f"[INFO] Added 'date' to {file_path}: {current_date}")
    
    return modified

def update_categories(data, file_path):
    """
    Update the 'categories' field in the provided data dictionary based on certain conditions.

    Args:
        data (dict): The dictionary containing the frontmatter data.
        file_path (str): The path to the file being processed.

    Returns:
        bool: True if the data was modified, False otherwise.
    """
    modified = False
    if "categories" in data:
        original_categories = data["categories"]
        if isinstance(original_categories, list):
            new_categories = [DoubleQuotedScalarString(cat.strip()) for cat in original_categories if isinstance(cat, str) and cat.strip()]
            if not new_categories:
                del data["categories"]
                modified = True
                print(f"[INFO] Removed empty categories from {file_path}.")
            elif new_categories != original_categories:
                data["categories"] = new_categories
                modified = True
                print(f"[INFO] Updated categories for {file_path}.")
        else:
            del data["categories"]
            modified = True
            print(f"[INFO] Removed invalid 'categories' field from {file_path}.")

    if "categories" not in data:
        data["categories"] = [DoubleQuotedScalarString("Uncategorized")]
        modified = True
        print(f"[INFO] Added default category to {file_path}: Uncategorized")

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
    """
    try:
        stream = StringIO()
        yaml = YAML()
        yaml.preserve_quotes = True
        yaml.dump(data, stream)
        updated_frontmatter = stream.getvalue().rstrip()

        # Ensure body starts with a newline
        if not body.startswith('\n'):
            body = '\n' + body

        updated_content = f"---\n{updated_frontmatter}\n---\n{body}"

        with open(file_path, "w", encoding="utf-8") as f:
            f.write(updated_content)
        return True
    except Exception as e:
        print(f"[ERROR] Failed to save file {file_path}: {e}")
        return False

def add_frontmatter_if_missing(data, body, file_path):
    """
    Add frontmatter to a file if it is missing.

    Args:
        data (dict): The frontmatter data to create.
        body (str): The body content of the file.
        file_path (str): The path to the file.

    Returns:
        bool: True if the frontmatter was added, False otherwise.
    """
    try:
        stream = StringIO()
        yaml = YAML()
        yaml.preserve_quotes = True
        yaml.dump(data, stream)
        frontmatter = stream.getvalue().rstrip()

        # Ensure body starts with a newline
        if not body.startswith('\n'):
            body = '\n' + body

        updated_content = f"---\n{frontmatter}\n---\n{body}"

        with open(file_path, "w", encoding="utf-8") as f:
            f.write(updated_content)
        print(f"[INFO] Added frontmatter to {file_path}.")
        return True
    except Exception as e:
        print(f"[ERROR] Failed to add frontmatter to {file_path}: {e}")
        return False

def update_frontmatter(file_path):
    """
    Update the frontmatter of a Markdown file. Adds frontmatter if missing.

    Args:
        file_path (str): The path to the Markdown file to be updated.

    Returns:
        bool: True if the frontmatter was successfully updated or added, False otherwise.
    """
    content = read_markdown_file(file_path)
    if content is None:
        return False

    frontmatter_text, body = split_frontmatter(content, file_path)

    if frontmatter_text is not None:
        # File already has frontmatter, update necessary fields
        data = parse_yaml_frontmatter(frontmatter_text, file_path)
        if data is None:
            return False

        modified = update_title_and_date(data, file_path)
        modified = update_categories(data, file_path) or modified

        if not modified:
            return False

        return save_frontmatter(data, body, file_path)
    else:
        # File does not have frontmatter, create it
        data = {}
        modified = False

        # Add title
        default_title = os.path.basename(file_path).replace(".md", "").replace("_", " ").title()
        data["title"] = DoubleQuotedScalarString(default_title)
        modified = True
        print(f"[INFO] Added 'title' to {file_path}: {default_title}")

        # Add date in RFC3339 format
        current_date = datetime.utcnow().isoformat() + "Z"
        data["date"] = DoubleQuotedScalarString(current_date)
        modified = True
        print(f"[INFO] Added 'date' to {file_path}: {current_date}")

        # Add default category
        data["categories"] = [DoubleQuotedScalarString("Uncategorized")]
        modified = True
        print(f"[INFO] Added default category to {file_path}: Uncategorized")

        return add_frontmatter_if_missing(data, body, file_path) if modified else False

def process_markdown_file(file_path, previous_hash):
    """
    Process a Markdown file to update its frontmatter if necessary.

    Args:
        file_path (str): The path to the Markdown file to be processed.
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

    print(f"[INFO] Processing: {file_path}")
    was_modified = update_frontmatter(file_path)

    if was_modified:
        new_hash = calculate_hash(file_path)
        print(f"[INFO] Updated frontmatter for: {file_path}")
        return new_hash, file_path, True

    print(f"[INFO] No changes needed for: {file_path}")
    return current_hash, None, False

def get_markdown_files(directory):
    """
    Generator function to yield the absolute paths of all Markdown files in a given directory.

    Args:
        directory (str): The root directory to search for Markdown files.

    Yields:
        str: The absolute path of each Markdown file found in the directory.
    """
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".md"):
                yield os.path.abspath(os.path.join(root, file))

def print_results(modified_files):
    """
    Print the results of the file processing.

    Args:
        modified_files (list): List of file paths that were modified.
    """
    if modified_files:
        print("\n[INFO] Modified files:")
        for file in modified_files:
            print(f" - {file}")
    else:
        print("\n[INFO] No files were modified.")

def main(directory, hash_file):
    """
    Main function to process Markdown files in a directory, update their hashes, and print the results.

    Args:
        directory (str): The path to the directory containing Markdown files.
        hash_file (str): The path to the file where hashes are stored.
    """
    directory = os.path.abspath(directory)
    print(f"[INFO] Processing directory: {directory}")

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
    print("[INFO] Hash update completed.")
    print_results(modified_files)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: update_frontmatter.py <directory> <hash_file>", file=sys.stderr)
        sys.exit(1)

    target_directory = sys.argv[1]
    hash_file = sys.argv[2]
    if not os.path.isdir(target_directory):
        print(f"[ERROR] Specified directory does not exist: {target_directory}", file=sys.stderr)
        sys.exit(1)

    main(target_directory, hash_file)
