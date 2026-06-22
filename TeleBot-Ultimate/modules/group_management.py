from telegram import Update, ChatPermissions
from telegram.ext import ContextTypes
from database import db
import datetime

async def welcome_message(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if update.message.new_chat_members:
        for user in update.message.new_chat_members:
            db.add_user(user.id, user.username, user.first_name, user.last_name)
            group_id = update.effective_chat.id
            group_info = db.get_group(group_id)
            if group_info and group_info[2]:  # welcome_message exists
                await update.message.reply_text(group_info[2].format(user=user.full_name))
            else:
                await update.message.reply_text(f"Welcome to the group, {user.full_name}!")

async def set_welcome(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.effective_chat.type in ["group", "supergroup"]:
        await update.message.reply_text("This command can only be used in a group.")
        return

    if not context.args:
        await update.message.reply_text("Usage: /set_welcome <message>. Use {user} as a placeholder for the new member's name.")
        return

    group_id = update.effective_chat.id
    welcome_msg = " ".join(context.args)
    db.add_group(group_id, update.effective_chat.title)
    db.update_group_welcome_message(group_id, welcome_msg)
    await update.message.reply_text("Welcome message set successfully!")

async def set_rules(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.effective_chat.type in ["group", "supergroup"]:
        await update.message.reply_text("This command can only be used in a group.")
        return

    if not context.args:
        await update.message.reply_text("Usage: /set_rules <rules message>")
        return

    group_id = update.effective_chat.id
    rules_msg = " ".join(context.args)
    db.add_group(group_id, update.effective_chat.title)
    db.update_group_rules_message(group_id, rules_msg)
    await update.message.reply_text("Rules message set successfully!")

async def rules(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.effective_chat.type in ["group", "supergroup"]:
        await update.message.reply_text("This command can only be used in a group.")
        return

    group_id = update.effective_chat.id
    group_info = db.get_group(group_id)
    if group_info and group_info[3]:  # rules_message exists
        await update.message.reply_text(group_info[3])
    else:
        await update.message.reply_text("No rules have been set for this group yet.")

async def kick_user(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.effective_chat.type in ["group", "supergroup"]:
        await update.message.reply_text("This command can only be used in a group.")
        return

    if not update.message.reply_to_message:
        await update.message.reply_text("Reply to a user's message to kick them.")
        return

    target_user = update.message.reply_to_message.from_user
    chat_id = update.effective_chat.id
    admin_id = update.effective_user.id

    try:
        await context.bot.kick_chat_member(chat_id, target_user.id)
        await update.message.reply_text(f"{target_user.full_name} has been kicked.")
    except Exception as e:
        await update.message.reply_text(f"Failed to kick user: {e}")

async def ban_user(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.effective_chat.type in ["group", "supergroup"]:
        await update.message.reply_text("This command can only be used in a group.")
        return

    if not update.message.reply_to_message:
        await update.message.reply_text("Reply to a user's message to ban them.")
        return

    target_user = update.message.reply_to_message.from_user
    chat_id = update.effective_chat.id
    admin_id = update.effective_user.id
    reason = " ".join(context.args) if context.args else "No reason provided."

    try:
        await context.bot.ban_chat_member(chat_id, target_user.id)
        db.add_ban(target_user.id, chat_id, admin_id, reason)
        await update.message.reply_text(f"{target_user.full_name} has been banned. Reason: {reason}")
    except Exception as e:
        await update.message.reply_text(f"Failed to ban user: {e}")

async def unban_user(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.effective_chat.type in ["group", "supergroup"]:
        await update.message.reply_text("This command can only be used in a group.")
        return

    if not context.args:
        await update.message.reply_text("Usage: /unban <user_id or username>")
        return

    chat_id = update.effective_chat.id
    target_identifier = context.args[0]

    try:
        # Try to unban by user ID first
        user_id = int(target_identifier)
        await context.bot.unban_chat_member(chat_id, user_id)
        db.remove_ban(user_id, chat_id)
        await update.message.reply_text(f"User with ID {user_id} has been unbanned.")
    except ValueError:
        # If not a number, assume it's a username (this is more complex as Telegram doesn't provide direct unban by username)
        await update.message.reply_text("Unbanning by username is not directly supported by Telegram Bot API. Please use user ID.")
    except Exception as e:
        await update.message.reply_text(f"Failed to unban user: {e}")

async def mute_user(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.effective_chat.type in ["group", "supergroup"]:
        await update.message.reply_text("This command can only be used in a group.")
        return

    if not update.message.reply_to_message:
        await update.message.reply_text("Reply to a user's message to mute them.")
        return

    target_user = update.message.reply_to_message.from_user
    chat_id = update.effective_chat.id
    admin_id = update.effective_user.id

    if not context.args or not context.args[0].isdigit():
        await update.message.reply_text("Usage: /mute <duration_in_minutes> [reason].")
        return

    duration_minutes = int(context.args[0])
    reason = " ".join(context.args[1:]) if len(context.args) > 1 else "No reason provided."
    until_date = datetime.datetime.now() + datetime.timedelta(minutes=duration_minutes)

    try:
        await context.bot.restrict_chat_member(
            chat_id,
            target_user.id,
            permissions=ChatPermissions(can_send_messages=False),
            until_date=until_date
        )
        db.add_mute(target_user.id, chat_id, admin_id, until_date.isoformat())
        await update.message.reply_text(f"{target_user.full_name} has been muted for {duration_minutes} minutes. Reason: {reason}")
    except Exception as e:
        await update.message.reply_text(f"Failed to mute user: {e}")

async def unmute_user(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.effective_chat.type in ["group", "supergroup"]:
        await update.message.reply_text("This command can only be used in a group.")
        return

    if not update.message.reply_to_message:
        await update.message.reply_text("Reply to a user's message to unmute them.")
        return

    target_user = update.message.reply_to_message.from_user
    chat_id = update.effective_chat.id

    try:
        await context.bot.restrict_chat_member(
            chat_id,
            target_user.id,
            permissions=ChatPermissions(can_send_messages=True,
                                                can_send_audios=True,
                                                can_send_documents=True,
                                                can_send_photos=True,
                                                can_send_videos=True,
                                                can_send_video_notes=True,
                                                can_send_voice_notes=True,
                                                can_send_polls=True,
                                                can_send_other_messages=True,
                                                can_add_web_page_previews=True,
                                                can_change_info=False,
                                                can_invite_users=True,
                                                can_pin_messages=False,
                                                can_manage_topics=False)
        )
        db.remove_mute(target_user.id, chat_id)
        await update.message.reply_text(f"{target_user.full_name} has been unmuted.")
    except Exception as e:
        await update.message.reply_text(f"Failed to unmute user: {e}")

async def warn_user(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.effective_chat.type in ["group", "supergroup"]:
        await update.message.reply_text("This command can only be used in a group.")
        return

    if not update.message.reply_to_message:
        await update.message.reply_text("Reply to a user's message to warn them.")
        return

    target_user = update.message.reply_to_message.from_user
    chat_id = update.effective_chat.id
    admin_id = update.effective_user.id
    reason = " ".join(context.args) if context.args else "No reason provided."

    db.add_warning(target_user.id, chat_id, admin_id, reason)
    warnings_count = db.get_warnings_count(target_user.id, chat_id)

    await update.message.reply_text(f"{target_user.full_name} has been warned. Reason: {reason}. Total warnings: {warnings_count}")


