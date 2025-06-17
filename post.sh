#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Check that at least one argument is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 inputfile1 [inputfile2] [inputfile3]"
    exit 1
fi

#####################################
# Dependency checks and installations
#####################################

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
    echo "Homebrew is not installed. Please install Homebrew first:"
    echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# Check and install ffmpeg if missing
if ! command -v ffmpeg &>/dev/null; then
    echo "ffmpeg not found. Installing via Homebrew..."
    brew install ffmpeg
fi

# Check if ffmpeg supports videotoolbox
if ! ffmpeg -hwaccels | grep -q "videotoolbox"; then
    echo "Your ffmpeg does not appear to support videotoolbox. Reinstalling ffmpeg..."
    brew reinstall ffmpeg
    # Re-check videotoolbox support
    if ! ffmpeg -hwaccels | grep -q "videotoolbox"; then
        echo "Unable to confirm videotoolbox support. Please ensure ffmpeg is built with --enable-videotoolbox."
        exit 1
    fi
fi

# Ensure pip is available
if ! python3 -m pip --version &>/dev/null; then
    echo "pip not found. Attempting to bootstrap pip..."
    if ! python3 -m ensurepip --upgrade &>/dev/null; then
        echo "ensurepip failed. Trying get-pip.py..."
        curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
        if ! python3 get-pip.py; then
            echo "Failed to install pip via get-pip.py. Please install pip manually."
            rm -f get-pip.py
            exit 1
        fi
        rm -f get-pip.py
    fi
fi

# Check and install auto-editor if missing
if ! command -v auto-editor &>/dev/null; then
    echo "auto-editor not found. Installing via pip..."
    python3 -m pip install --upgrade pip
    if ! python3 -m pip install --upgrade auto-editor; then
        echo "Failed to install auto-editor via pip. Please check for errors above and install manually if needed."
        exit 1
    fi
fi

#####################################
# Script Main Logic
#####################################

# Generate a random hex string
random_hex=$(openssl rand -hex 6)

# Get the current directory
current_dir=$(pwd)

# Define the final output file
final_output="${current_dir}/output-${random_hex}.mkv"

# If more than one file, we need to concatenate; if only one, skip concatenation
if [ $# -gt 1 ]; then
    echo "####### Multiple input files detected. Concatenating..."
    # Create a temporary file list
    filelist=$(mktemp)
    for f in "$@"; do
        echo "file '$(pwd)/$f'" >> "$filelist"
    done

    # Concatenate files without re-encoding initially (just to ensure they match)
    combine_step="${current_dir}/combine_step.mkv"
    ffmpeg -y -f concat -safe 0 -i "$filelist" -c:v h264_videotoolbox -b:v 10M -c:a aac -b:a 256k "$combine_step"
    rm -f "$filelist"
else
    # Only one file, no concatenation needed
    echo "####### Single file input. Skipping concatenation..."
    combine_step="$1"
fi

# Log the full length of the (combined or single) file
ffmpeg -i "$combine_step" -f null - 
wait

# Step 2: Remove silence using auto-editor
echo "####### Step 2: Removing silence with auto-editor..."
auto_edit_output="${combine_step%.*}_ALTERED.mkv"
auto-editor "$combine_step" \
  --margin 0.3s,1.0sec \
  --edit audio:0.035 \
  --no-open \
  --video-codec h264_videotoolbox \
  --video-bitrate 10M \
  --audio-codec aac \
  --audio-bitrate 256k \
  -o "$auto_edit_output"
wait

# Step 3: Extract loudness normalization values
echo "####### Step 3: Extracting loudness normalization values..."
log_file="loudnorm_log.txt"
ffmpeg -y -fflags +genpts -i "$auto_edit_output" -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=summary -f null - 2>&1 | tee "$log_file"
wait

# Extracting the measured values from the log
measured_I=$(grep "Input Integrated:" "$log_file" | awk '{print $3}')
measured_TP=$(grep "Input True Peak:" "$log_file" | awk '{print $4}')
measured_LRA=$(grep "Input LRA:" "$log_file" | awk '{print $3}')
measured_thresh=$(grep "Input Threshold:" "$log_file" | awk '{print $3}')
offset=$(grep "Target Offset:" "$log_file" | awk '{print $3}')

echo "Measured I: $measured_I"
echo "Measured TP: $measured_TP"
echo "Measured LRA: $measured_LRA"
echo "Measured Threshold: $measured_thresh"
echo "Offset: $offset"

# Step 4: Normalize the audio using extracted values
echo "####### Step 4: Normalizing audio..."
ffmpeg -y -i "$auto_edit_output" \
-af loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=$measured_I:measured_TP=$measured_TP:measured_LRA=$measured_LRA:measured_thresh=$measured_thresh:offset=$offset -c:v h264_videotoolbox -b:v 10M -c:a aac -b:a 256k "$final_output"
wait

# Step 5: Clean up unnecessary files
echo "####### Step 5: Cleaning up intermediate files..."
# Only remove combine_step if it was created by concatenation
[ $# -gt 1 ] && rm -f "$combine_step"
rm -f "$auto_edit_output" "$log_file" loudnorm_log.txt

echo "Processing complete. Final file saved as $final_output."
echo "Intermediate files have been removed."
