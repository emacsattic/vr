# Microsoft Developer Studio Generated NMAKE File, Based on vr.dsp
!IF "$(CFG)" == ""
CFG=vr - Win32 Debug
!MESSAGE No configuration specified. Defaulting to vr - Win32 Debug.
!ENDIF 

!IF "$(CFG)" != "vr - Win32 Release" && "$(CFG)" != "vr - Win32 Debug"
!MESSAGE Invalid configuration "$(CFG)" specified.
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "vr.mak" CFG="vr - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "vr - Win32 Release" (based on "Win32 (x86) Application")
!MESSAGE "vr - Win32 Debug" (based on "Win32 (x86) Application")
!MESSAGE 
!ERROR An invalid configuration is specified.
!ENDIF 

!IF "$(OS)" == "Windows_NT"
NULL=
!ELSE 
NULL=nul
!ENDIF 

CPP=cl.exe
MTL=midl.exe
RSC=rc.exe

!IF  "$(CFG)" == "vr - Win32 Release"

OUTDIR=.\Release
INTDIR=.\Release
# Begin Custom Macros
OutDir=.\Release
# End Custom Macros

!IF "$(RECURSE)" == "0" 

ALL : "$(OUTDIR)\vr.exe"

!ELSE 

ALL : "hook - Win32 Release" "$(OUTDIR)\vr.exe"

!ENDIF 

!IF "$(RECURSE)" == "1" 
CLEAN :"hook - Win32 ReleaseCLEAN" 
!ELSE 
CLEAN :
!ENDIF 
	-@erase "$(INTDIR)\buffer.obj"
	-@erase "$(INTDIR)\Client.obj"
	-@erase "$(INTDIR)\DictSink.obj"
	-@erase "$(INTDIR)\EngSink.obj"
	-@erase "$(INTDIR)\IO.obj"
	-@erase "$(INTDIR)\main.obj"
	-@erase "$(INTDIR)\micsink.obj"
	-@erase "$(INTDIR)\vc50.idb"
	-@erase "$(INTDIR)\VCmdSink.obj"
	-@erase "$(INTDIR)\vr.res"
	-@erase "$(OUTDIR)\vr.exe"

"$(OUTDIR)" :
    if not exist "$(OUTDIR)/$(NULL)" mkdir "$(OUTDIR)"

CPP_PROJ=/nologo /MT /W3 /GX /O2 /I "." /D "WIN32" /D "NDEBUG" /D "_WINDOWS"\
 /Fp"$(INTDIR)\vr.pch" /YX /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\" /FD /c 
CPP_OBJS=.\Release/
CPP_SBRS=.
MTL_PROJ=/nologo /D "NDEBUG" /mktyplib203 /o NUL /win32 
RSC_PROJ=/l 0x409 /fo"$(INTDIR)\vr.res" /d "NDEBUG" 
BSC32=bscmake.exe
BSC32_FLAGS=/nologo /o"$(OUTDIR)\vr.bsc" 
BSC32_SBRS= \
	
LINK32=link.exe
LINK32_FLAGS=Debug/hook.lib winsock.lib kernel32.lib user32.lib gdi32.lib\
 winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib\
 uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /incremental:no\
 /pdb:"$(OUTDIR)\vr.pdb" /machine:I386 /out:"$(OUTDIR)\vr.exe" 
LINK32_OBJS= \
	"$(INTDIR)\buffer.obj" \
	"$(INTDIR)\Client.obj" \
	"$(INTDIR)\DictSink.obj" \
	"$(INTDIR)\EngSink.obj" \
	"$(INTDIR)\IO.obj" \
	"$(INTDIR)\main.obj" \
	"$(INTDIR)\micsink.obj" \
	"$(INTDIR)\VCmdSink.obj" \
	"$(INTDIR)\vr.res" \
	"$(OUTDIR)\hook.lib"

"$(OUTDIR)\vr.exe" : "$(OUTDIR)" $(DEF_FILE) $(LINK32_OBJS)
    $(LINK32) @<<
  $(LINK32_FLAGS) $(LINK32_OBJS)
<<

!ELSEIF  "$(CFG)" == "vr - Win32 Debug"

OUTDIR=.\Debug
INTDIR=.\Debug
# Begin Custom Macros
OutDir=.\Debug
# End Custom Macros

!IF "$(RECURSE)" == "0" 

ALL : "$(OUTDIR)\vr.exe" "$(OUTDIR)\vr.bsc"

!ELSE 

ALL : "hook - Win32 Debug" "$(OUTDIR)\vr.exe" "$(OUTDIR)\vr.bsc"

!ENDIF 

