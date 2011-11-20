Enumeration
	#Main_Window
	#Main_Text
	#Main_CompareList
	#Main_CreateList
	#Main_CheckUpdates
	#Module_CompareList_Window
	#Module_CompareList_CurrentFile
	#Module_CompareList_FileList
	#Module_CreateList_Window
	#Module_CreateList_CurrentFile
	#Module_CreateList_FileList
EndEnumeration

#Title="Directory Checksum"


;- General functions
Procedure GetParameter(sName$)
	For lIndex = 0 To CountProgramParameters() - 1
		If LCase(ProgramParameter(lIndex)) = "/" + LCase(sName$)
			ProcedureReturn #True
		EndIf
	Next
EndProcedure


;- Subthreads
Procedure SubThread_CompareList(lFile1, lFile2)
	FileSeek(lFile1, 0)
	Repeat
		sLine1$ = ReadString(lFile1)
		sFile1$ = StringField(sLine1$, 1, Chr(9))
		sMD51$ = StringField(sLine1$, 2, Chr(9))
		If sFile1$ And sMD51$
			SetGadgetText(#Module_CompareList_CurrentFile, sFile1$)
			FileSeek(lFile2, 0)
			Repeat
				sLine2$ = ReadString(lFile2)
				sFile2$ = StringField(sLine2$, 1, Chr(9))
				sMD52$ = StringField(sLine2$, 2, Chr(9))
				If LCase(sFile1$) = LCase(sFile2$)
					If LCase(sMD51$) <> LCase(sMD52$)
						AddGadgetItem(#Module_CompareList_FileList, -1, sFile1$ + Chr(10) + sMD51$ + Chr(10) + sMD52$)
					EndIf
					Break
				EndIf
			Until Eof(lFile2)
		EndIf
	Until Eof(lFile1)
EndProcedure

Procedure SubThread_CreateList(sFullPath$, sRootPath$)
	lDir = ExamineDirectory(#PB_Any, sFullPath$, "*.*")
	If IsDirectory(ldir)
		While NextDirectoryEntry(lDir)
			sName$ = DirectoryEntryName(lDir)
			If sName$ <> "." And sName$ <> ".."
				Select DirectoryEntryType(lDir)
					Case #PB_DirectoryEntry_Directory
						SubThread_CreateList(sFullPath$ + sName$ + "\", sRootPath$ + sName$ + "\")
					Case #PB_DirectoryEntry_File
						sMD5$ = MD5FileFingerprint(sFullPath$ + sName$)
						If sMD5$
							SetGadgetText(#Module_CreateList_CurrentFile, sRootPath$ + sName$)
							AddGadgetItem(#Module_CreateList_FileList, -1, sRootPath$ + sName$ + Chr(10) + sMD5$)
						EndIf
				EndSelect
			EndIf
		Wend
		FinishDirectory(lDir)
	EndIf
EndProcedure


;- Threads
Procedure Thread_CompareList(*mData)
	lFile1 = Val(StringField(PeekS(*mData), 1, Chr(9)))
	lFile2 = Val(StringField(PeekS(*mData), 2, Chr(9)))
	If IsFile(lFile1) And IsFile(lFile2)
		SubThread_CompareList(lFile1, lFile2)
	EndIf
EndProcedure

Procedure Thread_CreateList(*mPath)
	SubThread_CreateList(PeekS(*mPath), "")
EndProcedure


;- Module parts
Procedure ModulePart_CreateList_SelectSaveFile(sPath$)
	sFile$ = SaveFileRequester("Save MD5 checksum list", RTrim(GetFilePart(RTrim(RTrim(sPath$, "\"), "/")), ":") + ".md5", "MD5 checksum list|*.md5", 0)
	If sFile$
		If Right(sFile$, 4) <> ".md5"
			sFile$ + ".md5"
		EndIf
		lFile = ReadFile(#PB_Any, sFile$)
		If IsFile(lFile)
			CloseFile(lFile)
			bWrite.b = MessageRequester(#Title, "The file already exists!" +Chr(13) + "Do you want to overwrite it?" + Chr(13) + Chr(13) + "File: " + sFile$, #MB_YESNO | #MB_ICONWARNING)
		Else
			bWrite.b = #PB_MessageRequester_Yes
		EndIf
		If bWrite = #PB_MessageRequester_Yes
			If MessageRequester(#Title, "The program will now write the MD5 checksumes of the selected source directory to the selected file." + Chr(13) + "This progress may take a while!" + Chr(13) + Chr(13) + "Source directory: " + sPath$ + Chr(13) + "Checksum file: " + sFile$ + Chr(13) + Chr(13) + "Are you sure to continue?", #MB_YESNO | #MB_ICONQUESTION) = #PB_MessageRequester_Yes
				If OpenWindow(#Module_CreateList_Window, 100, 100, 800, 500, #Title, #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget | #PB_Window_SizeGadget | #PB_Window_ScreenCentered)
					TextGadget(#Module_CreateList_CurrentFile, 10, 10, WindowWidth(#Module_CreateList_Window) - 20, 20, "")
					ListIconGadget(#Module_CreateList_FileList, 10, 40, WindowWidth(#Module_CreateList_Window) - 20, WindowHeight(#Module_CreateList_Window) - 50, "File", 540, #PB_ListIcon_FullRowSelect)
					AddGadgetColumn(#Module_CreateList_FileList, 1, "MD5 checksum", 210)
					lThreadID = CreateThread(@Thread_CreateList(), @sPath$)
					Repeat
						If lThreadID And Not IsThread(lThreadID)
							lThreadID = 0
							lFile = CreateFile(#PB_Any, sFile$)
							If IsFile(lFile)
								For lItem = 0 To CountGadgetItems(#Module_CreateList_FileList) -1
									WriteStringN(lFile, GetGadgetItemText(#Module_CreateList_FileList, lItem, 0) + Chr(9) + GetGadgetItemText(#Module_CreateList_FileList, lItem, 1))
								Next
								CloseFile(lFile)
								SetGadgetText(#Module_CreateList_CurrentFile, "Progress complete")
								MessageRequester(#Title, "Progress complete!", #MB_ICONINFORMATION)
							Else
								MessageRequester(#Title, "Can not write to file!", #MB_ICONERROR)
							EndIf
						EndIf
						Select WaitWindowEvent(10)
							Case #PB_Event_CloseWindow
								If lThreadID
									If MessageRequester(#Title, "The progress is still running!" + Chr(13) + "Are you sure To terminate it?", #MB_YESNO | #MB_ICONQUESTION) = #PB_MessageRequester_Yes
										KillThread(lThreadID)
										Break
									EndIf
								Else
									Break
								EndIf
							Case #PB_Event_SizeWindow
								ResizeGadget(#Module_CreateList_CurrentFile, #PB_Ignore, #PB_Ignore, WindowWidth(#Module_CreateList_Window) - 20, #PB_Ignore)
								ResizeGadget(#Module_CreateList_FileList, #PB_Ignore, #PB_Ignore, WindowWidth(#Module_CreateList_Window) - 20, WindowHeight(#Module_CreateList_Window) - 50)
						EndSelect
					ForEver
					CloseWindow(#Module_CreateList_Window)
				EndIf
			EndIf
		Else
			ModulePart_CreateList_SelectSaveFile(sPath$)
		EndIf
	EndIf
EndProcedure


;- Modules
Procedure Module_CheckUpdates()
	sTempFile$ = GetTemporaryDirectory() + "DirectoryChecksum.update"
	If ReceiveHTTPFile("http://updates.selfcoders.com/getupdate.php?project=directorychecksum", sTempFile$)
		lFile = ReadFile(#PB_Any, sTempFile$)
		If IsFile(lFile)
			If Val(ReadString(lFile)) > #PB_Editor_CompileCount
				If MessageRequester(#Title, "An update is available!" + Chr(13) + Chr(13) + "Do you want to download it now?", #MB_ICONQUESTION | #MB_YESNO) = #PB_MessageRequester_Yes
					sUpdateFile$ = GetPathPart(ProgramFilename()) + ReplaceString(GetFilePart(ProgramFilename()), ".exe", "_Update.exe", #PB_String_NoCase)
					If ReceiveHTTPFile(ReadString(lFile), sUpdateFile$)
						RunProgram(sUpdateFile$, "/update1", GetPathPart(sUpdateFile$))
						End
					Else
						MessageRequester(#Title, "Download failed!" + Chr(13) + Chr(13) + "Please look on selfcoders.com for a current version.", #MB_ICONERROR)
					EndIf
				EndIf
			Else
				MessageRequester(#Title, "You already have the newest version!", #MB_ICONINFORMATION)
			EndIf
			CloseFile(lFile)
		EndIf
	Else
		MessageRequester(#Title, "Update check failed!", #MB_ICONERROR)
	EndIf
EndProcedure

Procedure Module_CreateList()
	sPath$ = PathRequester("Select the folder to get the MD5 checksums.", "")
	If sPath$
		ModulePart_CreateList_SelectSaveFile(sPath$)
	EndIf
EndProcedure

Procedure Module_CompareList()
	sFile1$ = OpenFileRequester("Open first file list", "List1.md5", "MD5 checksum list|*.md5", 0)
	If sFile1$
		lFile1 = ReadFile(#PB_Any, sFile1$)
		If IsFile(lFile1)
			sFile2$ = OpenFileRequester("Open second file list", "List2.md5", "MD5 checksum list|*.md5", 0)
			If sFile2$
				lFile2 = ReadFile(#PB_Any, sFile2$)
				If IsFile(lFile2)
					If OpenWindow(#Module_CompareList_Window, 100, 100, 800, 500, #Title, #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget | #PB_Window_SizeGadget | #PB_Window_ScreenCentered)
						TextGadget(#Module_CompareList_CurrentFile, 10, 10, WindowWidth(#Module_CompareList_Window) - 20, 20, "")
						ListIconGadget(#Module_CompareList_FileList, 10, 40, WindowWidth(#Module_CompareList_Window) - 20, WindowHeight(#Module_CompareList_Window) - 50, "File", (WindowWidth(#Module_CompareList_Window) - 20) / 3 - 5, #PB_ListIcon_FullRowSelect)
						AddGadgetColumn(#Module_CompareList_FileList, 1, "List 1", (WindowWidth(#Module_CompareList_Window) - 20) / 3 - 5)
						AddGadgetColumn(#Module_CompareList_FileList, 2, "List 2", (WindowWidth(#Module_CompareList_Window) - 20) / 3 - 5)
						sData$ = Str(lFile1) + Chr(9) + Str(lFile2)
						lThreadID = CreateThread(@Thread_CompareList(), @sData$)
						Repeat
							If lThreadID And Not IsThread(lThreadID)
								lThreadID = 0
								SetGadgetText(#Module_CompareList_CurrentFile, "Progress complete")
								MessageRequester(#Title, "Progress complete!", #MB_ICONINFORMATION)
							EndIf
							Select WaitWindowEvent(10)
								Case #PB_Event_CloseWindow
									If lThreadID
										If MessageRequester(#Title, "The progress is still running!" + Chr(13) + "Are you sure To terminate it?", #MB_YESNO | #MB_ICONQUESTION) = #PB_MessageRequester_Yes
											KillThread(lThreadID)
											Break
										EndIf
									Else
										Break
									EndIf
								Case #PB_Event_SizeWindow
									ResizeGadget(#Module_CompareList_CurrentFile, #PB_Ignore, #PB_Ignore, WindowWidth(#Module_CompareList_Window) - 20, #PB_Ignore)
									ResizeGadget(#Module_CompareList_FileList, #PB_Ignore, #PB_Ignore, WindowWidth(#Module_CompareList_Window) - 20, WindowHeight(#Module_CompareList_Window) - 50)
							EndSelect
						ForEver
						CloseWindow(#Module_CompareList_Window)
					EndIf
					CloseFile(lFile2)
				EndIf
			EndIf
			CloseFile(lFile1)
		EndIf
	EndIf
EndProcedure


;- Main
Procedure Main()
	If OpenWindow(#Main_Window, 100, 100, 300, 190, #Title, #PB_Window_MinimizeGadget | #PB_Window_ScreenCentered)
		TextGadget(#Main_Text, 10, 10, WindowWidth(#Main_Window) - 20, 20, "What do you want to do?")
		ButtonGadget(#Main_CreateList, 10, 50, WindowWidth(#Main_Window) - 20, 30, "Create file list")
		ButtonGadget(#Main_CompareList, 10, 90, WindowWidth(#Main_Window) - 20, 30, "Compare two file lists")
		ButtonGadget(#Main_CheckUpdates, 10, 150, WindowWidth(#Main_Window) - 20, 30, "Check for updates")
		Repeat
			Select WaitWindowEvent()
				Case #PB_Event_CloseWindow
					Break
				Case #PB_Event_Gadget
					lOption = EventGadget()
					Break
			EndSelect
		ForEver
		CloseWindow(#Main_Window)
		If lOption
			Select lOption
				Case #Main_CreateList
					Module_CreateList()
				Case #Main_CompareList
					Module_CompareList()
				Case #Main_CheckUpdates
					Module_CheckUpdates()
			EndSelect
			Main()
		EndIf
	EndIf
EndProcedure

InitNetwork()

If GetParameter("getbuild")
	MessageRequester(#Title, "Current build: " + Str(#PB_Editor_CompileCount), #MB_ICONINFORMATION)
	End
EndIf

If GetParameter("update1")
	Delay(1000)
	sOriginalFile$ = GetPathPart(ProgramFilename()) + ReplaceString(GetFilePart(ProgramFilename()), "_Update.exe", ".exe", #PB_String_NoCase)
	CopyFile(ProgramFilename(), sOriginalFile$)
	RunProgram(sOriginalFile$, "/update2", GetPathPart(sOriginalFile$))
	End
EndIf

If GetParameter("update2")
	Delay(1000)
	DeleteFile(GetPathPart(ProgramFilename()) + ReplaceString(GetFilePart(ProgramFilename()), ".exe", "_Update.exe", #PB_String_NoCase))
	MessageRequester(#Title, "Update OK", #MB_ICONINFORMATION)
	RunProgram(ProgramFilename(), "", GetPathPart(ProgramFilename()))
	End
EndIf

Main()
; IDE Options = PureBasic 4.60 RC 2 (Windows - x86)
; CursorPosition = 129
; FirstLine = 97
; Folding = --
; EnableXP
; UseIcon = Main.ico
; Executable = DirectoryChecksum.exe
; EnableCompileCount = 38
; EnableBuildCount = 14
; EnableExeConstant
; IncludeVersionInfo
; VersionField0 = 1,0,0,0
; VersionField1 = 1,0,0,0
; VersionField2 = SelfCoders
; VersionField3 = Directory Checksum
; VersionField4 = 1.0
; VersionField5 = 1.0
; VersionField6 = Directory Checksum
; VersionField7 = Directory Checksum
; VersionField8 = %EXECUTABLE
; VersionField13 = directorychecksum@selfcoders.com
; VersionField14 = http://www.selfcoders.com
; VersionField15 = VOS_NT_WINDOWS32
; VersionField16 = VFT_APP
; VersionField17 = 0409 English (United States)
; VersionField18 = Build
; VersionField19 = Project Start
; VersionField20 = Compile Time
; VersionField21 = %COMPILECOUNT
; VersionField22 = 2011-10-24
; VersionField23 = %yyyy-%mm-%dd %hh:%ii:%ss