def get_user_mention(user):
    if user.username:
        return f"@{user.username}"
    else:
        return f"[{user.first_name}](tg://user?id={user.id})"
