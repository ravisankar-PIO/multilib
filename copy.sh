#!/QOpenSys/usr/bin/sh
# ------------------------------------------------------------------------- #
# Program       : copy.sh (Multi-Library Dynamic Copy)
# Author        : Ravisankar Pandian
# Company       : Programmers.io
# Date Written  : 20/07/2023
# Modified      : 20/03/2026
# Description   : Dynamically discovers all library directories at the
#                 repository root, creates corresponding QSYS libraries
#                 and source physical files, then copies IFS sources to
#                 QSYS members with proper source type assignment.
#
# Repo layout   : REPO_ROOT/LIB1/QRPGLESRC/PGM1.RPGLE
#                 REPO_ROOT/LIB2/QCLLESRC/PGM2.CLLE
#                 ...
#
# Usage         : ./copy.sh [/path/to/repo/root]
#                 Defaults to present working directory if not specified.
# ------------------------------------------------------------------------- #

# -----------------------------------------------------------
# Global configuration
# -----------------------------------------------------------

# Use the repo root as the base directory (arg1 or pwd)
ifs_dir="${1:-$(pwd)}"

# Application name used as member text
application="Git for IBMi"

# Source file description text
src_txt="Sources file"

# Record length for all source physical files
rcdlen=200

# Library type for CRTLIB
lib_type="*TEST"

# Color codes for terminal output
green='\033[32m'
red='\033[31m'
nc='\033[0m'
yellow='\033[33m'
cyan='\033[36m'

# Arrays to track failures across all libraries
copy_failures=()
lib_failures=()


# -----------------------------------------------------------
# Execute a CL command silently via qsh and return status
# -----------------------------------------------------------
exec_cmd() {
    qsh -c "system \"$1\" > /dev/null 2>&1"
    return $?
}

# -----------------------------------------------------------
# Execute a system command silently and return status
# -----------------------------------------------------------
silent_cmd() {
    system "$1" > /dev/null 2>&1
    return $?
}


# -----------------------------------------------------------
# Map a file extension to its IBM i source type.
# Returns the source type string, or empty if not recognized.
# -----------------------------------------------------------
get_source_type() {
    local ext=$(echo "$1" | tr '[:upper:]' '[:lower:]')

    case "$ext" in
        rpgle)    echo "RPGLE"    ;;
        sqlrpgle) echo "SQLRPGLE" ;;
        clle)     echo "CLLE"     ;;
        sql)      echo "SQL"      ;;
        cmd)      echo "CMD"      ;;
        pnlgrp)   echo "PNLGRP"  ;;
        pf)       echo "PF"       ;;
        dspf)     echo "DSPF"     ;;
        prtf)     echo "PRTF"     ;;
        lf)       echo "LF"       ;;
        rpgleinc) echo "RPGLEINC" ;;
        clleinc)  echo "CLLEINC"  ;;
        bnd)      echo "BND"      ;;
        *)        echo ""         ;;
    esac
}


# -----------------------------------------------------------
# Check if a directory should be skipped.
# Skips hidden directories (starting with '.')
# Returns 0 if should skip, 1 if should process.
# -----------------------------------------------------------
should_skip_dir() {
    local dir_name=$(basename "$1")

    # Skip hidden directories (.git, .vscode, etc.)
    if [[ "$dir_name" == .* ]]; then
        return 0
    fi

    return 1
}


# -----------------------------------------------------------
# Create a QSYS library if it does not already exist.
# Args: $1 = library name
# Returns 0 on success, 1 on failure.
# -----------------------------------------------------------
create_library() {
    local lib_name="$1"

    if silent_cmd "DSPOBJD OBJ(QSYS/$lib_name) OBJTYPE(*LIB)"; then
        echo -e "  Library ${cyan}$lib_name${nc} already exists"
        return 0
    fi

    echo -n "  Creating library $lib_name... "
    if silent_cmd "CRTLIB LIB($lib_name) TYPE($lib_type) TEXT('$application')"; then
        echo -e "${green}created${nc}"
        return 0
    else
        echo -e "${red}failed${nc}"
        lib_failures+=("$lib_name")
        return 1
    fi
}


