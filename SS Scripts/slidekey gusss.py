"""
Mouse Axis Lock Application
Extended with Premiere-only slow horizontal movement mode.
Dependencies: pynput

Installation:
    pip install pynput

Run this script on Windows with Python 3.
"""

import threading
import time
import tkinter as tk
import ctypes
import ctypes.wintypes
from pynput import keyboard
from pynput.mouse import Controller as MouseController

# Global state variables
hotkey = 'z'           # Axis-lock hotkey (default Z)
slow_hotkey = 'alt'  # Slow horizontal movement modifier (default Alt)
axis = None            # Axis to lock ('x' or 'y')
hotkey_pressed = False
slow_pressed = False
initial_x = None
initial_y = None
listener_select = None
listener_slow_select = None
listener_hotkey = None
lock_thread = None
running = False

# GUI widgets (assigned later)
label_hotkey = None
label_slow_hotkey = None
btn_lock_x = None
btn_lock_y = None
btn_listen = None
btn_slow_listen = None
btn_restart = None
frame_initial = None

mouse = MouseController()
user32 = ctypes.windll.user32
psapi = ctypes.windll.psapi
kernel32 = ctypes.windll.kernel32
SLOW_SCALE = 0.15  # 15% of normal horizontal movement

# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------

def get_foreground_process_name():
    hwnd = user32.GetForegroundWindow()
    if not hwnd:
        return ""
    pid = ctypes.wintypes.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    process = kernel32.OpenProcess(0x0410, False, pid.value)  # QUERY_INFORMATION | VM_READ
    if not process:
        return ""
    exe_buffer = (ctypes.c_wchar * 260)()
    psapi.GetModuleFileNameExW(process, None, exe_buffer, 260)
    kernel32.CloseHandle(process)
    return exe_buffer.value.split("\\")[-1].lower()

def is_premiere_active():
    return get_foreground_process_name() == "adobe premiere pro.exe"

def normalise_key(key_event):
    try:
        key_str = key_event.char
    except AttributeError:
        key_str = key_event.name if hasattr(key_event, 'name') else None
    if key_str is None:
        return None
    return key_str.lower()

# ---------------------------------------------------------------------------
# Hotkey selection helpers
# ---------------------------------------------------------------------------

def listen_axis_hotkey():
    global listener_select, btn_listen
    btn_listen.config(text="Press a key...", state=tk.DISABLED)

    def on_press_set_hotkey(key):
        global hotkey
        key_str = normalise_key(key)
        if key_str:
            hotkey = key_str
            root.after(0, finalize_axis_selection, key_str)
        return False

    listener_select = keyboard.Listener(on_press=on_press_set_hotkey)
    listener_select.start()

def finalize_axis_selection(key_str):
    global btn_listen, btn_lock_x, btn_lock_y
    label_hotkey.config(text=f"Axis Hotkey: {key_str}")
    btn_lock_x.config(state=tk.NORMAL)
    btn_lock_y.config(state=tk.NORMAL)
    btn_listen.config(state=tk.NORMAL, text="Set Axis Hotkey")

def listen_slow_hotkey():
    global listener_slow_select, btn_slow_listen
    btn_slow_listen.config(text="Press a key...", state=tk.DISABLED)

    def on_press_set_slow(key):
        global slow_hotkey
        key_str = normalise_key(key)
        if key_str:
            slow_hotkey = key_str
            root.after(0, finalize_slow_selection, key_str)
        return False

    listener_slow_select = keyboard.Listener(on_press=on_press_set_slow)
    listener_slow_select.start()

def finalize_slow_selection(key_str):
    global btn_slow_listen
    label_slow_hotkey.config(text=f"Slow Hotkey: {key_str} (hold with {hotkey})")
    btn_slow_listen.config(state=tk.NORMAL, text="Set Slow Hotkey")

# ---------------------------------------------------------------------------
# Axis locking + slow-mode handling
# ---------------------------------------------------------------------------

def lock_x():
    global axis
    axis = 'x'
    activate_locking()

def lock_y():
    global axis
    axis = 'y'
    activate_locking()

