# Microsoft Developer Studio Generated NMAKE File, Based on hook.dsp
!IF "$(CFG)" == ""
CFG=hook - Win32 Debug
!MESSAGE No configuration specified. Defaulting to hook - Win32 Debug.
!ENDIF 

!IF "$(CFG)" != "hook - Win32 Release" && "$(CFG)" != "hook - Win32 Debug"
!MESSAGE Invalid configuration "$(CFG)" specified.
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "hook.mak" CFG="hook - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "hook - Win32 Release" (based on "Win32 (x86) Dynamic-Link Library")
!MESSAGE "hook - Win32 Debug" (based on "Win32 (x86) Dynamic-Link Library")
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

!IF  "$(CFG)" == "hook - Win32 Release"

OUTDIR=.\Release
INTDIR=.\Release
# Begin Custom Macros
OutDir=.\Release
# End Custom Macros

!IF "$(RECURSE)" == "0" 

ALL : "$(OUTDIR)\hook.dll"

!ELSE 

ALL : "$(OUTDIR)\hook.dll"

!ENDIF 

CLEAN :
	-@erase "$(INTDIR)\hook.obj"
	-@erase "$(INTDIR)\vc50.idb"
	-@erase "$(OUTDIR)\hook.dll"
	-@erase "$(OUTDIR)\hook.exp"
	-@erase "$(OUTDIR)\hook.lib"

"$(OUTDIR)" :
    if not exist "$(OUTDIR)/$(NULL)" mkdir "$(OUTDIR)"

CPP_PROJ=/nologo /MT /W3 /GX /O2 /D "NDEBUG" /D "WIN32" /D "_WINDOWS" /D\
 "_EXPORTING" /Fp"$(INTDIR)\hook.pch" /YX /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\" /FD\
 /c 
CPP_OBJS=.\Release/
CPP_SBRS=.
MTL_PROJ=/nologo /D "NDEBUG" /mktyplib203 /o NUL /win32 
BSC32=bscmake.exe
BSC32_FLAGS=/nologo /o"$(OUTDIR)\hook.bsc" 
BSC32_SBRS= \
	
LINK32=link.exe
LINK32_FLAGS=kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib\
 advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib\
 odbccp32.lib /nologo /subsystem:windows /dll /incremental:no\
 /pdb:"$(OUTDIR)\hook.pdb" /machine:I386 /def:".\hook.def"\
 /out:"$(OUTDIR)\hook.dll" /implib:"$(OUTDIR)\hook.lib" 
DEF_FILE= \
	".\hook.def"
LINK32_OBJS= \
	"$(INTDIR)\hook.obj"

"$(OUTDIR)\hook.dll" : "$(OUTDIR)" $(DEF_FILE) $(LINK32_OBJS)
    $(LINK32) @<<
  $(LINK32_FLAGS) $(LINK32_OBJS)
<<

!ELSEIF  "$(CFG)" == "hook - Win32 Debug"

OUTDIR=.\Debug
INTDIR=.\Debug
# Begin Custom Macros
OutDir=.\Debug
# End Custom Macros

!IF "$(RECURSE)" == "0" 

ALL : "$(OUTDIR)\hook.dll"

!ELSE 

ALL : "$(OUTDIR)\hook.dll"

!ENDIF 

CLEAN :
	-@erase "$(INTDIR)\hook.obj"
	-@erase "$(INTDIR)\vc50.idb"
	-@erase "$(INTDIR)\vc50.pdb"
	-@erase "$(OUTDIR)\hook.dll"
	-@erase "$(OUTDIR)\hook.exp"
	-@erase "$(OUTDIR)\hook.ilk"
	-@erase "$(OUTDIR)\hook.lib"
	-@erase "$(OUTDIR)\hook.pdb"

"$(OUTDIR)" :
    if not exist "$(OUTDIR)/$(NULL)" mkdir "$(OUTDIR)"

CPP_PROJ=/nologo /MTd /W3 /Gm /GX /Zi /Od /D "_DEBUG" /D "WIN32" /D "_WINDOWS"\
 /D "_EXPORTING" /Fp"$(INTDIR)\hook.pch" /YX /Fo"$(INTDIR)\\" /Fd"$(INTDIR)\\"\
 /FD /c 
CPP_OBJS=.\Debug/
CPP_SBRS=.
MTL_PROJ=/nologo /D "_DEBUG" /mktyplib203 /o NUL /win32 
BSC32=bscmake.exe
BSC32_FLAGS=/nologo /o"$(OUTDIR)\hook.bsc" 
BSC32_SBRS= \
	
LINK32=link.exe
LINK32_FLAGS=kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib\
 advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib\
 odbccp32.lib /nologo /subsystem:windows /dll /incremental:yes\
 /pdb:"$(OUTDIR)\hook.pdb" /debug /machine:I386 /def:".\hook.def"\
 /out:"$(OUTDIR)\hook.dll" /implib:"$(OUTDIR)\hook.lib" /pdbtype:sept 
DEF_FILE= \
	".\hook.def"
LINK32_OBJS= \
	"$(INTDIR)\hook.obj"

"$(OUTDIR)\hook.dll" : "$(OUTDIR)" $(DEF_FILE) $(LINK32_OBJS)
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


!IF "$(CFG)" == "hook - Win32 Release" || "$(CFG)" == "hook - Win32 Debug"
SOURCE=.\hook.c
DEP_CPP_HOOK_=\
	".\hook.h"\
	

"$(INTDIR)\hook.obj" : $(SOURCE) $(DEP_CPP_HOOK_) "$(INTDIR)"



!ENDIF 

