#!/bin/bash

# Generate a random hex string for unique filenames
random_hex=$(openssl rand -hex 6)

# Get the current directory
current_dir=$(pwd)

# Define the final output file
final_output="${current_dir}/output-${random_hex}.mkv"

# If more than one file, concatenate them; if only one, use it directly
if [ $# -gt 1 ]; then
    echo "####### Multiple input files detected. Concatenating..."
    
    # Create a temporary file list
    filelist=$(mktemp)
    for f in "$@"; do
        echo "file '$(pwd)/$f'" >> "$filelist"
    done

    # Concatenate files without re-encoding initially
    combine_step="${current_dir}/combine_step.mkv"
    ffmpeg -y -f concat -safe 0 -i "$filelist" -c copy "$combine_step"
    rm -f "$filelist"
else
    # Single file, no concatenation needed
    echo "####### Single file input. Skipping concatenation..."
    combine_step="$1"
fi

# Step 2: Extract loudness normalization values
echo "####### Extracting loudness normalization values..."
log_file="loudnorm_log.txt"
ffmpeg -y -i "$combine_step" -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=summary -f null - 2>&1 | tee "$log_file"

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

# Step 3: Normalize the audio using extracted values
echo "####### Normalizing audio..."
ffmpeg -y -i "$combine_step" \
-af loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=$measured_I:measured_TP=$measured_TP:measured_LRA=$measured_LRA:measured_thresh=$measured_thresh:offset=$offset \
-c:v h264_videotoolbox -b:v 10M -c:a aac -b:a 256k "$final_output"

# Step 4: Clean up intermediate files
echo "####### Cleaning up intermediate files..."
[ $# -gt 1 ] && rm -f "$combine_step"
rm -f "$log_file"

echo "Processing complete. Final file saved as $final_output."
