--TEST--
my_php_extension function, error and exception metrics
--EXTENSIONS--
my_php_extension
--FILE--
<?php
function check($actual, $expected): void {
    if ($actual !== $expected) {
        throw new Exception(var_export([$actual, $expected], true));
    }
}

MyPHPExt\Metrics::reset();

function metricUserFunction(string $value): string
{
    return strtoupper(trim($value));
}

metricUserFunction(' first ');
metricUserFunction(' second ');
greet('first');
greet('second');
@trigger_error('metric warning', E_USER_WARNING);

try {
    throw new LogicException('first');
} catch (LogicException) {
}

try {
    throw new RuntimeException('second');
} catch (RuntimeException) {
}

// Capture both snapshots before assertion helpers can add observed calls.
$snapshot = MyPHPExt\Metrics::snapshot();
MyPHPExt\Metrics::reset();
$reset = MyPHPExt\Metrics::snapshot();

$expectedCalls = [
    'metricUserFunction' => ['user', 'function', 2],
    'trim' => ['internal', 'function', 2],
    'strtoupper' => ['internal', 'function', 2],
    'greet' => ['internal', 'function', 2],
    'trigger_error' => ['internal', 'function', 1],
    'Exception::__construct' => ['internal', 'instance_method', 2],
];
check($snapshot['function_calls']['total'], 11);
check(count($snapshot['function_calls']['by_name']), count($expectedCalls));
foreach ($expectedCalls as $name => [$kind, $role, $count]) {
    $call = $snapshot['function_calls']['by_name'][$name];
    check([$call['kind'], $call['role'], $call['calls']], [$kind, $role, $count]);
    check(count($call['duration_ns']), $count);
    foreach ($call['duration_ns'] as $duration) {
        check(is_int($duration) && $duration >= 0, true);
    }
}
echo "call counts, classifications and duration samples: passed\n";

check($snapshot['errors']['total'], 1);
check($snapshot['errors']['warnings'], 1);
check($snapshot['exceptions']['total'], 2);
check(count($snapshot['exceptions']['by_class']), 2);
check($snapshot['exceptions']['by_class']['LogicException'], 1);
check($snapshot['exceptions']['by_class']['RuntimeException'], 1);
echo "error and exception counts: passed\n";

check($reset['function_calls']['total'], 0);
check($reset['function_calls']['by_name'], []);
check($reset['errors']['total'], 0);
check($reset['errors']['warnings'], 0);
check($reset['exceptions']['total'], 0);
check($reset['exceptions']['by_class'], []);
echo "reset clears metrics: passed\n";
?>
--EXPECT--
call counts, classifications and duration samples: passed
error and exception counts: passed
reset clears metrics: passed
