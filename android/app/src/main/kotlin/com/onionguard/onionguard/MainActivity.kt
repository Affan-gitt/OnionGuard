package com.onionguard.onionguard

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import android.telephony.TelephonyManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.charset.StandardCharsets

class MainActivity : FlutterActivity() {
    private val USB_METHOD_CHANNEL = "com.onionguard.onionguard/usb"
    private val USB_EVENT_CHANNEL = "com.onionguard.onionguard/usb_stream"
    private val SMS_METHOD_CHANNEL = "com.onionguard.onionguard/sms"

    private val ACTION_USB_PERMISSION = "com.onionguard.onionguard.USB_PERMISSION"
    private val ACTION_SMS_SENT = "com.onionguard.onionguard.SMS_SENT"
    private val SMS_PERMISSION_REQUEST_CODE = 101

    private var usbManager: UsbManager? = null
    private var usbConnection: UsbDeviceConnection? = null
    private var usbInterface: UsbInterface? = null
    private var endpointIn: UsbEndpoint? = null
    private var endpointOut: UsbEndpoint? = null
    private var connectedUsbDevice: UsbDevice? = null

    private var usbReadThread: Thread? = null
    @Volatile private var isReadingUsb = false

    private var usbEventSink: EventChannel.EventSink? = null
    private var smsPermissionResultCallback: MethodChannel.Result? = null

