#!/usr/bin/env python3

import sys
import hashlib
import os

def calculate_hash(file_path):
    """Calcola l'hash SHA256 di un file."""
    sha256 = hashlib.sha256()
    try:
        with open(file_path, 'rb') as f:
            for block in iter(lambda: f.read(65536), b''):
                sha256.update(block)
        return sha256.hexdigest()
    except Exception as e:
        print(f"Error processing {file_path}: {e}", file=sys.stderr)
        return None

def main():
    # Stampa gli argomenti ricevuti per debugging
    print(f"Arguments received: {sys.argv[1:]}", file=sys.stderr)

    if len(sys.argv) < 2:
        print("Usage: generate_hashes.py <file1> <file2> ...", file=sys.stderr)
        sys.exit(1)
    
    # Elabora ogni file passato come argomento
    for file_path in sys.argv[1:]:
        if os.path.isfile(file_path):
            hash_value = calculate_hash(file_path)
            if hash_value:
                print(f"{file_path}\t{hash_value}")
        else:
            print(f"Warning: {file_path} is not a file or does not exist.", file=sys.stderr)

if __name__ == "__main__":
    main()
