#!/usr/bin/env bash
# ------------------------------------------------------------------
# Base16 Template Converter
# URL: https://github.com/ntpeters/base16-template-converter
# Author: Nate Peterson
#
# This script converts old-style Base16 templates written in
# Embedded Ruby syntax to the Mustache syntax.
# ------------------------------------------------------------------
version="0.1"

echo "base16-template-converter - v$version"

# Arrays used for value lookups throughout the script
types=("hex" "hexbgr" "dhex" "rgb" "srgb")
rgb=("r" "g" "b")

function main() {
    local src="$@"
    local srcPath="$(dirname ${src})"
    local srcFile="$(basename ${src})"
    local srcFilename="${srcFile%.*}"
    local srcFileExtension="${srcFile#$srcFilename.}"
    # Ensure relative paths are expanded
    local fullpath="$( cd "$( dirname "$0" )" && pwd )"
    local dest="${fullpath}/${srcFilename}.mustache"
    local ret=0;

    if [[ ! "$srcFileExtension" = "erb" ]]; then
        echo -e "\nWARNING: Expected '.erb' (Embedded Ruby) file, but input points to file with extension '.$srcFileExtension'"
    fi

    # GNU sed is required for regex extensions support
    if [[ ! "$(sed --version | head -n 1)" = *"GNU sed"* ]]; then
        echo -e "\nWARNING: You may be using an incompatible version of sed. GNU sed is required."
        if [[ "${OSTYPE,,}" = *"darwin"* ]]; then
            echo "To get GNU sed for macOS: 'brew install gnu-sed --with-default-names', then restart your terminal."
        fi
    fi

    echo -e "\nCopying template to: '${dest}'"

    # Copy target as new .mustache file
    cp -n "$src" "$dest" > /dev/null 2>&1
    ret=$((ret|$?))

    if [ $ret -ne 0 ]; then
        echo "ERROR: Failed to copy file! Ensure file does not already exist."
        return $ret
    fi

    echo -e "\nConverting template...\n"

    # Convert template in place
    convertFile "$dest"
    ret=$((ret|$?))

    echo -e "\nChecking converted template..."

    # We may have missed some tags if they weren't formatted as expected
    local remainingTags=$(grep -cE "<%(.|\n|\r)*?%>" "$dest")
    ret=$((ret|$?))
    if [ $remainingTags -ne 0 ]; then
        echo "Some tags could not be converted in the template. They will need to be updated manually."
    else
        echo "All tags converted."
    fi

    # Did anything bad happen?
    if [ $ret -ne 0 ]; then
        echo "ERROR: An error occurred at some point during this script."
    else
        echo "No errors detected."
    fi

    echo -e "\nDone"

    return $ret
}

# Converts all Ruby-style Base16 template tags in a file to mustache style
# Input:
#   $1 - File to run against
function convertFile() {
    local file="$1"
    local ret=0

    # Strip header
    echo "Removing header..."
    removeHeader "$file"
    ret=$((ret|$?))

    # Convert name pattern
    echo "Converting scheme name..."
    replaceInFile $(rubyTag "@scheme") $(mustacheTag "scheme-name") "$file"
    ret=$((ret|$?))

    # Convert author pattern
    echo "Converting scheme author..."
    replaceInFile $(rubyTag "@author") $(mustacheTag "scheme-author") "$file"
    ret=$((ret|$?))

    # Convert slug pattern
    echo "Converting scheme slug..."
    replaceInFile $(rubyTag "slug(@scheme)") $(mustacheTag "scheme-slug") "$file"
    ret=$((ret|$?))

    # Convert color patterns
    for type in "${types[@]}"; do
        echo "Converting '${type}' tags..."
        for base in {0..15}; do
            base=$(printf "%.2X" $base)
            for index in "${!rgb[@]}"; do
                convertColors "$base" "$type" "$file" "$index"
                ret=$((ret|$?))
            done
            convertColors "$base" "$type" "$file"
            ret=$((ret|$?))
        done
    done

    return $ret
}

