#!/bin/bash

echo "🔍 Running Topic Discovery Test"
echo "================================"

# Change to the project directory
cd /Users/timflack/git/f3/visionOS/ROSNavigator

# Compile and run the test
swiftc -framework Foundation Tests/TopicDiscoveryTest.swift -o topic_test

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful, running test..."
    ./topic_test
    rm -f topic_test
else
    echo "❌ Compilation failed"
    exit 1
fi
