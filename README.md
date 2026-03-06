Application Requirement (Voice Recorder with Smart Reminder)

I want to develop a Flutter mobile application with the following features:

Voice Recording

The user can press a Start Recording button to record their voice.

When the user presses Stop Recording, the audio recording should stop.

The recorded audio file should be stored locally on the device.

Audio List Dashboard

All recorded audio files should be displayed in a dashboard list.

Each item in the list should show:

Recording title (or timestamp)

Play button to listen to the recording again.

The recordings must remain available even after the app is closed and reopened.

Voice-Based Task Reminder (Advanced Feature)

The user can record a voice note describing a task.

Example voice input:

“I have a task to email my HR at 12:00 AM.”

The application should:

Convert the recorded voice to text.

Extract the task and time from the sentence.

Automatically schedule a reminder notification at the specified time.

Reminder Notification

At the detected time (for example, 12:00 AM), the app should send a local notification reminder.

The notification should display the task text extracted from the voice recording.

Offline Capability

Audio recordings should be saved locally.

Previously recorded audio and reminders should still appear when the user opens the app again.

Technologies to Use

Flutter

Local storage (Hive / SQLite / SharedPreferences)

Audio recording plugin

Speech-to-text for converting voice to text

Local notifications for reminders

Example User Flow

User taps Record Task

User speaks:

“I have a task to email my HR at 12:00 AM.”

App converts voice → text

App extracts task = email HR and time = 12:00 AM

App schedules a notification reminder at 12:00 AM

The voice recording appears in the dashboard list