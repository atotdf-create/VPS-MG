import logging
import asyncio
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

from config import BOT_TOKEN
from database import db
from modules import group_management, file_tools, utilities, search, ai_chat, reminders, admin
from modules.ai_chat import clear_chat_history, inline_query_handler, voice_message_handler, image_message_handler, generate_image_command, summarize_command, execute_code_command

# Enable logging
logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", level=logging.INFO
)
logger = logging.getLogger(__name__)

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    user = update.effective_user
    db.add_user(user.id, user.username, user.first_name, user.last_name)
    await update.message.reply_html(
        f"Hi {user.mention_html()}! I am your ultimate Telegram bot. How can I help you today?",
    )

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    help_text = (
        "Here are the commands you can use:\n\n"
        "*Group Management*\n"
        "/set_welcome <message> - Set welcome message for new members. Use {user} as placeholder.\n"
        "/set_rules <message> - Set group rules.\n"
        "/rules - Get group rules.\n"
        "/kick - Reply to a user to kick them.\n"
        "/ban [reason] - Reply to a user to ban them.\n"
        "/unban <user_id> - Unban a user by ID.\n"
        "/mute <duration_in_minutes> [reason] - Reply to a user to mute them.\n"
        "/unmute - Reply to a user to unmute them.\n"
        "/warn [reason] - Reply to a user to warn them.\n\n"
        "*File Tools*\n"
        "/yt_dl <url> - Download video from YouTube.\n"
        "/yt_audio_dl <url> - Download audio from YouTube.\n"
        "/insta_dl <url> - Download media from Instagram.\n"
        "/tiktok_dl <url> - Download media from TikTok.\n\n"
        "*Utilities*\n"
        "/weather <city> - Get weather information.\n"
        "/translate <target_lang> <text> - Translate text.\n"
        "/calc <expression> - Evaluate a mathematical expression.\n"
        "/currency - Currency converter (not yet implemented).\n\n"
        "*Search*\n"
        "/google <query> - Google search.\n"
        "/image <query> - Google image search.\n"
        "/wiki <query> - Wikipedia search.\n\n"
        "*AI Chat*\n"
        "Just chat with me directly!\n\n"
        "*Reminders/Notes*\n"
        "/remind <time_in_minutes> <message> - Set a reminder.\n"
        "/savenote <title> <content> - Save a personal note.\n"
        "/getnotes - Retrieve your saved notes.\n"
        "/delnote <title> - Delete a note.\n\n"
        "*Admin Panel* (Admin only)\n"
        "/set_admin <user_id> - Grant admin status.\n"
        "/remove_admin <user_id> - Revoke admin status.\n"
        "/bot_stats - Get bot statistics.\n"
        "/broadcast <message> - Broadcast message to all users.\n"
    )
    await update.message.reply_text(help_text)

async def post_init(application: Application) -> None:
    # Schedule reminder checks
    application.job_queue.run_repeating(reminders.check_reminders, interval=60, first=10)
    logger.info("Reminder job scheduled.")

def main() -> None:
    db.init_db()
    logger.info("Database initialized.")

    application = Application.builder().token(BOT_TOKEN).post_init(post_init).build()

    # Handlers
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("help", help_command))

    # Group Management
    application.add_handler(MessageHandler(filters.StatusUpdate.NEW_CHAT_MEMBERS, group_management.welcome_message))
    application.add_handler(CommandHandler("set_welcome", group_management.set_welcome))
    application.add_handler(CommandHandler("set_rules", group_management.set_rules))
    application.add_handler(CommandHandler("rules", group_management.rules))
    application.add_handler(CommandHandler("kick", group_management.kick_user))
    application.add_handler(CommandHandler("ban", group_management.ban_user))
    application.add_handler(CommandHandler("unban", group_management.unban_user))
    application.add_handler(CommandHandler("mute", group_management.mute_user))
    application.add_handler(CommandHandler("unmute", group_management.unmute_user))
    application.add_handler(CommandHandler("warn", group_management.warn_user))

    # File Tools
    application.add_handler(CommandHandler("yt_dl", file_tools.youtube_dl))
    application.add_handler(CommandHandler("yt_audio_dl", file_tools.youtube_audio_dl))
    application.add_handler(CommandHandler("insta_dl", file_tools.instagram_dl))
    application.add_handler(CommandHandler("tiktok_dl", file_tools.tiktok_dl))

    # Utilities
    application.add_handler(CommandHandler("weather", utilities.weather))
    application.add_handler(CommandHandler("translate", utilities.translate_text))
    application.add_handler(CommandHandler("calc", utilities.calculate))
    application.add_handler(CommandHandler("currency", utilities.currency_converter))

    # Search
    application.add_handler(CommandHandler("google", search.google_search))
    application.add_handler(CommandHandler("image", search.google_image_search))
    application.add_handler(CommandHandler("wiki", search.wikipedia_search))

    # AI Chat - responds to any text message not handled by other commands
    application.add_handler(CommandHandler("clear_history", clear_chat_history))
    application.add_handler(CommandHandler("generate_image", generate_image_command))
    application.add_handler(CommandHandler("summarize", summarize_command))
    application.add_handler(CommandHandler("exec_code", execute_code_command))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, ai_chat.ai_chat_reply))
    application.add_handler(MessageHandler(filters.VOICE, voice_message_handler))
    application.add_handler(MessageHandler(filters.PHOTO, image_message_handler))
    application.add_handler(InlineQueryHandler(inline_query_handler))

    # Reminders/Notes
    application.add_handler(CommandHandler("remind", reminders.set_reminder))
    application.add_handler(CommandHandler("savenote", reminders.save_note))
    application.add_handler(CommandHandler("getnotes", reminders.get_notes))
    application.add_handler(CommandHandler("delnote", reminders.delete_note))

    # Admin Panel
    application.add_handler(CommandHandler("set_admin", admin.set_admin))
    application.add_handler(CommandHandler("remove_admin", admin.remove_admin))
    application.add_handler(CommandHandler("bot_stats", admin.bot_stats))
    application.add_handler(CommandHandler("broadcast", admin.broadcast_message))

    # Run the bot until the user presses Ctrl-C
    application.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == "__main__":
    main()
