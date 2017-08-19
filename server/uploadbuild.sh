VERSION=${1:-"1"}

aws gamelift upload-build --operating-system AMAZON_LINUX --build-root out --name BroadsockGamelift --build-version $VERSION --region eu-central-1
