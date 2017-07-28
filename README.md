# Base16 Template Converter

This script converts [Base16](https://github.com/chriskempson/base16) templates written
using the old Embedded Ruby syntax to the new Mustache syntax.

## Usage

Just run the script with the path to the template you want to convert:
```
base16-template-converter.sh template.erb
```
A new, converted file is output in the same directory: `template.mustache`

## Requirements

This script uses `sed` to modify the text in the file, and specifically
requires the GNU version of `sed`.

If you are on macOS, you can install GNU `sed` through Homebrew:
```
brew install gnu-sed --with-default-names
```
*Note:* the `--with-default-names` option will cause `gnu-sed` to be used instead
of the built-in `sed`.
