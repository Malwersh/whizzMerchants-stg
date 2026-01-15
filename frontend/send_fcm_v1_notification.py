#!/usr/bin/env python3
"""
Send a test FCM push notification using Firebase Cloud Messaging API (V1)
This simulates a scheduled maintenance notification for Whizz Merchants iOS app
"""

import json
import sys
import os
from datetime import datetime
import subprocess

def get_access_token(service_account_file):
    """
    Get OAuth 2.0 access token using gcloud CLI
    
    Args:
        service_account_file: Path to service account JSON file
    
    Returns:
        Access token string
    """
    try:
        # Activate service account
        subprocess.run([
            'gcloud', 'auth', 'activate-service-account',
            '--key-file=' + service_account_file
        ], check=True, capture_output=True)
        
        # Get access token
        result = subprocess.run([
            'gcloud', 'auth', 'print-access-token'
        ], check=True, capture_output=True, text=True)
        
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"❌ Error getting access token: {e}")
        print(f"   Make sure gcloud CLI is installed: https://cloud.google.com/sdk/docs/install")
        sys.exit(1)

def send_fcm_v1_notification(fcm_token, service_account_file, project_id="wizz-business-app"):
    """
    Send a Firebase Cloud Messaging notification using V1 API
    
    Args:
        fcm_token: The FCM device token from the app
        service_account_file: Path to Firebase service account JSON file
        project_id: Firebase project ID
    """
    
    import requests
    
    # Get OAuth 2.0 access token
    print("🔑 Getting OAuth 2.0 access token...")
    access_token = get_access_token(service_account_file)
    print("✅ Access token obtained")
    
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    
    # Scheduled maintenance notification payload
    payload = {
        "message": {
            "token": fcm_token,
            "notification": {
                "title": "🔧 Scheduled Maintenance",
                "body": "System maintenance scheduled for tonight at 11 PM. Expected downtime: 2 hours."
            },
            "data": {
                "type": "maintenance",
                "scheduled_time": "2024-11-20T23:00:00Z",
                "duration": "2 hours",
                "priority": "high",
                "click_action": "FLUTTER_NOTIFICATION_CLICK"
            },
            "apns": {
                "payload": {
                    "aps": {
                        "alert": {
                            "title": "🔧 Scheduled Maintenance",
                            "body": "System maintenance scheduled for tonight at 11 PM. Expected downtime: 2 hours."
                        },
                        "sound": "default",
                        "badge": 1,
                        "content-available": 1
                    }
                }
            }
        }
    }
    
    print("\n📤 Sending FCM notification...")
    print(f"Target token: {fcm_token[:20]}...")
    print(f"\nNotification:")
    print(f"  Title: {payload['message']['notification']['title']}")
    print(f"  Body: {payload['message']['notification']['body']}")
    print(f"\nData payload:")
    for key, value in payload['message']['data'].items():
        print(f"  {key}: {value}")
    
    try:
        response = requests.post(url, headers=headers, json=payload)
        
        print(f"\n📥 Response Status: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ Notification sent successfully!")
            print(f"\nResponse:")
            print(json.dumps(response.json(), indent=2))
            return True
        else:
            print(f"❌ Failed to send notification")
            print(f"\nError Response:")
            print(json.dumps(response.json(), indent=2))
            return False
            
    except Exception as e:
        print(f"❌ Error sending notification: {e}")
        return False

def main():
    print("=" * 60)
    print("🔥 Firebase Cloud Messaging V1 - Test Notification Sender")
    print("=" * 60)
    print()
    
    # Check if service account file exists
    service_account_file = "service-account-key.json"
    if not os.path.exists(service_account_file):
        print(f"❌ Service account file not found: {service_account_file}")
        print("\n📋 To get your service account key:")
        print("1. Go to: https://console.cloud.google.com/iam-admin/serviceaccounts")
        print("2. Click on: firebase-adminsdk-fbsvc@wizz-business-app.iam.gserviceaccount.com")
        print("3. Go to KEYS tab")
        print("4. Click ADD KEY → Create new key → JSON")
        print("5. Save the file as: service-account-key.json")
        print(f"6. Move it to: {os.getcwd()}")
        sys.exit(1)
    
    # Get FCM token from user or file
    fcm_token = None
    if os.path.exists("/tmp/fcm_token.txt"):
        with open("/tmp/fcm_token.txt", "r") as f:
            fcm_token = f.read().strip()
        print(f"📱 Using FCM token from /tmp/fcm_token.txt")
        print(f"   Token: {fcm_token[:20]}...")
        use_saved = input("\nUse this token? (y/n): ").strip().lower()
        if use_saved != 'y':
            fcm_token = None
    
    if not fcm_token:
        print("\n📱 Enter your FCM device token:")
        print("   (You can find this in the app's debug console)")
        fcm_token = input("Token: ").strip()
    
    if not fcm_token:
        print("❌ No FCM token provided")
        sys.exit(1)
    
    # Get project ID
    try:
        with open(service_account_file, 'r') as f:
            service_account_data = json.load(f)
            project_id = service_account_data.get('project_id', 'wizz-business-app')
            print(f"\n🏢 Using Firebase Project: {project_id}")
    except Exception as e:
        print(f"⚠️  Could not read project ID from service account file: {e}")
        project_id = "wizz-business-app"
        print(f"   Using default: {project_id}")
    
    # Send notification
    print("\n" + "=" * 60)
    success = send_fcm_v1_notification(fcm_token, service_account_file, project_id)
    print("=" * 60)
    
    if success:
        print("\n🎉 Check your iPhone for the notification!")
    else:
        print("\n❌ Failed to send notification. Please check the error messages above.")
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
