# PHP image for buildable Moodle

[![Build Status](https://github.com/wodby/moodle-php/workflows/Build%20docker%20image/badge.svg)](https://github.com/wodby/moodle-php/actions)

PHP-FPM with Wodby's setup for Moodle, but no Moodle. The
[buildable Moodle](https://github.com/wodby/service-moodle-buildable) service
builds an app's image on it: Wodby CI puts the Moodle release the app's
repository pins together with the repository's plugins, and the result is
copied onto this image. For Moodle without your own plugins, use the prebuilt
[wodby/moodle](https://github.com/wodby/moodle) image.

Based on [wodby/php](https://github.com/wodby/php).

## Tags

| Tag | PHP |
| --- | --- |
| `8.4`, `8`, `latest` | 8.4 |

Image revisions are tagged `rN`, such as `8.4-r0`.

## What's inside

- `/usr/local/share/moodle/config.php`: Moodle's settings, read from the
  container's environment. It is the same as in wodby/moodle.
- `moodle-install-release`: puts a Moodle release together with the app's
  code in the current directory. It reads the release from `.moodle-version`
  (or its first argument), downloads it from Moodle's GitHub tag, installs its
  Composer packages, adds the repository's `public/` files, which must not
  replace any of Moodle's, and adds `config.php`. Moodle 5.1 and later 5.x
  releases are supported.
- `moodle-update`: installs Moodle into an empty database or upgrades it, so
  Moodle's web installer is never used.
- `moodle-cron`: keeps Moodle's cron running.
- PHP settings Moodle needs: `max_input_vars` 5000, 256 MB uploads.

## Environment variables

The variables of [wodby/moodle](https://github.com/wodby/moodle#configuration)
apply: database (`DB_*`), `MOODLE_WWWROOT` or `WODBY_PRIMARY_URL`,
`MOODLE_DATAROOT`, the administrator (`MOODLE_ADMIN_*`) and Redis sessions
(`REDIS_*`).

## Use

```Dockerfile
FROM wodby/moodle-php:8.4
COPY --chown=wodby:wodby . /var/www/html
```

Run `moodle-install-release` in the build directory before building, for
example with `wodby ci run -- moodle-install-release`.
