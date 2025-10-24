#!/bin/bash

echo "🧪 Running MJPEG Stream Test"
echo "=============================="

# Change to the project directory
cd /Users/timflack/git/f3/visionOS/ROSNavigator

# Compile and run the test
swiftc -framework Foundation ROSNavigator/MJPEGStreamTest.swift -o mjpeg_test

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful, running test..."
    ./mjpeg_test
    rm -f mjpeg_test
else
    echo "❌ Compilation failed"
    exit 1
fi
