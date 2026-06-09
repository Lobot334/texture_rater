@echo off
cd /d C:\ClaudeCode
start "" http://localhost:8000/texture_rater/
python -m http.server 8000