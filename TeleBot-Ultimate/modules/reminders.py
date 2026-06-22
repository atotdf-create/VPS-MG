from telegram import Update
from telegram.ext import ContextTypes
from database import db
import datetime
import asyncio

async def set_reminder(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not context.args or len(context.args) < 2:
        await update.message.reply_text("Usage: /remind <time_in_minutes> <message>")
        return

    try:
        minutes = int(context.args[0])
        if minutes <= 0:
            await update.message.reply_text("Time must be a positive number of minutes.")
            return
    except ValueError:
        await update.message.reply_text("Invalid time. Please provide a number in minutes.")
        return

    message = " ".join(context.args[1:])
    user_id = update.effective_user.id
    remind_at = datetime.datetime.now() + datetime.timedelta(minutes=minutes)

    db.add_reminder(user_id, message, remind_at.isoformat())
    await update.message.reply_text(f"Reminder set for {minutes} minutes from now: '{message}'")

async def check_reminders(context: ContextTypes.DEFAULT_TYPE) -> None:
    reminders = db.get_pending_reminders()
    for reminder_id, user_id, message in reminders:
        try:
            await context.bot.send_message(chat_id=user_id, text=f"Reminder: {message}")
            db.delete_reminder(reminder_id)
        except Exception as e:
            print(f"Failed to send reminder to user {user_id}: {e}")

async def save_note(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not context.args or len(context.args) < 2:
        await update.message.reply_text("Usage: /savenote <title> <content>")
        return

    title = context.args[0]
    content = " ".join(context.args[1:])
    user_id = update.effective_user.id

    db.add_note(user_id, title, content)
    await update.message.reply_text(f"Note '{title}' saved successfully.")

async def get_notes(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    user_id = update.effective_user.id
    notes = db.get_notes(user_id)

    if not notes:
        await update.message.reply_text("You have no saved notes.")
        return

    message = "Your Notes:\n\n"
    for title, content, timestamp in notes:
        message += f"**{title}** (Saved on {timestamp}):\n{content}\n\n"
    await update.message.reply_text(message)

async def delete_note(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not context.args or len(context.args) < 1:
        await update.message.reply_text("Usage: /delnote <title>")
        return

    title = context.args[0]
    user_id = update.effective_user.id

    db.delete_note(user_id, title)
    await update.message.reply_text(f"Note '{title}' deleted successfully (if it existed).")
