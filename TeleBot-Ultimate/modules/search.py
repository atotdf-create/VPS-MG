import requests
from telegram import Update
from telegram.ext import ContextTypes
from config import GOOGLE_API_KEY, GOOGLE_CSE_ID
import wikipedia

async def google_search(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not context.args:
        await update.message.reply_text("Please provide a search query. Usage: /google <query>")
        return

    query = " ".join(context.args)
    search_url = "https://www.googleapis.com/customsearch/v1"
    params = {
        "key": GOOGLE_API_KEY,
        "cx": GOOGLE_CSE_ID,
        "q": query
    }

    try:
        response = requests.get(search_url, params=params)
        data = response.json()

        if "items" in data:
            results = data["items"]
            message = "Google Search Results:\n\n"
            for i, item in enumerate(results[:5]): # Limit to 5 results
                message += f"{i+1}. <a href=\"{item["link"]}\">{item["title"]}</a>\n{item["snippet"]}\n\n"
            await update.message.reply_text(message, parse_mode="HTML", disable_web_page_preview=True)
        else:
            await update.message.reply_text("No results found for your query.")

    except Exception as e:
        await update.message.reply_text(f"An error occurred during Google search: {e}")

async def google_image_search(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not context.args:
        await update.message.reply_text("Please provide an image search query. Usage: /image <query>")
        return

    query = " ".join(context.args)
    search_url = "https://www.googleapis.com/customsearch/v1"
    params = {
        "key": GOOGLE_API_KEY,
        "cx": GOOGLE_CSE_ID,
        "q": query,
        "searchType": "image"
    }

    try:
        response = requests.get(search_url, params=params)
        data = response.json()

        if "items" in data:
            image_results = data["items"]
            # Send the first image found
            if image_results:
                image_url = image_results[0]["link"]
                await update.message.reply_photo(photo=image_url, caption=f"Image for: {query}")
            else:
                await update.message.reply_text("No image results found for your query.")
        else:
            await update.message.reply_text("No image results found for your query.")

    except Exception as e:
        await update.message.reply_text(f"An error occurred during Google image search: {e}")

async def wikipedia_search(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not context.args:
        await update.message.reply_text("Please provide a Wikipedia search query. Usage: /wiki <query>")
        return

    query = " ".join(context.args)
    try:
        # Set language for Wikipedia search (optional, defaults to English)
        wikipedia.set_lang("en")
        summary = wikipedia.summary(query, sentences=3) # Get first 3 sentences
        page_url = wikipedia.page(query).url
        await update.message.reply_text(f"Wikipedia Summary for '{query}':\n\n{summary}\n\nRead more: {page_url}", disable_web_page_preview=True)
    except wikipedia.exceptions.PageError:
        await update.message.reply_text(f"No Wikipedia page found for '{query}'.")
    except wikipedia.exceptions.DisambiguationError as e:
        await update.message.reply_text(f"'{query}' is too ambiguous. Please be more specific. Possible options: {e.options[:5]}")
    except Exception as e:
        await update.message.reply_text(f"An error occurred during Wikipedia search: {e}")
