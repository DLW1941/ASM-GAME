#*******************************************************************************
#
#*******************************************************************************
EXE = ..\MagicBoard.exe

OBJ = MagicBoard.obj
RES = MagicBoard.res
ELS = MagicBoard.xml MagicBoard.ico Normal.cur Finger.cur 


LINK_FLAG = /nologo /out:$(EXE) /subsystem:windows
ML_FLAG = /nologo /c /coff /W3


$(EXE) : $(OBJ) $(RES) $(ELS)
    link $(LINK_FLAG) $(OBJ) $(RES)

.asm.obj :
    ml $(ML_FLAG) $<

.rc.res :
    rc $<

.PHONY : clean
clean :
    del *.obj
    del *.res