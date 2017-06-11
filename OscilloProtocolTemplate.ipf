#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Oscillo Protocol Template
Menu "tClamp18"
	SubMenu "Oscillo Protocols"
"any name of protocol", tClampSetParamProtocolX() // any name of setting protocol
	End
End

Function tClampSetParamProtocolX() 					//any name of setting protocol
	tClamp18_FolderCheck()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp18

	String/G SelectedProtocol = "protocol label X()"	// any name of protocol
	String/G StrITC18SeqDAC = "0"				// must be same length
	String/G StrITC18SeqADC = "0"
	Variable/G RecordingCheckADC0 = 0			//Select recording channels
	Variable/G RecordingCheckADC1 = 0
	Variable/G RecordingCheckADC2 = 0
	Variable/G RecordingCheckADC3 = 0
	Variable/G RecordingCheckADC4 = 0
	Variable/G RecordingCheckADC5 = 0
	Variable/G RecordingCheckADC6 = 0
	Variable/G RecordingCheckADC7 = 0
	Variable/G OscilloCmdPulse0 = 0.25			//Command output
	Variable/G OscilloCmdPulse1 = 0.25
	Variable/G OscilloCmdPulse2 = 0.25
	Variable/G OscilloCmdPulse3 = 0.25
	Variable/G OscilloCmdPulse4 = 0.25
	Variable/G OscilloCmdPulse5 = 0.25
	Variable/G OscilloCmdPulse6 = 0.25
	Variable/G OscilloCmdPulse7 = 0.25
	Variable/G OscilloCounterLimit = 0				//Sweep number
	Variable/G OscilloSamplingNpnts = 1024 			//Number of Sampling Points at each channel
	Variable/G OscilloITC18ExtTrig = 0				//0: off, 1: on
	Variable/G OscilloITC18Output = 1				//0: off, 1: on
	Variable/G OscilloITC18Overflow = 1				//0: 
	Variable/G OscilloITC18Reserved = 1			// Reserved
	Variable/G OscilloITC18Period = 4				// must be between 4 and 65535. Each sampling tick is 1.25 micro sec.

	///////////////////////
	//Protocol-Specific parameters and procedures are here
	///////////////////////

	tClamp18ApplyProtocolSetting()

	SetDataFolder fldrSav0
end

Function tClampAcquisitionProcX() //same as StrAcquisitionProcName and SelectedProtocol
	NVAR bit = root:Packages:tClamp18:RecordingBit

	// Specific global variables here

	Variable i = 0
	For(i = 0; i < 8; i += 1)
		If(bit & 2^i)
			Wave OscilloADC = $("root:Packages:tClamp18:OscilloADC" + Num2str(i))
			NVAR OscilloCmdPulse = $("root:Packages:tClamp18:OscilloCmdPulse" + Num2str(i))		//
			NVAR OscilloCmdOnOff = $("root:Packages:tClamp18:OscilloCmdOnOff" + Num2str(i))		//

			If(OscilloCmdOnOff)
				OscilloADC[0, ] = OscilloCmdPulse	// create DAC output data in volt
				OscilloADC *= 3200										// scale into point
			else
				OscilloADC[0, ] = 0
				OscilloADC *= 3200
			endif
		endif
	endFor

	Wave DigitalOut1 = $"root:Packages:tClamp18:DigitalOut1"	//Output Wave for DigitalOut1
	NVAR StimulatorCheck = root:Packages:tClamp18:StimulatorCheck

	If(StimulatorCheck)
		tClamp18UseStimulator()
	else
//		DigitalOut1 = 0
	endIf
end