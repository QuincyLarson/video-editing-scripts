These are scripts I use for editing videos programmatically and mastering their audio. 

These save me a ton of time that I would otherwise spend inside Final Cut Pro.

They will:
1. Concatenate your .mkv format files into a single output file (.mkv is a good format for recording your screen using OBS)
2. Use Python auto-editor to remove silent sequences without narration – giving you time to pause and collect your thoughts while recording
3. Level audio to -14 i-LUFS to prevent YouTube and other services from automatically normalizing it (which results in worse sound)

To run the script:
`bash post.sh file1.mkv file2.mkv ... fileN.mkv`

I also have a version that skips the editing step, called `post-no-editing.sh`, and a tool that will remove a section based on timestamps if you mess something up.

I've produced a ton of tightly-edited videos using this without ever needing to install video editing software. I hope these scripts are helpful for you, too.
