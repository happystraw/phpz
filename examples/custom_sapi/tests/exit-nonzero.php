<?php

register_shutdown_function(static function () {
    echo '|shutdown';
});
echo 'body';
exit(7);
echo '|unreachable';
