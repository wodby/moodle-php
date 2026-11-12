<?php
// Moodle settings of the wodby/moodle image, read from the container's
// environment.

unset($CFG);
global $CFG;
$CFG = new stdClass();

$wodbyenv = static function (string $name, ?string $default = null): ?string {
    $value = getenv($name);
    return $value === false || $value === '' ? $default : $value;
};

// Database. DB_KIND tells MariaDB and MySQL apart; DB_DRIVER cannot.
$CFG->dbtype = match ($wodbyenv('DB_KIND', $wodbyenv('DB_DRIVER', 'mariadb'))) {
    'postgres', 'pgsql' => 'pgsql',
    'mysql' => 'mysqli',
    default => 'mariadb',
};
$CFG->dblibrary = 'native';
$CFG->dbhost = $wodbyenv('DB_HOST', 'localhost');
$CFG->dbname = $wodbyenv('DB_NAME', 'moodle');
$CFG->dbuser = $wodbyenv('DB_USERNAME', 'moodle');
$CFG->dbpass = $wodbyenv('DB_PASSWORD', '');
$CFG->prefix = $wodbyenv('MOODLE_DB_PREFIX', 'mdl_');
$CFG->dboptions = [
    'dbpersist' => false,
    'dbport' => $wodbyenv('DB_PORT', ''),
];
if ($CFG->dbtype !== 'pgsql') {
    $CFG->dboptions['dbcollation'] = 'utf8mb4_unicode_ci';
}
// A managed database server with a CA certificate is reached over TLS.
// PostgreSQL also verifies the server against that certificate.
if ($dbca = $wodbyenv('DB_SSL_CA')) {
    if ($CFG->dbtype === 'pgsql') {
        putenv('PGSSLROOTCERT=' . $dbca);
        $CFG->dboptions['ssl'] = 'verify-full';
    } else {
        $CFG->dboptions['ssl'] = 'require';
    }
}

// The public address: the app's main route, unless MOODLE_WWWROOT is set.
$CFG->wwwroot = rtrim($wodbyenv('MOODLE_WWWROOT', $wodbyenv('WODBY_PRIMARY_URL', 'http://localhost')), '/');
// Wodby terminates TLS before the request reaches Nginx.
if (str_starts_with($CFG->wwwroot, 'https://')) {
    $CFG->sslproxy = true;
}

// Files Moodle stores, shared by every replica and the cron worker. Caches that
// do not have to be shared stay on each container's own disk.
$CFG->dataroot = $wodbyenv('MOODLE_DATAROOT', '/mnt/files/moodledata');
$CFG->localcachedir = $wodbyenv('MOODLE_LOCALCACHEDIR', '/tmp/moodle-localcache');
$CFG->directorypermissions = 02777;
if (!is_dir($CFG->dataroot)) {
    $umask = umask(0);
    @mkdir($CFG->dataroot, $CFG->directorypermissions, true);
    umask($umask);
    unset($umask);
}

$CFG->admin = 'admin';

// The Nginx service sends requests for unknown paths to r.php.
$CFG->routerconfigured = true;

// The code is part of the image: plugins installed from the web interface
// would be lost on the next deployment, and executable paths must not be
// changed from it.
$CFG->disableupdateautodeploy = true;
$CFG->preventexecpath = true;

// Sessions are kept in Redis or Valkey when the service is linked to one.
if ($redishost = $wodbyenv('REDIS_HOST')) {
    $CFG->session_handler_class = '\core\session\redis';
    $CFG->session_redis_host = $redishost;
    $CFG->session_redis_port = (int) $wodbyenv('REDIS_PORT', '6379');
    $CFG->session_redis_auth = $wodbyenv('REDIS_PASSWORD', '');
    $CFG->session_redis_prefix = $wodbyenv('MOODLE_SESSION_REDIS_PREFIX', 'moodle_sess_');
    $CFG->session_redis_acquire_lock_timeout = 120;
    $CFG->session_redis_lock_expire = 7200;
}

unset($wodbyenv, $dbca, $redishost);

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
