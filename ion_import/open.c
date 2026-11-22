#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <string.h>
#include <sys/types.h>

extern int __open_2(const char *path, int flags);

static int retry_ion_import(int fd, const char *path, int flags) {
    if (fd >= 0 || (errno != EACCES && errno != EPERM) ||
        strcmp(path, "/dev/ion") != 0) {
        return fd;
    }
    return __open_2("/dev/ion-import", flags);
}

int lilac_ion_open_2(const char *path, int flags) {
    return retry_ion_import(__open_2(path, flags), path, flags);
}

int lilac_ion_open(const char *path, int flags, ...) {
    if ((flags & O_CREAT) || (flags & O_TMPFILE) == O_TMPFILE) {
        va_list args;
        va_start(args, flags);
        mode_t mode = (mode_t)va_arg(args, int);
        va_end(args);
        return open(path, flags, mode);
    }
    return retry_ion_import(open(path, flags), path, flags);
}
