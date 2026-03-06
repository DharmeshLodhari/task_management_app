package com.example.task_reminder_app;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;

import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.Locale;
import java.util.Set;
import java.util.TimeZone;

/**
 * Reschedules all future AlarmManager alarms after a device reboot.
 *
 * Android clears every AlarmManager alarm when the device reboots.
 * This receiver fires on BOOT_COMPLETED, reads saved reminders from the
 * same SharedPreferences file that Flutter's shared_preferences plugin
 * uses, and re-registers each future alarm with setAlarmClock().
 */
public class BootReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (!Intent.ACTION_BOOT_COMPLETED.equals(action)
                && !"android.intent.action.QUICKBOOT_POWERON".equals(action)) {
            return;
        }

        // Flutter's shared_preferences_android stores data here by default.
        SharedPreferences prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE);

        // The plugin prefixes every key with "flutter."
        // List<String> is stored as a StringSet.
        Set<String> rawSet = prefs.getStringSet("flutter.task_reminders", null);
        if (rawSet == null || rawSet.isEmpty()) return;

        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        long now = System.currentTimeMillis();

        for (String json : rawSet) {
            try {
                JSONObject obj       = new JSONObject(json);
                String reminderId    = obj.getString("id");
                long   timeMillis    = parseIso8601(obj.getString("reminderTime"));
                int    notifId       = obj.getInt("notificationId");

                if (timeMillis < 0 || timeMillis <= now) continue; // past alarm, skip

                Intent ai = new Intent(context, MainActivity.class);
                ai.setAction(AlarmReceiver.ACTION_ALARM);
                ai.putExtra(AlarmReceiver.EXTRA_REMINDER_ID, reminderId);
                ai.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                        | Intent.FLAG_ACTIVITY_CLEAR_TOP
                        | Intent.FLAG_ACTIVITY_SINGLE_TOP);

                PendingIntent pi = PendingIntent.getActivity(
                        context, notifId, ai,
                        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

                am.setAlarmClock(new AlarmManager.AlarmClockInfo(timeMillis, pi), pi);

            } catch (Exception ignored) {
                // Malformed entry — skip
            }
        }
    }

    /**
     * Parses a Dart ISO-8601 string (local or UTC) into epoch milliseconds.
     * Dart's DateTime.toIso8601String() produces "2025-01-15T14:30:00.000000"
     * (local, no Z) or "2025-01-15T14:30:00.000000Z" (UTC).
     */
    private long parseIso8601(String iso) {
        try {
            boolean isUtc = iso.endsWith("Z");
            if (isUtc) iso = iso.substring(0, iso.length() - 1);

            // Normalize fractional seconds to exactly 3 digits (milliseconds).
            if (iso.contains(".")) {
                String[] parts = iso.split("\\.");
                String frac = parts[1];
                if (frac.length() > 3) frac = frac.substring(0, 3);
                while (frac.length() < 3) frac += "0";
                iso = parts[0] + "." + frac;
            } else {
                iso += ".000";
            }

            SimpleDateFormat sdf = new SimpleDateFormat(
                    "yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US);
            sdf.setTimeZone(isUtc ? TimeZone.getTimeZone("UTC") : TimeZone.getDefault());

            java.util.Date d = sdf.parse(iso);
            return d != null ? d.getTime() : -1;
        } catch (Exception e) {
            return -1;
        }
    }
}
