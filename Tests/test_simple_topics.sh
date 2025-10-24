#!/bin/bash

echo "🔍 Running Simple Topic Test"
echo "==========================="

# Change to the project directory
cd /Users/timflack/git/f3/visionOS/ROSNavigator

# Compile and run the test
swiftc -framework Foundation Tests/SimpleTopicTest.swift -o simple_topic_test

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful, running test..."
    ./simple_topic_test
    rm -f simple_topic_test
else
    echo "❌ Compilation failed"
    exit 1
fi
