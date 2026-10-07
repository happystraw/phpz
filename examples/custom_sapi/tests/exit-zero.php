<?php

register_shutdown_function(static function () {
    echo '|shutdown';
});
echo 'body';
exit(0);
echo '|unreachable';
