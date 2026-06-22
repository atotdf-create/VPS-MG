from telegram import Update
from telegram.ext import ContextTypes
from database import db

ADMIN_IDS = [YOUR_ADMIN_TELEGRAM_ID] # Replace with your Telegram User ID

def is_admin(user_id: int) -> bool:
    return user_id in ADMIN_IDS or db.get_user(user_id) and db.get_user(user_id)[4] == 1 # Check if user is in ADMIN_IDS or marked as admin in DB

async def set_admin(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("You are not authorized to use this command.")
        return

    if not context.args or not context.args[0].isdigit():
        await update.message.reply_text("Usage: /set_admin <user_id>")
        return

    target_user_id = int(context.args[0])
    db.update_user_admin_status(target_user_id, 1)
    await update.message.reply_text(f"User {target_user_id} has been set as admin.")

async def remove_admin(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("You are not authorized to use this command.")
        return

    if not context.args or not context.args[0].isdigit():
        await update.message.reply_text("Usage: /remove_admin <user_id>")
        return

    target_user_id = int(context.args[0])
    db.update_user_admin_status(target_user_id, 0)
    await update.message.reply_text(f"User {target_user_id} has been removed from admin.")

async def bot_stats(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("You are not authorized to use this command.")
        return

    total_users = len(db.get_all_users())
    # Add more stats here as needed, e.g., total groups, active mutes, etc.
    await update.message.reply_text(f"Bot Statistics:\nTotal Users: {total_users}")

async def broadcast_message(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("You are not authorized to use this command.")
        return

    if not context.args:
        await update.message.reply_text("Usage: /broadcast <message>")
        return

    message_to_broadcast = " ".join(context.args)
    all_users = db.get_all_users()

    success_count = 0
    fail_count = 0

    for user_id in all_users:
        try:
            await context.bot.send_message(chat_id=user_id, text=message_to_broadcast)
            success_count += 1
        except Exception as e:
            print(f"Failed to send message to user {user_id}: {e}")
            fail_count += 1

    await update.message.reply_text(f"Broadcast complete.\nSuccessful: {success_count}\nFailed: {fail_count}")
