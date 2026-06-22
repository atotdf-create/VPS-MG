import asyncio
import yt_dlp
import os
import shutil
from telegram import Update
from telegram.ext import ContextTypes

async def download_media(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not context.args:
        await update.message.reply_text("Please provide a link to download.")
        return

    url = context.args[0]
    chat_id = update.effective_chat.id

    await update.message.reply_text(f"Downloading media from {url}... This might take a while.")

    try:
        # Create a temporary directory for downloads
        download_dir = f"downloads/{chat_id}"
        os.makedirs(download_dir, exist_ok=True)

        ydl_opts = {
            'format': 'bestaudio/best' if 'audio' in context.args else 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best',
            'outtmpl': os.path.join(download_dir, '%(title)s.%(ext)s'),
            'noplaylist': True,
            'progress_hooks': [lambda d: asyncio.create_task(download_progress_hook(d, update, context))]
        }

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            filepath = ydl.prepare_filename(info)

        await update.message.reply_text("Download complete. Uploading...")

        if os.path.exists(filepath):
            if 'audio' in context.args:
                await context.bot.send_audio(chat_id=chat_id, audio=open(filepath, 'rb'), title=info.get('title', 'audio'))
            else:
                await context.bot.send_video(chat_id=chat_id, video=open(filepath, 'rb'), caption=info.get('title', 'video'))
            os.remove(filepath) # Clean up the downloaded file
        else:
            await update.message.reply_text("Error: Downloaded file not found.")

    except Exception as e:
        await update.message.reply_text(f"An error occurred during download: {e}")
    finally:
        # Clean up the temporary directory
        if os.path.exists(download_dir):
            shutil.rmtree(download_dir)

async def download_progress_hook(d, update: Update, context: ContextTypes.DEFAULT_TYPE):
    if d['status'] == 'downloading':
        # You can add progress updates here if needed, but it can be spammy for short downloads
        pass
    elif d['status'] == 'finished':
        await context.bot.send_message(chat_id=update.effective_chat.id, text="Finished downloading.")

async def youtube_dl(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    context.args.append('video') # Default to video if not specified
    await download_media(update, context)

async def youtube_audio_dl(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    context.args.append('audio')
    await download_media(update, context)

async def instagram_dl(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    context.args.append('video') # Instagram usually video/image, treat as video for now
    await download_media(update, context)

async def tiktok_dl(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    context.args.append('video') # TikTok is primarily video
    await download_media(update, context)