# -----------------------------------------------------------
# Create a source physical file in the given library
# if it does not already exist.
# Args: $1 = library name, $2 = source file name
# Returns 0 on success, 1 on failure.
# -----------------------------------------------------------
create_source_file() {
    local lib_name="$1"
    local src_file="$2"

    # Check if the source file already exists
    if silent_cmd "CHKOBJ OBJ($lib_name/$src_file) OBJTYPE(*FILE)"; then
        echo -e "  Source file ${cyan}$src_file${nc} already exists in $lib_name"
        return 0
    fi

    # Build the CRTSRCPF command (skip RCDLEN for DDS source files)
    local crt_cmd="CRTSRCPF FILE($lib_name/$src_file) TEXT('$src_txt')"
    if [[ "$src_file" != "QDDSSRC" ]]; then
        crt_cmd="CRTSRCPF FILE($lib_name/$src_file) RCDLEN($rcdlen) TEXT('$src_txt')"
    fi

    echo -n "  Creating source file $src_file in $lib_name... "
    if exec_cmd "$crt_cmd"; then
        echo -e "${green}created${nc}"
        return 0
    else
        echo -e "${red}failed${nc}"
        return 1
    fi
}


# -----------------------------------------------------------
# Copy a single IFS source file into a QSYS source member.
# Performs CHGATR, CPYFRMSTMF, and CHGPFM in sequence.
# Args: $1 = full IFS path, $2 = library, $3 = srcpf, $4 = srctype
# -----------------------------------------------------------
copy_single_source() {
    local file_path="$1"
    local lib_name="$2"
    local src_file="$3"
    local src_typ="$4"

    local justname=$(basename "$file_path")
    local member="${justname%.*}"

    echo -n "    Copying $justname -> $lib_name/$src_file ($src_typ)... "

    # Set the IFS file CCSID to UTF-8
    if ! exec_cmd "CHGATR OBJ('$file_path') ATR(*CCSID) VALUE(1208)"; then
        echo -e "${red}failed (attribute change)${nc}"
        copy_failures+=("$lib_name/$src_file/$justname")
        return 1
    fi

    # Copy from IFS stream file to QSYS source member
    if ! exec_cmd "CPYFRMSTMF FROMSTMF('$file_path') TOMBR('/QSYS.lib/$lib_name.lib/$src_file.file/$member.mbr') MBROPT(*REPLACE)"; then
        echo -e "${red}failed (copy)${nc}"
        copy_failures+=("$lib_name/$src_file/$justname")
        return 1
    fi

    # Set the member source type and text description
    if ! exec_cmd "CHGPFM FILE($lib_name/$src_file) MBR($member) SRCTYPE($src_typ) TEXT('$application')"; then
        echo -e "${red}failed (CHGPFM)${nc}"
        copy_failures+=("$lib_name/$src_file/$justname")
        return 1
    fi

    echo -e "${green}ok${nc}"
    return 0
}


# -----------------------------------------------------------
# Process all source members within a single source
# physical file directory (e.g., QRPGLESRC).
# Args: $1 = library name, $2 = full path to srcpf directory
# -----------------------------------------------------------
process_source_directory() {
    local lib_name="$1"
    local srcpf_path="$2"
    local srcpf_name=$(basename "$srcpf_path")

    # Convert directory name to uppercase for QSYS source file name
    local src_file=$(echo "$srcpf_name" | tr '[:lower:]' '[:upper:]')

    echo ""
    echo "  Source file: $src_file (from $srcpf_name)"
    echo "  ----------------------------------------"

    # Create the source physical file if needed
    if ! create_source_file "$lib_name" "$src_file"; then
        echo -e "  ${red}Skipping $srcpf_name - source file creation failed${nc}"
        return 1
    fi

    # Iterate over all files in this source directory
    local file_count=0
    for file_path in "$srcpf_path"/*; do
        # Only process regular files
        if [[ -f "$file_path" ]]; then
            local ext="${file_path##*.}"
            local src_typ=$(get_source_type "$ext")

            # Skip files with unrecognized extensions
            if [[ -z "$src_typ" ]]; then
                echo -e "    ${yellow}Skipping $(basename "$file_path") (unknown extension: $ext)${nc}"
                continue
            fi

            copy_single_source "$file_path" "$lib_name" "$src_file" "$src_typ"
            ((file_count++))
        fi
    done

    if [[ $file_count -eq 0 ]]; then
        echo -e "    ${yellow}No source members found in $srcpf_name${nc}"
    else
        echo -e "  ${green}Processed $file_count member(s) from $srcpf_name${nc}"
    fi
}


# -----------------------------------------------------------
# Process a single library directory.
# Creates the QSYS library, then iterates over its
# subdirectories to create source files and copy members.
# Args: $1 = full path to the library directory
# -----------------------------------------------------------
process_library() {
    local lib_path="$1"
    local lib_name=$(basename "$lib_path")

    # Convert to uppercase for QSYS library name
    lib_name=$(echo "$lib_name" | tr '[:lower:]' '[:upper:]')

    echo ""
    echo "=========================================="
    echo "  Library: $lib_name"
    echo "  Path:    $lib_path"
    echo "=========================================="

    # Create the library
    if ! create_library "$lib_name"; then
        echo -e "${red}Skipping library $lib_name - creation failed${nc}"
        return 1
    fi

    # Iterate over each subdirectory (source physical file directories)
    local srcpf_count=0
    for srcpf_dir in "$lib_path"/*/; do
        srcpf_dir="${srcpf_dir%/}"

        if [[ -d "$srcpf_dir" ]]; then
            # Skip hidden subdirectories inside the library too
            if should_skip_dir "$srcpf_dir"; then
                continue
            fi

            process_source_directory "$lib_name" "$srcpf_dir"
            ((srcpf_count++))
        fi
    done

    if [[ $srcpf_count -eq 0 ]]; then
        echo -e "  ${yellow}No source file directories found in $lib_name${nc}"
    fi
}


