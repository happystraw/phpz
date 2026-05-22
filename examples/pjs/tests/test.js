// test.js - QuickJS test script

// 1. Simple greeting function
function greet(name) {
    return 'Hello, ' + name + '!';
}

// 2. Mathematical calculation
function fibonacci(n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

// 3. Array and object operations
function processData(arr) {
    return arr
        .filter(x => x > 0)
        .map(x => x * 2)
        .reduce((sum, x) => sum + x, 0);
}

// 4. Date handling
function getCurrentTime() {
    return new Date().toISOString();
}

// 5. String manipulation
function reverseString(str) {
    return str.split('').reverse().join('');
}

// 6. Object factory
function createPerson(name, age) {
    return {
        name: name,
        age: age,
        introduce: function () {
            return this.name + ' is ' + this.age + ' years old';
        }
    };
}

// Export test results
var testResults = {
    greeting: greet('Zig-PHP'),
    fibonacci: fibonacci(10),
    dataProcessing: processData([1, -2, 3, -4, 5, 6]),
    currentTime: getCurrentTime(),
    reversed: reverseString('QuickJS'),
    person: createPerson('Alice', 25)
};

// Return test results
JSON.stringify(testResults);;
