#!/bin/bash

echo "🔍 Running ROS2 Topic Discovery Test"
echo "===================================="

# Change to the project directory
cd /Users/timflack/git/f3/visionOS/ROSNavigator

# Compile and run the test
swiftc -framework Foundation Tests/ROS2TopicDiscoveryTest.swift -o ros2_topic_test

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful, running test..."
    ./ros2_topic_test
    rm -f ros2_topic_test
else
    echo "❌ Compilation failed"
    exit 1
fi
