#!/usr/bin/env bash
set -eo pipefail

file="extensions.txt"

if [ ! -f "$file" ]; then
    echo "File $file does not exist."
    exit 1
fi

# Check if browser is provided otherwise default to librewolf
browser=$1
if [ -z "$browser" ]; then
    echo "Browser is not provided. Defaulting to librewolf"
    browser="librewolf"
fi

# Check if the browser is installed
if ! command -v $1 &> /dev/null; then
    echo "$1 is not installed."
    exit 1
fi

# Loop through each line of the file
while IFS= read -r url; do
    # Open the URL in browser
    $browser "$url" &
done < "$file"
