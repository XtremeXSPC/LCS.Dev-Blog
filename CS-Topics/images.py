import os
import re
import shutil

# Paths
posts_dir = "/Users/lcs-dev/04_LCS.Blog/CS-Topics/content/posts/"
attachments_dir = "/Users/lcs-dev/Documents/Obsidian-Vault/XSPC-Vault/00_Note_Images"
static_images_dir = "/Users/lcs-dev/04_LCS.Blog/CS-Topics/static/images/"

# Process each markdown file in the posts directory
for filename in os.listdir(posts_dir):
    if filename.endswith(".md"):
        filepath = os.path.join(posts_dir, filename)
        
        with open(filepath, "r") as file:
            content = file.read()
        
        # Find all image links in the format [[image.png]]
        images = re.findall(r'\[\[([^]]*\.png)\]\]', content)
        
        for image in images:
            # Replace with Markdown-compatible link
            markdown_image = f"![Image Description](/images/{image.replace(' ', '%20')})"
            content = content.replace(f"[[{image}]]", markdown_image)
            
            # Copy the image to the static directory
            image_source = os.path.join(attachments_dir, image)
            if os.path.exists(image_source):
                print(f"Copying {image_source} to {static_images_dir}")
                shutil.copy(image_source, static_images_dir)
            else:
                print(f"Image not found: {image_source}")

        # Write updated content back to the markdown file
        with open(filepath, "w") as file:
            file.write(content)

print("Markdown files processed and images copied successfully.")
