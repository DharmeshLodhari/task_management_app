package com.apps.audiotaskreminder;

import android.app.AlarmManager;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.PowerManager;
import android.provider.Settings;
import android.view.WindowManager;

import androidx.core.app.ActivityCompat;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    private static final String ALARM_CHANNEL = "com.task_reminder/alarm";
    private static final String PERM_CHANNEL  = "com.task_reminder/permissions";
    private static final int    NOTIF_REQ     = 1001;

    // Reminder ID delivered by AlarmReceiver before the Flutter engine starts.
    // Read once by Dart via getLaunchReminderId(), then cleared.
    private String      pendingAlarmReminderId = null;
    private MethodChannel alarmChannel         = null;
    private MediaPlayer   alarmPlayer          = null;

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // Read alarm intent BEFORE super.onCreate() so the value is set
        // before the Flutter engine starts (engine init happens in super).
        Intent i = getIntent();
        if (i != null && AlarmReceiver.ACTION_ALARM.equals(i.getAction())) {
            pendingAlarmReminderId = i.getStringExtra(AlarmReceiver.EXTRA_REMINDER_ID);
        }

        super.onCreate(savedInstanceState);
        applyAlarmWindowFlags();
    }

    @Override
    public void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        // App was backgrounded; notification tap brings it to foreground.
        // Store the reminder ID exactly like the cold-launch case — Dart reads
        // it in didChangeAppLifecycleState(resumed) via getLaunchReminderId().
        if (intent != null && AlarmReceiver.ACTION_ALARM.equals(intent.getAction())) {
            applyAlarmWindowFlags();
            pendingAlarmReminderId = intent.getStringExtra(AlarmReceiver.EXTRA_REMINDER_ID);
        }
    }

    // ── Flutter engine ────────────────────────────────────────────────────────

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // ── Alarm channel (schedule / cancel / bridge) ─────────────────────
        alarmChannel = new MethodChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(), ALARM_CHANNEL);

        alarmChannel.setMethodCallHandler((call, result) -> {
            switch (call.method) {

                case "scheduleAlarm": {
                    int    id         = ((Number) call.argument("id")).intValue();
                    long   timeMillis = ((Number) call.argument("timeMillis")).longValue();
                    String rid        = call.argument("reminderId");

                    // Fire at AlarmReceiver via getBroadcast — the receiver then
                    // posts a notification with fullScreenIntent, which is the
                    // reliable pattern for all OEMs and Android 10+ devices.
                    // Direct getActivity() background starts are blocked on most
                    // real devices (Samsung, Xiaomi, OnePlus, Android 12+).
                    Intent alarmIntent = new Intent(this, AlarmReceiver.class);
                    alarmIntent.setAction(AlarmReceiver.ACTION_ALARM);
                    alarmIntent.putExtra(AlarmReceiver.EXTRA_REMINDER_ID, rid);
                    alarmIntent.putExtra(AlarmReceiver.EXTRA_NOTIF_ID, id);

                    PendingIntent pi = PendingIntent.getBroadcast(
                        this, id, alarmIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

                    // showIntent: tapping the alarm clock icon in the status bar
                    // opens MainActivity (separate PendingIntent, different requestCode).
                    Intent showIntent = new Intent(this, MainActivity.class);
                    PendingIntent showPi = PendingIntent.getActivity(
                        this, id + 100000, showIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

                    AlarmManager am = (AlarmManager) getSystemService(ALARM_SERVICE);
                    am.setAlarmClock(new AlarmManager.AlarmClockInfo(timeMillis, showPi), pi);
                    result.success(null);
                    break;
                }

                case "cancelAlarm": {
                    int id = ((Number) call.argument("id")).intValue();

                    // Must match the getBroadcast PendingIntent used in scheduleAlarm.
                    Intent alarmIntent = new Intent(this, AlarmReceiver.class);
                    alarmIntent.setAction(AlarmReceiver.ACTION_ALARM);

                    PendingIntent pi = PendingIntent.getBroadcast(
                        this, id, alarmIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

                    AlarmManager am = (AlarmManager) getSystemService(ALARM_SERVICE);
                    am.cancel(pi);
                    result.success(null);
                    break;
                }

                case "startAlarmRingtone": {
                    stopAlarmPlayer(); // stop any previous instance
                    try {
                        Uri alarmUri = RingtoneManager.getDefaultUri(
                                RingtoneManager.TYPE_ALARM);
                        if (alarmUri == null) {
                            alarmUri = RingtoneManager.getDefaultUri(
                                    RingtoneManager.TYPE_RINGTONE);
                        }
                        alarmPlayer = new MediaPlayer();
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            alarmPlayer.setAudioAttributes(
                                new AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_ALARM)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                    .build());
                        }
                        alarmPlayer.setDataSource(this, alarmUri);
                        alarmPlayer.setLooping(true);
                        alarmPlayer.prepare();
                        alarmPlayer.start();
                    } catch (Exception e) {
                        alarmPlayer = null;
                    }
                    result.success(null);
                    break;
                }

                case "stopAlarmRingtone": {
                    stopAlarmPlayer();
                    result.success(null);
                    break;
                }

                case "getLaunchReminderId": {
                    // One-time read — cleared after Dart consumes it.
                    result.success(pendingAlarmReminderId);
                    pendingAlarmReminderId = null;
                    break;
                }

                default:
                    result.notImplemented();
            }
        });

        // ── Permissions channel ────────────────────────────────────────────
        new MethodChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(), PERM_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                switch (call.method) {

                    case "requestNotificationsPermission": {
                        if (Build.VERSION.SDK_INT >= 33) {
                            ActivityCompat.requestPermissions(
                                this,
                                new String[]{"android.permission.POST_NOTIFICATIONS"},
                                NOTIF_REQ);
                        }
                        result.success(null);
                        break;
                    }

                    case "isIgnoringBatteryOptimizations": {
                        PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
                        result.success(pm.isIgnoringBatteryOptimizations(getPackageName()));
                        break;
                    }

                    case "requestIgnoreBatteryOptimizations": {
                        try {
                            Intent i = new Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
                            i.setData(Uri.parse("package:" + getPackageName()));
                            startActivity(i);
                        } catch (Exception e) {
                            startActivity(new Intent(
                                Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS));
                        }
                        result.success(null);
                        break;
                    }

                    case "canUseFullScreenIntent": {
                        if (Build.VERSION.SDK_INT >= 34) {
                            NotificationManager nm =
                                (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
                            result.success(nm.canUseFullScreenIntent());
                        } else {
                            result.success(true);
                        }
                        break;
                    }

                    case "requestFullScreenIntentPermission": {
                        if (Build.VERSION.SDK_INT >= 34) {
                            Intent i = new Intent(
                                "android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENTS");
                            i.setData(Uri.parse("package:" + getPackageName()));
                            startActivity(i);
                        }
                        result.success(null);
                        break;
                    }

                    case "canDrawOverlays": {
                        result.success(Settings.canDrawOverlays(this));
                        break;
                    }

                    case "requestOverlayPermission": {
                        Intent i = new Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:" + getPackageName()));
                        startActivity(i);
                        result.success(null);
                        break;
                    }

                    default:
                        result.notImplemented();
                }
            });
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /** Stops and releases the alarm MediaPlayer if it is running. */
    private void stopAlarmPlayer() {
        if (alarmPlayer != null) {
            try {
                if (alarmPlayer.isPlaying()) alarmPlayer.stop();
                alarmPlayer.release();
            } catch (Exception ignored) {}
            alarmPlayer = null;
        }
    }

    /** Makes the activity visible over a locked / sleeping screen. */
    private void applyAlarmWindowFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true);
            setTurnScreenOn(true);
        } else {
            getWindow().addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        }
    }
}
