#!/bin/bash
# Emergency SSH re-enable script
sudo systemctl start ssh
sudo systemctl enable ssh
sudo ufw allow 22/tcp
echo "✅ SSH re-enabled on port 22"
