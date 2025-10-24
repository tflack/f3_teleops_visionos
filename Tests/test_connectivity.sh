#!/bin/bash

echo "🌐 Running Connectivity Test"
echo "=============================="

# Change to the project directory
cd /Users/timflack/git/f3/visionOS/ROSNavigator

# Compile and run the test
swiftc -framework Foundation ROSNavigator/ConnectivityTest.swift -o connectivity_test

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful, running test..."
    ./connectivity_test
    rm -f connectivity_test
else
    echo "❌ Compilation failed"
    exit 1
fi
