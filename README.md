# Jellyfin Audio Normalizer

A Bash script for normalizing the audio of TV shows and movies for easier listening on TVs and other devices with limited speakers.

The script uses FFmpeg to normalize audio while copying the video stream without re-encoding it. It supports both MKV and MP4 files and preserves the original filename so Jellyfin's existing library organization isn't affected.

## Features
- Normalizes audio using FFmpeg's loudnorm filter
- Useful for TVs and built-in TV speakers where dialogue can be difficult to hear
- Supports .mkv and .mp4
- Video is copied without re-encoding, so there is no video quality loss
- Subtitles are copied
- Adds a metadata marker to processed files
- Automatically skips files that have already been processed
- Process individual files or entire directories recursively
- Dry-run mode to see what would be processed
- Original files are only replaced after FFmpeg completes successfully
- Original filenames are preserved
- Failed conversions do not replace the original file
- Includes --help
## Requirements
- Debian/Ubuntu/Linux system
- Bash
- FFmpeg
- FFprobe
## Debian / Ubuntu
FFmpeg can be installed with:  
```
sudo apt update
sudo apt install ffmpeg
```

Verify the installation:
```
ffmpeg -version
ffprobe -version
```
## Installation
Clone the repository:
```
git clone https://github.com/lukemcelligott/jellyfin-audio-normalizer.git
cd jellyfin-audio-normalizer
```

Make the script executable:
```
chmod +x normalize-audio.sh
```

You can optionally place it somewhere in your PATH:
```
sudo cp normalize-audio.sh /usr/local/bin/normalize-audio
```

Then you can run it from anywhere:
```
normalize-audio --help
```
## Usage
### Show help
```
./normalize-audio.sh --help
```
or:
```
./normalize-audio.sh -h
```
### Process a single file
```
./normalize-audio.sh -f "/mnt/nas/media/shows/ExampleShow/Season 4/ExampleShow S04E04.mkv"
```
### Process multiple files
The `-f` option can be specified multiple times:
```
./normalize-audio.sh \
    -f "/path/episode1.mkv" \
    -f "/path/episode2.mkv" \
    -f "/path/episode3.mp4"
```
### Process an entire directory
The `-d` option recursively searches the directory for MKV and MP4 files:
```
./normalize-audio.sh -d "/mnt/media/shows/ExampleShow"
```

For example:

ExampleShow/
├── Season 1/
│   ├── ExampleShow S01E01.mkv
│   ├── ExampleShow S01E02.mkv
│   └── ...
├── Season 2/
│   └── ...
└── Season 4/
    ├── ExampleShow S04E04.mkv
    ├── ExampleShow S04E05.mkv
    └── ...


All `.mkv` and `.mp4` files underneath the specified directory will be considered.

### Dry run
Before modifying a directory, you can see which files would be processed:
```
./normalize-audio.sh --dry-run -d "/mnt/nas/media/shows/ExampleShow"
```
or:
```
./normalize-audio.sh -n -d "/mnt/nas/media/shows/ExampleShow"
```
Dry-run mode does not modify any files.

## How It Works

For each file, the script:

Checks that the file exists and is an MKV or MP4.
Checks the file's metadata for the JellyfinAudioNormalized=true marker.
Skips the file if it has already been processed.
Creates a temporary file in the same directory.
Uses FFmpeg to normalize the audio.
Copies the video stream without re-encoding.
Copies subtitle streams.
Preserves existing metadata.
Adds the JellyfinAudioNormalized=true marker.
Replaces the original file only after FFmpeg succeeds.

The filename remains unchanged.

For example:
```
Before:
ExampleShow S04E04.mkv

After:
ExampleShow S04E04.mkv
```
There is no .normalized suffix or other filename change.

## Preventing Double Processing

Processed files receive the following metadata tag:
```
JellyfinAudioNormalized=true
```

When the script encounters a file containing this marker, it skips it.

For example:
```
[PROCESS] ExampleShow S04E04.mkv
[SUCCESS] FFmpeg completed.
[DONE] Original replaced.

[SKIP] Already normalized.
```
This means it is safe to run the directory command repeatedly:
```
./normalize-audio.sh -d "/mnt/nas/media/shows"
```

Previously processed files will be skipped.

## Audio Processing

The current audio filter is:
```
loudnorm=I=-16:TP=-1.5:LRA=11
```

This uses FFmpeg's loudnorm filter to target a consistent perceived loudness.

Audio is encoded as AAC at 192 kbps:
```
-c:a aac -b:a 192k
```

The video is not re-encoded:
```
-c:v copy
```

Therefore, video quality is unchanged.

## File Safety

The script intentionally processes files through a temporary file first.

It does not immediately overwrite the original.

The general process is:
```
Original
   │
   ▼
FFmpeg
   │
   ▼
Temporary file
   │
   ├── FFmpeg fails ──► Temporary file deleted
   │                    Original untouched
   │
   └── FFmpeg succeeds
             │
             ▼
       Replace original
```

If FFmpeg encounters an error, the original media file is left untouched.

## Important: Backups

Although the script is designed to avoid replacing files when FFmpeg fails, it does replace the original after a successful conversion.

If your media library is important, make sure you have a backup before processing a large number of files.

It is recommended to test the script on a few episodes first.

### Free Space

Because the script creates a temporary copy of the media file before replacing the original, you need enough free space for the temporary file.

For example, processing a 4 GB MKV may temporarily require approximately 4 GB of additional free space in the same filesystem.

The final file may be smaller or larger depending on the original audio.

## Jellyfin

The script is designed with Jellyfin libraries in mind.

The media filename and path are preserved:
```
/mnt/nas/media/shows/Show Name/Season 01/Show Name S01E01.mkv
```

remains:
```
/mnt/nas/media/shows/Show Name/Season 01/Show Name S01E01.mkv
```

Only the contents of the media file are changed.

Jellyfin may need to rescan the library after files are modified if you want it to immediately recognize the changed media.

## Supported Containers

Currently supported:
```
MKV (.mkv)
MP4 (.mp4)
```
The script is not limited to a particular source audio format. FFmpeg decodes the existing audio and encodes the result as AAC.

Command Reference
Option	Long Option	Description
-f	--file	Process a specific file
-d	--directory	Recursively process a directory
-n	--dry-run	Show files without modifying them
-h	--help	Display help
Examples

Process one episode:
```
./normalize-audio.sh -f "/mnt/nas/media/shows/Show/Season 01/Show S01E01.mkv"
```

Process an entire show:
```
./normalize-audio.sh -d "/mnt/nas/media/shows/Show"
```

Preview an entire show:
```
./normalize-audio.sh --dry-run -d "/mnt/nas/media/shows/Show"
```

Process an entire media library:
```
./normalize-audio.sh -d "/mnt/nas/media/shows"

Example Output
========================================
Checking:
/mnt/nas/media/shows/ExampleShow/Season 4/ExampleShow S04E04.mkv
========================================
[PROCESS] /mnt/nas/media/shows/ExampleShow/Season 4/ExampleShow S04E04.mkv
[SUCCESS] FFmpeg completed.
[DONE] Original replaced.

========================================
Checking:
/mnt/nas/media/shows/ExampleShow/Season 4/ExampleShow S04E05.mkv
========================================
[SKIP] Already normalized.

========================================
Finished
========================================
Processed: 1
Skipped:   1
Failed:    0
```
License

MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files, to deal in the Software
without restriction, including without limitation the rights to use, copy,
modify, merge, publish, distribute, sublicense, and/or sell copies of the
Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
