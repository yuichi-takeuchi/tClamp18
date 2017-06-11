#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Stimulator Protocol Template
Menu "tClamp18"
	SubMenu "Stimulator Protocol"
"any name", tClampSetStim()
	End
End

Function tClampSetStim()
	tClamp18_FolderCheck()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp18

	Variable/G StimulatorCheck = 1

	Variable/G StimulatorCounterLimit = 0
	Variable/G StimulatorISI = 600
	Variable/G StimulatorITC18Period = 4
	Variable/G StimulatorSamplingNpnts = 200000

	Variable/G StimulatorDelay0 = 0
	Variable/G StimulatorInterval0 = 0
	Variable/G StimulatorTrain0 = 0
	Variable/G StimulatorDuration0 = 0

	Variable/G StimulatorDelay1 = 0
	Variable/G StimulatorInterval1 = 0
	Variable/G StimulatorTrain1 = 0
	Variable/G StimulatorDuration1 = 0

	Variable/G StimulatorDelay2 = 0
	Variable/G StimulatorInterval2 = 0
	Variable/G StimulatorTrain2 = 0
	Variable/G StimulatorDuration2 = 0

	Variable/G StimulatorDelay3 = 0
	Variable/G StimulatorInterval3 = 0
	Variable/G StimulatorTrain3 = 0
	Variable/G StimulatorDuration3 = 0

	tClamp18ApplyStimulatorSetting()

	SetDataFolder fldrSav0
End

