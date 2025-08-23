#!/usr/bin/bash 


echo "compile docgen ..."
# dart run ./bin/docgen1.dart 
# dart run ./bin/docgen2.dart 
# dart run ./bin/docgen3.dart 
# dart run ./bin/docgen4.dart 
# dart run ./bin/docgen5.dart 
dart run ./bin/docgen6.dart 

echo "serve docgen ..."
../www/bin/www.exe --html-path=./public/index.html
