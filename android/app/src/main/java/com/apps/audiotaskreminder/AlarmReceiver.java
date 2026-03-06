package com.apps.audiotaskreminder;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.PowerManager;
import android.provider.Settings;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

/**
 * Receives the AlarmManager broadcast and posts a high-priority notification
 * with a fullScreenIntent. This is the standard Android pattern used by every
 * real alarm app — it works reliably across all OEMs and Android versions
 * because it goes through the notification system (which has its own
 * background-start exemptions) rather than calling startActivity() directly.
 *
 * Behavior by scenario:
 *   Screen OFF / locked  → fullScreenIntent fires immediately → MainActivity
 *   App backgrounded     → heads-up notification shown → user taps → MainActivity
 *   App foreground       → Dart Timer intercepts first; alarm is cancelled
 *                          before this receiver fires (see DashboardScreen)
 */
public class AlarmReceiver extends BroadcastReceiver {

    public static final String EXTRA_REMINDER_ID = "reminder_id";
    public static final String EXTRA_NOTIF_ID    = "notif_id";
    public static final String ACTION_ALARM      = "com.example.task_reminder_app.ALARM";

    private static final String CHANNEL_ID   = "task_reminder_alarm";
    private static final String CHANNEL_NAME = "Alarms";

    @Override
    public void onReceive(Context context, Intent intent) {
        String reminderId = intent.getStringExtra(EXTRA_REMINDER_ID);
        if (reminderId == null) return;

        int notifId = intent.getIntExtra(EXTRA_NOTIF_ID, reminderId.hashCode());

        // Wake the CPU + screen so the notification can appear on the lock screen.
        PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        PowerManager.WakeLock wl = pm.newWakeLock(
                PowerManager.FULL_WAKE_LOCK
                        | PowerManager.ACQUIRE_CAUSES_WAKEUP
                        | PowerManager.ON_AFTER_RELEASE,
                "task_reminder:AlarmReceiver");
        wl.acquire(10_000L); // auto-releases after 10 s

        // Ensure notification channel exists (required on Android 8.0+).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH);
            channel.setDescription("Task reminder alarms");
            channel.enableLights(true);
            channel.enableVibration(true);
            channel.setBypassDnd(true); // ring even in Do-Not-Disturb mode
            channel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            NotificationManager nm =
                    (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            nm.createNotificationChannel(channel);
        }

        // Intent that MainActivity receives in onCreate() (killed) or onNewIntent() (alive).
        Intent launch = new Intent(context, MainActivity.class);
        launch.setAction(ACTION_ALARM);
        launch.putExtra(EXTRA_REMINDER_ID, reminderId);
        launch.putExtra(EXTRA_NOTIF_ID, notifId);
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_CLEAR_TOP
                | Intent.FLAG_ACTIVITY_SINGLE_TOP);

        PendingIntent fullScreenPi = PendingIntent.getActivity(
                context, notifId, launch,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        // Build and post the alarm notification.
        // setFullScreenIntent(true) = high-priority; OS shows it as a full-screen
        // activity on a locked/sleeping screen instead of just a banner.
        Notification notification = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("Task Reminder")
                .setContentText("Your scheduled reminder is due")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setOngoing(false)
                .setFullScreenIntent(fullScreenPi, true)
                .setContentIntent(fullScreenPi)
                .build();

        NotificationManagerCompat.from(context).notify(notifId, notification);

        // ── Direct activity launch (screen-ON / app-backgrounded case) ────────
        // SYSTEM_ALERT_WINDOW ("Display over other apps") explicitly grants the
        // right to startActivity() from background on ALL Android versions and
        // OEMs (Samsung, Xiaomi, OnePlus, etc.).
        // Without it, strict OEMs silently block the call even though
        // setAlarmClock() is supposed to grant a BAL exemption.
        //
        // Fallback: if the user hasn't granted overlay permission yet, the
        // fullScreenIntent notification above still covers the screen-off case.
        if (Settings.canDrawOverlays(context)) {
            try {
                context.startActivity(launch);
            } catch (Exception ignored) {
                // Notification fallback is already posted above.
            }
        }
    }
}
