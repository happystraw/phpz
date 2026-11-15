<?php
// Evaluated inside each native worker request; deliberately no output.
if (isset($phpz_request_marker)) {
    throw new LogicException('PHP variables survived request shutdown');
}
$phpz_request_marker = "thread-$threadId";
$closure = MyPHPExt\Test\makeFnClosure();
if ($closure(20, 22) !== 42
    || (new ReflectionFunction($closure))->getParameters()[0]->getName() !== 'args') {
    throw new LogicException('Incorrect native closure metadata in worker request');
}
for ($i = 0; $i < $rounds; $i++) {
    if (greet($phpz_request_marker) !== "Hello, $phpz_request_marker!") {
        throw new LogicException('Incorrect thread greeting');
    }
    if (MyPHPExt\Test\typedArgument('u8', true, 42) !== 42) {
        throw new LogicException('Incorrect argument conversion');
    }
    try {
        throw new RuntimeException($phpz_request_marker);
    } catch (RuntimeException $exception) {
        if ($exception->getMessage() !== $phpz_request_marker) {
            throw new LogicException('Exception belongs to another thread');
        }
    }
}
$snapshot = MyPHPExt\Metrics::snapshot();
$evalObserved = false;
foreach ($snapshot['function_calls']['by_name'] as $call) {
    if ($call['kind'] === 'eval') $evalObserved = true;
}
if (!$evalObserved) {
    throw new LogicException('Eval frame kind was not observed');
}
if (($snapshot['function_calls']['by_name']['greet']['calls'] ?? -1) !== $rounds
    || ($snapshot['exceptions']['by_class']['RuntimeException'] ?? -1) !== $rounds) {
    throw new LogicException('Observer counts are not request-local');
}
register_shutdown_function(static function () use ($phpz_request_marker, $rounds): void {
    if (greet($phpz_request_marker) !== "Hello, $phpz_request_marker!") {
        throw new LogicException('Incorrect shutdown greeting');
    }
    try {
        throw new RuntimeException('shutdown');
    } catch (RuntimeException) {
    }
    $snapshot = MyPHPExt\Metrics::snapshot();
    if (($snapshot['function_calls']['by_name']['greet']['calls'] ?? -1) !== $rounds + 1
        || ($snapshot['exceptions']['by_class']['RuntimeException'] ?? -1) !== $rounds + 1) {
        throw new LogicException('Observers failed during request shutdown');
    }
});
