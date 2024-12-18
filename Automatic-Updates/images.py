import os
import re
import shutil
import logging

# Logging setup
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')

# Read environment variables or use default values
posts_dir = os.environ.get("BLOG_POSTS_DIR", "/Users/lcs-dev/04_LCS.Blog/CS-Topics/content/posts/")
attachments_dir = os.environ.get("OBSIDIAN_ATTACHMENTS_DIR", "/Users/lcs-dev/Documents/Obsidian-Vault/XSPC-Vault/Blog/images/")
static_images_dir = os.environ.get("BLOG_STATIC_IMAGES_DIR", "/Users/lcs-dev/04_LCS.Blog/CS-Topics/static/images/")

# Check if directories exist
for d, name in [(posts_dir, "Posts"), (attachments_dir, "Attachments"), (static_images_dir, "Static images")]:
    if not os.path.isdir(d):
        logging.error(f"{name} directory does not exist or is not accessible: {d}")
        raise SystemExit(1)

# Create the static images directory if it does not exist
os.makedirs(static_images_dir, exist_ok=True)

# Regex to find image references in the form [[image.png]]
pattern = re.compile(r'\[\[([\w\s.-]+\.(?:png|jpg|jpeg|gif|bmp))\]\]', re.IGNORECASE)

# Attempt to get the list of Markdown files in the posts directory
try:
    post_files = [f for f in os.listdir(posts_dir) if f.endswith(".md")]
except OSError as e:
    logging.error(f"Error reading posts directory: {e}")
    raise SystemExit(1)

if not post_files:
    logging.warning("No markdown files found in the posts directory.")
else:
    for filename in post_files:
        filepath = os.path.join(posts_dir, filename)

        # Check read access
        if not os.access(filepath, os.R_OK):
            logging.warning(f"Cannot read file {filepath}. Skipping.")
            continue

        # Read the file content
        try:
            with open(filepath, "r", encoding="utf-8") as file:
                content = file.read()
        except OSError as e:
            logging.error(f"Failed to read {filepath}: {e}")
            continue

        # Find all images in the content
        images = pattern.findall(content)

        if not images:
            logging.info(f"No images found in {filename}.")
            continue

        # Update the content with markdown links and copy the images
        updated_content = content
        for image in images:
            # Security check on the image name (no slashes)
            if '/' in image or '\\' in image:
                logging.warning(f"Suspicious image name '{image}' in file {filename}. Skipping this image.")
                continue
            
            # Replace [[image.png]] with ![Image Description](/images/image.png)
            markdown_image = f"[Image Description](/images/{image.replace(' ', '%20')})"
            updated_content = updated_content.replace(f"[[{image}]]", markdown_image)

            # Copy the image to the static folder
            image_source = os.path.join(attachments_dir, image)
            if not os.path.exists(image_source):
                logging.warning(f"Image not found: {image_source}, referenced in {filename}.")
                continue

            if not os.access(image_source, os.R_OK):
                logging.warning(f"Cannot read image: {image_source}. Skipping.")
                continue

            dest_path = os.path.join(static_images_dir, image)
            try:
                shutil.copy2(image_source, dest_path)
                logging.info(f"Copied {image_source} to {dest_path}")
            except OSError as e:
                logging.error(f"Failed to copy {image_source} to {dest_path}: {e}")

        # Write the updated content to the file, if possible
        if not os.access(filepath, os.W_OK):
            logging.warning(f"No write access to {filepath}. File not updated.")
            continue

        try:
            with open(filepath, "w", encoding="utf-8") as file:
                file.write(updated_content)
                logging.info(f"Updated file {filename} successfully.")
        except OSError as e:
            logging.error(f"Failed to write to {filepath}: {e}")

logging.info("Markdown files processed and images handled successfully.")