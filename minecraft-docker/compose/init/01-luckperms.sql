-- Create LuckPerms databases for 2b2t.tech Minecraft network
CREATE DATABASE IF NOT EXISTS luckperms_2b2t;
CREATE USER IF NOT EXISTS 'lpsql'@'%' IDENTIFIED BY 'your-db-password-here';
GRANT ALL PRIVILEGES ON luckperms_2b2t.* TO 'lpsql'@'%';
FLUSH PRIVILEGES;
