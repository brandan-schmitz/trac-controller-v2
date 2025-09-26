#!/usr/bin/env python3
"""
TRAC Pool GPIO Controller (Pi 5) — active-LOW relays
- Subscribes to MQTT feature/estop commands
- Drives GPIO and publishes retained feature state
- No watchdog/fail-safe timer: controller simply follows latest MQTT commands
- BCM pins per remap: see PIN_MAP
"""
import sys, time, signal, threading
from typing import Dict
import gpiod
from paho.mqtt import client as mqtt

# -------- Config --------
BROKER_HOST = "127.0.0.1"
BROKER_PORT = 1883
BROKER_USER = "tracpanel"
BROKER_PASS = "tr@c2017!"
CLIENT_ID   = "trac-controller"

ACTIVE_LOW = True

# Optional heartbeat (non-retained) for monitoring only
HEARTBEAT_TOPIC  = "trac/pool/heartbeat"
HEARTBEAT_PERIOD = 3.0  # seconds

# Feature → BCM GPIO
PIN_MAP: Dict[str, int] = {
    "play_structure": 5,
    "river_fountains": 6,
    "yellow_slide": 12,
    "lazy_river": 13,
    "center_jets": 16,
    "blue_slide": 26,
}
FEATURES = list(PIN_MAP.keys())

# -------- GPIO init --------
chip = gpiod.Chip("gpiochip0")
lines = {}

# runtime state (True=ON, False=OFF)
state: Dict[str, bool] = {k: False for k in FEATURES}
pre_estop_state: Dict[str, bool] = {k: False for k in FEATURES}
estop_tripped = False

stop_flag = False

def gpio_write(feature: str, on: bool):
    # active-LOW relay boards: ON => drive 0, OFF => drive 1
    val = 0 if (ACTIVE_LOW and on) else 1 if ACTIVE_LOW else (1 if on else 0)
    lines[feature].set_value(val)

def publish_state(m: mqtt.Client, feature: str):
    payload = "ON" if state[feature] else "OFF"
    m.publish(f"trac/pool/features/{feature}/state", payload, qos=1, retain=True)

def handle_cmd(topic: str, payload: str, m: mqtt.Client):
    """Handle feature and e-stop commands."""
    global pre_estop_state, estop_tripped
    parts = topic.split("/")

    # Feature command: trac/pool/features/<id>/cmd
    if parts[:3] == ["trac", "pool", "features"] and len(parts) >= 5 and parts[3] in FEATURES and parts[4] == "cmd":
        # Ignore feature commands if e-stop is tripped
        if estop_tripped:
            return
        f = parts[3]
        cmd = payload.upper()
        if cmd == "TOGGLE":
            state[f] = not state[f]
        elif cmd == "ON":
            state[f] = True
        elif cmd == "OFF":
            state[f] = False
        else:
            return
        gpio_write(f, state[f])
        publish_state(m, f)
        return

    # E-stop command: trac/pool/estop/cmd
    if topic == "trac/pool/estop/cmd":
        cmd = payload.upper()
        if cmd == "TRIP":
            pre_estop_state = state.copy()
            estop_tripped = True
            # Turn everything OFF immediately
            for f in FEATURES:
                state[f] = False
                gpio_write(f, False)
                publish_state(m, f)
            m.publish("trac/pool/estop/state", "TRIPPED", qos=1, retain=True)

        elif cmd == "DISARM":
            # Restore exactly what was ON before TRIP
            for f in FEATURES:
                desired = pre_estop_state.get(f, False)
                state[f] = desired
                gpio_write(f, desired)
                publish_state(m, f)
            estop_tripped = False
            m.publish("trac/pool/estop/state", "READY", qos=1, retain=True)

# -------- MQTT callbacks --------
def on_connect(m, userdata, flags, rc, properties=None):
    print("[mqtt] connected rc=", rc)
    # Subscribe
    for f in FEATURES:
        m.subscribe(f"trac/pool/features/{f}/cmd", qos=1)
    m.subscribe("trac/pool/estop/cmd", qos=1)

    # Publish status and retained states (reflect current local state)
    m.publish("trac/pool/controller/status", "ONLINE", qos=1, retain=True)
    for f in FEATURES:
        publish_state(m, f)
    m.publish("trac/pool/estop/state", "TRIPPED" if estop_tripped else "READY", qos=1, retain=True)

def on_disconnect(m, userdata, rc, properties=None):
    print("[mqtt] disconnected rc=", rc)
    # No watchdog actions; we simply stop receiving commands until reconnected.

def on_message(m, userdata, msg):
    payload = msg.payload.decode(errors="ignore").strip()
    handle_cmd(msg.topic, payload, m)

# -------- Background heartbeat (optional) --------
def heartbeat_publisher(m: mqtt.Client):
    """Publish a non-retained heartbeat every HEARTBEAT_PERIOD seconds while running (for monitoring only)."""
    while not stop_flag:
        try:
            m.publish(HEARTBEAT_TOPIC, str(int(time.time())), qos=0, retain=False)
        except Exception:
            pass
        time.sleep(HEARTBEAT_PERIOD)

def cleanup(signum=None, frame=None):
    global stop_flag
    stop_flag = True
    try:
        # Drive all OFF on exit
        for f in FEATURES:
            gpio_write(f, False)
    finally:
        try:
            client.publish("trac/pool/controller/status", "OFFLINE", qos=1, retain=True)
        except Exception:
            pass
        sys.exit(0)

# Request lines with default OFF (active-LOW => value 1)
for f, bcm in PIN_MAP.items():
    line = chip.get_line(bcm)
    line.request(consumer="trac-ctrl", type=gpiod.LINE_REQ_DIR_OUT, default_vals=[1])
    lines[f] = line

# -------- MQTT client --------
client = mqtt.Client(client_id=CLIENT_ID, clean_session=True)
client.username_pw_set(BROKER_USER, BROKER_PASS)
client.will_set("trac/pool/controller/status", "OFFLINE", qos=1, retain=True)
client.on_connect = on_connect
client.on_disconnect = on_disconnect
client.on_message = on_message

# KEY: make reconnects frequent and predictable
client.reconnect_delay_set(min_delay=1, max_delay=5)  # default max is ~120s; keep it snappy

# Optional: slightly shorter keepalive to detect dead broker faster
KEEPALIVE = 20

client.connect(BROKER_HOST, BROKER_PORT, keepalive=KEEPALIVE)

# Signals
signal.signal(signal.SIGINT, cleanup)
signal.signal(signal.SIGTERM, cleanup)

# Optional heartbeat thread
hb = threading.Thread(target=heartbeat_publisher, args=(client,), daemon=True)
hb.start()

# Loop forever (with built-in reconnect using our delay settings)
client.loop_forever(retry_first_connection=True)