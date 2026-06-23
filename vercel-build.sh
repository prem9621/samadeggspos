#!/bin/bash
git clone -b stable --depth 1 https://github.com/flutter/flutter.git /tmp/flutter
export PATH="$PATH:/tmp/flutter/bin"
flutter config --enable-web
flutter pub get
flutter build web --release --base-href "/"
