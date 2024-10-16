#!/bin/bash

# Set your ngrok authentication token
NGROK_AUTHTOKEN=""
PHP_PORT=8080
NGROK_PORT=4040  # Ngrok’s local status API runs on 4040

# Function to test if a service is running
test_service() {
  local url=$1
  echo "Testing service at $url..."
  response=$(curl -s -o /dev/null -w "%{http_code}" "$url")

  if [ "$response" -eq 200 ]; then
    echo "Service is up and running!"
  else
    echo "Failed to connect to $url. HTTP status code: $response"
  fi
}

# Function to check if a port is in use and clean up
check_and_clean_port() {
  local port=$1
  echo "Checking if port $port is in use..."
  pid=$(lsof -ti:$port)

  if [ -n "$pid" ]; then
    echo "Port $port is in use by PID $pid. Stopping the process..."
    kill -9 $pid
    echo "Process on port $port stopped."
  else
    echo "Port $port is free."
  fi
}

# Function to clean up existing Docker containers by name
cleanup_docker_container() {
  local container_name=$1
  if [ $(docker ps -aq -f name=$container_name) ]; then
    echo "Removing existing Docker container: $container_name"
    docker rm -f $container_name
  fi
}

# Ensure the work environment is clean by checking ports
check_and_clean_port $PHP_PORT
check_and_clean_port $NGROK_PORT

# Clean up any existing PHP message board and Ngrok containers
cleanup_docker_container "php-message-board"
cleanup_docker_container "ngrok-tunnel"

# Step 1: Set up a PHP message board using Docker
echo "Setting up PHP message board..."

# Pull the official PHP-Apache Docker image
docker pull php:apache

# Create a directory for the message board and add a basic PHP script
MESSAGE_BOARD_DIR="./php_message_board"
mkdir -p $MESSAGE_BOARD_DIR
cat <<EOL > $MESSAGE_BOARD_DIR/index.php
<?php
if (\$_SERVER['REQUEST_METHOD'] == 'POST' && !empty(\$_POST['message'])) {
    \$message = htmlspecialchars(\$_POST['message']);
    file_put_contents('messages.txt', \$message . "\n", FILE_APPEND);
}
\$messages = file_exists('messages.txt') ? file('messages.txt', FILE_IGNORE_NEW_LINES) : [];
?>
<!DOCTYPE html>
<html lang="en">
<head><title>PHP Message Board</title></head>
<body>
    <h1>Message Board</h1>
    <form method="post">
        <textarea name="message" rows="4" cols="50"></textarea><br>
        <button type="submit">Post Message</button>
    </form>
    <ul><?php foreach (\$messages as \$msg): ?><li><?= \$msg ?></li><?php endforeach; ?></ul>
</body></html>
EOL

# Run the PHP message board using Docker
echo "Running PHP message board with Docker..."
docker run --name php-message-board -p $PHP_PORT:80 -v $MESSAGE_BOARD_DIR:/var/www/html -d php:apache

echo "Waiting for the PHP message board to start..."
sleep 5  # Give it some time to initialize

# Test the PHP message board locally
test_service "http://localhost:$PHP_PORT"

# Step 2: Pull the ngrok Docker image
echo "Pulling ngrok Docker image..."
docker pull ngrok/ngrok

# Step 3: Run ngrok using Docker to expose the PHP message board
echo "Starting ngrok with Docker..."
docker run --name ngrok-tunnel --net=host -e NGROK_AUTHTOKEN=$NGROK_AUTHTOKEN ngrok/ngrok:latest http $PHP_PORT &

# Give Ngrok time to establish the tunnel
sleep 10

# Step 4: Test if Ngrok is working
NGROK_URL=$(curl --silent http://127.0.0.1:$NGROK_PORT/api/tunnels | jq -r '.tunnels[0].public_url')

if [[ -z "$NGROK_URL" || "$NGROK_URL" == "null" ]]; then
  echo "Ngrok failed to start. Check your configuration."
  exit 1
else
  echo "Ngrok is running at $NGROK_URL"
fi

# Test the Ngrok tunnel
test_service "$NGROK_URL"

# Debugging: Show Ngrok logs (optional)
echo "Fetching Ngrok logs for debugging..."
docker logs ngrok-tunnel