# -----------------------------------------------------------
# Top-level function: discover all library directories
# at the repo root and process each one.
# -----------------------------------------------------------
copy_all() {
    echo ""
    echo "=========================================="
    echo "  Discovering libraries at repo root"
    echo "=========================================="

    # Validate the repo root directory
    if [[ ! -d "$ifs_dir" ]]; then
        echo -e "${red}Error: Directory $ifs_dir does not exist${nc}"
        exit 1
    fi

    # Iterate over top-level directories
    local lib_count=0
    for lib_dir in "$ifs_dir"/*/; do
        lib_dir="${lib_dir%/}"

        if [[ -d "$lib_dir" ]]; then
            # Skip hidden directories
            if should_skip_dir "$lib_dir"; then
                echo -e "  ${yellow}Skipping hidden directory: $(basename "$lib_dir")${nc}"
                continue
            fi

            process_library "$lib_dir"
            ((lib_count++))
        fi
    done

    if [[ $lib_count -eq 0 ]]; then
        echo -e "${red}No library directories found in $ifs_dir${nc}"
        exit 1
    fi

    echo ""
    echo "=========================================="
    echo "  Processed $lib_count library(ies)"
    echo "=========================================="
}


# -----------------------------------------------------------
# Display a summary of all failures across all libraries.
# -----------------------------------------------------------
display_summary() {
    echo ""
    echo "=========================================="
    echo "           PROCESS SUMMARY"
    echo "=========================================="

    local has_errors=0

    # Report library creation failures
    if [[ ${#lib_failures[@]} -gt 0 ]]; then
        has_errors=1
        echo ""
        echo -e "${red}LIBRARY CREATION FAILURES (${#lib_failures[@]}):${nc}"
        for failure in "${lib_failures[@]}"; do
            echo "  - $failure"
        done
    fi

    # Report source copy failures
    if [[ ${#copy_failures[@]} -gt 0 ]]; then
        has_errors=1
        echo ""
        echo -e "${red}SOURCE COPY FAILURES (${#copy_failures[@]}):${nc}"
        for failure in "${copy_failures[@]}"; do
            echo "  - $failure"
        done
    fi

    if [[ $has_errors -eq 0 ]]; then
        echo -e "${green}All operations completed successfully!${nc}"
    fi

    echo "=========================================="
}


# -----------------------------------------------------------
# Main entry point
# -----------------------------------------------------------
echo ""
echo "=========================================="
echo "   $application - Multi-Library Copy"
echo "=========================================="
echo "  Repo root: $ifs_dir"
echo "  Lib type:  $lib_type"
echo "=========================================="

# Set PDM user defaults
if ! exec_cmd "CHGPDMDFT USER($USER) CRTBCH(*NO) EXITENT(*NO) CHGTYPTXT(*NO)"; then
    echo -e "${yellow}Warning: Could not change PDM defaults${nc}"
fi

# Discover libraries and copy all sources
copy_all

# Show the results
display_summary

echo ""
echo -e "${cyan}Process completed. Check QSYS libraries for copied sources.${nc}"
echo ""