    // Broadcast receiver for USB attach, detach, and permission
    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                ACTION_USB_PERMISSION -> {
                    synchronized(this) {
                        val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                        }
                        val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                        if (granted && device != null) {
                            openUsbDevice(device)
                        } else {
                            sendUsbEvent("PERMISSION_DENIED", "USB Permission was denied by user")
                        }
                    }
                }
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }
                    if (device != null) {
                        sendUsbEvent("ATTACHED", mapOf(
                            "deviceName" to device.deviceName,
                            "vendorId" to device.vendorId,
                            "productId" to device.productId,
                            "isEsp32" to (device.vendorId == 0x303A || device.vendorId == 12346)
                        ))
                    }
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }
                    if (device != null && connectedUsbDevice?.deviceName == device.deviceName) {
                        closeUsbConnection()
                        sendUsbEvent("DETACHED", "ESP32 USB cable disconnected")
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        usbManager = getSystemService(Context.USB_SERVICE) as UsbManager

        // Register USB BroadcastReceiver
        val filter = IntentFilter().apply {
            addAction(ACTION_USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(usbReceiver, filter)
        }

        // 1. USB EventChannel for streaming incoming serial JSON
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, USB_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    usbEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    usbEventSink = null
                }
            }
        )

        // 2. USB MethodChannel for hardware controls
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USB_METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "listUsbDevices" -> {
                    val devices = usbManager?.deviceList?.values?.map { dev ->
                        mapOf(
                            "deviceName" to dev.deviceName,
                            "vendorId" to dev.vendorId,
                            "productId" to dev.productId,
                            "productName" to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) dev.productName else "USB Device"),
                            "manufacturerName" to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) dev.manufacturerName else "Unknown"),
                            "isEsp32" to (dev.vendorId == 0x303A || dev.vendorId == 12346),
                            "hasPermission" to (usbManager?.hasPermission(dev) ?: false)
                        )
                    } ?: emptyList<Map<String, Any>>()
                    result.success(devices)
                }

                "connectUsbDevice" -> {
                    val deviceName = call.argument<String>("deviceName")
                    val targetDevice = if (deviceName != null) {
                        usbManager?.deviceList?.values?.firstOrNull { it.deviceName == deviceName }
                    } else {
                        // Default to finding first ESP32 or CDC device
                        usbManager?.deviceList?.values?.firstOrNull { it.vendorId == 0x303A || it.vendorId == 12346 }
                            ?: usbManager?.deviceList?.values?.firstOrNull()
                    }

                    if (targetDevice == null) {
                        result.error("NO_DEVICE", "No compatible ESP32 USB device found", null)
                        return@setMethodCallHandler
                    }

                    if (!usbManager!!.hasPermission(targetDevice)) {
                        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                        } else {
                            PendingIntent.FLAG_UPDATE_CURRENT
                        }
                        val permIntent = PendingIntent.getBroadcast(this, 0, Intent(ACTION_USB_PERMISSION), flags)
                        usbManager!!.requestPermission(targetDevice, permIntent)
                        result.success(mapOf("status" to "REQUESTING_PERMISSION", "deviceName" to targetDevice.deviceName))
                    } else {
                        val ok = openUsbDevice(targetDevice)
                        result.success(mapOf("status" to (if (ok) "CONNECTED" else "FAILED"), "deviceName" to targetDevice.deviceName))
                    }
                }

                "sendUsbData" -> {
                    val data = call.argument<String>("data") ?: ""
                    val success = writeUsbSerial(data)
                    result.success(success)
                }

                "disconnectUsb" -> {
                    closeUsbConnection()
                    result.success(true)
                }

                "getUsbStatus" -> {
                    result.success(mapOf(
                        "connected" to (usbConnection != null && isReadingUsb),
                        "deviceName" to connectedUsbDevice?.deviceName,
                        "vendorId" to connectedUsbDevice?.vendorId,
                        "productId" to connectedUsbDevice?.productId
                    ))
                }

                else -> result.notImplemented()
            }
        }

        // 3. Real SMS Manager MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSmsCapability" -> {
                    val hasTelephony = packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
                    val hasPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
                    val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                    val simReady = tm?.simState == TelephonyManager.SIM_STATE_READY

                    val status = when {
                        !hasTelephony -> "SMS_UNAVAILABLE"
                        !simReady -> "NO_SIM"
                        !hasPermission -> "PERMISSION_DENIED"
                        else -> "READY"
                    }

                    result.success(mapOf(
                        "status" to status,
                        "hasPermission" to hasPermission,
                        "hasTelephony" to hasTelephony,
                        "simReady" to simReady
                    ))
                }

                "requestSmsPermission" -> {
                    smsPermissionResultCallback = result
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.SEND_SMS, Manifest.permission.READ_PHONE_STATE),
                        SMS_PERMISSION_REQUEST_CODE
                    )
                }

                "sendDirectSms" -> {
                    val phone = call.argument<String>("phone")?.trim() ?: ""
                    val message = call.argument<String>("message")?.trim() ?: ""

                    if (phone.isEmpty() || message.isEmpty()) {
                        result.error("INVALID_ARGS", "Phone or message cannot be empty", null)
                        return@setMethodCallHandler
                    }

                    val hasPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
                    if (!hasPermission) {
                        result.success(mapOf(
                            "success" to false,
                            "status" to "PERMISSION_DENIED",
                            "detailMessage" to "SMS PERMISSION DENIED: Grant SMS permission in Settings or app permissions."
                        ))
                        return@setMethodCallHandler
                    }

                    val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                    if (tm?.simState != TelephonyManager.SIM_STATE_READY) {
                        result.success(mapOf(
                            "success" to false,
                            "status" to "SMS_UNAVAILABLE",
                            "detailMessage" to "SMS UNAVAILABLE: No active mobile SIM card detected."
                        ))
                        return@setMethodCallHandler
                    }

                    sendSmsViaManager(phone, message, result)
                }

                "openNativeSmsComposer" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    try {
                        val intent = Intent(Intent.ACTION_SENDTO).apply {
                            data = Uri.parse("smsto:$phone")
                            putExtra("sms_body", message)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }

                "openWhatsApp" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    try {
                        val cleanPhone = phone.replace(Regex("[^0-9]"), "")
                        val encodedMsg = java.net.URLEncoder.encode(message, "UTF-8")
                        val uri = if (cleanPhone.isNotEmpty()) {
                            Uri.parse("https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedMsg")
                        } else {
                            Uri.parse("https://api.whatsapp.com/send?text=$encodedMsg")
                        }
                        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                            setPackage("com.whatsapp")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            val fallbackIntent = Intent(Intent.ACTION_VIEW, uri).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(fallbackIntent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }

                "showSystemNotification" -> {
                    val title = call.argument<String>("title") ?: "OnionGuard Storage Alert"
                    val message = call.argument<String>("message") ?: "Environmental alert triggered."
                    showSystemNotification(title, message)
                    result.success(true)
                }

                "openBrowserUrl" -> {
                    val urlStr = call.argument<String>("url") ?: ""
                    try {
                        val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(urlStr)).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(browserIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun showSystemNotification(title: String, message: String) {
        try {
            val channelId = "onionguard_storage_alerts"
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "OnionGuard Storage Alerts",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Critical Onion Storage Environmental Alerts"
                    enableVibration(true)
                }
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, MainActivity::class.java)
            launchIntent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, flags)

            val notification = NotificationCompat.Builder(this, channelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build()

            notificationManager.notify((System.currentTimeMillis() % 100000).toInt(), notification)
        } catch (_: Exception) {
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            smsPermissionResultCallback?.success(granted)
            smsPermissionResultCallback = null
        }
    }

    // ============================================================================
    // USB CDC-ACM SERIAL COMMUNICATION IMPLEMENTATION
    // ============================================================================
    private fun openUsbDevice(device: UsbDevice): Boolean {
        try {
            closeUsbConnection()

            val connection = usbManager?.openDevice(device) ?: run {
                sendUsbEvent("ERROR", "Failed to open USB device connection")
                return false
            }

            // Find bulk IN and bulk OUT endpoints across all interfaces
            var chosenInterface: UsbInterface? = null
            var inEp: UsbEndpoint? = null
            var outEp: UsbEndpoint? = null

            for (i in 0 until device.interfaceCount) {
                val iface = device.getInterface(i)
                var currentIn: UsbEndpoint? = null
                var currentOut: UsbEndpoint? = null

                for (j in 0 until iface.endpointCount) {
                    val ep = iface.getEndpoint(j)
                    if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                        if (ep.direction == UsbConstants.USB_DIR_IN) {
                            currentIn = ep
                        } else if (ep.direction == UsbConstants.USB_DIR_OUT) {
                            currentOut = ep
                        }
                    }
                }

                if (currentIn != null && currentOut != null) {
                    chosenInterface = iface
                    inEp = currentIn
                    outEp = currentOut
                    break
                }
            }

            if (chosenInterface == null || inEp == null || outEp == null) {
                connection.close()
                sendUsbEvent("ERROR", "Could not find compatible USB CDC serial endpoints on ESP32-H2")
                return false
            }

            if (!connection.claimInterface(chosenInterface, true)) {
                connection.close()
                sendUsbEvent("ERROR", "Failed to claim USB interface")
                return false
            }

            // Configure CDC Line Coding (115200 Baud, 1 Stop bit, No Parity, 8 Data bits)
            // SET_LINE_CODING = 0x20, REQ_TYPE = 0x21 (Host to Device, Class, Interface)
            val lineCoding = byteArrayOf(
                (115200 and 0xFF).toByte(),
                ((115200 shr 8) and 0xFF).toByte(),
                ((115200 shr 16) and 0xFF).toByte(),
                ((115200 shr 24) and 0xFF).toByte(),
                0x00.toByte(), // 1 stop bit
                0x00.toByte(), // no parity
                0x08.toByte()  // 8 data bits
            )
            connection.controlTransfer(0x21, 0x20, 0, chosenInterface.id, lineCoding, lineCoding.size, 500)

            // Assert DTR and RTS (SET_CONTROL_LINE_STATE = 0x22, value = 0x03)
            connection.controlTransfer(0x21, 0x22, 0x03, chosenInterface.id, null, 0, 500)

            usbConnection = connection
            usbInterface = chosenInterface
            endpointIn = inEp
            endpointOut = outEp
            connectedUsbDevice = device

            startUsbReadThread()

            sendUsbEvent("CONNECTED", mapOf(
                "deviceName" to device.deviceName,
                "vendorId" to device.vendorId,
                "productId" to device.productId,
                "baudRate" to 115200
            ))
            return true
        } catch (e: Exception) {
            sendUsbEvent("ERROR", "USB open exception: ${e.localizedMessage}")
            return false
        }
    }

    private fun startUsbReadThread() {
        isReadingUsb = true
        usbReadThread = Thread {
            val buffer = ByteArray(1024)
            val lineBuffer = ByteArrayOutputStream()

            while (isReadingUsb && usbConnection != null && endpointIn != null) {
                val bytesRead = usbConnection?.bulkTransfer(endpointIn, buffer, buffer.size, 200) ?: -1
                if (bytesRead > 0) {
                    for (i in 0 until bytesRead) {
                        val b = buffer[i]
                        if (b == '\n'.code.toByte()) {
                            val line = lineBuffer.toString(StandardCharsets.UTF_8.name()).trim()
                            lineBuffer.reset()
                            if (line.isNotEmpty()) {
                                runOnUiThread {
                                    sendUsbEvent("DATA", line)
                                }
                            }
                        } else if (b != '\r'.code.toByte()) {
                            lineBuffer.write(b.toInt())
                        }
                    }
                } else if (bytesRead < 0 && bytesRead != -1) { // Error
                    if (isReadingUsb) {
                        runOnUiThread {
                            sendUsbEvent("ERROR", "Serial read error ($bytesRead)")
                        }
                    }
                    break
                }
            }
        }.apply {
            name = "OnionGuardUsbReadThread"
            isDaemon = true
            start()
        }
    }

    private fun writeUsbSerial(data: String): Boolean {
        if (usbConnection == null || endpointOut == null) return false
        return try {
            val bytes = (if (data.endsWith("\n")) data else "$data\n").toByteArray(StandardCharsets.UTF_8)
            val written = usbConnection!!.bulkTransfer(endpointOut, bytes, bytes.size, 1000)
            written >= 0
        } catch (e: Exception) {
            false
        }
    }

    private fun closeUsbConnection() {
        isReadingUsb = false
        usbReadThread?.interrupt()
        usbReadThread = null

        usbInterface?.let { usbConnection?.releaseInterface(it) }
        usbConnection?.close()

        usbConnection = null
        usbInterface = null
        endpointIn = null
        endpointOut = null
        connectedUsbDevice = null
    }

    private fun sendUsbEvent(type: String, payload: Any?) {
        val event = mapOf("type" to type, "payload" to payload)
        usbEventSink?.success(event)
    }

    // ============================================================================
    // REAL TELEPHONY SMS MANAGER IMPLEMENTATION
    // ============================================================================
    private fun sendSmsViaManager(phone: String, message: String, result: MethodChannel.Result) {
        val uniqueAction = "${ACTION_SMS_SENT}_${System.currentTimeMillis()}"

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_ONE_SHOT
        } else {
            PendingIntent.FLAG_ONE_SHOT
        }
        val sentIntent = PendingIntent.getBroadcast(this, 0, Intent(uniqueAction), flags)

        val smsSentReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                try {
                    unregisterReceiver(this)
                } catch (_: Exception) {}

                when (resultCode) {
                    Activity.RESULT_OK -> {
                        result.success(mapOf(
                            "success" to true,
                            "status" to "DELIVERED",
                            "detailMessage" to "SMS delivered successfully via phone SIM."
                        ))
                    }
                    SmsManager.RESULT_ERROR_GENERIC_FAILURE -> {
                        result.success(mapOf(
                            "success" to false,
                            "status" to "FAILED",
                            "detailMessage" to "SMS FAILED: Radio generic failure."
                        ))
                    }
                    SmsManager.RESULT_ERROR_NO_SERVICE -> {
                        result.success(mapOf(
                            "success" to false,
                            "status" to "FAILED",
                            "detailMessage" to "SMS FAILED: No mobile carrier service."
                        ))
                    }
                    SmsManager.RESULT_ERROR_RADIO_OFF -> {
                        result.success(mapOf(
                            "success" to false,
                            "status" to "FAILED",
                            "detailMessage" to "SMS FAILED: Cellular radio is off (Airplane mode)."
                        ))
                    }
                    else -> {
                        result.success(mapOf(
                            "success" to false,
                            "status" to "FAILED",
                            "detailMessage" to "SMS FAILED: Error code $resultCode"
                        ))
                    }
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(smsSentReceiver, IntentFilter(uniqueAction), Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(smsSentReceiver, IntentFilter(uniqueAction))
        }

        try {
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                applicationContext.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                val sentIntents = ArrayList<PendingIntent>()
                sentIntents.add(sentIntent)
                for (k in 1 until parts.size) {
                    sentIntents.add(PendingIntent.getBroadcast(this, k, Intent("${uniqueAction}_$k"), flags))
                }
                smsManager.sendMultipartTextMessage(phone, null, parts, sentIntents, null)
            } else {
                smsManager.sendTextMessage(phone, null, message, sentIntent, null)
            }
        } catch (e: Exception) {
            try { unregisterReceiver(smsSentReceiver) } catch (_: Exception) {}
            result.success(mapOf(
                "success" to false,
                "status" to "FAILED",
                "detailMessage" to "SmsManager exception: ${e.localizedMessage}"
            ))
        }
    }

    override fun onDestroy() {
        closeUsbConnection()
        try { unregisterReceiver(usbReceiver) } catch (_: Exception) {}
        super.onDestroy()
    }
}
