#!/usr/bin/env python3
import paho.mqtt.client as mqtt
import json
import time
import sys

# MQTT broker settings
BROKER = "nhacuatoi.com.vn"
PORT = 8004

def on_connect(client, userdata, flags, rc):
    print(f"Connected with result code {rc}")

def publish_status_message(client, serial, status):
    topic = f"NhaCuaToi_{serial}_status"
    message = {
        "serial": serial,
        "status": status,
        "timestamp": int(time.time())
    }
    
    print(f"Publishing to {topic}: {json.dumps(message)}")
    client.publish(topic, json.dumps(message))

def main():
    if len(sys.argv) < 3:
        print("Usage: python mqtt_test.py <serial> <status>")
        print("Example: python mqtt_test.py 9249022997 online")
        sys.exit(1)
    
    serial = sys.argv[1]
    status = sys.argv[2]
    
    client = mqtt.Client()
    client.on_connect = on_connect
    
    try:
        print(f"Connecting to {BROKER}:{PORT}...")
        client.connect(BROKER, PORT, 60)
        client.loop_start()
        
        time.sleep(1)  # Wait for connection
        
        # Publish status message
        publish_status_message(client, serial, status)
        
        print("Message published. Waiting 2 seconds...")
        time.sleep(2)
        
        client.loop_stop()
        client.disconnect()
        print("Disconnected.")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
