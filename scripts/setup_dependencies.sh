BASEDIR=$(dirname "$0")

cd $BASEDIR/../packages/state_notifier

echo "Installing state_notifier"
dart pub get

cd ../flutter_state_notifier

echo "overriding flutter_state_notifier dependencies"
echo "
dependency_overrides:
  state_notifier:
    path: ../../packages/state_notifier" >> pubspec.yaml

echo "Installing flutter_state_notifier"
flutter pub get