!IF "$(RECURSE)" == "1" 
CLEAN :"hook - Win32 DebugCLEAN" 
!ELSE 
CLEAN :
!ENDIF 
	-@erase "$(INTDIR)\buffer.obj"
	-@erase "$(INTDIR)\buffer.sbr"
	-@erase "$(INTDIR)\Client.obj"
	-@erase "$(INTDIR)\Client.sbr"
	-@erase "$(INTDIR)\DictSink.obj"
	-@erase "$(INTDIR)\DictSink.sbr"
	-@erase "$(INTDIR)\EngSink.obj"
	-@erase "$(INTDIR)\EngSink.sbr"
	-@erase "$(INTDIR)\IO.obj"
	-@erase "$(INTDIR)\IO.sbr"
	-@erase "$(INTDIR)\main.obj"
	-@erase "$(INTDIR)\main.sbr"
	-@erase "$(INTDIR)\micsink.obj"
	-@erase "$(INTDIR)\micsink.sbr"
	-@erase "$(INTDIR)\vc50.idb"
	-@erase "$(INTDIR)\vc50.pdb"
	-@erase "$(INTDIR)\VCmdSink.obj"
	-@erase "$(INTDIR)\VCmdSink.sbr"
	-@erase "$(INTDIR)\vr.res"
	-@erase "$(OUTDIR)\vr.bsc"
	-@erase "$(OUTDIR)\vr.exe"
	-@erase "$(OUTDIR)\vr.ilk"
	-@erase "$(OUTDIR)\vr.pdb"

"$(OUTDIR)" :
    if not exist "$(OUTDIR)/$(NULL)" mkdir "$(OUTDIR)"

CPP_PROJ=/nologo /MT /W3 /Gm /GX /Zi /Od /I "." /D "WIN32" /D "_DEBUG" /D\
 "_WINDOWS" /FR"$(INTDIR)\\" /Fp"$(INTDIR)\vr.pch" /YX /Fo"$(INTDIR)\\"\
 /Fd"$(INTDIR)\\" /FD /c 
CPP_OBJS=.\Debug/
CPP_SBRS=.\Debug/
MTL_PROJ=/nologo /D "_DEBUG" /mktyplib203 /o NUL /win32 
RSC_PROJ=/l 0x409 /fo"$(INTDIR)\vr.res" /d "_DEBUG" 
BSC32=bscmake.exe
BSC32_FLAGS=/nologo /o"$(OUTDIR)\vr.bsc" 
BSC32_SBRS= \
	"$(INTDIR)\buffer.sbr" \
	"$(INTDIR)\Client.sbr" \
	"$(INTDIR)\DictSink.sbr" \
	"$(INTDIR)\EngSink.sbr" \
	"$(INTDIR)\IO.sbr" \
	"$(INTDIR)\main.sbr" \
	"$(INTDIR)\micsink.sbr" \
	"$(INTDIR)\VCmdSink.sbr"

"$(OUTDIR)\vr.bsc" : "$(OUTDIR)" $(BSC32_SBRS)
    $(BSC32) @<<
  $(BSC32_FLAGS) $(BSC32_SBRS)
<<

LINK32=link.exe
LINK32_FLAGS=Debug/hook.lib wsock32.lib kernel32.lib user32.lib gdi32.lib\
 winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib\
 uuid.lib odbc32.lib odbccp32.lib /nologo /subsystem:windows /incremental:yes\
 /pdb:"$(OUTDIR)\vr.pdb" /debug /machine:I386 /out:"$(OUTDIR)\vr.exe"\
 /pdbtype:sept 
LINK32_OBJS= \
	"$(INTDIR)\buffer.obj" \
	"$(INTDIR)\Client.obj" \
	"$(INTDIR)\DictSink.obj" \
	"$(INTDIR)\EngSink.obj" \
	"$(INTDIR)\IO.obj" \
	"$(INTDIR)\main.obj" \
	"$(INTDIR)\micsink.obj" \
	"$(INTDIR)\VCmdSink.obj" \
	"$(INTDIR)\vr.res" \
	"$(OUTDIR)\hook.lib"

"$(OUTDIR)\vr.exe" : "$(OUTDIR)" $(DEF_FILE) $(LINK32_OBJS)
    $(LINK32) @<<
  $(LINK32_FLAGS) $(LINK32_OBJS)
<<

!ENDIF 

