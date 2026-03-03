API endpoints for local testing / deploy

Available endpoints

- /api/profile-sync.php
  - Accepts POST with JSON body (application/json) - will append payload to data/profile_sync.log
  - Accepts multipart/form-data with file field `image` and returns JSON { success: true, url: 'https://<your-host>/uploads/<file>' }
  - Requires API key (X-API-Key header or form field `api_key`). Key used by the app: 8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef

- /api/business-sync.php
  - Accepts POST with JSON body (application/json) - will append payload to data/business_sync.log
  - Accepts multipart/form-data with file field `file` and returns JSON { success: true, url: 'https://<your-host>/uploads/<file>' }
  - Requires API key (X-API-Key header or form field `api_key`)

Deployment notes

- Copy the `api` folder to your web server's document root (for example `public_html/api`)
- Ensure `uploads/` and `data/` directories are writable by the web server user (chmod 755 or 775 as needed)
- After deployment, test using curl:

  # Upload an image (profile)
  curl -X POST -H "X-API-Key: 8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef" -F "image=@/path/to/file.jpg" https://your-host.example/api/profile-sync.php

  # Send JSON payload
  curl -X POST -H "Content-Type: application/json" -H "X-API-Key: 8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef" -d '{"userId":"u1","name":"Test"}' https://your-host.example/api/profile-sync.php

- If you want server-side delete/list functionality or database persistence, extend the scripts or implement a proper backend (recommended for production)
