@echo off

set NAME=sound

@del *.o
@del *.nes

echo.
echo Compiling...

ca65 %NAME%.s -o %NAME%.o

IF ERRORLEVEL 1 GOTO failure
echo.
echo Linking...
ld65 -o sound.nes -C nes.cfg %NAME%.o 
IF ERRORLEVEL 1 GOTO failure

echo Success!
GOTO endbuild
:failure
@echo.
@echo Build error!
:endbuild
