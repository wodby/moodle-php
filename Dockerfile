# check=skip=InvalidDefaultArgInFrom

# The Makefile supplies the required digest-pinned BASE_IMAGE (wodby/php).
ARG BASE_IMAGE

# PHP-FPM with Wodby's setup for Moodle, but no Moodle: Wodby CI puts a Moodle
# release and the app's plugins together with moodle-install-release, then
# builds the app's image on this one.
FROM ${BASE_IMAGE}

ENV APP_NAME="Moodle" \
    # The Moodle major versions that Wodby's scripts support, separated by \
    # spaces. Moodle 5.0 and earlier are not supported. \
    MOODLE_MAJOR_VERSIONS="5" \
    PHP_MAX_INPUT_VARS="5000" \
    PHP_UPLOAD_MAX_FILESIZE="256M" \
    PHP_POST_MAX_SIZE="256M" \
    PHP_ZEND_EXCEPTION_IGNORE_ARGS="1"

COPY config.php /usr/local/share/moodle/config.php
COPY bin /usr/local/bin/
