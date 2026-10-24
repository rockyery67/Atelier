package com.dexterous.flutterlocalnotifications;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.app.AlarmManager;
import android.app.PendingIntent;
import android.util.Log;
import org.json.JSONArray;
import org.json.JSONObject;
import java.time.LocalDateTime;
import java.time.ZoneId;

/** Version-pinned adapter for flutter_local_notifications 22.3.2.
 * Rebase device-local wall times after reboot/time changes, discard expired
 * one-shot alarms, then reuse the plugin's OS scheduling implementation.
 * The Dart reconciler remains authoritative when the app next resumes.
 */
public class AtelierClockReceiver extends BroadcastReceiver {
  @Override public void onReceive(Context context, Intent intent) {
    try {
      final String key = "scheduled_notifications";
      SharedPreferences preferences = context.getSharedPreferences(key, Context.MODE_PRIVATE);
      JSONArray stored = new JSONArray(preferences.getString(key, "[]"));
      JSONArray retained = new JSONArray();
      ZoneId zone = ZoneId.systemDefault();
      LocalDateTime now = LocalDateTime.now(zone);
      for (int i = 0; i < stored.length(); i++) {
        JSONObject record = stored.getJSONObject(i);
        // Cancel old registrations before rebasing; dropping an expired record
        // from preferences alone would leave its existing alarm alive.
        Intent oldIntent = new Intent(context, ScheduledNotificationReceiver.class);
        PendingIntent oldAlarm = PendingIntent.getBroadcast(context, record.getInt("id"), oldIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        ((AlarmManager) context.getSystemService(Context.ALARM_SERVICE)).cancel(oldAlarm);
        String wallTime = record.optString("scheduledDateTime", "");
        boolean repeats = !record.isNull("matchDateTimeComponents") || !record.isNull("repeatInterval");
        if (!wallTime.isEmpty()) {
          LocalDateTime due = LocalDateTime.parse(wallTime);
          if (!repeats && !due.isAfter(now)) continue;
          if (zone.getRules().getValidOffsets(due).isEmpty()) continue;
          record.put("timeZoneName", zone.getId());
        }
        retained.put(record);
      }
      preferences.edit().putString(key, retained.toString()).commit();
      FlutterLocalNotificationsPlugin.rescheduleNotifications(context);
    } catch (Exception error) {
      Log.e("AtelierClock", "Could not reconcile device clock; app will retry on resume", error);
    }
  }
}
