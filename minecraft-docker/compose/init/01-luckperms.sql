-- Create LuckPerms databases for 2b2t.tech Minecraft network
CREATE DATABASE IF NOT EXISTS luckperms_2b2t;
-- IMPORTANT: Replace the password below or set via docker-compose environment.
-- The docker-compose.yml injects LUCKPERMS_DB_PASSWORD env var at runtime.
CREATE USER IF NOT EXISTS 'lpsql'@'%' IDENTIFIED BY 'change-me-in-production';
GRANT ALL PRIVILEGES ON luckperms_2b2t.* TO 'lpsql'@'%';
FLUSH PRIVILEGES;
