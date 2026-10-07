<?php

register_shutdown_function(static function () {
    throw new RuntimeException('shutdown failure');
});
echo 'body';
