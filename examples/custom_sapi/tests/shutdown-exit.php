<?php

register_shutdown_function(static function () {
    exit(7);
});
echo 'body';
