import sqlite3

DATABASE_NAME = 'telebot_ultimate.db'

def connect_db():
    return sqlite3.connect(DATABASE_NAME)

def init_db():
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                user_id INTEGER PRIMARY KEY,
                username TEXT,
                first_name TEXT,
                last_name TEXT,
                is_admin INTEGER DEFAULT 0
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS groups (
                group_id INTEGER PRIMARY KEY,
                group_name TEXT,
                welcome_message TEXT,
                rules_message TEXT
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS warnings (
                warning_id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                group_id INTEGER,
                admin_id INTEGER,
                reason TEXT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS mutes (
                mute_id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                group_id INTEGER,
                admin_id INTEGER,
                until_timestamp DATETIME,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS bans (
                ban_id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                group_id INTEGER,
                admin_id INTEGER,
                reason TEXT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS notes (
                note_id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                title TEXT,
                content TEXT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS reminders (
                reminder_id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                message TEXT,
                remind_at DATETIME,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        conn.commit()

def add_user(user_id, username, first_name, last_name):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("INSERT OR IGNORE INTO users (user_id, username, first_name, last_name) VALUES (?, ?, ?, ?)",
                       (user_id, username, first_name, last_name))
        conn.commit()

def get_user(user_id):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE user_id = ?", (user_id,))
        return cursor.fetchone()

def update_user_admin_status(user_id, is_admin):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("UPDATE users SET is_admin = ? WHERE user_id = ?", (is_admin, user_id))
        conn.commit()

def get_all_users():
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT user_id FROM users")
        return [row[0] for row in cursor.fetchall()]

def add_group(group_id, group_name):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("INSERT OR IGNORE INTO groups (group_id, group_name) VALUES (?, ?)", (group_id, group_name))
        conn.commit()

def get_group(group_id):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM groups WHERE group_id = ?", (group_id,))
        return cursor.fetchone()

def update_group_welcome_message(group_id, message):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("UPDATE groups SET welcome_message = ? WHERE group_id = ?", (message, group_id))
        conn.commit()

def update_group_rules_message(group_id, message):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("UPDATE groups SET rules_message = ? WHERE group_id = ?", (message, group_id))
        conn.commit()

def add_warning(user_id, group_id, admin_id, reason):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("INSERT INTO warnings (user_id, group_id, admin_id, reason) VALUES (?, ?, ?, ?)",
                       (user_id, group_id, admin_id, reason))
        conn.commit()

def get_warnings_count(user_id, group_id):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM warnings WHERE user_id = ? AND group_id = ?", (user_id, group_id))
        return cursor.fetchone()[0]

def add_mute(user_id, group_id, admin_id, until_timestamp):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("INSERT INTO mutes (user_id, group_id, admin_id, until_timestamp) VALUES (?, ?, ?, ?)",
                       (user_id, group_id, admin_id, until_timestamp))
        conn.commit()

def remove_mute(user_id, group_id):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM mutes WHERE user_id = ? AND group_id = ?", (user_id, group_id))
        conn.commit()

def get_active_mute(user_id, group_id):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM mutes WHERE user_id = ? AND group_id = ? AND until_timestamp > CURRENT_TIMESTAMP",
                       (user_id, group_id))
        return cursor.fetchone()

def add_ban(user_id, group_id, admin_id, reason):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("INSERT INTO bans (user_id, group_id, admin_id, reason) VALUES (?, ?, ?, ?)",
                       (user_id, group_id, admin_id, reason))
        conn.commit()

def remove_ban(user_id, group_id):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM bans WHERE user_id = ? AND group_id = ?", (user_id, group_id))
        conn.commit()

def get_ban(user_id, group_id):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM bans WHERE user_id = ? AND group_id = ?", (user_id, group_id))
        return cursor.fetchone()

def add_note(user_id, title, content):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("INSERT INTO notes (user_id, title, content) VALUES (?, ?, ?)", (user_id, title, content))
        conn.commit()

def get_notes(user_id):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT title, content, timestamp FROM notes WHERE user_id = ?", (user_id,))
        return cursor.fetchall()

def delete_note(user_id, title):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM notes WHERE user_id = ? AND title = ?", (user_id, title))
        conn.commit()

def add_reminder(user_id, message, remind_at):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("INSERT INTO reminders (user_id, message, remind_at) VALUES (?, ?, ?)", (user_id, message, remind_at))
        conn.commit()

def get_pending_reminders():
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT reminder_id, user_id, message FROM reminders WHERE remind_at <= CURRENT_TIMESTAMP")
        return cursor.fetchall()

def delete_reminder(reminder_id):
    with connect_db() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM reminders WHERE reminder_id = ?", (reminder_id,))
        conn.commit()

if __name__ == '__main__':
    init_db()
    print("Database initialized and tables created.")