def activate_locking():
    global listener_hotkey, lock_thread, running

    if not hotkey or not axis:
        return

    frame_initial.pack_forget()
    btn_restart.pack(pady=10)

    def on_press_hotkey(key):
        global hotkey_pressed, slow_pressed, initial_x, initial_y
        key_str = normalise_key(key)
        if not key_str:
            return

        if key_str == hotkey:
            if not hotkey_pressed and is_premiere_active():
                initial_x, initial_y = mouse.position
            hotkey_pressed = True
        elif slow_hotkey and key_str == slow_hotkey:
            slow_pressed = True

    def on_release_hotkey(key):
        global hotkey_pressed, slow_pressed
        key_str = normalise_key(key)
        if not key_str:
            return

        if key_str == hotkey:
            hotkey_pressed = False
        elif slow_hotkey and key_str == slow_hotkey:
            slow_pressed = False

    if listener_hotkey is not None:
        listener_hotkey.stop()
    listener_hotkey = keyboard.Listener(on_press=on_press_hotkey, on_release=on_release_hotkey)
    listener_hotkey.start()

    running = True

    def lock_loop():
        global running, initial_x, initial_y
        last_x, last_y = mouse.position
        while running:
            time.sleep(0.01)

            if not is_premiere_active():
                continue

            current_x, current_y = mouse.position

            if slow_pressed and slow_hotkey:
                delta_x = current_x - last_x
                if delta_x != 0:
                    adjusted_x = last_x + (delta_x * SLOW_SCALE)
                    mouse.position = (adjusted_x, current_y)
                    current_x = adjusted_x
            last_x, last_y = mouse.position

            if hotkey_pressed and axis in ('x', 'y'):
                if initial_x is None or initial_y is None:
                    initial_x, initial_y = mouse.position
                if axis == 'x':
                    mouse.position = (current_x, initial_y)
                elif axis == 'y':
                    mouse.position = (initial_x, current_y)

    lock_thread = threading.Thread(target=lock_loop, daemon=True)
    lock_thread.start()

# ---------------------------------------------------------------------------
# Reset / Restart
# ---------------------------------------------------------------------------

def restart():
    global hotkey_pressed, slow_pressed, initial_x, initial_y, running
    global listener_hotkey, lock_thread, axis
    global label_hotkey, label_slow_hotkey, btn_lock_x, btn_lock_y, btn_listen, btn_slow_listen

    running = False
    slow_pressed = False
    hotkey_pressed = False

    if listener_hotkey is not None:
        listener_hotkey.stop()
    listener_hotkey = None

    if lock_thread is not None:
        lock_thread.join(timeout=0.1)
    lock_thread = None

    axis = None
    initial_x = None
    initial_y = None

    label_hotkey.config(text=f"Axis Hotkey: {hotkey or 'None'}")
    if slow_hotkey:
        label_slow_hotkey.config(text=f"Slow Hotkey: {slow_hotkey} (hold with {hotkey})")
    else:
        label_slow_hotkey.config(text="Slow Hotkey: None")

    btn_lock_x.config(state=tk.NORMAL)
    btn_lock_y.config(state=tk.NORMAL)
    btn_listen.config(state=tk.NORMAL)
    btn_slow_listen.config(state=tk.NORMAL)

    btn_restart.pack_forget()
    frame_initial.pack(pady=10)

# ---------------------------------------------------------------------------
# GUI setup
# ---------------------------------------------------------------------------

root = tk.Tk()
root.title("Mouse Axis Lock")
root.configure(bg='white')
root.geometry("320x260")

frame_initial = tk.Frame(root, bg='white')
frame_initial.pack(pady=10)

label_hotkey = tk.Label(frame_initial, text=f"Axis Hotkey: {hotkey}", bg='white')
label_hotkey.pack(pady=5)

btn_listen = tk.Button(frame_initial, text="Set Axis Hotkey", command=listen_axis_hotkey)
btn_listen.pack(pady=5)

label_slow_hotkey = tk.Label(frame_initial, text=f"Slow Hotkey: {slow_hotkey} (hold with {hotkey})", bg='white')
label_slow_hotkey.pack(pady=5)

btn_slow_listen = tk.Button(frame_initial, text="Set Slow Hotkey", command=listen_slow_hotkey)
btn_slow_listen.pack(pady=5)

btn_lock_x = tk.Button(frame_initial, text="Lock on X Axis", command=lock_x, state=tk.NORMAL)
btn_lock_x.pack(pady=5)

btn_lock_y = tk.Button(frame_initial, text="Lock on Y Axis", command=lock_y, state=tk.NORMAL)
btn_lock_y.pack(pady=5)

btn_restart = tk.Button(root, text="Restart Script", command=restart)

# Start with default X-axis locking
axis = 'x'
lock_x()

root.mainloop()

