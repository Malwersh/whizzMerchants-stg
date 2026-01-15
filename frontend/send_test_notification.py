#!/usr/bin/env python3
"""
Send a test FCM push notification using FCM V1 API
This simulates a scheduled maintenance notification
"""

import json
import sys
import requests
from google.oauth2 import service_account
from google.auth.transport.requests import Request

# Firebase project configuration
SERVICE_ACCOUNT_FILE = 'service-account-key.json'
PROJECT_ID = 'wizz-business-app'
FCM_ENDPOINT = f'https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send'
SCOPES = ['https://www.googleapis.com/auth/firebase.messaging']

def get_access_token():
    """
    Get OAuth 2.0 access token using service account
    """
    try:
        credentials = service_account.Credentials.from_service_account_file(
            SERVICE_ACCOUNT_FILE,
            scopes=SCOPES
        )
        credentials.refresh(Request())
        return credentials.token
    except Exception as e:
        print(f"❌ Error getting access token: {e}")
        return None

def send_notification(fcm_token):
    """
    Send FCM notification using V1 API
    """
    # Get access token
    access_token = get_access_token()
    if not access_token:
        print("❌ Failed to get access token")
        return False
    
    # Prepare headers
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json; UTF-8',
    }
    
    # Prepare notification payload
    message = {
        'message': {
            'token': fcm_token,
            'notification': {
                'title': '🔧 Scheduled Maintenance',
                'body': 'System maintenance scheduled for tonight at 11 PM. Expected downtime: 2 hours.'
            },
            'data': {
                'type': 'maintenance',
                'scheduled_time': '2024-11-20T23:00:00Z',
                'duration': '2 hours',
                'priority': 'high',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK'
            },
            'apns': {
                'payload': {
                    'aps': {
                        'alert': {
                            'title': '🔧 Scheduled Maintenance',
                            'body': 'System maintenance scheduled for tonight at 11 PM. Expected downtime: 2 hours.'
                        },
                        'sound': 'default',
                        'badge': 1,
                        'content-available': 1
                    }
                }
            }
        }
    }
    
    print("\n" + "="*60)
    print("📤 SENDING FCM V1 NOTIFICATION")
    print("="*60)
    print(f"📱 Target Token: {fcm_token[:30]}...")
    print(f"🎯 Title: {message['message']['notification']['title']}")
    print(f"💬 Body: {message['message']['notification']['body']}")
    print("="*60 + "\n")
    
    try:
        response = requests.post(
            FCM_ENDPOINT,
            headers=headers,
            json=message
        )
        
        if response.status_code == 200:
            print("✅ Notification sent successfully!")
            print(f"\n📊 Response:")
            print(json.dumps(response.json(), indent=2))
            return True
        else:
            print(f"❌ Failed to send notification")
            print(f"Status Code: {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error sending notification: {e}")
        return False

def main():
    print("\n" + "🔔 FCM V1 Notification Sender".center(60, "="))
    print()
    
    # Check if service account file exists
    try:
        with open(SERVICE_ACCOUNT_FILE, 'r') as f:
            sa_data = json.load(f)
            print(f"✅ Service account loaded: {sa_data.get('client_email', 'Unknown')}")
    except FileNotFoundError:
        print(f"❌ Service account file not found: {SERVICE_ACCOUNT_FILE}")
        print("\nPlease download your service account key from Firebase Console:")
        print("1. Go to Project Settings → Service Accounts")
        print("2. Click 'Generate New Private Key'")
        print("3. Save it as 'service-account-key.json' in this directory")
        sys.exit(1)
    
    # Get FCM token
    print("\n" + "-"*60)
    
    # Check if token is provided as argument
    if len(sys.argv) > 1:
        fcm_token = sys.argv[1]
        print(f"📱 Using token from command line argument")
    else:
        # Check if token file exists
        try:
            with open('/tmp/fcm_token.txt', 'r') as f:
                fcm_token = f.read().strip()
                print(f"📱 Using token from /tmp/fcm_token.txt")
        except FileNotFoundError:
            print("📱 Please enter the FCM token from your app:")
            print("   (Look for '✅ FCM Token:' in the debug console)")
            fcm_token = input("\n🎫 FCM Token: ").strip()
    
    if not fcm_token:
        print("❌ No FCM token provided!")
        sys.exit(1)
    
    print(f"✅ Token received: {fcm_token[:30]}...")
    print("-"*60 + "\n")
    
    # Send notification
    success = send_notification(fcm_token)
    
    if success:
        print("\n" + "="*60)
        print("✅ NOTIFICATION SENT SUCCESSFULLY!")
        print("="*60)
        print("\n📱 Check your iPhone for the notification!")
        print("💡 If you don't see it, make sure:")
        print("   1. The app is installed and has notification permissions")
        print("   2. Your device has internet connection")
        print("   3. The FCM token is correct and not expired")
        print()
    else:
        print("\n❌ Failed to send notification. Check the error above.")
        sys.exit(1)

if __name__ == '__main__':
    main()
