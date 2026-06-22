from telegram import Update
from telegram.ext import ContextTypes
from config import OPENAI_API_KEY
from openai import OpenAI

client = OpenAI(api_key=OPENAI_API_KEY)

async def ai_chat_reply(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.message.text:
        return

    user_message = update.message.text

    try:
        response = client.chat.completions.create(
            model="gpt-3.5-turbo", # Using a chat-optimized model
            messages=[
                {"role": "system", "content": "You are a helpful Telegram bot."}, # System message to set context
                {"role": "user", "content": user_message}
            ],
            max_tokens=150,
            temperature=0.7,
            top_p=1,
            frequency_penalty=0,
            presence_penalty=0
        )
        ai_response = response.choices[0].message.content.strip()
        await update.message.reply_text(ai_response)
    except Exception as e:
        await update.message.reply_text(f"AI chat failed: {e}")
