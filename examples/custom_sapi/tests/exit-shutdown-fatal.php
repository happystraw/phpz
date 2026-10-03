<?php

register_shutdown_function(static function () {
    trigger_error('shutdown failure after exit(0)', E_USER_ERROR);
});
echo 'body';
exit(0);