# Converts a color pattern matching the given parameters from Ruby-style to mustache style
# Input:
#   $1 - Color base (ie. 0F)
#   $2 - Type of color pattern (ie. hex, rgb, srgb)
#   $3 - File to run against
#   $4 - (optional) Color index
function convertColors() {
    local base="$1"
    local type="$2"
    local file="$3"
    local index="$4"

    local find="$(oldColorPattern ${base} ${type} ${index})"
    local replace="$(newColorPattern ${base} ${type} ${index})"
    replaceInFile "$find" "$replace" "$file"
}

# Replaces a given pattern with the provided text in a file.
# Input:
#   $1 - Search pattern
#   $2 - Replacement text
#   $3 - File to run against
function replaceInFile() {
    local find="$1"
    local replace="$2"
    local file="$3"

    local expr="s/${find}/${replace}/g"
    sed -i "$file" -e "$expr"
}

# Deletes a '<% %>' tag spanning one or more lines from the beginning of a file
function removeHeader() {
    # Yeah, this is ugly...
    sed -e '/<%/{1!b;:x;$!N;/%>/!bx;s/<%.*%>//}' -i "$1"
}

# Wraps a given value in a Ruby-style tag
function rubyTag() {
    echo "<%\s\?$1\s\?%>"
}

# Wraps a given value in a mustache-style tag
function mustacheTag() {
    echo "{{$1}}"
}

# Generates a Ruby-style color pattern based on the given values.
# Input:
#   $1 - Color base (ie. 0F)
#   $2 - Type of color pattern (ie. hex, rgb)
#   $3 - (optional) Color index
function oldColorPattern() {
    local base="$1"
    local type="$2"
    local index="$3"

    local pattern="=\s\?@base\[\"${base}\"\]\[\"${type}\"\]"
    if [ -n "$index" ]; then
        pattern+="\[${index}\]"
    fi

    echo "$(rubyTag ${pattern})"
}

# Generates a mustache-style color pattern based on the given values.
# Supports conversion from old color pattern types (ie. hexbgr, dhex).
# Input:
#   $1 - Color base (ie. 0F)
#   $2 - Type of color pattern (ie. hex, rgb)
#   $3 - (optional) Color index
function newColorPattern() {
    local base="$1"
    local type="$2"
    local index="$3"

    case $type in
        "hexbgr") echo "$(hexbgr ${base} ${index})"; ;;
        "dhex") echo "$(dhex ${base} ${index})"; ;;
        "srgb") echo "$(composeType ${base} dec ${index})"; ;;
        *) echo "$(composeType ${base} ${type} ${index})"; ;;
    esac
}

# Generates a mustache-style color pattern based on the given values.
# Input:
#   $1 - Color base (ie. 0F)
#   $2 - Type of color pattern (ie. hex, rgb)
#   $3 - (optional) Color index
function composeType() {
    local base="$1"
    local type="$2"
    local index="$3"

    local pattern="base${base}-${type}"
    if [ -n "$index" ]; then
        pattern+="-${rgb[$index]}"
    fi

    echo "$(mustacheTag ${pattern})"
}

# Generates a mustache-style hex color pattern with the color components reversed.
# Input:
#   $1 - Color base (ie. 0F)
#   $2 - (optional) Color index
function hexbgr() {
    local base="$1"
    local index="$2"

    if [ -z "$index" ]; then
        echo "$(composeTypeRgb ${base} hexbgr)"
    else
        local len=${#rgb[@]}
        local reverseIndex=$(( (2 * index - 1 + len) % len ))
        echo "$(composeType ${base} hex ${reverseIndex})"
    fi
}

# Generates a mustache-style hex color pattern with each color component doubled.
# Input:
#   $1 - Color base (ie. 0F)
#   $2 - (optional) Color index
function dhex() {
    local base="$1"
    local index="$2"

    if [ -z "$index" ]; then
        echo "$(composeTypeRgb $base dhex)"
    else
        local hexValue="$(composeType ${base} hex ${index})"
        echo "${hexValue}${hexValue}"
    fi
}

# Calls the given function for each color component and combines the results.
# Input:
#   $1 - Color base (ie. 0F)
#   $2 - Type function
function composeTypeRgb() {
    local base="$1"
    local typeFunc="$2"

    local pattern=""
    for i in "${!rgb[@]}"; do
        pattern+="$($typeFunc $base $i)"
    done

    echo "${pattern}"
}

main "$@"