.c{$(CPP_OBJS)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cpp{$(CPP_OBJS)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cxx{$(CPP_OBJS)}.obj::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.c{$(CPP_SBRS)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cpp{$(CPP_SBRS)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<

.cxx{$(CPP_SBRS)}.sbr::
   $(CPP) @<<
   $(CPP_PROJ) $< 
<<


!IF "$(CFG)" == "vr - Win32 Release" || "$(CFG)" == "vr - Win32 Debug"

!IF  "$(CFG)" == "vr - Win32 Release"

"hook - Win32 Release" : 
   cd "."
   $(MAKE) /$(MAKEFLAGS) /F .\hook.mak CFG="hook - Win32 Release" 
   cd "."

"hook - Win32 ReleaseCLEAN" : 
   cd "."
   $(MAKE) /$(MAKEFLAGS) CLEAN /F .\hook.mak CFG="hook - Win32 Release"\
 RECURSE=1 
   cd "."

!ELSEIF  "$(CFG)" == "vr - Win32 Debug"

"hook - Win32 Debug" : 
   cd "."
   $(MAKE) /$(MAKEFLAGS) /F .\hook.mak CFG="hook - Win32 Debug" 
   cd "."

"hook - Win32 DebugCLEAN" : 
   cd "."
   $(MAKE) /$(MAKEFLAGS) CLEAN /F .\hook.mak CFG="hook - Win32 Debug" RECURSE=1\
 
   cd "."

!ENDIF 

SOURCE=.\buffer.cpp

!IF  "$(CFG)" == "vr - Win32 Release"

DEP_CPP_BUFFE=\
	".\Client.h"\
	".\DictSink.h"\
	".\dnssdk.h"\
	".\IO.h"\
	".\micsink.h"\
	".\speech.h"\
	".\VCmdSink.h"\
	".\vr.h"\
	

"$(INTDIR)\buffer.obj" : $(SOURCE) $(DEP_CPP_BUFFE) "$(INTDIR)"


!ELSEIF  "$(CFG)" == "vr - Win32 Debug"

DEP_CPP_BUFFE=\
	".\Client.h"\
	".\DictSink.h"\
	".\dnssdk.h"\
	".\IO.h"\
	".\micsink.h"\
	".\speech.h"\
	".\VCmdSink.h"\
	".\vr.h"\
	

"$(INTDIR)\buffer.obj"	"$(INTDIR)\buffer.sbr" : $(SOURCE) $(DEP_CPP_BUFFE)\
 "$(INTDIR)"


!ENDIF 

SOURCE=.\Client.cpp

!IF  "$(CFG)" == "vr - Win32 Release"

DEP_CPP_CLIEN=\
	".\Client.h"\
	".\DictSink.h"\
	".\dnssdk.h"\
	".\IO.h"\
	".\speech.h"\
	".\VCmdSink.h"\
	".\vr.h"\
	

"$(INTDIR)\Client.obj" : $(SOURCE) $(DEP_CPP_CLIEN) "$(INTDIR)"


!ELSEIF  "$(CFG)" == "vr - Win32 Debug"

DEP_CPP_CLIEN=\
	".\Client.h"\
	".\DictSink.h"\
	".\dnssdk.h"\
	".\IO.h"\
	".\speech.h"\
	".\VCmdSink.h"\
	".\vr.h"\
	

"$(INTDIR)\Client.obj"	"$(INTDIR)\Client.sbr" : $(SOURCE) $(DEP_CPP_CLIEN)\
 "$(INTDIR)"


!ENDIF 

SOURCE=.\DictSink.cpp

!IF  "$(CFG)" == "vr - Win32 Release"

DEP_CPP_DICTS=\
	".\Client.h"\
	".\DictSink.h"\
	".\dnssdk.h"\
	".\IO.h"\
	".\micsink.h"\
	".\speech.h"\
	".\VCmdSink.h"\
	".\vr.h"\
	

"$(INTDIR)\DictSink.obj" : $(SOURCE) $(DEP_CPP_DICTS) "$(INTDIR)"


!ELSEIF  "$(CFG)" == "vr - Win32 Debug"

DEP_CPP_DICTS=\
	".\Client.h"\
	".\DictSink.h"\
	".\dnssdk.h"\
	".\IO.h"\
	".\micsink.h"\
	".\speech.h"\
	".\VCmdSink.h"\
	".\vr.h"\
	

"$(INTDIR)\DictSink.obj"	"$(INTDIR)\DictSink.sbr" : $(SOURCE) $(DEP_CPP_DICTS)\
 "$(INTDIR)"


!ENDIF 

SOURCE=.\EngSink.cpp

!IF  "$(CFG)" == "vr - Win32 Release"

DEP_CPP_ENGSI=\
	".\dnssdk.h"\
	".\EngSink.h"\
	".\speech.h"\
	".\vr.h"\
	

"$(INTDIR)\EngSink.obj" : $(SOURCE) $(DEP_CPP_ENGSI) "$(INTDIR)"


!ELSEIF  "$(CFG)" == "vr - Win32 Debug"

DEP_CPP_ENGSI=\
	".\dnssdk.h"\
	".\EngSink.h"\
	".\speech.h"\
	".\vr.h"\
	

"$(INTDIR)\EngSink.obj"	"$(INTDIR)\EngSink.sbr" : $(SOURCE) $(DEP_CPP_ENGSI)\
 "$(INTDIR)"


!ENDIF 

SOURCE=.\IO.cpp

!IF  "$(CFG)" == "vr - Win32 Release"

DEP_CPP_IO_CP=\
	".\Client.h"\
	".\DictSink.h"\
	".\dnssdk.h"\
	".\IO.h"\
	".\micsink.h"\
	".\speech.h"\
	".\VCmdSink.h"\
	".\vr.h"\
	

"$(INTDIR)\IO.obj" : $(SOURCE) $(DEP_CPP_IO_CP) "$(INTDIR)"


!ELSEIF  "$(CFG)" == "vr - Win32 Debug"

DEP_CPP_IO_CP=\
	".\Client.h"\
	".\DictSink.h"\
	".\dnssdk.h"\
	".\IO.h"\
	".\micsink.h"\
	".\speech.h"\
	".\VCmdSink.h"\
	".\vr.h"\
	

"$(INTDIR)\IO.obj"	"$(INTDIR)\IO.sbr" : $(SOURCE) $(DEP_CPP_IO_CP) "$(INTDIR)"


!ENDIF 

SOURCE=.\main.cpp

!IF  "$(CFG)" == "vr - Win32 Release"

DEP_CPP_MAIN_=\
	".\Client.h"\
	".\DictSink.h"\
	".\dnssdk.h"\
	".\EngSink.h"\
	".\hook.h"\
	".\IO.h"\
	".\micsink.h"\
	".\speech.h"\
	".\VCmdSink.h"\
	".\vr.h"\
	

"$(INTDIR)\main.obj" : $(SOURCE) $(DEP_CPP_MAIN_) "$(INTDIR)"


!ELSEIF  "$(CFG)" == "vr - Win32 Debug"

DEP_CPP_MAIN_=\
	".\Client.h"\
	".\DictSink.h"\
	".\dnssdk.h"\
	".\EngSink.h"\
	".\hook.h"\
	".\IO.h"\
	".\micsink.h"\
	".\speech.h"\
	".\VCmdSink.h"\
	".\vr.h"\
	

"$(INTDIR)\main.obj"	"$(INTDIR)\main.sbr" : $(SOURCE) $(DEP_CPP_MAIN_)\
 "$(INTDIR)"


!ENDIF 

SOURCE=.\micsink.cpp

!IF  "$(CFG)" == "vr - Win32 Release"

DEP_CPP_MICSI=\
	".\Client.h"\
	".\dnssdk.h"\
	".\IO.h"\
	".\micsink.h"\
	".\speech.h"\
	

"$(INTDIR)\micsink.obj" : $(SOURCE) $(DEP_CPP_MICSI) "$(INTDIR)"


!ELSEIF  "$(CFG)" == "vr - Win32 Debug"

DEP_CPP_MICSI=\
	".\Client.h"\
	".\dnssdk.h"\
	".\IO.h"\
	".\micsink.h"\
	".\speech.h"\
	

"$(INTDIR)\micsink.obj"	"$(INTDIR)\micsink.sbr" : $(SOURCE) $(DEP_CPP_MICSI)\
 "$(INTDIR)"


!ENDIF 

SOURCE=.\VCmdSink.cpp

!IF  "$(CFG)" == "vr - Win32 Release"

DEP_CPP_VCMDS=\
	".\Client.h"\
	".\dnssdk.h"\
	".\IO.h"\
	".\speech.h"\
	".\VCmdSink.h"\
	".\vr.h"\
	

"$(INTDIR)\VCmdSink.obj" : $(SOURCE) $(DEP_CPP_VCMDS) "$(INTDIR)"


!ELSEIF  "$(CFG)" == "vr - Win32 Debug"

DEP_CPP_VCMDS=\
	".\Client.h"\
	".\dnssdk.h"\
	".\IO.h"\
	".\speech.h"\
	".\VCmdSink.h"\
	".\vr.h"\
	

"$(INTDIR)\VCmdSink.obj"	"$(INTDIR)\VCmdSink.sbr" : $(SOURCE) $(DEP_CPP_VCMDS)\
 "$(INTDIR)"


!ENDIF 

SOURCE=.\vr.rc

"$(INTDIR)\vr.res" : $(SOURCE) "$(INTDIR)"
	$(RSC) $(RSC_PROJ) $(SOURCE)



!ENDIF 

