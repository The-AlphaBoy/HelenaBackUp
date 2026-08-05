#!/usr/bin/env python3
"""
🎤 Hermes STT Script — Google Speech Recognition
رایگان، بدون API key، پشتیبانی فارسی
"""
import sys
import os
import speech_recognition as sr
from pydub import AudioSegment

def transcribe(audio_path, language='fa'):
    """ترنسکریبت فایل صوتی"""
    # تبدیل OGG به WAV
    audio = AudioSegment.from_ogg(audio_path)
    wav_path = '/tmp/hermes_stt_temp.wav'
    audio.export(wav_path, format='wav')
    
    # Google Speech Recognition
    recognizer = sr.Recognizer()
    with sr.AudioFile(wav_path) as source:
        audio_data = recognizer.record(source)
    
    try:
        text = recognizer.recognize_google(audio_data, language=f'{language}-IR')
        os.remove(wav_path)
        return text
    except sr.UnknownValueError:
        os.remove(wav_path)
        return None
    except sr.RequestError as e:
        os.remove(wav_path)
        return None

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python stt_script.py <audio_file> [language]")
        sys.exit(1)
    
    audio_path = sys.argv[1]
    language = sys.argv[2] if len(sys.argv) > 2 else 'fa'
    
    result = transcribe(audio_path, language)
    if result:
        print(result)
    else:
        sys.exit(1)
