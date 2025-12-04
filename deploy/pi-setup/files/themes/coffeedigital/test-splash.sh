#!/bin/bash
set -e

echo "Starting Plymouth splash test for 5 seconds..."
sudo plymouthd
sudo plymouth --show-splash
sleep 5
sudo plymouth --quit
echo "Splash test completed."
