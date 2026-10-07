<?php

register_shutdown_function(static function () {
    exit(0);
});
echo 'body';
trigger_error('failure before shutdown exit(0)', E_USER_ERROR);
