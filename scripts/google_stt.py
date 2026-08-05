#!/opt/venv/bin/python
"""
🎤 Hermes STT — Google Speech Recognition (رایگان)
خروجی: فایل transcript.txt در output_dir
"""
import sys
import os
import subprocess

os.environ['PATH'] = '/data/bin:/opt/venv/bin:/usr/local/bin:' + os.environ.get('PATH', '')

# ── نصب خودکار پکیج‌ها ──
try:
    import speech_recognition
except ImportError:
    subprocess.run([sys.executable, '-m', 'pip', 'install', 'SpeechRecognition', '--quiet', '--no-cache-dir'], capture_output=True)
    import speech_recognition

try:
    from pydub import AudioSegment
except ImportError:
    subprocess.run([sys.executable, '-m', 'pip', 'install', 'pydub', '--quiet', '--no-cache-dir'], capture_output=True)
    from pydub import AudioSegment

# ── آرگومان‌ها ──
input_path = sys.argv[1] if len(sys.argv) > 1 else None
output_dir = sys.argv[2] if len(sys.argv) > 2 else None

if not input_path:
    print("Usage: google_stt.py <input_audio> [output_dir]", file=sys.stderr)
    sys.exit(1)

if not output_dir:
    output_dir = os.path.dirname(input_path) or '.'
os.makedirs(output_dir, exist_ok=True)

# ── تبدیل به WAV ──
wav_path = input_path
if not input_path.lower().endswith('.wav'):
    wav_path = os.path.join(output_dir, 'temp_stt.wav')
    try:
        audio = AudioSegment.from_file(input_path)
        audio = audio.set_frame_rate(16000).set_channels(1)
        audio.export(wav_path, format='wav')
    except Exception as e:
        print(f"Audio conversion error: {e}", file=sys.stderr)
        sys.exit(1)

# ── تبدیل صوت به متن ──
try:
    recognizer = speech_recognition.Recognizer()
    with speech_recognition.AudioFile(wav_path) as source:
        audio_data = recognizer.record(source)
    text = recognizer.recognize_google(audio_data, language='fa-IR')

    # ── نوشتن خروجی در فایل .txt ──
    txt_path = os.path.join(output_dir, 'transcript.txt')
    with open(txt_path, 'w', encoding='utf-8') as f:
        f.write(text)

    print(text)

except speech_recognition.UnknownValueError:
    print("Could not understand audio", file=sys.stderr)
    sys.exit(1)
except speech_recognition.RequestError as e:
    print(f"Google STT error: {e}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
