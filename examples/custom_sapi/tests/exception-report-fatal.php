<?php

register_shutdown_function(static function () {
    echo '|shutdown';
});
echo 'body';
throw new class extends RuntimeException {
    public function __toString(): string
    {
        trigger_error('exception reporting bailout', E_USER_ERROR);
    }
};
