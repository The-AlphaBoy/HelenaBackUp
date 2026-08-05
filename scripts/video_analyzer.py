#!/usr/bin/env python3
"""
Video Analyzer - analyze video with NVIDIA Vision API
"""
import base64
import json
import os
import subprocess
import sys
import tempfile
import urllib.request

NVIDIA_API_KEY = os.environ.get("NVIDIA_API_KEY", "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")
FFMPEG_PATH = "/usr/bin/ffmpeg"
VISION_MODEL = "meta/llama-3.2-90b-vision-instruct"

def get_video_duration(video_path):
    cmd = [FFMPEG_PATH, "-i", video_path, "-show_entries", "format=duration", "-v", "quiet", "-of", "csv=p=0"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    try:
        return float(result.stdout.strip())
    except:
        return 10.0

def extract_frames(video_path, num_frames=5):
    duration = get_video_duration(video_path)
    interval = max(1, int(duration // num_frames))
    
    with tempfile.TemporaryDirectory() as tmpdir:
        cmd = [
            FFMPEG_PATH, "-i", video_path,
            "-vf", "fps=1/" + str(interval),
            "-q:v", "2",
            os.path.join(tmpdir, "frame_%03d.jpg")
        ]
        subprocess.run(cmd, capture_output=True)
        
        frames = []
        for f in sorted(os.listdir(tmpdir)):
            if f.endswith(".jpg"):
                with open(os.path.join(tmpdir, f), "rb") as fp:
                    frames.append(base64.b64encode(fp.read()).decode())
        return frames

def analyze_frame(frame_b64, prompt="Describe this image"):
    payload = {
        "model": VISION_MODEL,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64," + frame_b64}}
                ]
            }
        ],
        "max_tokens": 300
    }
    
    req = urllib.request.Request(
        "https://integrate.api.nvidia.com/v1/chat/completions",
        data=json.dumps(payload).encode(),
        headers={
            "Authorization": "Bearer " + NVIDIA_API_KEY,
            "Content-Type": "application/json"
        }
    )
    
    with urllib.request.urlopen(req, timeout=30) as response:
        result = json.loads(response.read())
        return result["choices"][0]["message"]["content"]

def analyze_video(video_path, prompt="What is in this video? Summarize it briefly."):
    print("Extracting frames from " + video_path + "...")
    frames = extract_frames(video_path, num_frames=5)
    
    if not frames:
        return "No frames extracted!"
    
    print(str(len(frames)) + " frames extracted")
    
    analyses = []
    for i, frame in enumerate(frames):
        print("Analyzing frame " + str(i+1) + "/" + str(len(frames)) + "...")
        try:
            analysis = analyze_frame(frame, prompt)
            analyses.append("Frame " + str(i+1) + ": " + analysis)
        except Exception as e:
            analyses.append("Frame " + str(i+1) + ": ERROR - " + str(e))
    
    return "\n\n".join(analyses)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python video_analyzer.py <video_path> [prompt]")
        sys.exit(1)
    
    video_path = sys.argv[1]
    prompt = sys.argv[2] if len(sys.argv) > 2 else "What is in this video? Summarize it briefly."
    
    result = analyze_video(video_path, prompt)
    print("\n" + "="*50)
    print("Analysis Result:")
    print("="*50)
    print(result)
