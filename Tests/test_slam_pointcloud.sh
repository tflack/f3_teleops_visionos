#!/bin/bash

# Define project and scheme
PROJECT_NAME="ROSNavigator"
SCHEME_NAME="F3ROSTeleops"
TEST_TARGET="ROSNavigatorTests"
DESTINATION="platform=visionOS Simulator,name=Apple Vision Pro"

echo "🔍 Running SLAM and Point Cloud Topic Test"
echo "=========================================="

# Build the test target
xcodebuild -project "${PROJECT_NAME}.xcodeproj" \
           -scheme "${SCHEME_NAME}" \
           -destination "${DESTINATION}" \
           build-for-testing \
           -only-testing "${TEST_TARGET}/SLAMPointCloudTest" \
           -derivedDataPath "./DerivedData" \
           -quiet

if [ $? -ne 0 ]; then
    echo "❌ Build failed. Check Xcode for details."
    exit 1
fi

echo "✅ Compilation successful, running test..."

# Run the test
xcodebuild -project "${PROJECT_NAME}.xcodeproj" \
           -scheme "${SCHEME_NAME}" \
           -destination "${DESTINATION}" \
           test \
           -only-testing "${TEST_TARGET}/SLAMPointCloudTest" \
           -derivedDataPath "./DerivedData"

if [ $? -ne 0 ]; then
    echo "❌ Test failed. Check Xcode for details."
    exit 1
fi

echo "✅ SLAM and Point Cloud Topic Test completed successfully."
