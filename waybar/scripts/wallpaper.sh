#!/usr/bin/env bash
# Configuration
WALLPAPER_DIR="$HOME/Pictures/wallpapers"  # Change this to your wallpaper directory
CACHE_DIR="$HOME/.cache/wallpaper-selector"
THUMBNAIL_WIDTH="250"  # Size of thumbnails in pixels (16:9)
THUMBNAIL_HEIGHT="141"
# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"

# Function to generate thumbnail
generate_thumbnail() {
    local input="$1"
    local output="$2"
    magick "$input" -thumbnail "${THUMBNAIL_WIDTH}x${THUMBNAIL_HEIGHT}^" -gravity center -extent "${THUMBNAIL_WIDTH}x${THUMBNAIL_HEIGHT}" "$output"
}

# Create shuffle icon thumbnail on the fly
SHUFFLE_ICON="$CACHE_DIR/shuffle_thumbnail.png"
# Create a properly sized shuffle icon thumbnail
# magick -size "${THUMBNAIL_WIDTH}x${THUMBNAIL_HEIGHT}" xc:#1e1e2e \
#     "$HOME/Repos/wallpaper-selector/assets/shuffle.png" -resize "120x120" -gravity center -composite \
#     "$SHUFFLE_ICON"
magick -size "${THUMBNAIL_WIDTH}x${THUMBNAIL_HEIGHT}" xc:#1e1e2e \
    \( "$HOME/.config/wofi/assets/shuffle.png" -resize "80x80" \) \
    -gravity center -composite "$SHUFFLE_ICON"

# Generate thumbnails and create menu items
generate_menu() {
    # Add random/shuffle option with a name that sorts first (using ! prefix)
    echo -en "img:$SHUFFLE_ICON\x00info:!Random Wallpaper\x1fRANDOM\n"
    
    # Then add all wallpapers
    for img in "$WALLPAPER_DIR"/*.{jpg,jpeg,png}; do
        # Skip if no matches found
        [[ -f "$img" ]] || continue
        
        # Generate thumbnail filename
        thumbnail="$CACHE_DIR/$(basename "${img%.*}").png"
        
        # Generate thumbnail if it doesn't exist or is older than source
        if [[ ! -f "$thumbnail" ]] || [[ "$img" -nt "$thumbnail" ]]; then
            generate_thumbnail "$img" "$thumbnail"
        fi
        
        # Output menu item (filename and path)
        echo -en "img:$thumbnail\x00info:$(basename "$img")\x1f$img\n"
    done
}

# Set original wallpaper path depending on mode
if [[ "$1" == "--random" ]]; then
    selected=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | shuf -n 1)
else
    # Use wofi to display grid of wallpapers - IMPORTANT: added --sort-order=default
    selected=$(generate_menu | wofi --show dmenu \
        --cache-file /dev/null \
        --define "image-size=${THUMBNAIL_WIDTH}x${THUMBNAIL_HEIGHT}" \
        --columns 3 \
        --allow-images \
        --insensitive \
        --sort-order=default \
        --prompt "Select Wallpaper" \
        --conf ~/.config/wofi/wallpaper.conf \
    )
fi

# Set wallpaper if one was selected
if [ -n "$selected" ]; then
    # Remove the img: prefix to get the cached thumbnail path
    thumbnail_path="${selected#img:}"

    # Check if random wallpaper was selected
    if [[ "$thumbnail_path" == "$SHUFFLE_ICON" ]]; then
        # Select a random wallpaper from the directory
        original_path=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | shuf -n 1)
    else
        # Get the original filename from the thumbnail path
        original_filename=$(basename "${thumbnail_path%.*}")

        # Find the corresponding original file in the wallpaper directory
        original_path=$(find "$WALLPAPER_DIR" -type f -name "${original_filename}.*" | head -n1)
    fi

    # Ensure a valid wallpaper was found before proceeding
    if [ -n "$original_path" ]; then
        # Set wallpaper using awww with the original file
        awww img -t grow "$original_path"

        # replace the current wallpaper path in the wlogout style.css with the new one
        sed -i "13 s|background-image: .*;|background-image: image(url(\"$original_path\"));|1" ~/.config/wlogout/style.css

        # replace the current wallpaper path in the hyprlock.conf file with the new one
        sed -i "15 s|path = .*|path = $original_path|" ~/.config/hypr/hyprlock.conf

        # Save the selection for persistence
        echo "$original_path" > "$HOME/.cache/current_wallpaper"

        # Optional: Notify user
        notify-send "Wallpaper" "Wallpaper has been updated" -i "$original_path"
    else
        notify-send "Wallpaper Error" "Could not find the original wallpaper file."
    fi
fi