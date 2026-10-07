<?php

register_shutdown_function(static function () {
    echo '|shutdown';
});
echo 'body';
trigger_error('execution bailout', E_USER_ERROR);
