import logging
import asyncio
import io
import traceback
import contextlib
import json

from telegram import Update, InlineQueryResultArticle, InputTextMessageContent
from telegram.ext import ContextTypes
from config import OPENAI_API_KEY
from openai import AsyncOpenAI
from database import db

import edge_tts
import whisper_timestamped as whisper
from duckduckgo_search import DDGS

logger = logging.getLogger(__name__)
client = AsyncOpenAI(api_key=OPENAI_API_KEY)

SYSTEM_PROMPT = """You are a helpful, friendly, fast, and capable personal AI assistant on Telegram. You can answer any question intelligently, write code, essays, and summaries, have natural conversations with context and memory, help with math, science, and translations, and much more. You also have access to several tools:

1. Web Search: Use this tool to get up-to-date information from the internet. When asked a question that requires current knowledge or specific facts, use this tool. Example: 'What is the capital of France?' -> Use web search.
2. Image Generation (DALL-E): Use this tool to generate images from a text description. When the user asks to create an image, use this tool. Example: 'Generate an image of a cat playing piano.' -> Use DALL-E.
3. Code Execution: Use this tool to execute Python code and get the output. This is useful for calculations, data processing, or testing code snippets. Example: 'Run this Python code: print(2 + 2)' -> Use code execution.
4. Summarization: Use this tool to summarize long texts or articles from URLs. When the user asks to summarize something, use this tool. Example: 'Summarize this article: [URL]' -> Use summarization.

Always strive to be accurate, concise, and polite. Your responses should be clear and easy to understand. If you don't know something, admit it gracefully. When using a tool, clearly indicate what tool you are using and its purpose.
"""

async def ai_chat_reply(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.message or not update.message.text:
        return

    user_message = update.message.text
    chat_id = update.effective_chat.id

    # Add user message to history
    db.add_history(chat_id, "user", user_message)

    # Get conversation history
    conversation_history = db.get_history(chat_id, limit=10) # Limit to last 10 messages for context
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    for role, content in conversation_history:
        messages.append({"role": role, "content": content})

    # Define tools for OpenAI function calling
    tools = [
        {
            "type": "function",
            "function": {
                "name": "web_search",
                "description": "Get up-to-date information from the internet using a web search engine.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "query": {
                            "type": "string",
                            "description": "The search query."
                        }
                    },
                    "required": ["query"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "generate_image",
                "description": "Generate an image from a text description using DALL-E.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "prompt": {
                            "type": "string",
                            "description": "The text description for the image to be generated."
                        }
                    },
                    "required": ["prompt"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "execute_python_code",
                "description": "Execute Python code and return its output. Use this for calculations or testing code snippets.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "code": {
                            "type": "string",
                            "description": "The Python code to execute."
                        }
                    },
                    "required": ["code"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "summarize_text",
                "description": "Summarize a given text or the content of a URL.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "text_or_url": {
                            "type": "string",
                            "description": "The text or URL to summarize."
                        }
                    },
                    "required": ["text_or_url"]
                }
            }
        }
    ]

    try:
        # Send typing indicator
        await context.bot.send_chat_action(chat_id=chat_id, action="typing")

        response = await client.chat.completions.create(
            model="gpt-4o",
            messages=messages,
            tools=tools,
            tool_choice="auto",
            max_tokens=1000,
            temperature=0.7,
            stream=True
        )

        full_response_content = []
        tool_calls = []
        message_placeholder = None

        async for chunk in response:
            delta = chunk.choices[0].delta
            if delta.content:
                full_response_content.append(delta.content)
                if not message_placeholder:
                    message_placeholder = await update.message.reply_text("...")
                await message_placeholder.edit_text("".join(full_response_content))
                await asyncio.sleep(0.05) # Small delay to avoid hitting API limits
            if delta.tool_calls:
                for tool_call in delta.tool_calls:
                    tool_calls.append(tool_call)

        if tool_calls:
            for tool_call in tool_calls:
                function_name = tool_call.function.name
                function_args = json.loads(tool_call.function.arguments)

                if function_name == "web_search":
                    await context.bot.send_chat_action(chat_id=chat_id, action="typing")
                    search_results = await perform_web_search(function_args.get("query"))
                    messages.append({"role": "tool", "tool_call_id": tool_call.id, "name": function_name, "content": search_results})
                elif function_name == "generate_image":
                    await context.bot.send_chat_action(chat_id=chat_id, action="upload_photo")
                    image_url = await generate_image_with_dalle(function_args.get("prompt"))
                    if image_url:
                        await update.message.reply_photo(photo=image_url, caption=f"Here is your image for: {function_args.get('prompt')}")
                        messages.append({"role": "tool", "tool_call_id": tool_call.id, "name": function_name, "content": f"Image generated successfully: {image_url}"})
                    else:
                        await update.message.reply_text("Failed to generate image.")
                        messages.append({"role": "tool", "tool_call_id": tool_call.id, "name": function_name, "content": "Failed to generate image."})
                elif function_name == "execute_python_code":
                    await context.bot.send_chat_action(chat_id=chat_id, action="typing")
                    code_output = await execute_python_code_safely(function_args.get("code"))
                    messages.append({"role": "tool", "tool_call_id": tool_call.id, "name": function_name, "content": code_output})
                elif function_name == "summarize_text":
                    await context.bot.send_chat_action(chat_id=chat_id, action="typing")
                    summary_result = await summarize_content(function_args.get("text_or_url"))
                    messages.append({"role": "tool", "tool_call_id": tool_call.id, "name": function_name, "content": summary_result})

            # Get final response after tool execution
            final_response = await client.chat.completions.create(
                model="gpt-4o",
                messages=messages,
                stream=True
            )

            final_full_response_content = []
            final_message_placeholder = await update.message.reply_text("...")

            async for final_chunk in final_response:
                if final_chunk.choices[0].delta.content:
                    final_full_response_content.append(final_chunk.choices[0].delta.content)
                    await final_message_placeholder.edit_text("".join(final_full_response_content))
                    await asyncio.sleep(0.05)

            ai_response = "".join(final_full_response_content).strip()
            if not ai_response:
                ai_response = "I'm sorry, I couldn't generate a response after using the tool."

            await final_message_placeholder.edit_text(ai_response)
            db.add_history(chat_id, "assistant", ai_response)

        else:
            ai_response = "".join(full_response_content).strip()
            if not ai_response:
                ai_response = "I'm sorry, I couldn't generate a response."

            if message_placeholder:
                await message_placeholder.edit_text(ai_response)
            else:
                await update.message.reply_text(ai_response)

            # Add AI response to history
            db.add_history(chat_id, "assistant", ai_response)

    except Exception as e:
        logger.error(f"AI chat failed for chat_id {chat_id}: {e}")
        await update.message.reply_text(f"AI chat failed: {e}")

