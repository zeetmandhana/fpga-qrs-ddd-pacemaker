@echo off
REM ============================================================================
REM  HW/SW benchmark firmware for the board's NEORV32 configuration.
REM  Same toolchain and flags as rtl\firmware\build_p17_fw.bat
REM  (rv32i_zicsr_zifencei / ilp32 / -Os, no M extension), NEORV32 v1.13.2.
REM  hwsw_bench.c + NEORV32 runtime -> build\main.elf -> build\neorv32_imem_image.vhd
REM ============================================================================
setlocal enabledelayedexpansion
set "RVBIN=C:\Users\Zeet Mandhana\AppData\Roaming\xpack-riscv-none-elf-gcc-15.2.0-1\bin"
set "CC=%RVBIN%\riscv-none-elf-gcc.exe"
set "OBJCOPY=%RVBIN%\riscv-none-elf-objcopy.exe"
set "OBJDUMP=%RVBIN%\riscv-none-elf-objdump.exe"
set "SIZE=%RVBIN%\riscv-none-elf-size.exe"
set "NEO=C:\NEORV32\neorv32"
set "COM=%NEO%\sw\common"
set "LIBSRC=%NEO%\sw\lib\source"
set "LIBINC=%NEO%\sw\lib\include"
set "IMGGEN=%NEO%\sw\image_gen\image_gen.exe"
set "HERE=%~dp0"
set "BUILD=%HERE%build"
if exist "%BUILD%" rmdir /s /q "%BUILD%"
mkdir "%BUILD%"

set "MARCH=rv32i_zicsr_zifencei"
set "MABI=ilp32"
set "CCFLAGS=-march=%MARCH% -mabi=%MABI% -Os -Wall -Wextra -ffunction-sections -fdata-sections -mno-fdiv -mstrict-align -mbranch-cost=10 -ffp-contract=off -g"
set "INCS=-I %LIBINC% -I %HERE%."
set "LDFLAGS=-march=%MARCH% -mabi=%MABI% -nostartfiles -Wl,--gc-sections"
set "LDDEFS=-Wl,--defsym,__neorv32_rom_size=16k -Wl,--defsym,__neorv32_ram_size=8k"

"%CC%" -c %CCFLAGS% -I %LIBINC% "%COM%\crt0.S" -o "%BUILD%\crt0.S.o"
if errorlevel 1 ( echo CRT0 COMPILE FAILED & exit /b 1 )
for %%F in ("%LIBSRC%\*.c") do (
    "%CC%" -c %CCFLAGS% %INCS% "%%F" -o "%BUILD%\%%~nF.c.o"
    if errorlevel 1 ( echo LIB COMPILE FAILED: %%~nxF & exit /b 1 )
)
"%CC%" -c %CCFLAGS% %INCS% "%HERE%hwsw_bench.c" -o "%BUILD%\hwsw_bench.c.o"
if errorlevel 1 ( echo BENCH COMPILE FAILED & exit /b 1 )

set "OBJS="
for %%O in ("%BUILD%\*.o") do set "OBJS=!OBJS! "%%O""
"%CC%" %LDFLAGS% %LDDEFS% -T "%COM%\neorv32.ld" !OBJS! -lm -lc -lgcc -o "%BUILD%\main.elf"
if errorlevel 1 ( echo LINK FAILED & exit /b 1 )
"%SIZE%" "%BUILD%\main.elf"
"%OBJCOPY%" -O binary "%BUILD%\main.elf" "%BUILD%\main.bin"
"%IMGGEN%" -t vhd -i "%BUILD%\main.bin" -o "%BUILD%\neorv32_imem_image.vhd"
if errorlevel 1 ( echo IMAGE_GEN FAILED & exit /b 1 )
"%OBJDUMP%" -d "%BUILD%\main.elf" > "%BUILD%\main.asm"
echo FIRMWARE BUILD OK: %BUILD%\neorv32_imem_image.vhd
endlocal
