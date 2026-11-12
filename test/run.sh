#!/usr/bin/env bash
#
# Puts the release in MOODLE_VER together with the test plugin in app/, then
# installs and upgrades it against MariaDB, as Wodby CI and the buildable Moodle
# service do.

set -euo pipefail

if [[ -n "${DEBUG:-}" ]]; then
    set -x
fi

: "${IMAGE:?}" "${MOODLE_VER:?}"
name="${NAME:-moodle-php-test}"
net="${name}-net"
db="${name}-db"
work="$(mktemp -d)"
# The container user writes builds here and replaces them.
chmod 777 "${work}"

cleanup() {
    docker rm -f "${db}" "${name}" >/dev/null 2>&1 || true
    docker network rm "${net}" >/dev/null 2>&1 || true
    docker image rm -f "${name}:app" >/dev/null 2>&1 || true
    # Files written by the container user.
    docker run --rm -v "${work}:/work" --entrypoint sh "${IMAGE}" -c 'rm -rf /work/* /work/.[!.]*' >/dev/null 2>&1 || true
    rm -rf "${work}"
}
trap cleanup EXIT

ok() { echo "OK: $*"; }

# A copy of app/ the container user can write, as Wodby CI's working directory.
prepare() {
    rm -rf "${work:?}/$1"
    cp -R app "${work}/$1"
    printf '%s\n' "${MOODLE_VER}" > "${work}/$1/.moodle-version"
    chmod -R a+rwX "${work}/$1"
}

# Replaces the app directory with another build. The container user owns the
# files, so the container removes them.
replace_app() {
    docker run --rm -v "${work}:/work" --entrypoint sh "${IMAGE}" -c "rm -rf /work/app && mv /work/$1 /work/app"
}

install_release() {
    docker run --rm -v "${work}/$1:/var/www/html" -w /var/www/html "${IMAGE}" moodle-install-release
}

echo "Refusing an unsupported release"
prepare old
# The command fails; its output says why.
out="$(docker run --rm -v "${work}/old:/var/www/html" -w /var/www/html "${IMAGE}" moodle-install-release 5.0.3 2>&1 || true)"
if grep "not supported" <<<"${out}"; then
    ok "Moodle 5.0 refused"
else
    echo >&2 "Moodle 5.0 was not refused"; exit 1
fi

echo "Refusing a repository file that replaces one of Moodle's"
prepare conflict
printf '<?php\n' > "${work}/conflict/public/index.php"
out="$(install_release conflict 2>&1 || true)"
if grep -F "public/index.php" <<<"${out}"; then
    ok "public/index.php refused"
else
    echo >&2 "public/index.php was not refused"; exit 1
fi

echo "Putting Moodle ${MOODLE_VER} together with the test plugin"
prepare app
install_release app | tee "${work}/install.log"
grep -qx "Plugins from the repository: local/wodbyhello" "${work}/install.log"
for file in config.php public/version.php lib/setup.php vendor/autoload.php public/local/wodbyhello/version.php .moodle-version; do
    test -e "${work}/app/${file}" || { echo >&2 "Missing ${file}"; exit 1; }
done
ok "release, Composer packages, config.php and the plugin are in place"

echo "Building the app image"
printf 'FROM %s\nCOPY --chown=wodby:wodby app /var/www/html\n' "${IMAGE}" > "${work}/Dockerfile"
docker build -q -t "${name}:app" -f "${work}/Dockerfile" "${work}" >/dev/null

docker network create "${net}" >/dev/null
docker run -d --name "${db}" --network "${net}" \
    -e MARIADB_ROOT_PASSWORD=root -e MARIADB_DATABASE=moodle -e MARIADB_USER=moodle -e MARIADB_PASSWORD=moodle \
    mariadb:11.8 --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci >/dev/null
moodle() {
    docker run --rm --network "${net}" -v "${name}-files:/mnt/files" \
        -e DB_HOST="${db}" -e DB_NAME=moodle -e DB_USERNAME=moodle -e DB_PASSWORD=moodle -e DB_KIND=mariadb \
        -e MOODLE_WWWROOT=http://localhost -e MOODLE_ADMIN_PASSWORD='Test-pass-1234!' \
        "${name}:app" "$@"
}
# The server restarts once after creating the database and user.
until docker exec "${db}" mariadb -h127.0.0.1 -umoodle -pmoodle moodle -e "SELECT 1" >/dev/null 2>&1; do sleep 1; done

echo "Installing"
moodle moodle-update > "${work}/update.log" 2>&1 || { tail -20 "${work}/update.log"; exit 1; }
version="$(moodle php -r 'define("CLI_SCRIPT", true); require "config.php"; echo get_config("local_wodbyhello", "version");')"
test "${version}" = 2026111200 || { echo >&2 "Plugin version ${version}"; exit 1; }
ok "the plugin is installed with Moodle"

# A copy of app/ with the test plugin at version 2026111201 and, unless "-",
# a second plugin.
prepare_next() {
    prepare "$1"
    sed -i.bak 's/2026111200/2026111201/' "${work}/$1/public/local/wodbyhello/version.php"
    rm "${work}/$1/public/local/wodbyhello/version.php.bak"
    if [[ "${2:-}" != - ]]; then
        cp -R "${work}/$1/public/local/wodbyhello" "${work}/$1/public/local/wodbyextra"
        sed -i.bak -e 's/wodbyhello/wodbyextra/' "${work}/$1/public/local/wodbyextra/version.php"
        mv "${work}/$1/public/local/wodbyextra/lang/en/local_wodbyhello.php" "${work}/$1/public/local/wodbyextra/lang/en/local_wodbyextra.php"
        rm -f "${work}/$1/public/local/wodbyextra/version.php.bak" "${work}/$1/public/local/wodbyextra/index.php"
    fi
}

echo "Upgrading the plugin and adding another"
prepare_next app2
install_release app2 >/dev/null
replace_app app2
docker build -q -t "${name}:app" -f "${work}/Dockerfile" "${work}" >/dev/null
moodle moodle-update > "${work}/update.log" 2>&1 || { tail -20 "${work}/update.log"; exit 1; }
version="$(moodle php -r 'define("CLI_SCRIPT", true); require "config.php"; echo get_config("local_wodbyhello", "version");')"
test "${version}" = 2026111201 || { echo >&2 "Plugin version ${version}"; exit 1; }
ok "a new plugin version is upgraded on the next deployment"
test "$(moodle php -r 'define("CLI_SCRIPT", true); require "config.php"; echo get_config("local_wodbyextra", "version");')" = 2026111201
ok "a plugin added to the repository is installed on the next deployment"

echo "Removing an installed plugin from the repository"
prepare_next app3 -
install_release app3 >/dev/null
replace_app app3
docker build -q -t "${name}:app" -f "${work}/Dockerfile" "${work}" >/dev/null
if moodle moodle-update > "${work}/update.log" 2>&1; then
    echo "INFO: the upgrade succeeds after a plugin was removed"
else
    echo "INFO: the upgrade fails after a plugin was removed:"
fi
tail -5 "${work}/update.log"

docker volume rm -f "${name}-files" >/dev/null
echo "All checks passed"
