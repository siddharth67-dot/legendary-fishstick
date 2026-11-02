---
description: Download a video from a URL, sample frames, transcribe the audio, and package the result as a new Claude Code skill
argument-hint: <video-url> [skill-name]
---

Turn a video into a reusable skill under `.claude/skills/`.

Arguments (`$ARGUMENTS`): the first token is the video URL (required). The
second token, if given, is the desired skill name — lowercase kebab-case
(e.g. `onboarding-demo-walkthrough`). If it's missing, derive one yourself
from the video's title/content once you know it (kebab-case, no generic
names like `video` or `video-skill`), and tell the user what you chose.

Steps:

1. Parse the URL and optional skill name from `$ARGUMENTS`.
2. Run the pipeline script, which downloads the video, extracts frames every
   5 seconds, transcribes the audio with `faster-whisper`, and writes a new
   skill folder:

   ```
   .claude/scripts/video_to_skill.sh "<video-url>" "<skill-name>"
   ```

   This installs `yt-dlp` and `faster-whisper` on first use if they're not
   already present (via pip, user-level). It can take a few minutes for
   longer videos — the transcription step is the slow part. If the URL
   isn't something `yt-dlp` understands, the script falls back to a plain
   HTTP download of the URL as a video file.
3. Once it finishes, read the generated `assets/transcript.txt` and a couple
   of the sampled frames in `assets/frames/` to understand what the video
   actually covers.
4. Rewrite the generated `SKILL.md`'s `description` and body so the skill is
   actually useful later: name the real topic, summarize what the video
   shows/says in your own words, and note anything a future invocation of
   this skill should know (don't just leave the auto-generated placeholder
   text).
5. Report back: the skill's path, its name, frame count, and a one-line
   summary of what the video was about.

If the download or transcription step fails outright, report the exact
error rather than guessing at the video's content — do not fabricate a
transcript or description.
