# ONIONGUARD — SMS & ALERT NOTIFICATION ARCHITECTURE

## 1. Alert Notification System Overview

OnionGuard provides a multi-channel alert pipeline for agricultural storage operators:
1. **In-App Local Notifications & SnackBar Banners**
2. **Activity History Event Logging**
3. **SMS Alert Gateway Dispatch**

---

## 2. Supported SMS Gateway Providers (India & International)

The application supports three configurable SMS delivery modes (configured in **Settings**):

### Option 1: Fast2SMS (India Bulk SMS API)
- **API Endpoint:** `https://www.fast2sms.com/dev/bulkV2`
- **Method:** HTTP POST / GET
- **Features:** Supports quick transactional SMS in India with free test credits upon signup.
- **Payload:**
  ```json
  {
    "route": "v3",
    "sender_id": "TXTIND",
    "message": "OnionGuard Alert: Storage temperature exceeded 26.0C. Exhaust activated.",
    "language": "english",
    "flash": 0,
    "numbers": "9876543210"
  }
  ```

### Option 2: Textbee / Local Android SMS Gateway
- Uses an Android smartphone with an active SIM card acting as an SMS gateway server via REST API.
- Completely free within standard carrier SMS bundle limits.

### Option 3: Simulation Test Mode (Default)
- Simulates SMS dispatch directly inside the application.
- Dispatches a delivery receipt, verifies recipient phone number format, and logs the SMS event in Activity History without consuming carrier credits.

---

## 3. Cooldown & Anti-Spam Deduplication Engine

To avoid exhausting SMS quotas or spamming the operator with duplicate alerts during a prolonged temperature rise:
1. **Configurable Cooldown Period:** Default is **15 minutes** (adjustable from 5 to 60 minutes in Settings).
2. **State Transition Triggers:** SMS alerts are dispatched on *state entry*:
   - Trigger 1: Dispatched once when temperature crosses $\ge 26.0^\circ\text{C}$.
   - Subsequent readings while still above 26.0°C are suppressed during the cooldown window.
   - Trigger 2: Recovery alert dispatched once temperature drops back $\le 24.0^\circ\text{C}$.
3. **Simulation Safeguard:** In Simulation Mode, emergency SMS messages are flagged with `[SIM]` and never dispatched to external phone numbers without explicit manual confirmation.
