@echo off
REM ============================================================================
REM  P17 board firmware build for the NEORV32 (no make needed)
REM  p17_main.c + ddd_driver.c + NEORV32 runtime  ->  build\main.elf
REM  -> build\neorv32_imem_image.vhd  (IMEM pre-load, BOOT_MODE_SELECT = 2)
REM ============================================================================
setlocal enabledelayedexpansion
set "RVBIN=C:\Users\Zeet Mandhana\AppData\Roaming\xpack-riscv-none-elf-gcc-15.2.0-1\bin"
set "CC=%RVBIN%\riscv-none-elf-gcc.exe"
set "OBJCOPY=%RVBIN%\riscv-none-elf-objcopy.exe"
set "OBJDUMP=%RVBIN%\riscv-none-elf-objdump.exe"
set "SIZE=%RVBIN%\riscv-none-elf-size.exe"
set "HOSTGCC=C:\AMDDesignTools\2025.2\Vivado\tps\mingw\10.0.0\win64.o\nt\bin\gcc.exe"
set "NEO=C:\NEORV32\neorv32"
set "COM=%NEO%\sw\common"
set "LIBSRC=%NEO%\sw\lib\source"
set "LIBINC=%NEO%\sw\lib\include"
set "EXG=%NEO%\sw\image_gen"
set "HERE=%~dp0"
set "BUILD=%HERE%build"
if exist "%BUILD%" rmdir /s /q "%BUILD%"
mkdir "%BUILD%"

set "MARCH=rv32i_zicsr_zifencei"
set "MABI=ilp32"
set "CCFLAGS=-march=%MARCH% -mabi=%MABI% -Os -Wall -Wextra -ffunction-sections -fdata-sections -mno-fdiv -mstrict-align -mbranch-cost=10 -ffp-contract=off -g -DDDD_NO_MAIN"
set "INCS=-I %LIBINC% -I %HERE%."
set "LDFLAGS=-march=%MARCH% -mabi=%MABI% -nostartfiles -Wl,--gc-sections"
set "LDDEFS=-Wl,--defsym,__neorv32_rom_size=16k -Wl,--defsym,__neorv32_ram_size=8k"

if not exist "%EXG%\image_gen.exe" (
    "%HOSTGCC%" "%EXG%\image_gen.c" -o "%EXG%\image_gen.exe"
    if errorlevel 1 ( echo IMAGE_GEN BUILD FAILED & exit /b 1 )
)

"%CC%" -c %CCFLAGS% -I %LIBINC% "%COM%\crt0.S" -o "%BUILD%\crt0.S.o"
if errorlevel 1 ( echo CRT0 COMPILE FAILED & exit /b 1 )
for %%F in ("%LIBSRC%\*.c") do (
    "%CC%" -c %CCFLAGS% %INCS% "%%F" -o "%BUILD%\%%~nF.c.o"
    if errorlevel 1 ( echo LIB COMPILE FAILED: %%~nxF & exit /b 1 )
)
"%CC%" -c %CCFLAGS% %INCS% "%HERE%ddd_driver.c" -o "%BUILD%\ddd_driver.c.o"
if errorlevel 1 ( echo DDD_DRIVER COMPILE FAILED & exit /b 1 )
"%CC%" -c %CCFLAGS% %INCS% "%HERE%p17_main.c" -o "%BUILD%\p17_main.c.o"
if errorlevel 1 ( echo MAIN COMPILE FAILED & exit /b 1 )

set "OBJS="
for %%O in ("%BUILD%\*.o") do set "OBJS=!OBJS! "%%O""
"%CC%" %LDFLAGS% %LDDEFS% -T "%COM%\neorv32.ld" !OBJS! -lm -lc -lgcc -o "%BUILD%\main.elf"
if errorlevel 1 ( echo LINK FAILED & exit /b 1 )
"%SIZE%" "%BUILD%\main.elf"
"%OBJCOPY%" -O binary "%BUILD%\main.elf" "%BUILD%\main.bin"
"%EXG%\image_gen.exe" -t vhd -i "%BUILD%\main.bin" -o "%BUILD%\neorv32_imem_image.vhd"
if errorlevel 1 ( echo IMAGE_GEN FAILED & exit /b 1 )
"%OBJDUMP%" -d "%BUILD%\main.elf" > "%BUILD%\main.asm"
echo FIRMWARE BUILD OK: %BUILD%\neorv32_imem_image.vhd
endlocal
