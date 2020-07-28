BASEDIR=$(dirname "$0")

cd $BASEDIR/../packages/state_notifier
dart test
cd ../flutter_state_notifier
flutter test --no-pub