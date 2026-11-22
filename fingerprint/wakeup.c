#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

#define FPC_SYSFS "/sys/devices/soc/soc:fpc1145/"

static int write_switch(const char *path, int enabled) {
    int fd = TEMP_FAILURE_RETRY(open(path, O_WRONLY | O_CLOEXEC));
    if (fd < 0) {
        return -errno;
    }

    const char *value = enabled ? "enable" : "disable";
    size_t size = strlen(value);
    ssize_t written = TEMP_FAILURE_RETRY(write(fd, value, size));
    int result = written < 0 ? -errno : (size_t)written == size ? 0 : -EIO;
    close(fd);
    return result;
}

/* The Sony HAL invokes this when arming and cancelling authentication. */
__attribute__((visibility("default"))) int device_set_pm_wakeup(int enabled) {
    int result = write_switch(FPC_SYSFS "pm_wakeup", enabled);
    if (result != 0 || !enabled) {
        return result;
    }

    /* The IRQ notification switch only takes effect after PM wake is armed. */
    result = write_switch(FPC_SYSFS "wakeup_enable", enabled);
    if (result != 0) {
        write_switch(FPC_SYSFS "pm_wakeup", 0);
    }
    return result;
}
