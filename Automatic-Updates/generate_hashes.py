#!/usr/bin/env python3

import sys
import os
import hashlib

HASH_FILE = ".file_hashes"

def calculate_hash(file_path):
    # Calculate the SHA256 hash of a file
    sha256 = hashlib.sha256()
    with open(file_path, "rb") as f:
        for block in iter(lambda: f.read(65536), b""):
            sha256.update(block)
    return sha256.hexdigest()

def load_existing_hashes(hash_file):
    # Load existing hashes from a file
    if not os.path.exists(hash_file):
        return {}
    hashes = {}
    with open(hash_file, "r", encoding="utf-8") as f:
        for line in f:
            file_path, file_hash = line.strip().split("\t")
            hashes[file_path] = file_hash
    return hashes

def save_hashes(hash_file, hashes):
    # Save updated hashes to a file for future comparison
    with open(hash_file, "w", encoding="utf-8") as f:
        for file_path, file_hash in hashes.items():
            f.write(f"{file_path}\t{file_hash}\n")

def update_hashes(directory):
    # Update hashes for Markdown files in a directory
    existing_hashes = load_existing_hashes(HASH_FILE)
    current_hashes = {}

    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".md"):
                file_path = os.path.join(root, file)
                current_hash = calculate_hash(file_path)
                current_hashes[file_path] = current_hash

    # Remove hashes of files that are no longer present
    updated_hashes = {**existing_hashes, **current_hashes}
    for file_path in list(updated_hashes.keys()):
        if file_path not in current_hashes:
            del updated_hashes[file_path]

    # Save updated hashes
    save_hashes(HASH_FILE, updated_hashes)
    return updated_hashes

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: update_hashes.py <directory>", file=sys.stderr)
        sys.exit(1)

    directory = sys.argv[1]
    if not os.path.isdir(directory):
        print(f"Error: {directory} is not a valid directory.", file=sys.stderr)
        sys.exit(1)

    updated_hashes = update_hashes(directory)
    print(f"Updated hashes for {len(updated_hashes)} files.")