async def clear_chat_history(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    chat_id = update.effective_chat.id
    db.clear_history(chat_id)
    await update.message.reply_text("Conversation history cleared.")

async def inline_query_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    query = update.inline_query.query
    if not query:
        return

    await context.bot.send_chat_action(chat_id=update.inline_query.from_user.id, action="typing")

    try:
        response = await client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": query}
            ],
            max_tokens=200,
            temperature=0.7,
            stream=True
        )

        full_response_content = []
        async for chunk in response:
            if chunk.choices[0].delta.content:
                full_response_content.append(chunk.choices[0].delta.content)

        ai_response = "".join(full_response_content).strip()

        if not ai_response:
            ai_response = "I'm sorry, I couldn't generate a response."

        results = [
            InlineQueryResultArticle(
                id=query,
                title="AI Response",
                input_message_content=InputTextMessageContent(ai_response)
            )
        ]
        await update.inline_query.answer(results)

    except Exception as e:
        logger.error(f"Inline query failed: {e}")
        # Optionally, provide a default error message or no results
        await update.inline_query.answer([])

async def voice_message_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.message.voice:
        return

    chat_id = update.effective_chat.id
    file_id = update.message.voice.file_id
    new_file = await context.bot.get_file(file_id)
    voice_file_path = f"./{file_id}.ogg"
    await new_file.download_to_drive(voice_file_path)

    await context.bot.send_chat_action(chat_id=chat_id, action="typing")

    try:
        # Transcribe voice message using whisper-timestamped
        model = whisper.load_model("base")
        audio = whisper.load_audio(voice_file_path)
        result = whisper.transcribe(model, audio, language="en")
        transcribed_text = result["text"]

        # Clean up the downloaded voice file
        import os
        os.remove(voice_file_path)

        await update.message.reply_text(f"You said: \"{transcribed_text}\"")

        # Pass transcribed text to AI chat for response
        update.message.text = transcribed_text # Temporarily set text for ai_chat_reply
        await ai_chat_reply(update, context)

    except Exception as e:
        logger.error(f"Voice message processing failed: {e}")
        await update.message.reply_text(f"Failed to process voice message: {e}")

