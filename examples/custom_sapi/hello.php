<?php
echo custom_sapi_greeting(), "\n";
register_shutdown_function(function () { echo "Request finished\n"; });
