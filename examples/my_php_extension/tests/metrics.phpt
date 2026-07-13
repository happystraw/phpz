--TEST--
my_php_extension function, error and exception metrics
--EXTENSIONS--
my_php_extension
--FILE--
<?php
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

var_dump(MyPHPExt\Metrics::snapshot());

MyPHPExt\Metrics::reset();
var_dump(MyPHPExt\Metrics::snapshot());
?>
--EXPECTF--
array(3) {
  ["function_calls"]=>
  array(2) {
    ["total"]=>
    int(11)
    ["by_name"]=>
    array(6) {
      ["metricUserFunction"]=>
      array(4) {
        ["kind"]=>
        string(4) "user"
        ["role"]=>
        string(8) "function"
        ["calls"]=>
        int(2)
        ["duration_ns"]=>
        array(2) {
          [0]=>
          int(%d)
          [1]=>
          int(%d)
        }
      }
      ["trim"]=>
      array(4) {
        ["kind"]=>
        string(8) "internal"
        ["role"]=>
        string(8) "function"
        ["calls"]=>
        int(2)
        ["duration_ns"]=>
        array(2) {
          [0]=>
          int(%d)
          [1]=>
          int(%d)
        }
      }
      ["strtoupper"]=>
      array(4) {
        ["kind"]=>
        string(8) "internal"
        ["role"]=>
        string(8) "function"
        ["calls"]=>
        int(2)
        ["duration_ns"]=>
        array(2) {
          [0]=>
          int(%d)
          [1]=>
          int(%d)
        }
      }
      ["greet"]=>
      array(4) {
        ["kind"]=>
        string(8) "internal"
        ["role"]=>
        string(8) "function"
        ["calls"]=>
        int(2)
        ["duration_ns"]=>
        array(2) {
          [0]=>
          int(%d)
          [1]=>
          int(%d)
        }
      }
      ["trigger_error"]=>
      array(4) {
        ["kind"]=>
        string(8) "internal"
        ["role"]=>
        string(8) "function"
        ["calls"]=>
        int(1)
        ["duration_ns"]=>
        array(1) {
          [0]=>
          int(%d)
        }
      }
      ["Exception::__construct"]=>
      array(4) {
        ["kind"]=>
        string(8) "internal"
        ["role"]=>
        string(15) "instance_method"
        ["calls"]=>
        int(2)
        ["duration_ns"]=>
        array(2) {
          [0]=>
          int(%d)
          [1]=>
          int(%d)
        }
      }
    }
  }
  ["errors"]=>
  array(2) {
    ["total"]=>
    int(1)
    ["warnings"]=>
    int(1)
  }
  ["exceptions"]=>
  array(2) {
    ["total"]=>
    int(2)
    ["by_class"]=>
    array(2) {
      ["LogicException"]=>
      int(1)
      ["RuntimeException"]=>
      int(1)
    }
  }
}
array(3) {
  ["function_calls"]=>
  array(2) {
    ["total"]=>
    int(0)
    ["by_name"]=>
    array(0) {
    }
  }
  ["errors"]=>
  array(2) {
    ["total"]=>
    int(0)
    ["warnings"]=>
    int(0)
  }
  ["exceptions"]=>
  array(2) {
    ["total"]=>
    int(0)
    ["by_class"]=>
    array(0) {
    }
  }
}
