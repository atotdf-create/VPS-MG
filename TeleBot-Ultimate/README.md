# TeleBot-Ultimate

[![Python](https://img.shields.io/badge/Python-3.9%2B-blue?style=flat-square&logo=python)](https://www.python.org/)
[![python-telegram-bot](https://img.shields.io/badge/python--telegram--bot-20.8-blue?style=flat-square&logo=telegram)](https://python-telegram-bot.org/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

A full-featured, multi-purpose Telegram bot built with Python, designed for easy deployment on a VPS or via Docker.

## Features

- **Group Management**: Kick, ban, mute, warn users, set rules, welcome messages.
- **File Tools**: Download videos/audio from YouTube, Instagram, TikTok links using `yt-dlp`.
- **Utilities**: Weather forecasts (OpenWeatherMap API), text translation, currency conversion, calculator.
- **Search**: Google search, image search, Wikipedia integration.
- **AI Chat**: Conversational replies powered by OpenAI API.
- **Reminders/Notes**: Set personal reminders and save notes per user.
- **Admin Panel**: Bot statistics, broadcast messages, user management.

## Technical Specifications

- **Language**: Python 3.9+
- **Library**: `python-telegram-bot` (latest version)
- **Database**: SQLite for user data, notes, warnings, etc.
- **Configuration**: `.env` file for API keys and bot token.
- **Architecture**: Modular structure with separate files for each feature group.
- **Dependencies**: `requirements.txt` for easy installation.
- **Deployment**: 
  - `Dockerfile` for Docker containerization.
  - `docker-compose.yml` for multi-service deployment.
  - `telebot.service` for systemd integration on VPS.

## File Structure

```
TeleBot-Ultimate/
├── bot.py (main entry point)
├── config.py (load env vars)
├── .env.example (template for API keys)
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
├── telebot.service (systemd service file)
├── README.md
├── database/
│   └── db.py (SQLite handler)
├── modules/
│   ├── group_management.py
│   ├── file_tools.py
│   ├── utilities.py
│   ├── search.py
│   ├── ai_chat.py
│   ├── reminders.py
│   └── admin.py
└── utils/
    └── helpers.py
```

## Installation

### Prerequisites

- Python 3.9+
- pip
- Git
- Docker (optional, for Docker deployment)

### Steps

1. **Clone the repository:**

   ```bash
   git clone https://github.com/atotdf-create/VPS-MG.git
   cd VPS-MG/TeleBot-Ultimate
   ```

2. **Set up environment variables:**

   Copy the example environment file and fill in your API keys and bot token.

   ```bash
   cp .env.example .env
   ```

   Edit the `.env` file:

   ```
   BOT_TOKEN=YOUR_TELEGRAM_BOT_TOKEN
   OPENAI_API_KEY=YOUR_OPENAI_API_KEY
   OPENWEATHER_API_KEY=YOUR_OPENWEATHER_API_KEY
   GOOGLE_API_KEY=YOUR_GOOGLE_API_KEY
   GOOGLE_CSE_ID=YOUR_GOOGLE_CUSTOM_SEARCH_ENGINE_ID
   ```

   - **Telegram Bot Token**: Obtain from BotFather on Telegram.
   - **OpenAI API Key**: Get from the OpenAI platform.
   - **OpenWeatherMap API Key**: Register on OpenWeatherMap.
   - **Google API Key & CSE ID**: Create a Custom Search Engine and get API keys from Google Cloud Console.

3. **Install dependencies:**

   ```bash
   pip install -r requirements.txt
   ```

## Usage

### Running Locally

```bash
python3 bot.py
```

### Deployment on a VPS (Systemd)

1. **Copy the project to your VPS.**

2. **Install dependencies** (if not using Docker):

   ```bash
   sudo apt update
   sudo apt install python3 python3-pip
   pip install -r requirements.txt
   ```

3. **Copy the systemd service file:**

   ```bash
   sudo cp telebot.service /etc/systemd/system/
   ```

4. **Reload systemd and start the service:**

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable telebot.service
   sudo systemctl start telebot.service
   ```

5. **Check the bot status:**

   ```bash
   sudo systemctl status telebot.service
   ```

### Deployment with Docker

1. **Build the Docker image:**

   ```bash
   docker build -t telebot-ultimate .
   ```

2. **Run the Docker container:**

   ```bash
   docker run -d --name telebot-ultimate --env-file .env telebot-ultimate
   ```

### Deployment with Docker Compose

1. **Ensure your `.env` file is configured.**

2. **Run Docker Compose:**

   ```bash
   docker-compose up -d
   ```

## Contributing

Feel free to fork the repository, open issues, and submit pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
