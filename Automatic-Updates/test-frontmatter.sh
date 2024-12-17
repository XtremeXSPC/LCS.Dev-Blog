#!/bin/bash

# Input / output folders
sourcePath="${SOURCE_PATH:-$HOME/Documents/Obsidian-Vault/XSPC-Vault/Blog/posts}"
destinationPath="${DESTINATION_PATH:-$HOME/04_LCS.Blog/CS-Topics/content/posts}"

# Check if the destination folder exists
if [[ ! -d "$destinationPath" ]]; then
    echo "La cartella di destinazione non esiste: $destinationPath"
    exit 1
fi

# Function to get creation date of a file
get_creation_date() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        stat -f "%Sm" -t "%Y-%m-%d" "$1"
    else
        # Linux
        stat --format="%w" "$1" | awk '{print $1}'
    fi
}

# Elaborate each Markdown file in the Obsidian folder
for file in "$sourcePath"/*.md; do
    if [[ -f "$file" ]]; then
        filename=$(basename -- "$file")
        title="${filename%.*}"
        creation_date=$(get_creation_date "$file")

        # If creation date is not available, use the modification date
        if [[ "$creation_date" == "-" || -z "$creation_date" ]]; then
            creation_date=$(date -r "$file" +"%Y-%m-%d")
        fi

        # Read the existing frontmatter and replace only 'title' and 'date'
        awk -v new_title="$title" -v new_date="$creation_date" '
        BEGIN { in_frontmatter = 0 }
        /^---$/ {
            if (in_frontmatter == 0) {
                in_frontmatter = 1
                print
                next
            } else {
                in_frontmatter = 0
                print
                next
            }
        }
        in_frontmatter && $1 == "title:" {
            print "title: \"" new_title "\""
            next
        }
        in_frontmatter && $1 == "date:" {
            print "date: \"" new_date "\""
            next
        }
        { print }
        ' "$file" > "$destinationPath/$filename"

        echo "Updated: $filename"
    fi
done