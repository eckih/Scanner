@echo off
echo Starte Krypto Scanner Rails App...

echo.
echo Installiere Ruby Gems...
call bundle install

echo.
echo Erstelle Datenbank...
call bundle exec rails db:create

echo.
echo Führe Migrationen aus...
call bundle exec rails db:migrate

echo.
echo Starte Rails Server...
echo Die App wird unter http://localhost:3000 verfügbar sein
echo Drücken Sie Ctrl+C zum Beenden
call bundle exec rails server

pause 