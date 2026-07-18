@echo off
for /f "tokens=2 delims==" %%a in ('findstr POSTMAN_API_KEY C:\Users\kasha\postman-mcp.bat') do set POSTMAN_API_KEY=%%a
curl -s -X POST "https://api.getpostman.com/collections?workspace=8f8205b4-1f6e-4b7b-8b73-1397399bbabc" -H "X-Api-Key: %POSTMAN_API_KEY%" -H "Content-Type: application/json" --data-binary "@d:\Elay_Backend-master\.cursor\chat-day12-upload-body.json"
