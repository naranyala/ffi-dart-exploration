#include <libnotify/notify.h>
int main() {
  notify_init("Example");
  NotifyNotification *notification =
      notify_notification_new("Hello", "This is a notification", NULL);
  notify_notification_show(notification, NULL);
  return 0;
}