async def image_message_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.message.photo:
        return

    chat_id = update.effective_chat.id
    # Get the largest photo available
    file_id = update.message.photo[-1].file_id
    new_file = await context.bot.get_file(file_id)
    image_file_path = f"./{file_id}.jpg"
    await new_file.download_to_drive(image_file_path)

    await context.bot.send_chat_action(chat_id=chat_id, action="typing")

    try:
        # Read the image file as bytes
        with open(image_file_path, "rb") as image_file:
            image_bytes = image_file.read()

        # Encode image to base64
        import base64
        base64_image = base64.b64encode(image_bytes).decode("utf-8")

        # Clean up the downloaded image file
        import os
        os.remove(image_file_path)

        # Call OpenAI Vision API
        vision_response = await client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Describe this image in detail."},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}}
                    ]
                }
            ],
            max_tokens=300,
        )
        description = vision_response.choices[0].message.content.strip()
        await update.message.reply_text(f"Image description: {description}")

        # Optionally, pass description to AI chat for further interaction
        # update.message.text = description
        # await ai_chat_reply(update, context)

    except Exception as e:
        logger.error(f"Image analysis failed: {e}")
        await update.message.reply_text(f"Failed to analyze image: {e}")

async def generate_image_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not context.args:
        await update.message.reply_text("Please provide a description for the image. Usage: /generate_image <prompt>")
        return

    prompt = " ".join(context.args)
    chat_id = update.effective_chat.id

    await context.bot.send_chat_action(chat_id=chat_id, action="upload_photo")

    try:
        image_url = await generate_image_with_dalle(prompt)
        if image_url:
            await update.message.reply_photo(photo=image_url, caption=f"Here is your image for: {prompt}")
        else:
            await update.message.reply_text("Failed to generate image.")
    except Exception as e:
        logger.error(f"DALL-E image generation failed: {e}")
        await update.message.reply_text(f"Failed to generate image: {e}")

async def generate_image_with_dalle(prompt: str) -> str | None:
    try:
        response = await client.images.generate(
            model="dall-e-3",
            prompt=prompt,
            size="1024x1024",
            quality="standard",
            n=1,
        )
        image_url = response.data[0].url
        return image_url
    except Exception as e:
        logger.error(f"Error generating image with DALL-E: {e}")
        return None

async def perform_web_search(query: str) -> str:
    try:
        # Using duckduckgo_search for web search
        results = DDGS().text(keywords=query, max_results=5)
        if results:
            formatted_results = []
            for i, result in enumerate(results):
                formatted_results.append(f"{i+1}. {result['title']} - {result['href']}\n{result['body']}")
            return "\n\n".join(formatted_results)
        else:
            return "No web search results found."
    except Exception as e:
        logger.error(f"Web search failed: {e}")
        return f"Web search failed: {e}"

async def summarize_content(text_or_url: str) -> str:
    content_to_summarize = text_or_url
    if text_or_url.startswith("http") or text_or_url.startswith("https"):
        try:
            import requests
            response = requests.get(text_or_url)
            response.raise_for_status() # Raise an exception for HTTP errors
            # Basic text extraction from HTML, can be improved with BeautifulSoup
            from bs4 import BeautifulSoup
            soup = BeautifulSoup(response.text, 'html.parser')
            content_to_summarize = soup.get_text()
        except Exception as e:
            logger.error(f"Failed to fetch or parse URL for summarization: {e}")
            return f"Failed to fetch or parse URL for summarization: {e}"

    try:
        summary_response = await client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": "You are a helpful assistant that summarizes text concisely."},
                {"role": "user", "content": f"Please summarize the following content:\n\n{content_to_summarize[:8000]}"}
            ], # Limit content to avoid token limits
            max_tokens=500,
            temperature=0.7,
        )
        return summary_response.choices[0].message.content.strip()
    except Exception as e:
        logger.error(f"Summarization failed: {e}")
        return f"Summarization failed: {e}"

async def execute_python_code_safely(code: str) -> str:
    # This is a basic and UNSAFE implementation for demonstration. 
    # For production, consider a more robust sandboxed execution environment.
    old_stdout = io.StringIO()
    redirect_stdout = contextlib.redirect_stdout(old_stdout)

    try:
        with redirect_stdout:
            exec(code, {'__builtins__': {}})
        output = old_stdout.getvalue()
    except Exception as e:
        output = f"Error during code execution: {e}\n{traceback.format_exc()}"
    finally:
        redirect_stdout.__exit__(None, None, None) # Ensure stdout is restored

    return output if output else "No output."

async def execute_code_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not context.args:
        await update.message.reply_text("Please provide Python code to execute. Usage: /exec_code print('Hello, World!')")
        return

    code = " ".join(context.args)
    chat_id = update.effective_chat.id

    await context.bot.send_chat_action(chat_id=chat_id, action="typing")

    output = await execute_python_code_safely(code)
    await update.message.reply_text(f"Code Output:\n```\n{output}\n```"))
