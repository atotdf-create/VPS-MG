import requests
from telegram import Update
from telegram.ext import ContextTypes
from config import OPENWEATHER_API_KEY
from googletrans import Translator
import operator

async def weather(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not context.args:
        await update.message.reply_text("Please provide a city name. Usage: /weather <city>")
        return

    city = " ".join(context.args)
    base_url = "http://api.openweathermap.org/data/2.5/weather?"
    complete_url = f"{base_url}appid={OPENWEATHER_API_KEY}&q={city}&units=metric"

    response = requests.get(complete_url)
    data = response.json()

    if data["cod"] != "404":
        main = data["main"]
        weather_desc = data["weather"][0]

        temperature = main["temp"]
        pressure = main["pressure"]
        humidity = main["humidity"]
        description = weather_desc["description"]

        await update.message.reply_text(
            f"Weather in {city}:\n"
            f"Temperature: {temperature}°C\n"
            f"Pressure: {pressure} hPa\n"
            f"Humidity: {humidity}%\n"
            f"Description: {description.capitalize()}"
        )
    else:
        await update.message.reply_text("City not found.")

async def translate_text(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not context.args or len(context.args) < 2:
        await update.message.reply_text("Usage: /translate <target_language_code> <text_to_translate>")
        return

    target_lang = context.args[0]
    text_to_translate = " ".join(context.args[1:])

    translator = Translator()
    try:
        translated = translator.translate(text_to_translate, dest=target_lang)
        await update.message.reply_text(f"Translated ({target_lang}): {translated.text}")
    except Exception as e:
        await update.message.reply_text(f"Translation failed: {e}")

async def currency_converter(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    # This will require a currency exchange rate API.
    # For simplicity, let's use a placeholder.
    await update.message.reply_text("Currency converter feature is not yet implemented. Please provide a currency exchange rate API key and integrate it.")

async def calculate(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not context.args:
        await update.message.reply_text("Usage: /calc <expression>")
        return

    expression = " ".join(context.args)
    try:
        # Basic and safe evaluation for simple arithmetic expressions
        # WARNING: eval() is dangerous. For a production bot, use a safer math expression parser.
        result = eval(expression, {"__builtins__": None}, {
            "+": operator.add,
            "-": operator.sub,
            "*": operator.mul,
            "/": operator.truediv,
            "**": operator.pow, # Added power operator
            "%": operator.mod, # Added modulo operator
        })
        await update.message.reply_text(f"Result: {result}")
    except Exception as e:
        await update.message.reply_text(f"Calculation failed: {e}. Please ensure it's a valid arithmetic expression.")
