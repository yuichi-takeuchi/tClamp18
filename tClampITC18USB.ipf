#pragma rtGlobals = 1		// Use modern global access method.
#pragma version = 1.0.0	
#pragma IgorVersion = 6.1	//Igor Pro 6.1 or later

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// This procedure (tClamp18) offers a GUI for data acquisition via InstruTECH ITC-18.
// The GUI is optimized for whole-cell patch-clamp recordings but can be used for other purposes.
// The latest version is available at Github (https://github.com/yuichi-takeuchi/tClamp18).
//
// Prerequisites:
// * Igor Pro 6.1 or later
// * InstruTECH ITC-18 and a host interface
// (http://www.heka.com/products/products_main.html#acq_itc18)
// * ITC-18 legacy XOP for Igor Pro 6.x (ITC18_X86_V76.XOP)
// (http://www.heka.com/downloads/downloads_main.html#down_xops)
//
// Author:
// Yuichi Takeuchi PhD
// Department of Physiology, University of Szeged, Hungary
// Email: yuichi-takeuchi@umin.net
// 
// Lisence:
// MIT License
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Menu "tClamp18"
	SubMenu "DAC ADC Settings"
	End
	SubMenu "Oscillo Protocols"
	End
	SubMenu "Stimulator Protocols"
	End
"-"
	SubMenu "Initialize"
		"tClampInitialize", tClamp18Main()
		"InitializeGVs&Waves", tClamp18MainGVsWaves()
		"ITC18Reset", ITC18Reset // The A/D gains will remain at the state they were previously set, if not optinal flag /S is not set.
	End

	SubMenu "Main Control"
		"New Control", tClamp18_MainControlPanel()
		"Display Control", tClamp18_DisplayMain()
		"Hide Control", tClamp18_HideMainControlPanel()
		"Close Control", DoWindow/K tClamp18MainControlPanel
		".ipf",  DisplayProcedure/W= 'tClampITC18USB.ipf' "tClamp18_MainControlPanel"
	End

	SubMenu "Timer"	
		"New Panel", tClamp18_NewTimerPanel()
		"Display Panel", tClamp18_DisplayTimer()
		"Hide Panel", tClamp18_HideTimer()
		"Close Panel", DoWindow/K tClamp18_TimerPanel
		".ipf", DisplayProcedure/W= 'tClampITC18USB.ipf' "tClamp18_TimerPanel"
	End

	SubMenu "tClampITC18USB.ipf"
		"Display Procedure", DisplayProcedure/W= 'tClampITC18USB.ipf'
		"Main", DisplayProcedure/W= 'tClampITC18USB.ipf' "tClamp18_MainControlPanel"
		"DAC", DisplayProcedure/W= 'tClampITC18USB.ipf' "ClampNewDACPanel"
 		"ADC", DisplayProcedure/W= 'tClampITC18USB.ipf' "tClamp18NewADCPanel"
		"Oscillo", DisplayProcedure/W= 'tClampITC18USB.ipf' "tClamp18NewOscilloADC"
		"Seal", DisplayProcedure/W= 'tClampITC18USB.ipf' "tClamp18NewSealTestADC"
		"Timer", DisplayProcedure/W='tClampITC18USB.ipf' "tClamp18_TimerPanel"
	End

	SubMenu "Template"
		"Oscillo Protocol Template", tClamp18OSCProtocolTemplate()
		"Stimulator Protocol Template", tClamp18StimProtocolTemplate()
		"Setting Template", tClamp18SettingTemplate()
	End
	
	"Kill All", tClamp18_KillAllWindows()
"-"
	"Help", tClamp18HelpNote()
End


///////////////////////////////////////////////////////////////////
//Menu

Function tClamp18_FolderCheck()
	If(DataFolderExists("root:Packages:tClamp18"))
		else
			If(DataFolderExists("root:Packages"))
					NewDataFolder root:Packages:tClamp18
				else
					NewDataFolder root:Packages
					NewDataFolder root:Packages:tClamp18
			endif
	endif
End

Function tClamp18Main()
	tClamp18_FolderCheck()
	tClamp18_PrepWaves()
	tClamp18_PrepGVs()	
	tClamp18_MainControlPanel()
	tClamp18_NewTimerPanel()
end

Function tClamp18MainGVsWaves()
	tClamp18_FolderCheck()
	tClamp18_PrepWaves()
	tClamp18_PrepGVs()	
end

Function tClamp18_PrepWaves()
	tClamp18_FolderCheck()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp18
	
	Make/O/n=1024 FIFOout, FIFOin, DigitalOut0, DigitalOut1, DigitalOutSeal0, DigitalOutSeal1
		
	Variable i = 0
	For(i = 0; i <= 7; i += 1)
		Make/O/n=1024 $("SealTestADC" + Num2str(i))
		Make/O/n=1024 $("SealTestPntsADC" + Num2str(i))
		Make/O/n=1024 $("OscilloADC" + Num2str(i))
		Make/O/n=1024 $("ScaledADC" + Num2str(i))
	endFor
	
	SetDataFolder fldrSav0
end

Function tClamp18_PrepGVs()
	tClamp18_FolderCheck()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp18

	String/G StrADCRange = "10;5;2;1"
	String/G SelectedProtocol = "none"
	String/G StrITC18SeqDAC = "0", StrITC18SeqADC = "0", SealITC18SeqDAC = "0", SealITC18SeqADC = "0"
	String/G StrAcquisitionProcName ="tClampAquisitionProcX"
	String/G WaveListTemp = ""

	Variable/G NumTrial = 0
	Variable/G TimeFromTick = ticks/60, ElapsedTime = 0, TimerISITicks = ticks
	Variable/G OscilloFreq = 200000, SealTestFreq = 20000, StimulatorFreq = 200000
	Variable/G DACBit = 0, ADCBit = 0, DigitalOut1Bit = 0, OscilloBit = 0, RecordingBit = 0, SealTestBit = 0
	Variable/G TimerISI = 6, OscilloISI = 600, SealTestISI = 6, StimulatorISI = 600
	Variable/G OscilloCounter = 0, SealTestCounter = 0, StimulatorCounter = 0
	Variable/G OscilloCounterLimit = 0, SealTestCounterLimit = 0, StimulatorCounterLimit = 0
	Variable/G OscilloITC18ExtTrig = 0, OscilloITC18Output = 1, OscilloITC18Overflow = 1, OscilloITC18Reserved = 1, OscilloITC18Flags = 14
	Variable/G OscilloITC18Period = 4, OscilloITC18StrlenSeq = 1, OscilloSamplingNpnts = 1024, OscilloAcqTime = 0.00512
	Variable/G SealITC18Trigout = 0, SealITC18ExtTrig = 0, SealITC18Output = 1, SealITC18Overflow = 1, SealITC18Reserved = 1, SealITC18Flags = 14
	Variable/G SealITC18Period = 4, SealITC18StrlenSeq = 1, SealSamplingNpnts = 1024, SealAcqTime = 0.00512
	Variable/G StimulatorITC18Period = 4, StimulatorSamplingNpnts = 200000, StimulatorAcqTime = 1
	Variable/G StimulatorCheck = 1

	Variable i = 0
	For(i = 0; i <= 7; i +=1)
		Variable/G $("MainCheckADC" + Num2str(i)) = 0
		Variable/G $("OscilloTestCheckADC" + Num2str(i)) = 0
		Variable/G $("OscilloExpand" + Num2str(i)) = 1
		Variable/G $("SealExpand" + Num2str(i)) = 1
		Variable/G $("RecordingCheckADC" + Num2str(i)) = 0
		Variable/G $("SealTestCheckADC" + Num2str(i)) = 0
		Variable/G $("SealTestPulse" + Num2str(i)) = 0.25
		Variable/G $("OscilloCmdPulse" + Num2str(i)) = 0.25
		Variable/G $("OscilloCmdOnOff" + Num2str(i)) = 1
		Variable/G $("PipetteR" + Num2str(i)) = 1
		Variable/G $("ADCMode"+ Num2str(i)) = 0		//0: voltage-clamp, 1:current-clamp
		Variable/G $("ADCValuePoint"+ Num2str(i)) = 0
		Variable/G $("ADCValueVolt"+ Num2str(i)) = 0
		Variable/G $("ADCRange"+ Num2str(i)) = 10
		Variable/G $("InputOffset"+Num2str(i)) = 0
		Variable/G $("ADCOffset"+Num2str(i)) = 0
		Variable/G $("AmpGainADC" + Num2str(i)) = 1
		Variable/G $("ScalingFactorADC" + Num2str(i)) = 1
		Variable/G $("SealCouplingDAC_ADC" + Num2str(i)) = 0
		String/G $("LabelADC" + Num2str(i)) = "ADC" + Num2str(i)
		String/G $("UnitADC" + Num2str(i)) = "A"
		String/G $("AmpGainListADC" + Num2str(i)) = "1;2;5;10;20;50;100;200;500;1000;2000"
		String/G $("CouplingDAC_ADC" + Num2str(i)) = "none"
		String/G $("CouplingADC_ADC" + Num2str(i)) = "none"

		Variable/G $("ADCRangeVC"+ Num2str(i)) = 10
		Variable/G $("AmpGainADCVC" + Num2str(i)) = 1
		Variable/G $("ScalingFactorADCVC" + Num2str(i)) = 1
		String/G $("LabelADCVC" + Num2str(i)) = "ADC" + Num2str(i)
		String/G $("UnitADCVC" + Num2str(i)) = "A"
		String/G $("AmpGainListADCVC" + Num2str(i)) = "1;2;5;10;20;50;100;200;500;1000;2000"
		String/G $("CouplingDAC_ADCVC" + Num2str(i)) = "none"
		String/G $("CouplingADC_ADCVC" + Num2str(i)) = "none"

		Variable/G $("ADCRangeCC"+ Num2str(i)) = 10
		Variable/G $("AmpGainADCCC" + Num2str(i)) = 1
		Variable/G $("ScalingFactorADCCC" + Num2str(i)) = 1
		String/G $("LabelADCCC" + Num2str(i)) = "ADC" + Num2str(i)
		String/G $("UnitADCCC" + Num2str(i)) = "V"
		String/G $("AmpGainListADCCC" + Num2str(i)) = "1;2;5;10;20;50;100;200;500;1000;2000"
		String/G $("CouplingDAC_ADCCC" + Num2str(i)) = "none"
		String/G $("CouplingADC_ADCCC" + Num2str(i)) = "none"
	endFor	
	
	For(i = 0; i <= 3; i +=1)
		Variable/G $("DACValueVolt" + Num2str(i)) = 0
		Variable/G $("MainCheckDAC" + Num2str(i)) = 0
		Variable/G $("CommandSensVC_DAC" + Num2str(i)) = 1
		Variable/G $("CommandSensCC_DAC" + Num2str(i)) = 1
		Variable/G $("DigitalOut1Check" + Num2str(i)) = 0
		Variable/G $("StimulatorDelay" + Num2str(i)) = 0
		Variable/G $("StimulatorInterval"+ Num2str(i)) = 0.01
		Variable/G $("StimulatorTrain"+ Num2str(i)) = 0
		Variable/G $("StimulatorDuration"+ Num2str(i)) = 0.0001
		String/G $("StimulatorTrig"+ Num2str(i)) = "main;"
	endFor
	
	SetDataFolder fldrSav0
end

Function tClamp18_KillAllWindows()
	DoAlert 2, "All tClamp Windows and Parameters are going to be killed. OK?"
	If(V_Flag != 1)
		Abort
	endif
	
	If(WinType("tClamp18MainControlPanel"))
		DoWindow/K tClamp18MainControlPanel
	endIf

	If(WinType("tClamp18_TimerPanel"))
		DoWindow/K tClamp18_TimerPanel
	endIf

	If(WinType("WinSineHertz"))
		DoWindow/K WinSineHertz
	endIf
	
	If(WinType("tClamp18FIFOout"))
		DoWindow/K tClamp18FIFOout
	endIf

	If(WinType("tClamp18FIFOin"))
		DoWindow/K tClamp18FIFOin
	endIf

	If(WinType("tClamp18DigitalOut1"))
		DoWindow/K tClamp18DigitalOut1
	endIf	
	
	Variable i = 0

	For(i = 0; i < 4; i += 1)
		If(WinType("tClamp18DAC" + Num2str(i)))
			DoWindow/K $("tClamp18DAC" + Num2str(i))
		endIf
	endFor
	
	For(i = 0; i < 8; i += 1)
		If(WinType("tClamp18ADC" + Num2str(i)))
			DoWindow/K $("tClamp18ADC" + Num2str(i))
		endIf
		
		If(WinType("tClamp18OscilloADC" + Num2str(i)))
			DoWindow/K $("tClamp18OscilloADC" + Num2str(i))
		endIf
		
		If(WinType("tClamp18SealTestADC" + Num2str(i)))
			DoWindow/K $("tClamp18SealTestADC" + Num2str(i))
		endIf
	endFor
end

Function tClamp18SettingTemplate()
	NewNotebook/F=0
	String strset =""
	strset += "// DAC ADC Setting Template" + "\r"
	strset += "Menu \"tClamp18\""+"\r"
	strset += "	SubMenu \"DAC ADC Settings\""+"\r"
	strset += "\"Setting A\", tClampSettingTemplateA()"+"\r"
	strset += "	End"+"\r"
	strset += "End"+"\r"
	strset += ""+"\r"
	strset += "Function tClampSettingTemplateA()"+"\r"
	strset += "	tClamp18_FolderCheck()" + "\r"
	strset += "	String fldrSav0= GetDataFolder(1)"+"\r"
	strset += "	SetDataFolder root:Packages:tClamp18"+"\r"
	strset += ""+"\r"
	strset += "	//DAC0"+"\r"	
	strset += "	Variable/G CommandSensVC_DAC0 = 1"+"\r"
	strset += "	Variable/G CommandSensCC_DAC0 = 1"+"\r"	
	strset += ""+"\r"
	strset += "	//DAC1"+"\r"	
	strset += "	Variable/G CommandSensVC_DAC1 = 1"+"\r"	
	strset += "	Variable/G CommandSensCC_DAC1 = 1"+"\r"	
	strset += ""+"\r"
	strset += "	//DAC2"+"\r"	
	strset += "	Variable/G CommandSensVC_DAC2 = 1"+"\r"	
	strset += "	Variable/G CommandSensCC_DAC2 = 1	"+"\r"	
	strset += ""+"\r"
	strset += "	//DAC3"+"\r"	
	strset += "	Variable/G CommandSensVC_DAC3 = 1"+"\r"
	strset += "	Variable/G CommandSensCC_DAC3 = 1"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC0"+"\r"	
	strset += "	Variable/G ADCMode0 = 0"+"\r"
	strset += "	Variable/G SealTestPulse0 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC0 VC"+"\r"
	strset += "	Variable/G ADCRangeVC0 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC0 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC0 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC0 = \"ADCVC0\""+"\r"
	strset += "	String/G UnitADCVC0 = \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC0 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC0 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC0 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC0 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC0 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC0 = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC0 = 1"+"\r"
	strset += "	String/G LabelADCCC0 = \"ADC0 CC\""+"\r"	
	strset += "	String/G UnitADCCC0 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC0 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCCC0 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCCC0 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC1"+"\r"	
	strset += "	Variable/G ADCMode1 = 0"+"\r"
	strset += "	Variable/G SealTestPulse1 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC1 VC"+"\r"
	strset += "	Variable/G ADCRangeVC1 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC1 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC1 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC1 = \"ADC1 VC\""+"\r"
	strset += "	String/G UnitADCVC1 = \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC1 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC1 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC1 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC1 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC1 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC1 = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC1 = 1"+"\r"
	strset += "	String/G LabelADCCC1 = \"ADC1 CC\""+"\r"	
	strset += "	String/G UnitADCCC1 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC1 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCCC1 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCCC1 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC2"+"\r"	
	strset += "	Variable/G ADCMode2 = 0"+"\r"
	strset += "	Variable/G SealTestPulse2 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC2 VC"+"\r"
	strset += "	Variable/G ADCRangeVC2 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC2 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC2 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC2 = \"ADC2 VC\""+"\r"
	strset += "	String/G UnitADCVC02= \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC2 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC2 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC2 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC2 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC2 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC2 = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC2 = 1"+"\r"
	strset += "	String/G LabelADCCC2 = \"ADC2 CC\""+"\r"	
	strset += "	String/G UnitADCCC2 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC2 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCCC2 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCCC2 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC3"+"\r"	
	strset += "	Variable/G ADCMode3 = 0"+"\r"
	strset += "	Variable/G SealTestPulse3 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC3 VC"+"\r"
	strset += "	Variable/G ADCRangeVC3 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC3 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC3 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC3 = \"ADC3 VC\""+"\r"
	strset += "	String/G UnitADCVC3 = \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC3 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC3 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC3 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC3 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC3 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC3 = 1"+"\r"
	strset += "	String/G LabelADCCC3 = \"ADC3 CC\""+"\r"	
	strset += "	String/G UnitADCCC3 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC3 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCCC3 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCCC3 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC4"+"\r"	
	strset += "	Variable/G ADCMode4 = 0"+"\r"
	strset += "	Variable/G SealTestPulse4 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC4 VC"+"\r"
	strset += "	Variable/G ADCRangeVC4 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC4 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC4 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC4 = \"ADC4 VC\""+"\r"
	strset += "	String/G UnitADCVC4 = \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC4 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC4 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC4 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC4 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC4 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC4 = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC4 = 1"+"\r"
	strset += "	String/G LabelADCCC4 = \"ADC4 CC\""+"\r"	
	strset += "	String/G UnitADCCC4 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC4 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCCC4 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCCC4 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC5"+"\r"	
	strset += "	Variable/G ADCMode5 = 0"+"\r"
	strset += "	Variable/G SealTestPulse5 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC5 VC"+"\r"
	strset += "	Variable/G ADCRangeVC5 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC5 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC5 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC5 = \"ADC5 VC\""+"\r"
	strset += "	String/G UnitADCVC5 = \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC5 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC5 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC5 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC5 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC5 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC5 = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC5 = 1"+"\r"
	strset += "	String/G LabelADCCC5 = \"ADC5 CC\""+"\r"	
	strset += "	String/G UnitADCCC5 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC5 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCCC5 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCCC5 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC6"+"\r"	
	strset += "	Variable/G ADCMode6 = 0"+"\r"
	strset += "	Variable/G SealTestPulse6 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC6 VC"+"\r"
	strset += "	Variable/G ADCRangeVC6 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC6 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC6 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC6 = \"ADC6 VC\""+"\r"
	strset += "	String/G UnitADCVC6 = \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC6 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC6 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC6 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC6 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC6 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC6 = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC6 = 1"+"\r"
	strset += "	String/G LabelADCCC6 = \"ADC6 CC\""+"\r"	
	strset += "	String/G UnitADCCC6 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC6 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCCC6 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCCC6 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC7"+"\r"	
	strset += "	Variable/G ADCMode7 = 0"+"\r"
	strset += "	Variable/G SealTestPulse7 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC7 VC"+"\r"
	strset += "	Variable/G ADCRangeVC7 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC7 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC7 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC7 = \"ADCVC7\""+"\r"
	strset += "	String/G UnitADCVC7 = \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC7 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC7 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC7 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC7 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC7 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC7 = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC7 = 1"+"\r"
	strset += "	String/G LabelADCCC7 = \"ADC7 CC\""+"\r"	
	strset += "	String/G UnitADCCC7 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC7 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCCC7 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCCC7 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	tClamp18SetChannelMode()"+"\r"	
	strset += ""+"\r"	
	strset += "	tClamp18PrepWindows(1, 1) // tClamp18PrepWindows(bitDAC, bitADC)"+"\r"	
	strset += "	tClamp18MoveWinXXXX()"+"\r"	
	strset += "	SetDataFolder fldrSav0"+"\r"
	strset += "	tClamp18SetChannelMode()"+"\r"	
	strset += "End"+"\r"
	strset += ""+"\r"	
	strset += "Function tClamp18MoveWinXXXX()"+"\r"	
	strset += "	MoveWindow/W=tClamp18_TimerPanel 800,7,1020,85"+"\r"	
	strset += "	MoveWindow/W=tClamp18DAC0 193.5, 743, 438.75, 815"+"\r"	
	strset += "	MoveWindow/W=tClamp18ADC0 58.5, 564.5, 283.5, 714.5"+"\r"	
	strset += "	MoveWindow/W=tClamp18OscilloADC0 28.5,151.25,305.25,389.75"+"\r"	
	strset += "	MoveWindow/W=tClamp18SealTestADC0 28.5,297.5,305.25,536"+"\r"
	strset += "End"+"\r"
	strset += ""+"\r"	
	Notebook $WinName(0, 16) selection={endOfFile, endOfFile}
	Notebook $WinName(0, 16) text = strset + "\r"
end

Function tClamp18OSCProtocolTemplate()
	NewNotebook/F=0

	String strproc = ""
	strproc += "// Oscillo Protocol Template" + "\r"
	strproc += "" + "\r"
	strproc += "Menu \"tClamp18\"" + "\r"
	strproc += "	SubMenu \"Oscillo Protocols\"" + "\r"
	strproc += "\"any name of protocol\", tClampSetParamProtocolX() // any name of setting protocol" + "\r"
	strproc += "	End" + "\r"
	strproc += "End" + "\r"
	strproc += "" + "\r"
	strproc += "Function tClampSetParamProtocolX() 					//any name of setting protocol" + "\r"
	strproc += "	tClamp18_FolderCheck()" + "\r"
	strproc += "	String fldrSav0= GetDataFolder(1)" + "\r"
	strproc += "	SetDataFolder root:Packages:tClamp18" + "\r"
	strproc += "" + "\r"
	strproc += "	String/G SelectedProtocol = \"protocol label X()\"	// any name of protocol" + "\r"
	strproc += "	String/G StrITC18SeqDAC = \"0\"				// must be same length" + "\r"
	strproc += "	String/G StrITC18SeqADC = \"0\"" + "\r"
	strproc += "	Variable/G RecordingCheckADC0 = 0			//Select recording channels" + "\r"
	strproc += "	Variable/G RecordingCheckADC1 = 0" + "\r"
	strproc += "	Variable/G RecordingCheckADC2 = 0" + "\r"
	strproc += "	Variable/G RecordingCheckADC3 = 0" + "\r"
	strproc += "	Variable/G RecordingCheckADC4 = 0" + "\r"
	strproc += "	Variable/G RecordingCheckADC5 = 0" + "\r"
	strproc += "	Variable/G RecordingCheckADC6 = 0" + "\r"
	strproc += "	Variable/G RecordingCheckADC7 = 0" + "\r"
	strproc += "	Variable/G OscilloCmdPulse0 = 0.25			//Command output" + "\r"
	strproc += "	Variable/G OscilloCmdPulse1 = 0.25" + "\r"
	strproc += "	Variable/G OscilloCmdPulse2 = 0.25" + "\r"
	strproc += "	Variable/G OscilloCmdPulse3 = 0.25" + "\r"
	strproc += "	Variable/G OscilloCmdPulse4 = 0.25" + "\r"
	strproc += "	Variable/G OscilloCmdPulse5 = 0.25" + "\r"
	strproc += "	Variable/G OscilloCmdPulse6 = 0.25" + "\r"
	strproc += "	Variable/G OscilloCmdPulse7 = 0.25" + "\r"
	strproc += "	Variable/G OscilloCounterLimit = 0				//Sweep number" + "\r"
	strproc += "	Variable/G OscilloSamplingNpnts = 1024 			//Number of Sampling Points at each channel" + "\r"
	strproc += "	Variable/G OscilloITC18ExtTrig = 0				//0: off, 1: on" + "\r"
	strproc += "	Variable/G OscilloITC18Output = 1				//0: off, 1: on" + "\r"
	strproc += "	Variable/G OscilloITC18Overflow = 1				//0: " + "\r"
	strproc += "	Variable/G OscilloITC18Reserved = 1			// Reserved" + "\r"
	strproc += "	Variable/G OscilloITC18Period = 4				// must be between 4 and 65535. Each sampling tick is 1.25 micro sec." + "\r"
	strproc += "" + "\r"
	strproc += "	///////////////////////" + "\r"
	strproc += "	//Protocol-Specific parameters and procedures are here" + "\r"
	strproc += "	///////////////////////" + "\r"
	strproc += "" + "\r"
	strproc += "	tClamp18ApplyProtocolSetting()" + "\r"
	strproc += "" + "\r"
	strproc += "	SetDataFolder fldrSav0" + "\r"
	strproc += "end" + "\r"
	strproc += "" + "\r"
	strproc += "Function tClampAcquisitionProcX() //same as StrAcquisitionProcName and SelectedProtocol" + "\r"
	strproc += "	NVAR bit = root:Packages:tClamp18:RecordingBit" + "\r"
	strproc += "" + "\r"
	strproc += "	// Specific global variables here" + "\r"
	strproc += "" + "\r"
	strproc += "	Variable i = 0" + "\r"
	strproc += "	For(i = 0; i < 8; i += 1)" + "\r"
	strproc += "		If(bit & 2^i)" + "\r"
	strproc += "			Wave OscilloADC = $(\"root:Packages:tClamp18:OscilloADC\" + Num2str(i))" + "\r"
	strproc += "			NVAR OscilloCmdPulse = $(\"root:Packages:tClamp18:OscilloCmdPulse\" + Num2str(i))		//" + "\r"
	strproc += "			NVAR OscilloCmdOnOff = $(\"root:Packages:tClamp18:OscilloCmdOnOff\" + Num2str(i))		//" + "\r"
	strproc += "" + "\r"
	strproc += "			If(OscilloCmdOnOff)" + "\r"
	strproc += "				OscilloADC[0, ] = OscilloCmdPulse	// create DAC output data in volt" + "\r"
	strproc += "				OscilloADC *= 3200										// scale into point" + "\r"
	strproc += "			else" + "\r"
	strproc += "				OscilloADC[0, ] = 0" + "\r"
	strproc += "				OscilloADC *= 3200" + "\r"
	strproc += "			endif" + "\r"
	strproc += "		endif" + "\r"
	strproc += "	endFor" + "\r"
	strproc += "" + "\r"
	strproc += "	Wave DigitalOut1 = $\"root:Packages:tClamp18:DigitalOut1\"	//Output Wave for DigitalOut1" + "\r"
	strproc += "	NVAR StimulatorCheck = root:Packages:tClamp18:StimulatorCheck" + "\r"
	strproc += "" + "\r"
	strproc += "	If(StimulatorCheck)" + "\r"
	strproc += "		tClamp18UseStimulator()" + "\r"
	strproc += "	else" + "\r"
	strproc += "//		DigitalOut1 = 0" + "\r"
	strproc += "	endIf" + "\r"
	strproc += "end" + "\r"
	strproc += "" + "\r"
	Notebook $WinName(0, 16) selection={endOfFile, endOfFile}
	Notebook $WinName(0, 16) text = strproc + "\r"
end

Function tClamp18StimProtocolTemplate()
	NewNotebook/F=0

	String strproc = ""
	strproc += "// Stimulator Protocol Template" + "\r"
	strproc += "Menu \"tClamp18\"" + "\r"
	strproc += "	SubMenu \"Stimulator Protocols\"" + "\r"
	strproc += "\"any name\", tClampSetStim()" + "\r"
	strproc += "	End" + "\r"
	strproc += "End" + "\r"
	strproc += "" + "\r"
	strproc += "Function tClampSetStim()" + "\r"
	strproc += "	tClamp18_FolderCheck()" + "\r"
	strproc += "	String fldrSav0= GetDataFolder(1)" + "\r"
	strproc += "	SetDataFolder root:Packages:tClamp18" + "\r"
	strproc += "" + "\r"
	strproc += "	Variable/G StimulatorCheck = 1" + "\r"
	strproc += "" + "\r"
	strproc += "	Variable/G StimulatorCounterLimit = 0" + "\r"
	strproc += "	Variable/G StimulatorISI = 600" + "\r"
	strproc += "	Variable/G StimulatorITC18Period = 4" + "\r"
	strproc += "	Variable/G StimulatorSamplingNpnts = 200000" + "\r"
	strproc += "" + "\r"
	strproc += "	Variable/G StimulatorDelay0 = 0" + "\r"
	strproc += "	Variable/G StimulatorInterval0 = 0" + "\r"
	strproc += "	Variable/G StimulatorTrain0 = 0" + "\r"
	strproc += "	Variable/G StimulatorDuration0 = 0" + "\r"
	strproc += "" + "\r"
	strproc += "	Variable/G StimulatorDelay1 = 0" + "\r"
	strproc += "	Variable/G StimulatorInterval1 = 0" + "\r"
	strproc += "	Variable/G StimulatorTrain1 = 0" + "\r"
	strproc += "	Variable/G StimulatorDuration1 = 0" + "\r"
	strproc += "" + "\r"
	strproc += "	Variable/G StimulatorDelay2 = 0" + "\r"
	strproc += "	Variable/G StimulatorInterval2 = 0" + "\r"
	strproc += "	Variable/G StimulatorTrain2 = 0" + "\r"
	strproc += "	Variable/G StimulatorDuration2 = 0" + "\r"
	strproc += "" + "\r"
	strproc += "	Variable/G StimulatorDelay3 = 0" + "\r"
	strproc += "	Variable/G StimulatorInterval3 = 0" + "\r"
	strproc += "	Variable/G StimulatorTrain3 = 0" + "\r"
	strproc += "	Variable/G StimulatorDuration3 = 0" + "\r"
	strproc += "" + "\r"
	strproc += "	tClamp18ApplyStimulatorSetting()" + "\r"
	strproc += "" + "\r"
	strproc += "	SetDataFolder fldrSav0" + "\r"
	strproc += "End" + "\r"
	
	Notebook $WinName(0, 16) selection={endOfFile, endOfFile}
	Notebook $WinName(0, 16) text = strproc + "\r"
end

Function  tClamp18HelpNote()
	NewNotebook/F=0
	String strhelp =""
	strhelp += "0. Click tClampInitialize						(Menu -> tClamp18 -> Initialize -> tClampInitialize)"+"\r"
	strhelp += "1. Select setting.ipf				 			(Menu -> tClamp18 -> Setting -> any setting)"+"\r"
	strhelp += "2. Select oscillo protocol.ipf		 			(Menu -> tClamp18 -> Oscillo Protocol)"+"\r"
	strhelp += "3. If you need it, select stimulator protocol.ipf 	(Menu -> tClamp18 -> Stimulator Protocol)"+"\r"
	strhelp += ""+"\r"
	strhelp += ""+"\r"
	strhelp += ""+"\r"
	strhelp += ""+"\r"
	strhelp += ""+"\r"
	strhelp += ""+"\r"
	strhelp += ""+"\r"
	Notebook $WinName(0, 16) selection={endOfFile, endOfFile}
	Notebook $WinName(0, 16) text = strhelp + "\r"
end

Function tClamp18SetChannelMode()
	Variable i = 0
	For(i = 0; i < 8; i += 1)
		NVAR ADCMode = $("root:Packages:tClamp18:ADCMode" + Num2str(i))
		tClamp18ModeSwitch(i, ADCMode)
	endfor
end

Function tClamp18PrepWindows(bitDAC, bitADC)
	Variable bitDAC, bitADC
	
	Variable i = 0
	For(i = 0; i < 8; i += 1)
		If(bitDAC & 2^i)
			CheckBox $("ChecktClampDAC" + Num2str(i) + "_tab0"), win = tClamp18MainControlPanel, value = 1
			tClamp18MainDACCheckProc("ChecktClampDAC" + Num2str(i),1)
		endif
		
		If(bitADC & 2^i)
			CheckBox $("ChecktClampADC" + Num2str(i) + "_tab0"), win = tClamp18MainControlPanel, value = 1
			tClamp18MainADCCheckProc("ChecktClampADC"+ Num2str(i),1)
			
			CheckBox $("ChecktClampOscilloADC" + Num2str(i) + "_tab1"), win = tClamp18MainControlPanel, value = 1
			tClamp18OscilloCheckProc("ChecktClampOscilloADC" + Num2str(i),1)
			
			CheckBox $("ChecktClampMainSealADC" + Num2str(i) + "_tab2"), win = tClamp18MainControlPanel, value = 1
			tClamp18MainSealTestCheckProc("ChecktClampMainSealADC" + Num2str(i),1)
		endif
	endFor
end

///////////////////////////////////////////////////////////////////
// Main Control Panel

Function tClamp18_MainControlPanel()
	NewPanel /N=tClamp18MainControlPanel/W=(310,56,1039,159)
	TabControl TabtClampMain,pos={6,4},size={720,96},proc=tClamp18MainTabProc
	TabControl TabtClampMain,tabLabel(0)="DAC/ADC",tabLabel(1)="Oscillo Protocol"
	TabControl TabtClampMain,tabLabel(2)="Seal Test",tabLabel(3)="Stimulator"
	TabControl TabtClampMain,tabLabel(4)="FIFO"
	TabControl TabtClampMain,value= 0
	
//tab0 (DAC/ADC)
	GroupBox GrouptClampMainDACs_tab0,pos={40,28},size={156,65},title="DAC"
	CheckBox ChecktClampDAC0_tab0,pos={60,50},size={24,14},proc=tClamp18MainDACCheckProc,title="0",variable = root:Packages:tClamp18:MainCheckDAC0
	CheckBox ChecktClampDAC1_tab0,pos={90,50},size={24,14},proc=tClamp18MainDACCheckProc,title="1",variable = root:Packages:tClamp18:MainCheckDAC1
	CheckBox ChecktClampDAC2_tab0,pos={120,50},size={24,14},proc=tClamp18MainDACCheckProc,title="2",variable = root:Packages:tClamp18:MainCheckDAC2
	CheckBox ChecktClampDAC3_tab0,pos={150,50},size={24,14},proc=tClamp18MainDACCheckProc,title="3",variable = root:Packages:tClamp18:MainCheckDAC3
	Button BtDACShow_tab0,pos={45,68},size={40,20},proc=tClamp18DACADCShowHide,title="Show"
	Button BtDACHide_tab0,pos={90,68},size={40,20},proc=tClamp18DACADCShowHide,title="Hide"
	ValDisplay ValdisptClampDACBit_tab0,pos={139,74},size={50,13},title="bit",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:DACBit"
	
	GroupBox GrouptClampMainADCs_tab0,pos={208,28},size={274,65},title="ADC"	
	CheckBox ChecktClampADC0_tab0,pos={220,50},size={24,14},proc=tClamp18MainADCCheckProc,title="0",variable = root:Packages:tClamp18:MainCheckADC0
	CheckBox ChecktClampADC1_tab0,pos={250,50},size={24,14},proc=tClamp18MainADCCheckProc,title="1",variable = root:Packages:tClamp18:MainCheckADC1
	CheckBox ChecktClampADC2_tab0,pos={280,50},size={24,14},proc=tClamp18MainADCCheckProc,title="2",variable = root:Packages:tClamp18:MainCheckADC2
	CheckBox ChecktClampADC3_tab0,pos={310,50},size={24,14},proc=tClamp18MainADCCheckProc,title="3",variable = root:Packages:tClamp18:MainCheckADC3
	CheckBox ChecktClampADC4_tab0,pos={340,50},size={24,14},proc=tClamp18MainADCCheckProc,title="4",variable = root:Packages:tClamp18:MainCheckADC4
	CheckBox ChecktClampADC5_tab0,pos={370,50},size={24,14},proc=tClamp18MainADCCheckProc,title="5",variable = root:Packages:tClamp18:MainCheckADC5
	CheckBox ChecktClampADC6_tab0,pos={400,50},size={24,14},proc=tClamp18MainADCCheckProc,title="6",variable = root:Packages:tClamp18:MainCheckADC6
	CheckBox ChecktClampADC7_tab0,pos={430,50},size={24,14},proc=tClamp18MainADCCheckProc,title="7",variable = root:Packages:tClamp18:MainCheckADC7
	Button BtADCShow_tab0,pos={245,68},size={40,20},proc=tClamp18DACADCShowHide,title="Show"
	Button BtADCHide_tab0,pos={290,68},size={40,20},proc=tClamp18DACADCShowHide,title="Hide"
	ValDisplay ValdisptClampADCBit_tab0,pos={415,74},size={50,13},title="bit",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:ADCBit"
	
	GroupBox GrouptClampMainDigital1_tab0,pos={496,28},size={220,65},title="DigitalOut1"
	CheckBox CktClampDO1Bit0_tab0,pos={540,50},size={24,14},proc=tClamp18CheckProcDigitalOut1Bit,title="0",variable= root:Packages:tClamp18:DigitalOut1Check0,mode=0
	CheckBox CktClampDO1Bit1_tab0,pos={570,50},size={24,14},proc=tClamp18CheckProcDigitalOut1Bit,title="1",variable= root:Packages:tClamp18:DigitalOut1Check1,mode=0
	CheckBox CktClampDO1Bit2_tab0,pos={600,50},size={24,14},proc=tClamp18CheckProcDigitalOut1Bit,title="2",variable= root:Packages:tClamp18:DigitalOut1Check2,mode=0
	CheckBox CktClampDO1Bit3_tab0,pos={630,50},size={24,14},proc=tClamp18CheckProcDigitalOut1Bit,title="3",variable= root:Packages:tClamp18:DigitalOut1Check3,mode=0
	ValDisplay ValdisptClampDO1Bit_tab0,pos={575,74},size={50,13},title="bit",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:DigitalOut1Bit"

//tab1 (Oscillo Protocol)
	TitleBox TitletClampOscillo_tab1,pos={11,25},size={43,20},title="Oscillo", frame = 0
	CheckBox ChecktClampOscilloADC0_tab1,pos={58,24},size={24,14},proc=tClamp18OscilloCheckProc,title="0",variable = root:Packages:tClamp18:OscilloTestCheckADC0
	CheckBox ChecktClampOscilloADC1_tab1,pos={88,24},size={24,14},proc=tClamp18OscilloCheckProc,title="1",variable = root:Packages:tClamp18:OscilloTestCheckADC1
	CheckBox ChecktClampOscilloADC2_tab1,pos={118,24},size={24,14},proc=tClamp18OscilloCheckProc,title="2",variable = root:Packages:tClamp18:OscilloTestCheckADC2
	CheckBox ChecktClampOscilloADC3_tab1,pos={148,24},size={24,14},proc=tClamp18OscilloCheckProc,title="3",variable = root:Packages:tClamp18:OscilloTestCheckADC3
	CheckBox ChecktClampOscilloADC4_tab1,pos={178,24},size={24,14},proc=tClamp18OscilloCheckProc,title="4",variable = root:Packages:tClamp18:OscilloTestCheckADC4
	CheckBox ChecktClampOscilloADC5_tab1,pos={208,24},size={24,14},proc=tClamp18OscilloCheckProc,title="5",variable = root:Packages:tClamp18:OscilloTestCheckADC5
	CheckBox ChecktClampOscilloADC6_tab1,pos={238,24},size={24,14},proc=tClamp18OscilloCheckProc,title="6",variable = root:Packages:tClamp18:OscilloTestCheckADC6
	CheckBox ChecktClampOscilloADC7_tab1,pos={268,24},size={24,14},proc=tClamp18OscilloCheckProc,title="7",variable = root:Packages:tClamp18:OscilloTestCheckADC7
	ValDisplay ValdisptClampOscilloBit_tab1,pos={312,25},size={46,13},title="bit",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:OscilloBit"

	Button BtEditRecordingCheckADCs_tab1,pos={8,37},size={45,16},proc=tClamp18EditRecordingChecks,title="Record"
	CheckBox ChecktClampRecordingADC0_tab1,pos={58,39},size={24,14},proc=tClamp18CheckProcRecordingBit,title="0",variable= root:Packages:tClamp18:RecordingCheckADC0,mode=1
	CheckBox ChecktClampRecordingADC1_tab1,pos={88,39},size={24,14},proc=tClamp18CheckProcRecordingBit,title="1",variable= root:Packages:tClamp18:RecordingCheckADC1,mode=1
	CheckBox ChecktClampRecordingADC2_tab1,pos={118,39},size={24,14},proc=tClamp18CheckProcRecordingBit,title="2",variable= root:Packages:tClamp18:RecordingCheckADC2,mode=1
	CheckBox ChecktClampRecordingADC3_tab1,pos={148,39},size={24,14},proc=tClamp18CheckProcRecordingBit,title="3",variable= root:Packages:tClamp18:RecordingCheckADC3,mode=1
	CheckBox ChecktClampRecordingADC4_tab1,pos={178,39},size={24,14},proc=tClamp18CheckProcRecordingBit,title="4",variable= root:Packages:tClamp18:RecordingCheckADC4,mode=1
	CheckBox ChecktClampRecordingADC5_tab1,pos={208,39},size={24,14},proc=tClamp18CheckProcRecordingBit,title="5",variable= root:Packages:tClamp18:RecordingCheckADC5,mode=1
	CheckBox ChecktClampRecordingADC6_tab1,pos={238,39},size={24,14},proc=tClamp18CheckProcRecordingBit,title="6",variable= root:Packages:tClamp18:RecordingCheckADC6,mode=1
	CheckBox ChecktClampRecordingADC7_tab1,pos={268,39},size={24,14},proc=tClamp18CheckProcRecordingBit,title="7",variable= root:Packages:tClamp18:RecordingCheckADC7,mode=1
	ValDisplay ValdispRecordingChBit_tab1,pos={312,39},size={46,13},title="bit",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:RecordingBit"

	TitleBox TitletClampProtocolName_tab1,pos={11,54},size={32,20},variable= root:Packages:tClamp18:SelectedProtocol
	Button BttClampProtocolRun_tab1,pos={150,54},size={40,20},proc=tClamp18ProtocolRun,title="Run"
	Button BttClampProtocolCont_tab1,pos={190,54},size={40,20},proc=tClamp18ProtocolRun,title="Cont."
	Button BttClampBackGStop_tab1,pos={230,54},size={40,20},proc=tClamp18BackGStop,title="Stop"
	Button BttClampProtocolSave_tab1,pos={270,54},size={40,20},proc=tClamp18ProtocolSave,title="Save"
	Button BttClampClearWaves_tab1,pos={310,54},size={40,20},proc=tClamp18ClearTempWaves,title="Clear"
	Button BttClampEditProtocol_tab1,pos={350,54},size={40,20},proc=tClamp18EditProtocol,title="Edit"
	Button BtResetNumTrial_tab1,pos={396,54},size={30,20},proc=tClamp18ResetNumTrial,title="Trial",fColor=(48896,52992,65280)
	SetVariable SetvartClampNumTrial_tab1,pos={430,55},size={40,16},title=" ",limits={0,inf,1},value= root:Packages:tClamp18:NumTrial
	ValDisplay ValdisptClampOscilloCount_tab1,pos={478,56},size={100,13},title="Counter",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:OscilloCounter"
	SetVariable SetvarOscilloCounterLimit_tab1,pos={587,54},size={130,16},title="CounterLimit",limits={0,inf,1},value= root:Packages:tClamp18:OscilloCounterLimit
	
	TitleBox TitleDACSeq_tab1,pos={12,80},size={54,12},title="DAC/ADC",frame=0
	Button EditITC18Seq_tab1,pos={72,75},size={30,20},proc=tClamp18EditITC18Seq,title="Seq"
	TitleBox TitleDispDACSeq_tab1,pos={107,75},size={14,20},variable= root:Packages:tClamp18:StrITC18SeqDAC
	TitleBox TitleDispADCSeq_tab1,pos={176,75},size={14,20},variable= root:Packages:tClamp18:StrITC18SeqADC
	SetVariable SetvarITC18Perid_tab1,pos={245,77},size={70,16},limits={4,65535,1},proc=tClamp18SetVarProcOscilloFreq,title="Perid",value= root:Packages:tClamp18:OscilloITC18Period
	ValDisplay ValdisptClampOscilloFreq_tab1,pos={323,78},size={100,13},title="Frequency",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:OscilloFreq"
	SetVariable SetvarOscilloWaveReD_tab1,pos={428,76},size={100,16},proc=tClamp18OscilloReDimension,title="npnts",value= root:Packages:tClamp18:OscilloSamplingNpnts
	ValDisplay ValdispAcqTime_tab1,pos={534,79},size={125,13},title="AcqTime (s)",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:OscilloAcqTime"

	Button BtOSCShow_tab1,pos={367,28},size={20,20},proc=tClamp18OSCShowHide,title="S"
	Button BtOSCHide_tab1,pos={393,28},size={20,20},proc=tClamp18OSCShowHide,title="H"
	SetVariable SetvartClampOscilloISI_tab1,pos={425, 23},size={100,16},title="ISI (tick)",limits={1,inf,1},value= root:Packages:tClamp18:OscilloISI
	CheckBox CheckStimulator_tab1,pos={423,39},size={70,14},proc=tClamp18CheckProcITC18Flags,title="Stimulator",variable= root:Packages:tClamp18:StimulatorCheck
	CheckBox CheckExtTrig_tab1,pos={532,32},size={55,14},proc=tClamp18CheckProcITC18Flags,title="ExtTrig",variable= root:Packages:tClamp18:OscilloITC18ExtTrig
	CheckBox CheckOutputEnable_tab1,pos={595,32},size={52,14},proc=tClamp18CheckProcITC18Flags,title="Output",variable= root:Packages:tClamp18:OscilloITC18Output
	CheckBox CheckITC18Overflow_tab1,pos={654,32},size={63,14},proc=tClamp18CheckProcITC18Flags,title="Overflow",variable= root:Packages:tClamp18:OscilloITC18Overflow

//tab2 (Seal Test)
	CheckBox ChecktClampMainSealADC0_tab2,pos={15,30},size={24,14},proc=tClamp18MainSealTestCheckProc,title="0",variable= root:Packages:tClamp18:SealTestCheckADC0
	CheckBox ChecktClampMainSealADC1_tab2,pos={45,30},size={24,14},proc=tClamp18MainSealTestCheckProc,title="1",variable= root:Packages:tClamp18:SealTestCheckADC1
	CheckBox ChecktClampMainSealADC2_tab2,pos={75,30},size={24,14},proc=tClamp18MainSealTestCheckProc,title="2",variable= root:Packages:tClamp18:SealTestCheckADC2
	CheckBox ChecktClampMainSealADC3_tab2,pos={110,30},size={24,14},proc=tClamp18MainSealTestCheckProc,title="3",variable= root:Packages:tClamp18:SealTestCheckADC3
	CheckBox ChecktClampMainSealADC4_tab2,pos={140,30},size={24,14},proc=tClamp18MainSealTestCheckProc,title="4",variable= root:Packages:tClamp18:SealTestCheckADC4
	CheckBox ChecktClampMainSealADC5_tab2,pos={170,30},size={24,14},proc=tClamp18MainSealTestCheckProc,title="5",variable= root:Packages:tClamp18:SealTestCheckADC5
	CheckBox ChecktClampMainSealADC6_tab2,pos={200,30},size={24,14},proc=tClamp18MainSealTestCheckProc,title="6",variable= root:Packages:tClamp18:SealTestCheckADC6
	CheckBox ChecktClampMainSealADC7_tab2,pos={230,30},size={24,14},proc=tClamp18MainSealTestCheckProc,title="7",variable= root:Packages:tClamp18:SealTestCheckADC7
	ValDisplay ValdisptClampSealTestBit_tab2,pos={262,30},size={45,13},title="bit",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:SealTestBit"
	SetVariable SetvartClampSealTestISI_tab2,pos={325,31},size={100,16},title="ISI (tick)",limits={1,inf,1},value= root:Packages:tClamp18:SealTestISI
	CheckBox CheckTrigOut_tab2,pos={440,32},size={56,14},proc=tClamp18CheckSealTrigOut,title="TrigOut",variable= root:Packages:tClamp18:SealITC18Trigout
	CheckBox CheckExtTrig_tab2,pos={510,32},size={55,14},proc=tClamp18CheckSealITC18Flags,title="ExtTrig",variable= root:Packages:tClamp18:SealITC18ExtTrig
	CheckBox CheckOutputEnable_tab2,pos={580,32},size={52,14},proc=tClamp18CheckSealITC18Flags,title="Output",variable= root:Packages:tClamp18:SealITC18Output
	CheckBox CheckITC18Overflow_tab2,pos={650,32},size={63,14},proc=tClamp18CheckSealITC18Flags,title="Overflow",variable= root:Packages:tClamp18:SealITC18Overflow

	Button BttClampMainSealTestRun_tab2,pos={15,48},size={50,20},proc=tClamp18SealTestBGRun,title="Run"
	Button BttClampMainSealTestAbort_tab2,pos={65,48},size={50,20},proc=tClamp18BackGStop,title="Abort"
	Button BttClampMainSealTestShow_tab2,pos={115,48},size={50,20},proc=tClamp18MainSealShowHide,title="Show"
	Button BttClampMainSealTestHide_tab2,pos={165,48},size={50,20},proc=tClamp18MainSealShowHide,title="Hide"
	ValDisplay ValdisptClampSealCount_tab2,pos={430,52},size={100,13},title="Counter",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:SealTestCounter"
	SetVariable SetvarSealCounterLimit_tab2,pos={546,50},size={150,16},title="CounterLimit",limits={0,inf,1},value= root:Packages:tClamp18:SealTestCounterLimit

	TitleBox TitleDACSeq_tab2,pos={12,80},size={54,12},title="DAC/ADC",frame=0
	Button EditITC18Seq_tab2,pos={72,75},size={30,20},proc=tClamp18EditSealITC18Seq,title="Seq"
	TitleBox TitleDispDACSeq_tab2,pos={107,75},size={14,20},variable= root:Packages:tClamp18:SealITC18SeqDAC
	TitleBox TitleDispADCSeq_tab2,pos={176,75},size={14,20},variable= root:Packages:tClamp18:SealITC18SeqADC
	SetVariable SetvarITC18Perid_tab2,pos={245,77},size={70,16},proc=tClamp18SetVarProcSealFreq,title="Perid",limits={4,65535,1},value= root:Packages:tClamp18:SealITC18Period
	ValDisplay ValdisptClampSealFreq_tab2,pos={323,78},size={100,13},title="Frequency",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:SealTestFreq"
	SetVariable SetvarSealWaveReD_tab2,pos={428,76},size={100,16},proc=tClamp18SealRedimension,title="npnts",value= root:Packages:tClamp18:SealSamplingNpnts
	ValDisplay ValdispAcqTime_tab2,pos={534,79},size={125,13},title="AcqTime (s)",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:SealAcqTime"

//tab3 (Stimulator)
	ValDisplay ValdisptClampStimCount_tab3,pos={12,27},size={100,13},title="Counter",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:StimulatorCounter"
	SetVariable SetvarStimCounterLimit_tab3,pos={12,40},size={118,16},title="CounterLimit",limits={0,inf,1},value= root:Packages:tClamp18:StimulatorCounterLimit
	SetVariable SetvartClampStimISI_tab3,pos={12,57},size={118,16},title="ISI (tick)",limits={1,inf,1},value= root:Packages:tClamp18:StimulatorISI
	Button BttClampStimulatorRun_tab3,pos={10,74},size={40,20},proc=tClamp18StimulatorRun,title="Run"
	Button BttClampBackGStop_tab3,pos={50,74},size={40,20},proc=tClamp18BackGStop,title="Stop"
	Button BttClampStimulatorReset_tab3,pos={90,74},size={40,20},proc=tClamp18StimulatorReset,title="Reset"
	SetVariable SetvarITC18Perid_tab3,pos={135,22},size={70,16},proc=tClamp18SetVarProcStimulator,title="Perid",limits={4,65535,1},value= root:Packages:tClamp18:StimulatorITC18Period
	ValDisplay ValdisptClampStimFreq_tab3,pos={135,40},size={100,13},title="Frequency",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:StimulatorFreq"
	SetVariable SetvarStimulatorReD_tab3,pos={135,57},size={100,16},proc=tClamp18SetVarProcStimulator,title="npnts",value= root:Packages:tClamp18:StimulatorSamplingNpnts
	SetVariable SetvarStimulatorAcqTime_tab3,pos={135,76},size={100,16},proc=tClamp18SetVarProcStimulator,title="Time (s)",value= root:Packages:tClamp18:StimulatorAcqTime

	PopupMenu PopupStimulatorCh0_tab3,pos={243,23},size={99,20},proc=tClamp18PopMenuProcStimulator,title="Ch0 Trig",mode=1,popvalue="main",value= #"root:Packages:tClamp18:StimulatorTrig0"
	PopupMenu PopupStimulatorCh1_tab3,pos={243,41},size={99,20},proc=tClamp18PopMenuProcStimulator,title="Ch1 Trig",mode=1,popvalue="main",value= #"root:Packages:tClamp18:StimulatorTrig1"
	PopupMenu PopupStimulatorCh2_tab3,pos={243,59},size={99,20},proc=tClamp18PopMenuProcStimulator,title="Ch2 Trig",mode=1,popvalue="main",value= #"root:Packages:tClamp18:StimulatorTrig2"
	PopupMenu PopupStimulatorCh3_tab3,pos={243,77},size={99,20},proc=tClamp18PopMenuProcStimulator,title="Ch3 Trig",mode=1,popvalue="main",value= #"root:Packages:tClamp18:StimulatorTrig3"
	
	SetVariable SetvartClampStimDelay0_tab3,pos={362,25},size={90,16},title="Del (s)",limits={0,inf,1e-03},value= root:Packages:tClamp18:StimulatorDelay0
	SetVariable SetvartClampStimDelay1_tab3,pos={362,42},size={90,16},title="Del (s)",limits={0,inf,1e-03},value= root:Packages:tClamp18:StimulatorDelay1
	SetVariable SetvartClampStimDelay2_tab3,pos={362,59},size={90,16},title="Del (s)",limits={0,inf,1e-03},value= root:Packages:tClamp18:StimulatorDelay2
	SetVariable SetvartClampStimDelay3_tab3,pos={362,76},size={90,16},title="Del (s)",limits={0,inf,1e-03},value= root:Packages:tClamp18:StimulatorDelay3

	SetVariable SetvartClampStimInterval0_tab3,pos={458,25},size={90,16},title="ISI (s)",limits={0,inf,1e-03},value= root:Packages:tClamp18:StimulatorInterval0
	SetVariable SetvartClampStimInterval1_tab3,pos={458,42},size={90,16},title="ISI (s)",limits={0,inf,1e-03},value= root:Packages:tClamp18:StimulatorInterval1
	SetVariable SetvartClampStimInterval2_tab3,pos={458,59},size={90,16},title="ISI (s)",limits={0,inf,1e-03},value= root:Packages:tClamp18:StimulatorInterval2
	SetVariable SetvartClampStimInterval3_tab3,pos={458,76},size={90,16},title="ISI (s)",limits={0,inf,1e-03},value= root:Packages:tClamp18:StimulatorInterval3
	
	SetVariable SetvartClampStimTrain0_tab3,pos={552,25},size={70,16},title="Train",limits={0,inf,1},value= root:Packages:tClamp18:StimulatorTrain0
	SetVariable SetvartClampStimTrain1_tab3,pos={552,42},size={70,16},title="Train",limits={0,inf,1},value= root:Packages:tClamp18:StimulatorTrain1
	SetVariable SetvartClampStimTrain2_tab3,pos={552,59},size={70,16},title="Train",limits={0,inf,1},value= root:Packages:tClamp18:StimulatorTrain2
	SetVariable SetvartClampStimTrain3_tab3,pos={552,76},size={70,16},title="Train",limits={0,inf,1},value= root:Packages:tClamp18:StimulatorTrain3

	SetVariable SetvartClampStimDuration0_tab3,pos={626,25},size={95,16},title="Dur (s)",limits={0,inf,1e-05},value= root:Packages:tClamp18:StimulatorDuration0
	SetVariable SetvartClampStimDuration1_tab3,pos={626,42},size={95,16},title="Dur (s)",limits={0,inf,1e-05},value= root:Packages:tClamp18:StimulatorDuration1
	SetVariable SetvartClampStimDuration2_tab3,pos={626,59},size={95,16},title="Dur (s)",limits={0,inf,1e-05},value= root:Packages:tClamp18:StimulatorDuration2
	SetVariable SetvartClampStimDuration3_tab3,pos={626,76},size={95,16},title="Dur (s)",limits={0,inf,1e-05},value= root:Packages:tClamp18:StimulatorDuration3

//tab4 (FIFO)
	Button BttClampMainFIFOGraph_tab4,pos={344,33},size={50,20},proc=tClamp18DisplayHideFIFO,title="FIFO"

//
	ModifyControlList ControlNameList("tClamp18MainControlPanel", ";", "!*_tab0") disable = 1
	ModifyControl TabtClampMain disable=0
end

Function tClamp18MainTabProc(ctrlName,tabNum) : TabControl
	String ctrlName
	Variable tabNum
	String controlsInATab= ControlNameList("tClamp18MainControlPanel",";","*_tab*")
	String curTabMatch="*_tab*"+Num2str(tabNum)
	String controlsInCurTab= ListMatch(controlsInATab, curTabMatch)
	String controlsInOtherTab= ListMatch(controlsInATab, "!"+curTabMatch)
	ModifyControlList controlsInCurTab disable = 0 //show
	ModifyControlList controlsInOtherTab disable = 1 //hide
	return 0
End

Function tClamp18_DisplayMain()
	If(WinType("tClamp18MainControlPanel") == 7)
		DoWindow/HIDE = ? $("tClamp18MainControlPanel")
		If(V_flag == 1)
			DoWindow/HIDE = 1 $("tClamp18MainControlPanel")
		else
			DoWindow/HIDE = 0/F $("tClamp18MainControlPanel")
		endif
	else	
		tClamp18_MainControlPanel()
	endif
End

Function tClamp18_HideMainControlPanel()
	If(WinType("tClamp18MainControlPanel"))
		DoWindow/HIDE = 1 $("tClamp18MainControlPanel")
	endif
End

Function tClamp18MainDACCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	Variable num_channel

	sscanf ctrlName, "ChecktClampDAC%f", num_channel
	If(checked)
		If(WinType("tClamp18DAC"+Num2str(num_channel)) == 7)
			DoWindow/HIDE = ? $("tClamp18DAC"+Num2str(num_channel))
			If(V_flag == 1)
				DoWindow/HIDE = 1 $("tClamp18DAC"+Num2str(num_channel))
			else
				DoWindow/HIDE = 0/F $("tClamp18DAC"+Num2str(num_channel))
			endif
		else	
			tClamp18NewDACPanel(num_channel)
		endif
	else
		DoWindow/HIDE = 1 $("tClamp18DAC"+Num2str(num_channel))
	endif
	
	tClamp18BitUpdate("root:Packages:tClamp18:MainCheckDAC", "root:Packages:tClamp18:DACbit", 4)
End

Function tClamp18NewDACPanel(num_channel)
	Variable num_channel
	NewPanel/N=$("tClamp18DAC"+Num2str(num_channel))/W=(18+27*num_channel,595-20*num_channel,345+27*num_channel,691-20*num_channel)
	ValDisplay $("ValdisptClampValueVoltDAC"+Num2str(num_channel)),pos={11,9},size={75,13},title="Volt",limits={0,0,0},barmisc={0,1000},value= #("root:Packages:tClamp18:DACValueVolt"+Num2str(num_channel))
	SetVariable $("SetvartClampCommandSensVCDAC" +Num2str(num_channel)),pos={11,31},size={250,16},title="VC Command Sensitivity (mV/V)",value= $("root:Packages:tClamp18:CommandSensVC_DAC" + Num2str(num_channel))
	SetVariable $("SetvartClampCommandSensCCDAC" +Num2str(num_channel)),pos={11,52},size={250,16},title="CC Command Sensitivity (pA/V)",value= $("root:Packages:tClamp18:CommandSensCC_DAC" +Num2str(num_channel))
	SetVariable $("SetvartClampSetValueDAC" +Num2str(num_channel)),pos={102,7},size={50,16},proc=tClamp18SetVarProcSetVoltDAC,title=" ",limits={-10,10,0},value= $("root:Packages:tClamp18:DACValueVolt"+Num2str(num_channel))
	Slider $("SlidertClampSetDAC"+Num2str(num_channel)),pos={273,2},size={59,92},proc=tClamp18SetDACSliderProc,limits={-10,10,0.01},variable= $("root:Packages:tClamp18:DACValueVolt" +Num2str(num_channel))
End

Proc tClamp18SetVarProcSetVoltDAC(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	Variable num_channel
	num_channel = tClamp18sscanf(ctrlName, "SetvartClampSetValueDAC%f")
	ITC18SetDAC num_channel, varNum
EndMacro

Function tClamp18sscanf(inputstr, formatstr)
	String inputstr, formatstr

	Variable varReturn
	sscanf inputstr, formatstr, varReturn
	return varReturn
end

Function tClamp18DisplayHideFIFO(ctrlName) : ButtonControl
	String ctrlName
	If(WinType("tClamp18FIFOout") == 1)
		DoWindow/HIDE = ? $("tClamp18FIFOout")
		If(V_flag == 1)
			DoWindow/HIDE = 1 $("tClamp18FIFOout")
		else
			DoWindow/HIDE = 0/F $("tClamp18FIFOout")
		endif
	else	
		Display/W=(20.25,157.25,249,365.75)/N=$("tClamp18FIFOout") $("root:Packages:tClamp18:FIFOout")
	endif
	
	If(WinType("tClamp18FIFOin") == 1)
		DoWindow/HIDE = ? $("tClamp18FIFOin")
		If(V_flag == 1)
			DoWindow/HIDE = 1 $("tClamp18FIFOin")
		else
			DoWindow/HIDE = 0/F $("tClamp18FIFOin")
		endif
	else	
		Display/W=(261,157.25,489,365.75)/N=$("tClamp18FIFOin") $("root:Packages:tClamp18:FIFOin")
	endif
	
	If(WinType("tClamp18DigitalOut1") == 1)
		DoWindow/HIDE = ? $("tClamp18DigitalOut1")
		If(V_flag == 1)
			DoWindow/HIDE = 1 $("tClamp18DigitalOut1")
		else
			DoWindow/HIDE = 0/F $("tClamp18DigitalOut1")
		endif
	else	
		Display/W=(501,157.25,729,365.75)/N=$("tClamp18DigitalOut1") $("root:Packages:tClamp18:DigitalOut1")
	endif
End

// Main
///////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////
//DAC panel

Proc tClamp18SetDACSliderProc(ctrlName,sliderValue,event) : SliderControl
	String ctrlName
	Variable sliderValue
	Variable event	// bit field: bit 0: value set, 1: mouse down, 2: mouse up, 3: mouse moved

	Variable num_channel
	num_channel = tClamp18sscanf(ctrlName, "SlidertClampSetDAC%f")
	
	ITC18SetDAC num_channel, sliderValue
endMacro

Function tClamp18MainADCCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	Variable num_channel
	sscanf ctrlName, "ChecktClampADC%f", num_channel
	If(checked)
		If(WinType("tClamp18ADC"+Num2str(num_channel)) == 7)
			DoWindow/HIDE = ? $("tClamp18ADC"+Num2str(num_channel))
			If(V_flag == 1)
				DoWindow/HIDE = 1 $("tClamp18ADC"+Num2str(num_channel))
			else
				DoWindow/HIDE = 0/F $("tClamp18ADC"+Num2str(num_channel))
			endif
		else	
			tClamp18NewADCPanel(num_channel)
		endif
	else
		DoWindow/HIDE = 1 $("tClamp18ADC"+Num2str(num_channel))
	endif
	
	tClamp18BitUpdate("root:Packages:tClamp18:MainCheckADC", "root:Packages:tClamp18:ADCbit", 8)
End

Function tClamp18NewADCPanel(num_channel)
	Variable num_channel
	NewPanel/N=$("tClamp18ADC"+Num2str(num_channel))/W=(98+27*num_channel,646-20*num_channel,398+27*num_channel,846-20*num_channel)
	ValDisplay $("ValdisptClampADCValueV"+Num2str(num_channel)),pos={15,5},size={75,13},title="Volt",limits={0,0,0},barmisc={0,1000},value= #("root:Packages:tClamp18:ADCValueVolt"+Num2str(num_channel))
	ValDisplay $("ValdisptClampADCValueP"+Num2str(num_channel)),pos={145,5},size={75,13},title="Point",limits={0,0,0},barmisc={0,1000},value= #("root:Packages:tClamp18:ADCValuePoint"+Num2str(num_channel))
	TitleBox $("TitletClampADCLabel" + Num2str(num_channel)),pos={8,23},size={38,20},fSize=12,variable= $("root:Packages:tClamp18:LabelADC" + Num2str(num_channel))
	Button $("BttClampADCVCSwitch" + Num2str(num_channel)),pos={130,22},size={50,20},proc=tClamp18VClampSwitch,title="VClamp"
	Button $("BttClampADCCCSwitch" + Num2str(num_channel)),pos={230,22},size={50,20},proc=tClamp18CClampSwitch,title="CClamp"
	ValDisplay $("ValdisptClampADCRange"+ Num2str(num_channel)), pos={9,59},size={80,13},title="Range (V)", limits={0,0,0},barmisc={0,1000}, value= #("root:Packages:tClamp18:ADCRange"+Num2str(num_channel))
	PopupMenu $("PopuptClampADCRange"+ Num2str(num_channel)), pos={92,55},size={43,20},proc=tClamp18PopMenuProcADCRange, mode=1, popvalue = "10", value=#"\"10;5;2;1\""
	SetVariable $("SetvartClampInputOffset" + Num2str(num_channel)),pos={163,57},size={135,16},title="Input Off (V)",limits={-10,10,0.001},value= $("root:Packages:tClamp18:InputOffset" + Num2str(num_channel))
	SetVariable $("SetvartClampADCOffset" + Num2str(num_channel)),pos={163,77},size={135,16},title="ADC Off (V)",limits={-10,10,0.001},value= $("root:Packages:tClamp18:ADCOffset" + Num2str(num_channel))
	ValDisplay $("ValdisptClampAmpGain"+Num2str(num_channel)),pos={8,81},size={80,13},title="AmpGain",limits={0,0,0},barmisc={0,1000},value= #("root:Packages:tClamp18:AmpGainADC"+Num2str(num_channel))
	PopupMenu $("PopuptClampAmpGain"+Num2str(num_channel)),pos={92,77},size={56,20},proc=tClamp18PopMenuProcAmpGain,mode=1,popvalue="1",value= #("root:Packages:tClamp18:AmpGainListADC"+ Num2str(num_channel))
	SetVariable $("SetvartClampScalingADC" +Num2str(num_channel)),pos={10,100},size={205,16},proc=tClamp18SetVarProcScalingFactor,title="ScalingFactor (V/A or V/V)",value= $("root:Packages:tClamp18:ScalingFactorADC"+Num2str(num_channel))
	TitleBox $("TitletClampUnitADC" + Num2str(num_channel)),pos={10,119},size={16,20},variable= $("root:Packages:tClamp18:UnitADC" + Num2str(num_channel))
	PopupMenu $("PopuptClampUnitADC" + Num2str(num_channel)),pos={37,119},size={71,20},proc=tClamp18PopMenuProcUnitADC,title="Unit",mode=1,popvalue="A",value= #"\"A;V\""
	TitleBox $("TitletClampCoupling" + Num2str(num_channel)),pos={9,145},size={32,20},variable= $("root:Packages:tClamp18:CouplingDAC_ADC" + Num2str(num_channel))
	PopupMenu $("PopuptClampCoupling" + Num2str(num_channel)),pos={48,145},size={134,20},proc=tClamp18PopMenuProcCouplingDAC,title="CouplingDAC",mode=1,popvalue="none",value= #"\"none;0;1;2;3\""
	TitleBox $("TitletClampCouplingADC" + Num2str(num_channel)),pos={9,168},size={32,20},variable= $("root:Packages:tClamp18:CouplingADC_ADC" + Num2str(num_channel))
	PopupMenu $("PopuptClampCouplingADC" + Num2str(num_channel)),pos={48,168},size={134,20},proc=tClamp18PopMenuProcCouplingADC,title="CouplingADC",mode=1,popvalue="none",value= #"\"none;0;1;2;3;4;5;6;7\""
End

Function tClamp18PopMenuProcADCRange(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	Variable num_channel
	sscanf ctrlName, "PopuptClampADCRange%f", num_channel
	NVAR ADCRange = $("root:Packages:tClamp18:ADCRange"+ Num2str(num_channel))
	ADCRange = Str2Num(popStr)
	tClamp18SetADCRange(num_channel, ADCRange)
End

Function tClamp18PopMenuProcAmpGain(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	Variable num_channel
	sscanf ctrlName, "PopuptClampAmpGain%f", num_channel
	NVAR AmpGain = $("root:Packages:tClamp18:AmpGainADC"+ Num2str(num_channel))
	AmpGain = Str2Num(popStr)
End

Function tClamp18SetVarProcScalingFactor(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName

	Variable num_channel
	sscanf ctrlName, "SetvartClampScalingADC%f", num_channel
	NVAR Scaling = $("root:Packages:tClamp18:ScalingFactorADC"+Num2str(num_channel))
	Scaling = varNum
End

Function tClamp18PopMenuProcUnitADC(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	Variable num_channel
	sscanf ctrlName, "PopuptClampUnitADC%f", num_channel
	SVAR Unit = $("root:Packages:tClamp18:UnitADC" + Num2str(num_channel))
	Unit = popStr
End

Function tClamp18PopMenuProcCouplingDAC(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	Variable num_channel
	sscanf ctrlName, "PopuptClampCoupling%f", num_channel
	SVAR Coupling = $("root:Packages:tClamp18:CouplingDAC_ADC" + Num2str(num_channel))
	Coupling = popStr
End

Function tClamp18PopMenuProcCouplingADC(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	Variable num_channel
	sscanf ctrlName, "PopuptClampCouplingADC%f", num_channel
	SVAR Coupling = $("root:Packages:tClamp18:CouplingADC_ADC" + Num2str(num_channel))
	Coupling = popStr
End

Function tClamp18ModeSwitch(num_channel, mode)
	Variable num_channel, mode

	If(mode)
		tClamp18CClampSwitch("BttClampADCCCSwitch"+Num2str(num_channel))
	else
		tClamp18VClampSwitch("BttClampADCVCSwitch"+Num2str(num_channel))
	endif
end

Function tClamp18VClampSwitch(ctrlName) : ButtonControl
	String ctrlName
	Variable num_channel
	sscanf ctrlName, "BttClampADCVCSwitch%f", num_channel
	
	NVAR ADCMode = $("root:Packages:tClamp18:ADCMode" +Num2str(num_channel))
	
	NVAR ADCRange = $("root:Packages:tClamp18:ADCRange"+Num2str(num_channel))
	NVAR AmpGainADC =$("root:Packages:tClamp18:AmpGainADC"+Num2str(num_channel))
	NVAR ScalingFactorADC = $("root:Packages:tClamp18:ScalingFactorADC" +Num2str(num_channel))
	SVAR LabelADC = $("root:Packages:tClamp18:LabelADC" + Num2str(num_channel))
	SVAR UnitADC = $("root:Packages:tClamp18:UnitADC" + Num2str(num_channel))
	SVAR AmpGainListADC = $("root:Packages:tClamp18:AmpGainListADC" + Num2str(num_channel))
	SVAR CouplingDAC_ADC = $("root:Packages:tClamp18:CouplingDAC_ADC" + Num2str(num_channel))
	SVAR CouplingADC_ADC = $("root:Packages:tClamp18:CouplingADC_ADC" + Num2str(num_channel))
	
	NVAR ADCRangeVC = $("root:Packages:tClamp18:ADCRangeVC"+Num2str(num_channel))
	NVAR AmpGainADCVC =$("root:Packages:tClamp18:AmpGainADCVC"+Num2str(num_channel))
	NVAR ScalingFactorADCVC = $("root:Packages:tClamp18:ScalingFactorADCVC" +Num2str(num_channel))
	SVAR LabelADCVC = $("root:Packages:tClamp18:LabelADCVC" + Num2str(num_channel))
	SVAR UnitADCVC = $("root:Packages:tClamp18:UnitADCVC" + Num2str(num_channel))
	SVAR AmpGainListADCVC = $("root:Packages:tClamp18:AmpGainListADCVC" + Num2str(num_channel))
	SVAR CouplingDAC_ADCVC = $("root:Packages:tClamp18:CouplingDAC_ADCVC" + Num2str(num_channel))
	SVAR CouplingADC_ADCVC = $("root:Packages:tClamp18:CouplingADC_ADCVC" + Num2str(num_channel))
	
	ADCMode = 0
	
	ADCRange = ADCRangeVC
	AmpGainADC = AmpGainADCVC
	ScalingFactorADC = ScalingFactorADCVC
	LabelADC = LabelADCVC
	UnitADC = UnitADCVC
	AmpGainListADC = AmpGainListADCVC
	CouplingDAC_ADC = CouplingDAC_ADCVC
	CouplingADC_ADC = CouplingADC_ADCVC

	Variable ModeADCRange = tClamp18SearchMode(Num2str(ADCRange), "10;5;2;1")
	Variable ModeAmpGain = tClamp18SearchMode(Num2str(AmpGainADC), AmpGainListADC)
	Variable ModeUnit = tClamp18SearchMode(UnitADC, "A;V")
	Variable ModeCouplingDAC = tClamp18SearchMode(CouplingDAC_ADC, "none;0;1;2;3")
	Variable ModeCouplingADC = tClamp18SearchMode(CouplingADC_ADC, "none;0;1;2;3;4;5;6;7")
	tClamp18UpdatePopupADC(num_channel, ModeADCRange, ModeAmpGain, ModeUnit, ModeCouplingDAC, ModeCouplingADC)

	tClamp18SetADCRange(num_channel, ADCRange)
End

Function tClamp18CClampSwitch(ctrlName) : ButtonControl
	String ctrlName
	Variable num_channel
	sscanf ctrlName, "BttClampADCCCSwitch%f", num_channel
	
	NVAR ADCMode = $("root:Packages:tClamp18:ADCMode" +Num2str(num_channel))
	
	NVAR ADCRange = $("root:Packages:tClamp18:ADCRange"+Num2str(num_channel))
	NVAR AmpGainADC =$("root:Packages:tClamp18:AmpGainADC"+Num2str(num_channel))
	NVAR ScalingFactorADC = $("root:Packages:tClamp18:ScalingFactorADC" +Num2str(num_channel))
	SVAR LabelADC = $("root:Packages:tClamp18:LabelADC" + Num2str(num_channel))
	SVAR UnitADC = $("root:Packages:tClamp18:UnitADC" + Num2str(num_channel))
	SVAR AmpGainListADC = $("root:Packages:tClamp18:AmpGainListADC" + Num2str(num_channel))
	SVAR CouplingDAC_ADC = $("root:Packages:tClamp18:CouplingDAC_ADC" + Num2str(num_channel))
	SVAR CouplingADC_ADC = $("root:Packages:tClamp18:CouplingADC_ADC" + Num2str(num_channel))
	
	NVAR ADCRangeCC = $("root:Packages:tClamp18:ADCRangeCC"+Num2str(num_channel))
	NVAR AmpGainADCCC =$("root:Packages:tClamp18:AmpGainADCCC"+Num2str(num_channel))
	NVAR ScalingFactorADCCC = $("root:Packages:tClamp18:ScalingFactorADCCC" +Num2str(num_channel))
	SVAR LabelADCCC = $("root:Packages:tClamp18:LabelADCCC" + Num2str(num_channel))
	SVAR UnitADCCC = $("root:Packages:tClamp18:UnitADCCC" + Num2str(num_channel))
	SVAR AmpGainListADCCC = $("root:Packages:tClamp18:AmpGainListADCCC" + Num2str(num_channel))
	SVAR CouplingDAC_ADCCC = $("root:Packages:tClamp18:CouplingDAC_ADCCC" + Num2str(num_channel))
	SVAR CouplingADC_ADCCC = $("root:Packages:tClamp18:CouplingADC_ADCCC" + Num2str(num_channel))
	
	ADCMode = 1
	
	ADCRange = ADCRangeCC
	AmpGainADC = AmpGainADCCC
	ScalingFactorADC = ScalingFactorADCCC
	LabelADC = LabelADCCC
	UnitADC = UnitADCCC
	AmpGainListADC = AmpGainListADCCC
	CouplingDAC_ADC = CouplingDAC_ADCCC
	CouplingADC_ADC = CouplingADC_ADCCC
	
	Variable ModeADCRange = tClamp18SearchMode(Num2str(ADCRange), "10;5;2;1")
	Variable ModeAmpGain = tClamp18SearchMode(Num2str(AmpGainADC), AmpGainListADC)
	Variable ModeUnit = tClamp18SearchMode(UnitADC, "A;V")
	Variable ModeCouplingDAC = tClamp18SearchMode(CouplingDAC_ADC, "none;0;1;2;3")
	Variable ModeCouplingADC = tClamp18SearchMode(CouplingADC_ADC, "none;0;1;2;3;4;5;6;7")
	tClamp18UpdatePopupADC(num_channel, ModeADCRange, ModeAmpGain, ModeUnit, ModeCouplingDAC, ModeCouplingADC)

	tClamp18SetADCRange(num_channel, ADCRange)
End

Function tClamp18SearchMode(searchStr, StrList)
	String SearchStr, StrList
			
	Variable i = 0
	Variable mode = 1
	String SFL
	do
		SFL = StringFromList(i, StrList)
		if(Strlen(SFL) == 0)
			break
		endif
		If(StringMatch(SearchStr, SFL))
			mode = i + 1
			break
		endIf
		i += 1
	while(1)
	
	return mode
end

Function tClamp18UpdatePopupADC(num_channel, ModeADCRange, ModeAmpGain, ModeUnit, ModeCouplingDAC, ModeCouplingADC)
	Variable num_channel, ModeADCRange, ModeAmpGain, ModeUnit, ModeCouplingDAC, ModeCouplingADC

	If(Wintype("tClamp18ADC" + Num2str(num_channel)) == 7)
		PopupMenu $("PopuptClampADCRange" + Num2str(num_channel)) win = $("tClamp18ADC" + Num2str(num_channel)), mode = ModeADCRange
		PopupMenu $("PopuptClampAmpGain" + Num2str(num_channel)) win = $("tClamp18ADC" + Num2str(num_channel)), mode = ModeAmpGain
		PopupMenu $("PopuptClampUnitADC" + Num2str(num_channel)) win = $("tClamp18ADC" + Num2str(num_channel)), mode = ModeUnit
		PopupMenu $("PopuptClampCoupling" + Num2str(num_channel)) win = $("tClamp18ADC" + Num2str(num_channel)), mode = ModeCouplingDAC
		PopupMenu $("PopuptClampCouplingADC" + Num2str(num_channel)) win = $("tClamp18ADC" + Num2str(num_channel)), mode = ModeCouplingADC
	endif
end

Function tClamp18SetADCRange(num_channel, ADCRange)
	Variable num_channel, ADCRange
	
	String tobeExecuted = "ITC18SetADCRange "
	tobeExecuted += Num2str(num_channel) + ", " + Num2str(ADCRange)
	Execute/Q tobeExecuted
end

Function tClamp18DACADCShowHide(ctrlName) : ButtonControl
	String ctrlName

	String SFL = ""
	Variable i = 0

	do
		SFL = StringFromList(i, WinList("tClamp18DAC*",";","WIN:64"))
		if(strlen(SFL) == 0)
			break
		endif
		StrSwitch(ctrlName)
			case "BtDACShow_tab0" :
				DoWindow/HIDE = 1 $SFL
				DoWindow/HIDE = 0 $SFL
				DoWindow/F $SFL
				break
			case "BtDACHide_tab0" :
				DoWindow/HIDE = 1 $SFL
				break			
			default :
				break
		endSwitch
		i += 1
	while(1)
	 
	 i = 0
	do
		SFL = StringFromList(i, WinList("tClamp18ADC*",";","WIN:64"))
		if(strlen(SFL) == 0)
			break
		endif
		StrSwitch(ctrlName)
			case "BtADCShow_tab0" :
				DoWindow/HIDE = 1 $SFL
				DoWindow/HIDE = 0 $SFL
				break
			case "BtADCHide_tab0" :
				DoWindow/HIDE = 1 $SFL
				break			
			default :
				break
		endSwitch
		i += 1
	while(1)
End

Proc tClamp18CheckProcDigitalOut1Bit(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	tClamp18BitUpdate("root:Packages:tClamp18:DigitalOut1Check", "root:Packages:tClamp18:DigitalOut1Bit", 4)
	ITC18WriteDigital1 $("root:Packages:tClamp18:DigitalOut1Bit")
End

//End DAC and ADC
////////////////////////////////////////////////////////////
//Oscilloscope

Function tClamp18OscilloCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	Variable num_channel

	sscanf ctrlName, "ChecktClampOscilloADC%f", num_channel
	If(checked)
		If(WinType("tClamp18OscilloADC"+Num2str(num_channel)) == 1)
			DoWindow/HIDE = ? $("tClamp18OscilloADC"+Num2str(num_channel))
			If(V_flag == 1)
				DoWindow/HIDE = 1 $("tClamp18OscilloADC"+Num2str(num_channel))
			else
				DoWindow/HIDE = 0/F $("tClamp18OscilloADC"+Num2str(num_channel))
			endif
		else	
			tClamp18NewOscilloADC(num_channel)
		endif
	else
		DoWindow/HIDE = 1 $("tClamp18OscilloADC"+Num2str(num_channel))
	endif
	
	tClamp18BitUpdate("root:Packages:tClamp18:OscilloTestCheckADC", "root:Packages:tClamp18:OscilloBit", 8)
End

Function tClamp18NewOscilloADC(num_channel)
	Variable num_channel

	NVAR OscilloFreq = root:Packages:tClamp18:OscilloFreq
	SVAR UnitADC = $("root:Packages:tClamp18:UnitADC" + Num2str(num_channel))

	Wave ScaledADC = $("root:Packages:tClamp18:ScaledADC" + Num2str(num_channel))
	SetScale/P x 0, (1/OscilloFreq), "s", ScaledADC
	Wave OscilloADC = $("root:Packages:tClamp18:OscilloADC" + Num2str(num_channel))
	SetScale/P x 0, (1/OscilloFreq), "s", OscilloADC
	Display/W=(397.5+27*num_channel,299.75-20*num_channel,674.25+27*num_channel,538.25-20*num_channel)/N=$("tClamp18OscilloADC"+Num2str(num_channel)) ScaledADC
	ModifyGraph rgb=(0,0,0)
	ModifyGraph live ($("ScaledADC" + Num2str(num_channel))) = 1
	Label left ("\\u"+UnitADC)
	ControlBar 40
	Button BtYPlus,pos={44,0},size={20,20},proc=tClamp18GraphScale,title="+"
	Button BtYMinus,pos={44,19},size={20,20},proc=tClamp18GraphScale,title="-"
	Button BtXMinus,pos={1,1},size={20,20},proc=tClamp18GraphScale,title="-"
	Button BtXPlus,pos={20,1},size={20,20},proc=tClamp18GraphScale,title="+"
	SetVariable $("SetvarExpandOSCGraph" + Num2str(num_channel)),pos={3,21},size={38,16},proc=tClamp18SetVarProcGraphExpand,title=" ",limits={0.5,8,0.5},value= $("root:Packages:tClamp18:OscilloExpand" + Num2str(num_channel))
	Button $("BttClampAscaleOSCADC"+Num2str(num_channel)),pos={68, 0},size={50,20},proc=tClamp18AscaleOSCADC,title="Auto"
	Button $("BttClampFscaleOSCADC"+Num2str(num_channel)),pos={68, 19},size={50,20},proc=tClamp18FscaleOSCADC,title="Full"
	Button $("BtClearCmdPulse" + Num2str(num_channel)),pos={120,1},size={50,20},proc=tClamp18CmdClear,title="Cmd (V)",fColor=(32768,40704,65280)
	SetVariable $("SetvarSetCmdPulse" + Num2str(num_channel)),pos={173,3},size={50,16},proc=tClamp18SetVarCheckCouplingADC,title=" ",limits={-10,10,0.01},value= $("root:Packages:tClamp18:OscilloCmdPulse" + Num2str(num_channel))
	CheckBox $("CheckOscilloCmd" + Num2str(num_channel)),pos={120,23},size={108,14},title="Command On/Off",variable= $("root:Packages:tClamp18:OscilloCmdOnOff" + Num2str(num_channel))
	CheckBox $("ChecktClampOSCLiveMode"+Num2str(num_channel)),pos={232,4},size={70,14},proc=tClamp18OSCLiveModeCheckProc,title="Live mode",value= 1
	SetDrawLayer UserFront
End

Function tClamp18SetVarProcGraphExpand(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	ModifyGraph expand = varNum
End

Function tClamp18SetVarCheckCouplingADC(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName

	Variable num_channel	
	Switch(strlen(varName))
		case 16:	
			sscanf varName, "OscilloCmdPulse%f", num_channel
			SVAR CouplingADC = $("root:Packages:tClamp18:CouplingADC_ADC" + Num2str(num_channel))
			If(strlen(CouplingADC) != 1)
				Abort
			endif
			NVAR CouplingPulse = $("root:Packages:tClamp18:OscilloCmdPulse" + CouplingADC)
			break			
		case 14:
			sscanf varName, "SealTestPulse%f", num_channel
			SVAR CouplingADC = $("root:Packages:tClamp18:CouplingADC_ADC" + Num2str(num_channel))
			If(strlen(CouplingADC) != 1)
				Abort
			endif
			NVAR CouplingPulse = $("root:Packages:tClamp18:SealTestPulse" + CouplingADC)
			break
		default:
			Abort
			break
	endswitch

	CouplingPulse = varNum
End

Function tClamp18OSCLiveModeCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	Variable num_channel
	
	sscanf ctrlName, "ChecktClampOSCLiveMode%f", num_channel
	ModifyGraph live($("ScaledADC" + Num2str(num_channel))) = checked
End

Function tClamp18AscaleOSCADC(ctrlName) : ButtonControl
	String ctrlName
	
	Variable num_channel
	sscanf ctrlName, "BttClampAscaleOSCADC%f", num_channel
	NVAR OscilloFreq = root:Packages:tClamp18:OscilloFreq
	SVAR UnitADC = $("root:Packages:tClamp18:UnitADC" + Num2str(num_channel))
	Wave ScaledADC = $("root:Packages:tClamp18:ScaledADC" + Num2str(num_channel))
	SetScale/P x 0, (1/OscilloFreq), "s", ScaledADC
	Wave OscilloADC = $("root:Packages:tClamp18:OscilloADC" + Num2str(num_channel))
	SetScale/P x 0, (1/OscilloFreq), "s", OscilloADC
	SetAxis/A left
	Label left ("\\u"+UnitADC)
	SetAxis/A bottom
	
	Wave DigitalOut0 = $("root:Packages:tClamp18:DigitalOut0")
	SetScale/P x 0, (1/OscilloFreq), "s", DigitalOut0
	Wave DigitalOut1 = $("root:Packages:tClamp18:DigitalOut1")
	SetScale/P x 0, (1/OscilloFreq), "s", DigitalOut1
End

Function tClamp18FscaleOSCADC(ctrlName) : ButtonControl
	String ctrlName
	
	Variable num_channel
	sscanf ctrlName, "BttClampFscaleOSCADC%f", num_channel
	NVAR OscilloFreq = root:Packages:tClamp18:OscilloFreq
	SVAR UnitADC = $("root:Packages:tClamp18:UnitADC" + Num2str(num_channel))
	Wave ScaledADC = $("root:Packages:tClamp18:ScaledADC" + Num2str(num_channel))
	SetScale/P x 0, (1/OscilloFreq), "s", ScaledADC
	Wave OscilloADC = $("root:Packages:tClamp18:OscilloADC" + Num2str(num_channel))
	SetScale/P x 0, (1/OscilloFreq), "s", OscilloADC
	Label left ("\\u"+UnitADC)
	SetAxis/A bottom

	NVAR ADCRange = $("root:Packages:tClamp18:ADCRange"+ Num2str(num_channel))
	NVAR AmpGainADC = $("root:Packages:tClamp18:AmpGainADC" + Num2str(num_channel))
	NVAR ScalingFactorADC = $("root:Packages:tClamp18:ScalingFactorADC" + Num2str(num_channel))
	NVAR ADCOffset = $("root:Packages:tClamp18:ADCOffset" + Num2str(num_channel))
	NVAR InputOffset =  $("root:Packages:tClamp18:InputOffset"+ Num2str(num_channel))
	
	Variable leftmax = (+1.024*ADCRange + ADCOffset*AmpGainADC + InputOffset) /(AmpGainADC*ScalingFactorADC)
	Variable leftmin = (-1.024*ADCRange + ADCOffset*AmpGainADC + InputOffset) /(AmpGainADC*ScalingFactorADC)
	SetAxis/A left leftmin, leftmax

	Wave DigitalOut0 = $("root:Packages:tClamp18:DigitalOut0")
	SetScale/P x 0, (1/OscilloFreq), "s", DigitalOut0
	Wave DigitalOut1 = $("root:Packages:tClamp18:DigitalOut1")
	SetScale/P x 0, (1/OscilloFreq), "s", DigitalOut1
end

Function tClamp18RescaleAllOSCADC()
	NVAR OscilloFreq = root:Packages:tClamp18:OscilloFreq	
	Variable num_channel = 0
	
	do
		SVAR UnitADC = $("root:Packages:tClamp18:UnitADC" + Num2str(num_channel))
		Wave ScaledADC = $("root:Packages:tClamp18:ScaledADC" + Num2str(num_channel))
		SetScale/P x 0, (1/OscilloFreq), "s", ScaledADC
		Wave OscilloADC = $("root:Packages:tClamp18:OscilloADC" + Num2str(num_channel))
		SetScale/P x 0, (1/OscilloFreq), "s", OscilloADC
		If(WinType("tClamp18OscilloADC" + Num2str(num_channel)) == 1)
			Label/W = $("tClamp18OscilloADC" + Num2str(num_channel)) left ("\\u"+UnitADC)
		endif
		num_channel += 1
	while(num_channel <=7)
	
	Wave DigitalOut0 = $("root:Packages:tClamp18:DigitalOut0")
	SetScale/P x 0, (1/OscilloFreq), "s", DigitalOut0
	Wave DigitalOut1 = $("root:Packages:tClamp18:DigitalOut1")
	SetScale/P x 0, (1/OscilloFreq), "s", DigitalOut1
End

Function tClamp18CmdClear(ctrlName) : ButtonControl
	String ctrlName
	
	Variable num_channel
	sscanf ctrlName, "BtClearCmdPulse%f", num_channel
	NVAR OscilloCmdPulse = $("root:Packages:tClamp18:OscilloCmdPulse" + Num2str(num_channel))
	
	OscilloCmdPulse = 0
	
	tClamp18SetVarCheckCouplingADC("",OscilloCmdPulse,Num2str(OscilloCmdPulse),("OscilloCmdPulse" + Num2str(num_channel)))
End

Function tClamp18EditRecordingChecks(ctrlName) : ButtonControl
	String ctrlName

	NewPanel/N=EditRecordingCheckADCs/W=(368,91,633,144)
	CheckBox ChecktClampRecordingADC0_tab1,pos={14,9},size={24,14},title="0",variable= root:Packages:tClamp18:RecordingCheckADC0
	CheckBox ChecktClampRecordingADC1_tab1,pos={44,9},size={24,14},title="1",variable= root:Packages:tClamp18:RecordingCheckADC1
	CheckBox ChecktClampRecordingADC2_tab1,pos={74,9},size={24,14},title="2",variable= root:Packages:tClamp18:RecordingCheckADC2
	CheckBox ChecktClampRecordingADC3_tab1,pos={104,9},size={24,14},title="3",variable= root:Packages:tClamp18:RecordingCheckADC3
	CheckBox ChecktClampRecordingADC4_tab1,pos={134,9},size={24,14},title="4",variable= root:Packages:tClamp18:RecordingCheckADC4
	CheckBox ChecktClampRecordingADC5_tab1,pos={164,9},size={24,14},title="5",variable= root:Packages:tClamp18:RecordingCheckADC5
	CheckBox ChecktClampRecordingADC6_tab1,pos={194,9},size={24,14},title="6",variable= root:Packages:tClamp18:RecordingCheckADC6
	CheckBox ChecktClampRecordingADC7_tab1,pos={224,9},size={24,14},title="7",variable= root:Packages:tClamp18:RecordingCheckADC7
	Button BtKillTempEditPanelForRCAs,pos={102,27},size={50,20},proc=tClamp18KillTempPanelForRCAs,title="OK"
End

Function tClamp18KillTempPanelForRCAs(ctrlName) : ButtonControl
	String ctrlName
	
	KillWindow EditRecordingCheckADCs
	tClamp18BitUpdate("root:Packages:tClamp18:RecordingCheckADC", "root:Packages:tClamp18:RecordingBit", 8)
End

Function tClamp18CheckProcRecordingBit(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	tClamp18BitUpdate("root:Packages:tClamp18:RecordingCheckADC", "root:Packages:tClamp18:RecordingBit", 8)
End

Function tClamp18OSCShowHide(ctrlName) : ButtonControl
	String ctrlName

	String SFL
	Variable i = 0

	do
		SFL = StringFromList(i, WinList("tClamp18OscilloADC*",";","WIN:1"))
		if(strlen(SFL) == 0)
			break
		endif
		StrSwitch(ctrlName)
			case "BtOSCShow_tab1" :
				DoWindow/HIDE = 1 $SFL
				DoWindow/HIDE = 0 $SFL
				DoWindow/F $SFL
				break
			case "BtOSCHide_tab1" :
				DoWindow/HIDE = 1 $SFL
				break
			default :
				break
		endSwitch
		i += 1
	while(1)
End

Function tClamp18ApplyProtocolSetting()
	SVAR SelectedProtocol = root:Packages:tClamp18:SelectedProtocol
	SVAR StrITC18SeqDAC = root:Packages:tClamp18:StrITC18SeqDAC
	SVAR StrITC18SeqADC = root:Packages:tClamp18:StrITC18SeqADC
	
	NVAR RecordingCheckADC0 =  root:Packages:tClamp18:RecordingCheckADC0
	NVAR RecordingCheckADC1 =  root:Packages:tClamp18:RecordingCheckADC1
	NVAR RecordingCheckADC2 =  root:Packages:tClamp18:RecordingCheckADC2
	NVAR RecordingCheckADC3 =  root:Packages:tClamp18:RecordingCheckADC3
	NVAR RecordingCheckADC4 =  root:Packages:tClamp18:RecordingCheckADC4
	NVAR RecordingCheckADC5 =  root:Packages:tClamp18:RecordingCheckADC5
	NVAR RecordingCheckADC6 =  root:Packages:tClamp18:RecordingCheckADC6
	NVAR RecordingCheckADC7 =  root:Packages:tClamp18:RecordingCheckADC7

	NVAR OscilloCounterLimit =  root:Packages:tClamp18:OscilloCounterLimit
	NVAR OscilloSamplingNpnts =  root:Packages:tClamp18:OscilloSamplingNpnts
	NVAR OscilloITC18ExtTrig =  root:Packages:tClamp18:OscilloITC18ExtTrig
	NVAR OscilloITC18Output =  root:Packages:tClamp18:OscilloITC18Output
	NVAR OscilloITC18Overflow =  root:Packages:tClamp18:OscilloITC18Overflow
	NVAR OscilloITC18Reserved =  root:Packages:tClamp18:OscilloITC18Reserved
	NVAR OscilloITC18Period =  root:Packages:tClamp18:OscilloITC18Period
	
	String/G StrAcquisitionProcName = SelectedProtocol		//any name of acquisition macro
	Variable/G RecordingBit = tClamp18BitCoder(RecordingCheckADC0, RecordingCheckADC1, RecordingCheckADC2, RecordingCheckADC3, RecordingCheckADC4, RecordingCheckADC5, RecordingCheckADC6, RecordingCheckADC7) 		
	Variable/G OscilloITC18Flags = tClamp18BitCoder(OscilloITC18ExtTrig, OscilloITC18Output, OscilloITC18Overflow, OscilloITC18Reserved, 0, 0, 0, 0)
	Variable/G OscilloITC18StrlenSeq = Strlen(StrITC18SeqDAC)
	
	Wave OscilloADC0, OscilloADC1, OscilloADC2, OscilloADC3, OscilloADC4, OscilloADC5, OscilloADC6, OscilloADC7, ScaledADC0, ScaledADC1, ScaledADC2, ScaledADC3, ScaledADC4, ScaledADC5, ScaledADC6, ScaledADC7, DigitalOut0, DigitalOut1, FIFOOut, FIFOin
	Redimension/N = (OscilloSamplingNpnts) OscilloADC0, OscilloADC1, OscilloADC2, OscilloADC3, OscilloADC4, OscilloADC5, OscilloADC6, OscilloADC7, ScaledADC0, ScaledADC1, ScaledADC2, ScaledADC3, ScaledADC4, ScaledADC5, ScaledADC6, ScaledADC7, DigitalOut0, DigitalOut1
	Redimension/N = (OscilloSamplingNpnts*OscilloITC18StrlenSeq) FIFOOut, FIFOin
	
	tClamp18UpDateOSCFreqAndAcqTime()
end

Function tClamp18ProtocolRun(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR ISI = root:Packages:tClamp18:TimerISI
	NVAR npnts = root:Packages:tClamp18:OscilloSamplingNpnts
	
	tClamp18OSCShowHide("BtOSCShow_tab1")
	
	tClamp18OscilloRedimension(ctrlName,npnts,"","")
	
	SetBackground  tClamp18ProtocolBGFlowControl()
	If(StringMatch(ctrlName, "BttClampProtocolRun_tab1"))
		tClamp18TimerReset("")
	endif
	CtrlBackground period=ISI,dialogsOK=1,noBurst=1,start
End

Function tClamp18ProtocolBGFlowControl()
	NVAR ISI = root:Packages:tClamp18:OscilloISI
	NVAR Counter = root:Packages:tClamp18:OscilloCounter
	NVAR CounterLimit = root:Packages:tClamp18:OscilloCounterLimit
	NVAR TimerISITicks = root:Packages:tClamp18:TimerISITicks
	NVAR NumTrial = root:Packages:tClamp18:NumTrial
	SVAR SelectedProtocol = root:Packages:tClamp18:SelectedProtocol
	
	Variable now = ticks

	If(ISI <= (now - TimerISITicks)|| Counter ==0)
		TimerISITicks = now

		Execute/Q SelectedProtocol
		tClamp18OSCInterleave()
		Execute/Q "tClamp18OSCStimAndSample()"
		
		tClamp18ScaledADCDuplicate()
		Counter += 1
	endIf

	tClamp18TimerUpdate()
	
	If(Counter < CounterLimit || CounterLimit == 0)
		return 0
	else
		NumTrial += 1
		return 1
	endif
End

Function tClamp18OSCInterleave()
	NVAR StrlenSeq = root:Packages:tClamp18:OscilloITC18StrlenSeq
	SVAR SeqDAC = root:Packages:tClamp18:StrITC18SeqDAC

	Wave FIFOout = $"root:Packages:tClamp18:FIFOout"
	
	Variable num_DAC = 0, i = 0, j = 0
	
	do
		StrSwitch (SeqDAC[i])
			case "T":
				Wave DigitalOut0 = $"root:Packages:tClamp18:DigitalOut0"
				FIFOout[i,numpnts(FIFOout)-(StrlenSeq-i);StrlenSeq]=DigitalOut0[p/StrlenSeq]
				break
			case "D":
				Wave DigitalOut1 = $"root:Packages:tClamp18:DigitalOut1"
				FIFOout[i,numpnts(FIFOout)-(StrlenSeq-i);StrlenSeq]=DigitalOut1[p/StrlenSeq]
				break
			case "N":
				break
			default:
				Variable num_ADC 
				For(j = 0; j < 8; j += 1)
					SVAR CouplingDAC_ADC = $("root:Packages:tClamp18:CouplingDAC_ADC" + Num2str(j))
					If(Stringmatch(CouplingDAC_ADC, SeqDAC[i]))
						num_ADC = j
						Wave OscilloADC = $("root:Packages:tClamp18:OscilloADC" + Num2str(num_ADC))
						FIFOout[i,numpnts(FIFOout)-(StrlenSeq-i);StrlenSeq]=OscilloADC[p/StrlenSeq]
//						break
					endif
				endfor
				break
		endSwitch
		i += 1
	while(i < StrlenSeq)
end

Proc tClamp18OSCStimAndSample()
	silent 1	// retrieving data...

	//Global Strings
	String SeqDAC = "root:Packages:tClamp18:StrITC18SeqDAC"
	String SeqADC = "root:Packages:tClamp18:StrITC18SeqADC"
	//Global Variables
	String Period = "root:Packages:tClamp18:OscilloITC18Period"
	String Flags = "root:Packages:tClamp18:OscilloITC18Flags"
	//Global Waves	
	String FIFOout = "root:Packages:tClamp18:FIFOout"
	String FIFOin = "root:Packages:tClamp18:FIFOin"

	Variable InitDAC0 = tClamp18InitDAC("0")
	Variable InitDAC1 = tClamp18InitDAC("1")
	Variable InitDAC2 = tClamp18InitDAC("2")
	Variable InitDAC3 = tClamp18InitDAC("3")

	ITC18SetAll InitDAC0,InitDAC1,InitDAC2,InitDAC3,0,0		// bug!! don't pre-set Digital output channels. If they are set, all digial output channels will unintendedly fire.
	ITC18seq $SeqDAC, $SeqADC

	PauseUpdate

	ITC18StimandSample $FIFOout, $FIFOin, $Period, $Flags, 0
	tClamp18OSCScalingDeinterleave()
    
      ResumeUpdate
EndMacro

Function tClamp18InitDAC(instr)
	String instr
	
	SVAR  SeqADC = root:Packages:tClamp18:StrITC18SeqADC
	Wave FIFOout = $"root:Packages:tClamp18:FIFOout"
	Variable SeqPos = StrSearch(SeqADC, instr, 0)
	
	If(SeqPos == -1)
		return 0
	else
		return FIFOout[SeqPos]/3200
	endIf	
end

Function tClamp18OSCScalingDeinterleave()
	Variable Offset = 0
	Variable i = 0
	Variable num_channel = 0
	
	SVAR SeqADC = root:Packages:tClamp18:StrITC18SeqADC
	NVAR StrlenSeq = root:Packages:tClamp18:OscilloITC18StrlenSeq
	
	Wave FIFOin = $"root:Packages:tClamp18:FIFOin"
	
	do
		StrSwitch (SeqADC[i])
			case "D":
				break
			case "N":
				break
			default:
				sscanf SeqADC[i], "%d", num_channel
				NVAR ADCRange = $("root:Packages:tClamp18:ADCRange"+ Num2str(num_channel))
				NVAR AmpGainADC = $("root:Packages:tClamp18:AmpGainADC" + Num2str(num_channel))
				NVAR ScalingFactorADC = $("root:Packages:tClamp18:ScalingFactorADC" + Num2str(num_channel))
				NVAR ADCOffset = $("root:Packages:tClamp18:ADCOffset" + Num2str(num_channel))
				NVAR InputOffset =  $("root:Packages:tClamp18:InputOffset"+ Num2str(num_channel))
				NVAR ADCValueVolt = $("root:Packages:tClamp18:ADCValueVolt" + Num2str(num_channel))
				NVAR ADCValuePoint = $("root:Packages:tClamp18:ADCValuePoint" + Num2str(num_channel))
		
				Wave ScaledADC = $("root:Packages:tClamp18:ScaledADC" +  Num2str(num_channel))
	
				ScaledADC[0, ] = (FIFOin[StrlenSeq * p + i] *(ADCRange/10)/3200 + ADCOffset*AmpGainADC + InputOffset) /(AmpGainADC*ScalingFactorADC)
		
				ADCValueVolt = FIFOin[i]/3200
				ADCValuePoint = FIFOin[i]
				break
		endSwitch
		i += 1
	while(i < StrlenSeq)
End

Function tClamp18ScaledADCDuplicate()
	NVAR NumTrial = root:Packages:tClamp18:NumTrial
	NVAR Counter = root:Packages:tClamp18:OscilloCounter
	
	Variable num_channel = 0
	
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp18
	
	do
		NVAR RecordingCheckADC = $("root:Packages:tClamp18:RecordingCheckADC" + Num2str(num_channel))
		If(RecordingCheckADC)
			Duplicate/O $("ScaledADC"+Num2str(num_channel)), $("Temp_"+Num2str(NumTrial) + "_"+ Num2str(num_channel) + "_" + Num2str(Counter))
			If(WinType("tClamp18OscilloADC" + Num2str(num_channel)) == 0)
				tClamp18NewOscilloADC(num_channel)
			endif
			AppendToGraph/W=$("tClamp18OscilloADC" + Num2str(num_channel)) $("Temp_"+Num2str(NumTrial) + "_"+ Num2str(num_channel) + "_" + Num2str(Counter))
			RemoveFromGraph/W=$("tClamp18OscilloADC" + Num2str(num_channel)) $("ScaledADC" + Num2str(num_channel))
			AppendToGraph/W=$("tClamp18OscilloADC" + Num2str(num_channel))	$("ScaledADC" + Num2str(num_channel))
			ModifyGraph/W=$("tClamp18OscilloADC" + Num2str(num_channel)) rgb($("ScaledADC" + Num2str(num_channel))) = (0,0,0)
		endIf
		num_channel += 1
	While(num_channel < 8)
	
	SetDataFolder fldrSav0	
end

Function tClamp18ProtocolSave(ctrlName) : ButtonControl
	String ctrlName
	
	tClamp18_FolderCheck()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp18

	String SFL = ""
	String SFLWave = ""
	Variable i = 0, num_channel = 0
	String WaveListTemp = ""
	
	i = 0
	do
		For(num_channel = 0; num_channel < 8; num_channel += 1)
			WaveListTemp += WaveList("Temp_" + Num2str(i) + "_" + Num2str(num_channel) + "_*", ";", "")
		endFor
		If(Strlen(WaveListTemp) == Strlen(WaveList("Temp_*_*_*", ";", "")))
			break
		endif
		i += 1
	while(1)
	
	i = 0
	do
		SFL = StringFromList(i, WaveListTemp)
		if(Strlen(SFL) == 0)
			break
		endif
		SFLWave = ReplaceString("Temp", SFL, "w")
		Duplicate/O $SFL, root:$SFLWave
		i += 1		
	while(1)

	SetDataFolder fldrSav0
End

Function tClamp18ClearTempWaves(ctrlName) : ButtonControl
	String ctrlName

	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp18
	
	String SFL = ""
	String SFLWave = ""
	Variable i = 0, j = 0, k = 0,  num_channel = 0
	
	do
		SFL = StringFromList(i, WaveList("Temp*", ";", ""))
		if(strlen(SFL) == 0)
			break
		endif
		sscanf SFL, "Temp_%f_%f_%f", j, num_channel, k
		If(WinType("tClamp18OscilloADC" + Num2str(num_channel)) == 1)
			RemoveFromGraph/Z/W=$("tClamp18OscilloADC" + Num2str(num_channel)) $SFL
		endif
		KillWaves $SFL
	while(1)
	
	SetDataFolder fldrSav0
End

Function tClamp18EditProtocol(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR SelectedProtocol = root:Packages:tClamp18:SelectedProtocol
	Variable StrlenSrcProc = strlen(SelectedProtocol)
	Print SelectedProtocol[0, StrlenSrcProc - 2]
	 DisplayProcedure/W= $(SelectedProtocol[0, StrlenSrcProc - 3]+".ipf") SelectedProtocol[0, StrlenSrcProc - 3]
End

Function tClamp18ResetNumTrial(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR NumTrial = root:Packages:tClamp18:NumTrial
	
	NumTrial = 0
End

Function tClamp18EditITC18Seq(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR StrITC18SeqDAC = root:Packages:tClamp18:StrITC18SeqDAC
	SVAR StrITC18SeqADC = root:Packages:tClamp18:StrITC18SeqADC
	NVAR OscilloITC18StrlenSeq = root:Packages:tClamp18:OscilloITC18StrlenSeq
	
	String DAC, ADC
	
	Prompt DAC "DACSeq"
	Prompt ADC "ADCSeq"
	DoPrompt "DAC and ADC must be in same length.", DAC, ADC
	If(V_flag)
		Abort
	endif
	
	If(Strlen(DAC) != Strlen(ADC))
		DoAlert 0, "Different length! DAC and ADC must be in same length."
		Abort
	endIf
	
	StrITC18SeqDAC = DAC
	StrITC18SeqADC = ADC
	OscilloITC18StrlenSeq = Strlen(StrITC18SeqDAC)
	
	tClamp18UpDateOSCFreqAndAcqTime()
End

Function tClamp18SetVarProcOscilloFreq(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	tClamp18UpDateOSCFreqAndAcqTime()
End

Function tClamp18UpDateOSCFreqAndAcqTime()
	NVAR OscilloITC18StrlenSeq = root:Packages:tClamp18:OscilloITC18StrlenSeq
	NVAR OscilloITC18Period = root:Packages:tClamp18:OscilloITC18Period
	NVAR OscilloFreq = root:Packages:tClamp18:OscilloFreq
	NVAR OscilloSamplingNpnts = root:Packages:tClamp18:OscilloSamplingNpnts
	NVAR OscilloAcqTime = root:Packages:tClamp18:OscilloAcqTime
	
	OscilloFreq = 1/(1.25E-06*OscilloITC18Period*OscilloITC18StrlenSeq)
	OscilloAcqTime = OscilloSamplingNpnts/OscilloFreq
	
	If(OscilloITC18StrlenSeq * OscilloFreq > 200000)
		DoAlert 0, "Too Much Freq!!"
	endif
	
	tClamp18RescaleAllOSCADC()
end

Function tClamp18OscilloRedimension(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName

	NVAR OscilloITC18StrlenSeq = root:Packages:tClamp18:OscilloITC18StrlenSeq

	tClamp18_FolderCheck()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp18

	Wave FIFOout, FIFOin, OscilloADC0, OscilloADC1, OscilloADC2, OscilloADC3, OscilloADC4, OscilloADC5, OscilloADC6, OscilloADC7, ScaledADC0, ScaledADC1, ScaledADC2, ScaledADC3, ScaledADC4, ScaledADC5, ScaledADC6, ScaledADC7, DigitalOut0, DigitalOut1
	Redimension/N = (varNum) OscilloADC0, OscilloADC1, OscilloADC2, OscilloADC3, OscilloADC4, OscilloADC5, OscilloADC6, OscilloADC7, ScaledADC0, ScaledADC1, ScaledADC2, ScaledADC3, ScaledADC4, ScaledADC5, ScaledADC6, ScaledADC7, DigitalOut0, DigitalOut1
	Redimension/N = (varNum*OscilloITC18StrlenSeq) FIFOout, FIFOin
	
	tClamp18UpDateOSCFreqAndAcqTime()

	SetDataFolder fldrSav0
End

Function tClamp18CheckProcITC18Flags(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	NVAR OscilloITC18Flags = root:Packages:tClamp18:OscilloITC18Flags
	NVAR OscilloITC18ExtTrig = root:Packages:tClamp18:OscilloITC18ExtTrig
	NVAR OscilloITC18Output = root:Packages:tClamp18:OscilloITC18Output
	NVAR OscilloITC18Overflow = root:Packages:tClamp18:OscilloITC18Overflow
	NVAR OscilloITC18Reserved = root:Packages:tClamp18:OscilloITC18Reserved
	
	OscilloITC18Flags = tClamp18BitCoder(OscilloITC18ExtTrig, OscilloITC18Output, OscilloITC18Overflow, OscilloITC18Reserved, 0, 0, 0, 0)
End

//End Oscillo
////////////////////////////////////////////////////////////////////////////
//SealTest

Function tClamp18SealTestBGRun(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR ISI = root:Packages:tClamp18:TimerISI
	NVAR npnts = root:Packages:tClamp18:SealSamplingNpnts
	
	tClamp18MainSealShowHide("BttClampMainSealTestShow_tab2")
	
	tClamp18SealRedimension(ctrlName,npnts,"","")
	SetBackground  tClamp18SealTestBGFlowControl()
	tClamp18TimerReset("")
	CtrlBackground period=ISI,dialogsOK=1,noBurst=1,start
end

Function tClamp18SealTestBGFlowControl()
	NVAR ISI = root:Packages:tClamp18:SealTestISI
	NVAR Counter = root:Packages:tClamp18:SealTestCounter
	NVAR CounterLimit = root:Packages:tClamp18:SealTestCounterLimit
	NVAR TimerISITicks = root:Packages:tClamp18:TimerISITicks

	Variable now = ticks

	If(ISI <= (now - TimerISITicks))
		TimerISITicks = now
		tClamp18SealInterleave()
		Execute/Q "tClamp18SealStimAndSample()"
		tClamp18PipetteUpdate()
		Counter += 1
	endIf

	tClamp18TimerUpdate()
	If(Counter < CounterLimit || CounterLimit == 0)
		return 0
	endif
end

Function tClamp18SealInterleave()
	NVAR TrigOut = root:Packages:tClamp18:SealITC18TrigOut
	NVAR StrlenSeq = root:Packages:tClamp18:SealITC18StrlenSeq
	NVAR npnts = root:Packages:tClamp18:SealSamplingNpnts
	SVAR SeqADC = root:Packages:tClamp18:SealITC18SeqADC
	
	Wave DigitalOutSeal1 = $"root:Packages:tClamp18:DigitalOutSeal1"	
	Wave FIFOout = $"root:Packages:tClamp18:FIFOout"
	
	Variable num_channel = 0, i = 0
	
	If(Trigout)
		If(StrlenSeq != 1)
			do
				sscanf SeqADC[i], "%d", num_channel
				Wave SealTestPntsADC = $("root:Packages:tClamp18:SealTestPntsADC" + Num2str(num_channel))
				NVAR TestPulse = $("root:Packages:tClamp18:SealTestPulse" + Num2str(num_channel))
				SealTestPntsADC = 0
				SealTestPntsADC[trunc(npnts*0.2), trunc(npnts*0.8)] = TestPulse
				SealTestPntsADC *= 3200
				FIFOout[i,numpnts(FIFOout)-(StrlenSeq-i);StrlenSeq]=SealTestPntsADC[p/StrlenSeq]
				i += 1
			while(i < StrlenSeq)
		endif
		DigitalOutSeal1[0, 2] = 1
		DigitalOutSeal1[3, ] = 0
		FIFOout[i,numpnts(FIFOout)-(StrlenSeq-i);StrlenSeq]=DigitalOutSeal1[p/StrlenSeq]
	else
		do
			sscanf SeqADC[i], "%d", num_channel
			Wave SealTestPntsADC = $("root:Packages:tClamp18:SealTestPntsADC" + Num2str(num_channel))
			NVAR TestPulse = $("root:Packages:tClamp18:SealTestPulse" + Num2str(num_channel))
			SealTestPntsADC = 0
			SealTestPntsADC[trunc(npnts*0.2), trunc(npnts*0.8)] = TestPulse
			SealTestPntsADC *= 3200
			FIFOout[i,numpnts(FIFOout)-(StrlenSeq-i);StrlenSeq]=SealTestPntsADC[p/StrlenSeq]
			i += 1
		while(i < StrlenSeq)
	endif
end

Proc tClamp18SealStimAndSample()
	silent 1	// retrieving data...
	
	//Global Strings
	String SeqDAC = "root:Packages:tClamp18:SealITC18SeqDAC"
	String SeqADC = "root:Packages:tClamp18:SealITC18SeqADC"
	//Global Variables
	String Period = "root:Packages:tClamp18:SealITC18Period"
	String Flags = "root:Packages:tClamp18:SealITC18Flags"
	//Global Waves
	String FIFOout = "root:Packages:tClamp18:FIFOout"			//Out and In FIFO channel
	String FIFOin = "root:Packages:tClamp18:FIFOin"
	
	//body of macro
		
	ITC18SetAll 0,0,0,0,0,0					// bug!! don't pre-set Digital output channels. If they are set, all digial output channels will unintendedly fire.
	ITC18seq $SeqDAC, $SeqADC

	PauseUpdate

	ITC18StimandSample $FIFOout, $FIFOin, $Period, $Flags, 0
	tClamp18SealScalingDeinterleave()
   
      ResumeUpdate
endMacro

Function tClamp18SealScalingDeinterleave()
	SVAR SeqADC = root:Packages:tClamp18:SealITC18SeqADC
	NVAR StrlenSeq = root:Packages:tClamp18:SealITC18StrlenSeq
	
	Variable i = 0, num_channel = 0
	
	Wave FIFOin = $"root:Packages:tClamp18:FIFOin"
	
	do
		sscanf SeqADC[i], "%d", num_channel
			NVAR ADCRange = $("root:Packages:tClamp18:ADCRange"+ Num2str(num_channel))
			NVAR AmpGainADC = $("root:Packages:tClamp18:AmpGainADC" + Num2str(num_channel))
			NVAR ScalingFactorADC = $("root:Packages:tClamp18:ScalingFactorADC" + Num2str(num_channel))
			NVAR ADCOffset = $("root:Packages:tClamp18:ADCOffset" + Num2str(num_channel))
			NVAR InputOffset =  $("root:Packages:tClamp18:InputOffset"+ Num2str(num_channel))
			NVAR ADCValueVolt = $("root:Packages:tClamp18:ADCValueVolt" + Num2str(num_channel))
			NVAR ADCValuePoint = $("root:Packages:tClamp18:ADCValuePoint" + Num2str(num_channel))
	
			Wave SealTestADC = $("root:Packages:tClamp18:SealTestADC" +  Num2str(num_channel))
	
			SealTestADC[0, ] = (FIFOin[StrlenSeq * p + i] *(ADCRange/10)/3200 + ADCOffset*AmpGainADC + InputOffset) /(AmpGainADC*ScalingFactorADC)
		
			ADCValueVolt = FIFOin[i]/3200
			ADCValuePoint = FIFOin[i]
		i += 1
	while(i < StrlenSeq)
End

Function tClamp18PipetteUpdate()
	NVAR AcqTime = root:Packages:tClamp18:SealAcqTime
	
	Variable i = 0
	
	For(i=0;i<8;i+=1)
		NVAR bit = $("root:Packages:tClamp18:SealTestCheckADC" + Num2str(i))
		If(bit)
			NVAR ADCMode = $("root:Packages:tClamp18:ADCMode" + Num2str(i))
			NVAR SealTestPulse = $("root:Packages:tClamp18:SealTestPulse" + Num2str(i))
			NVAR PipetteR = $("root:Packages:tClamp18:PipetteR" + Num2str(i))
			SVAR CouplingDAC_ADC = $("root:Packages:tClamp18:CouplingDAC_ADC" + Num2str(i))
	
			Variable CommandSens = tClamp18CommandSensReturn(CouplingDAC_ADC, ADCMode)
					
			PipetteR = tClamp18PipetteR(i, ADCmode, SealTestPulse, CommandSens, AcqTime)
		endif
	endfor
end

Function tClamp18CommandSensReturn(CouplingDAC_ADC, ADCMode)
	String CouplingDAC_ADC
	Variable ADCMode

	NVAR VC_DAC0 = root:Packages:tClamp18:CommandSensVC_DAC0	
	NVAR CC_DAC0 = root:Packages:tClamp18:CommandSensCC_DAC0
	NVAR VC_DAC1 = root:Packages:tClamp18:CommandSensVC_DAC1
	NVAR CC_DAC1 = root:Packages:tClamp18:CommandSensCC_DAC1
	NVAR VC_DAC2 = root:Packages:tClamp18:CommandSensVC_DAC2
	NVAR CC_DAC2 = root:Packages:tClamp18:CommandSensCC_DAC2
	NVAR VC_DAC3 = root:Packages:tClamp18:CommandSensVC_DAC3
	NVAR CC_DAC3 = root:Packages:tClamp18:CommandSensCC_DAC3
	
	StrSwitch (CouplingDAC_ADC)
		case "0":
			If(ADCMode)
				return CC_DAC0
			else
				return VC_DAC0
			endif
			break
		case "1":
			If(ADCMode)
				return CC_DAC1
			else
				return VC_DAC1
			endif
			break
		case "2":
			If(ADCMode)
				return CC_DAC2
			else
				return VC_DAC2
			endif
			break
		case "3":
			If(ADCMode)
				return CC_DAC3
			else
				return VC_DAC3
			endif
			break		
		default:
			return NaN
			break
	endSwitch
end

Function tClamp18PipetteR(num_channel, mode, SealTestPulse, CommandSens, AcqTime)
	Variable num_channel, mode, SealTestPulse, CommandSens, AcqTime
	
	Wave SealTestADC = $("root:Packages:tClamp18:SealTestADC" + Num2str(num_channel))
	
	If(mode)
		return 1e-06*(mean(SealTestADC, 0.7*AcqTime, 0.75*AcqTime) - mean(SealTestADC, 0.1*AcqTime, 0.15*AcqTime))/(SealTestPulse*CommandSens*1e-12)
	else
		return 1e-06*(SealTestPulse*CommandSens*1e-03)/(mean(SealTestADC, 0.7*AcqTime, 0.75*AcqTime) - mean(SealTestADC, 0.1*AcqTime, 0.15*AcqTime))
	endif
end

Function tClamp18MainSealShowHide(ctrlName) : ButtonControl
	String ctrlName
	
	String SFL =""
	Variable i = 0

	do
		SFL = StringFromList(i, WinList("tClamp18SealTestADC*",";","WIN:1"))
		if(strlen(SFL) == 0)
			break
		endif
		StrSwitch(ctrlName)
			case "BttClampMainSealTestShow_tab2" :
				DoWindow/HIDE = 1 $SFL
				DoWindow/HIDE = 0 $SFL
				DoWindow/F $SFL
				break
			case "BttClampMainSealTestHide_tab2" :
				DoWindow/HIDE = 1 $SFL
				break
			default :
				break
		endSwitch
		i += 1
	while(1)
End

Function tClamp18MainSealTestCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	Variable num_channel
	
	sscanf ctrlName, "ChecktClampMainSealADC%f", num_channel
	If(checked)
		If(WinType("tClamp18SealTestADC"+Num2str(num_channel)) == 1)
			DoWindow/HIDE = ? $("tClamp18SealTestADC"+Num2str(num_channel))
			If(V_flag == 1)
				DoWindow/HIDE = 1 $("tClamp18SealTestADC"+Num2str(num_channel))
			else
				DoWindow/HIDE = 0/F $("tClamp18SealTestADC"+Num2str(num_channel))
			endif
		else	
			tClamp18NewSealTestADC(num_channel)
		endif
	else
		DoWindow/HIDE = 1 $("tClamp18SealTestADC"+Num2str(num_channel))
	endif
	
	tClamp18BitUpdate("root:Packages:tClamp18:SealTestCheckADC", "root:Packages:tClamp18:SealTestBit", 8)
	tClamp18SealStrSeqUpdate()
End

Function tClamp18SealStrSeqUpdate()
	NVAR Trig = root:Packages:tClamp18:SealITC18Trigout
	NVAR SealITC18StrlenSeq = root:Packages:tClamp18:SealITC18StrlenSeq

	SVAR SeqDAC = root:Packages:tClamp18:SealITC18SeqDAC
	SVAR SeqADC = root:Packages:tClamp18:SealITC18SeqADC
	
	SeqDAC = ""
	SeqADC = ""
	
	Variable i = 0
	For(i = 0; i < 8; i += 1)
		NVAR bit = $("root:Packages:tClamp18:SealTestCheckADC" + Num2str(i))
		SVAR CouplingDAC = $("root:Packages:tClamp18:CouplingDAC_ADC" + Num2str(i))
		bit = trunc(bit)
		If(bit)
			If(StringMatch(CouplingDAC, "none"))
				SeqDAC += "N"
			else
				SeqDAC += CouplingDAC
			endif
			SeqADC += Num2str(i)
		endif
	endFor
		
	Trig = trunc(Trig)
	If(Trig)
		SeqDAC += "D"
		SeqADC += "N"
	endif	
	
	SealITC18StrlenSeq = Strlen(SeqDAC)
	tClamp18UpDateSealFreqAcqTime()
end

Function tClamp18CheckSealTrigOut(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	tClamp18SealStrSeqUpdate()
End

Function tClamp18NewSealTestADC(num_channel)
	Variable num_channel

	NVAR SealTestFreq = root:Packages:tClamp18:SealTestFreq
	SVAR UnitADC = $("root:Packages:tClamp18:UnitADC" + Num2str(num_channel))
	Wave SealTestADC = $("root:Packages:tClamp18:SealTestADC" + Num2str(num_channel))
	SetScale/P x 0, (1/SealTestFreq), "s", SealTestADC
	Display/W=(99+27*num_channel,293-20*num_channel,375.75+27*num_channel,531.5-20*num_channel)/N=$("tClamp18SealTestADC"+Num2str(num_channel)) SealTestADC
	ModifyGraph live ($("SealTestADC" + Num2str(num_channel))) = 1
	Label left ("\\u"+UnitADC)
	ControlBar 40
	Button BtYPlus,pos={44, 0},size={20,20},proc=tClamp18GraphScale,title="+"
	Button BtYMinus,pos={44,19},size={20,20},proc=tClamp18GraphScale,title="-"
	Button BtXMinus,pos={1, 1},size={20,20},proc=tClamp18GraphScale,title="-"
	Button BtXPlus,pos={20, 1},size={20,20},proc=tClamp18GraphScale,title="+"
	SetVariable $("SetvarExpandSealGraph" + Num2str(num_channel)),pos={3,21},size={38,16},proc=tClamp18SetVarProcGraphExpand,title=" ",limits={0.5,8,0.5},value= $("root:Packages:tClamp18:SealExpand" + Num2str(num_channel))
	Button $("BttClampAutoscaleSealADC" +Num2str(num_channel)),pos={72,0},size={35,20},proc=tClamp18AscaleSealADC,title="Auto"
	Button $("BttClampFullscaleSealADC" +Num2str(num_channel)),pos={72,19},size={35,20},proc=tClamp18FscaleSealADC,title="Full"
	Button $("BttClampRunSealADC"+ Num2str(num_channel)),pos={112,0},size={35,20},proc=tClamp18SealTestBGRun,title="Run"
	Button $("BttClampAbortSealADC"+ Num2str(num_channel)),pos={112,19},size={35,20},proc=tClamp18BackGStop,title="Stop"
	Button $("BtClearTestPulse" + Num2str(num_channel)),pos={151,0},size={50,20},proc=tClamp18SealTestClear,title="DAC (V)",fColor=(32768,40704,65280)
	SetVariable $("SetvarSetSealTestPulse" + Num2str(num_channel)),pos={204,3},proc=tClamp18SetVarCheckCouplingADC,size={50,16},title=" ",limits={-10,10,0.01},value= $("root:Packages:tClamp18:SealTestPulse" + Num2str(num_channel))
	ValDisplay $("ValdispPipetteR" + Num2str(num_channel)),pos={152,20},size={100,19},title="Mƒ¶",fSize=18,limits={0,0,0},barmisc={0,1000},frame=5,value= #("root:Packages:tClamp18:PipetteR" + Num2str(num_channel))
	CheckBox $("ChecktClampSealLiveMode"+Num2str(num_channel)),pos={292,14},size={70,14},proc=tClamp18SealLiveModeCheckProc,title="Live mode",value= 1
	SetDrawLayer UserFront
End

Function tClamp18AscaleSealADC(ctrlName) : ButtonControl
	String ctrlName
	
	Variable num_channel
	sscanf ctrlName, "BttClampAutoscaleSealADC%f", num_channel
	NVAR SealTestFreq = root:Packages:tClamp18:SealTestFreq
	SVAR UnitADC = $("root:Packages:tClamp18:UnitADC" + Num2str(num_channel))
	Wave SealTestADC = $("root:Packages:tClamp18:SealTestADC" + Num2str(num_channel))
	SetScale/P x 0, (1/SealTestFreq), "s", SealTestADC
	SetAxis/A left
	Label left ("\\u"+UnitADC)
	SetAxis/A bottom
End

Function tClamp18FscaleSealADC(ctrlName) : ButtonControl
	String ctrlName
	
	Variable num_channel
	sscanf ctrlName, "BttClampFullscaleSealADC%f", num_channel
	NVAR SealTestFreq = root:Packages:tClamp18:SealTestFreq
	SVAR UnitADC = $("root:Packages:tClamp18:UnitADC" + Num2str(num_channel))
	Wave SealTestADC = $("root:Packages:tClamp18:SealTestADC" + Num2str(num_channel))
	SetScale/P x 0, (1/SealTestFreq), "s", SealTestADC
	SetAxis/A bottom
	Label left ("\\u"+UnitADC)
	
	NVAR ADCRange = $("root:Packages:tClamp18:ADCRange"+ Num2str(num_channel))
	NVAR AmpGainADC = $("root:Packages:tClamp18:AmpGainADC" + Num2str(num_channel))
	NVAR ScalingFactorADC = $("root:Packages:tClamp18:ScalingFactorADC" + Num2str(num_channel))
	NVAR ADCOffset = $("root:Packages:tClamp18:ADCOffset" + Num2str(num_channel))
	NVAR InputOffset =  $("root:Packages:tClamp18:InputOffset"+ Num2str(num_channel))
	
	Variable leftmax = (+1.024*ADCRange + ADCOffset*AmpGainADC + InputOffset) /(AmpGainADC*ScalingFactorADC)
	Variable leftmin = (-1.024*ADCRange + ADCOffset*AmpGainADC + InputOffset) /(AmpGainADC*ScalingFactorADC)
	SetAxis/A left leftmin, leftmax
end

Function tClamp18RescaleAllSealADC()
	NVAR SealTestFreq = root:Packages:tClamp18:SealTestFreq	
	Variable num_channel = 0
	
	do
		SVAR UnitADC = $("root:Packages:tClamp18:UnitADC" + Num2str(num_channel))
		Wave SealTestADC = $("root:Packages:tClamp18:SealTestADC" + Num2str(num_channel))
		SetScale/P x 0, (1/SealTestFreq), "s", SealTestADC
		If(WinType("tClamp18SealTestADC" + Num2str(num_channel)) == 1)
			Label/W = $("tClamp18SealTestADC" + Num2str(num_channel)) left ("\\u"+UnitADC)
		endif
		num_channel += 1
	while(num_channel <=7 )
End

Function tClamp18SealTestClear(ctrlName) : ButtonControl
	String ctrlName
	
	Variable num_channel
	sscanf ctrlName, "BtClearTestPulse%f", num_channel
	
	NVAR SealTestPulse = $("root:Packages:tClamp18:SealTestPulse" + Num2str(num_channel))
	
	If(SealTestPulse)
		SealTestPulse = 0
	else
		SealTestPulse = 0.25
	endif
	
	tClamp18SetVarCheckCouplingADC("",SealTestPulse,Num2str(SealTestPulse),("SealTestPulse" + Num2str(num_channel)))
End

Function tClamp18GraphScale(ctrlName) : ButtonControl
	String ctrlName
	
	Variable AX, AY, RX, RY
	
	GetAxis/Q bottom
	AX = V_min
	RX = V_max - V_min
	GetAxis/Q left
	AY = V_min
	RY = V_max - V_min

	StrSwitch (ctrlName)
		case "BtYPlus":
			SetAxis left (AY + 0.1 * RY), (AY + 0.9 * RY)
			break
		case "BtYMinus":
			SetAxis left (AY - 0.1 * RY), (AY + 1.1 * RY)
			break
		case "BtXPlus":
			SetAxis bottom (AX + 0.1 * RX), (AX + 0.9 * RX)
			break
		case "BtXMinus":
			SetAxis bottom (AX - 0.1 * RX), (AX + 1.1 * RX)
			break
		default:
			break
	endSwitch
End

Function tClamp18SealLiveModeCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	Variable num_channel
	sscanf ctrlName, "ChecktClampSealLiveMode%f", num_channel
	ModifyGraph live ($("SealTestADC" + Num2str(num_channel))) = checked
End

Function tClamp18CheckSealITC18Flags(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	NVAR SealITC18Flags = root:Packages:tClamp18:SealITC18Flags
	NVAR SealITC18ExtTrig = root:Packages:tClamp18:SealITC18ExtTrig
	NVAR SealITC18Output = root:Packages:tClamp18:SealITC18Output
	NVAR SealITC18Overflow = root:Packages:tClamp18:SealITC18Overflow
	NVAR SealITC18Reserved = root:Packages:tClamp18:SealITC18Reserved
	
	SealITC18Flags = tClamp18BitCoder(SealITC18ExtTrig, SealITC18Output, SealITC18Overflow, SealITC18Reserved, 0, 0, 0, 0)
End

Function tClamp18EditSealITC18Seq(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR SealITC18SeqDAC = root:Packages:tClamp18:SealITC18SeqDAC
	SVAR SealITC18SeqADC = root:Packages:tClamp18:SealITC18SeqADC
	NVAR SealITC18StrlenSeq = root:Packages:tClamp18:SealITC18StrlenSeq
	
	String DAC, ADC
	
	Prompt DAC "DACSeq"
	Prompt ADC "ADCSeq"
	DoPrompt "DAC and ADC must be in same length.", DAC, ADC
	If(V_flag)
		Abort
	endif
	
	If(Strlen(DAC) != Strlen(ADC))
		DoAlert 0, "Different length! DAC and ADC must be in same length."
		Abort
	endIf
	
	SealITC18SeqDAC = DAC
	SealITC18SeqADC = ADC
	SealITC18StrlenSeq = Strlen(SealITC18SeqDAC)
	
	tClamp18UpDateSealFreqAcqTime()
End

Function tClamp18SetVarProcSealFreq(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	tClamp18UpDateSealFreqAcqTime()
End

Function tClamp18UpDateSealFreqAcqTime()
	NVAR SealITC18StrlenSeq = root:Packages:tClamp18:SealITC18StrlenSeq
	NVAR SealITC18Period = root:Packages:tClamp18:SealITC18Period
	NVAR SealFreq = root:Packages:tClamp18:SealTestFreq
	NVAR SealSamplingNpnts = root:Packages:tClamp18:SealSamplingNpnts
	NVAR SealAcqTime = root:Packages:tClamp18:SealAcqTime
	
	SealFreq = 1/(1.25E-06*SealITC18Period*SealITC18StrlenSeq)	
	SealAcqTime = SealSamplingNpnts/SealFreq
	
	If(SealITC18StrlenSeq * SealFreq > 200000)
		DoAlert 0, "Too Much Freq!!"
	endif
	
	tClamp18RescaleAllSealADC()
end

Function tClamp18SealRedimension(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	NVAR SealITC18StrlenSeq = root:Packages:tClamp18:SealITC18StrlenSeq

	tClamp18_FolderCheck()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp18

	Wave FIFOout, FIFOin, SealTestPntsADC0, SealTestPntsADC1, SealTestPntsADC2, SealTestPntsADC3, SealTestPntsADC4, SealTestPntsADC5, SealTestPntsADC6, SealTestPntsADC7, SealTestADC0, SealTestADC1, SealTestADC2, SealTestADC3, SealTestADC4, SealTestADC5, SealTestADC6, SealTestADC7, DigitalOutSeal0, DigitalOutSeal1
	Redimension/N = (varNum) SealTestPntsADC0, SealTestPntsADC1, SealTestPntsADC2, SealTestPntsADC3, SealTestPntsADC4, SealTestPntsADC5, SealTestPntsADC6, SealTestPntsADC7, SealTestADC0, SealTestADC1, SealTestADC2, SealTestADC3, SealTestADC4, SealTestADC5, SealTestADC6, SealTestADC7, DigitalOutSeal0, DigitalOutSeal1
	Redimension/N = (varNum*SealITC18StrlenSeq) FIFOout, FIFOin
	
	tClamp18UpDateSealFreqAcqTime()

	SetDataFolder fldrSav0
End

//Seal Test End

///////////////////////////////////////////////////////////////////
// Stimulator

Function tClamp18PopMenuProcStimulator(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr

End

Function tClamp18SetVarProcStimulator(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	If(StringMatch(ctrlName, "SetvarStimulatorAcqTime_tab3"))
		tClamp18StimulatorTimeChanged()
	else
		tClamp18ApplyStimulatorSetting()
	endif
End

Function tClamp18StimulatorTimeChanged()
	NVAR Freq = root:Packages:tClamp18:StimulatorFreq
	NVAR SamplingNpnts =  root:Packages:tClamp18:StimulatorSamplingNpnts
	NVAR AcqTime = root:Packages:tClamp18:StimulatorAcqTime
	
	SamplingNpnts = AcqTime*Freq
	
	Wave DigitalOut1 = $"root:Packages:tClamp18:DigitalOut1"
	Wave FIFOOut = $"root:Packages:tClamp18:FIFOOut"
	Wave FIFOIn = $"root:Packages:tClamp18:FIFOIn"
	
	Redimension/N = (SamplingNpnts) DigitalOut1, FIFOOut, FIFOIn
End

Function tClamp18ApplyStimulatorSetting()
	NVAR StimulatorSamplingNpnts =  root:Packages:tClamp18:StimulatorSamplingNpnts
	Wave DigitalOut1 = $"root:Packages:tClamp18:DigitalOut1"
	Wave FIFOOut = $"root:Packages:tClamp18:FIFOOut"
	Wave FIFOIn = $"root:Packages:tClamp18:FIFOIn"
	
	Redimension/N = (StimulatorSamplingNpnts) DigitalOut1, FIFOOut, FIFOIn
	
	tClamp18UpDateStimFreqAndAcqT()
end

Function tClamp18UpDateStimFreqAndAcqT()
	NVAR StimulatorITC18Period = root:Packages:tClamp18:StimulatorITC18Period
	NVAR StimulatorFreq = root:Packages:tClamp18:StimulatorFreq
	NVAR StimulatorSamplingNpnts = root:Packages:tClamp18:StimulatorSamplingNpnts
	NVAR StimulatorAcqTime = root:Packages:tClamp18:StimulatorAcqTime
	
	StimulatorFreq = 1/(1.25E-06*StimulatorITC18Period)	
	StimulatorAcqTime = StimulatorSamplingNpnts/StimulatorFreq
	
	If(StimulatorFreq > 200000)
		DoAlert 0, "Too Much Freq!!"
	endif
	
	tClamp18RescaleDigitalOut1()
end

Function tClamp18RescaleDigitalOut1()
	NVAR StimulatorFreq = root:Packages:tClamp18:StimulatorFreq	
	Wave DigitalOut1 = $("root:Packages:tClamp18:DigitalOut1")
	SetScale/P x 0, (1/StimulatorFreq), "s", DigitalOut1
End

Function tClamp18StimulatorRun(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR ISI = root:Packages:tClamp18:TimerISI
	tClamp18ApplyStimulatorSetting()
	SetBackground  tClamp18StimulatorBGFlowControl()
	tClamp18TimerReset("")
	CtrlBackground period=ISI,dialogsOK=1,noBurst=1,start
End

Function tClamp18StimulatorBGFlowControl()
	NVAR ISI = root:Packages:tClamp18:StimulatorISI
	NVAR Counter = root:Packages:tClamp18:StimulatorCounter
	NVAR CounterLimit = root:Packages:tClamp18:StimulatorCounterLimit
	NVAR TimerISITicks = root:Packages:tClamp18:TimerISITicks
	
	Variable now = ticks

	If(ISI <= (now - TimerISITicks)|| Counter ==0)
		TimerISITicks = now

		tClamp18StimulatorMainProtocol()
		Execute/Q "tClamp18StimulatorStimAndSamlple()"
		
		Counter += 1
	endIf

	tClamp18TimerUpdate()
	
	If(Counter < CounterLimit || CounterLimit == 0)
		return 0
	else
		return 1
	endif
End

Function tClamp18StimulatorMainProtocol()
	Wave DigitalOut1 = $"root:Packages:tClamp18:DigitalOut1"	//Output Wave for DigitalOut1
	Wave FIFOOut = $"root:Packages:tClamp18:FIFOOut"

	DigitalOut1 = 0

	Variable i = 0
	For(i = 0; i < 4; i += 1)
		NVAR Delay = $("root:Packages:tClamp18:StimulatorDelay" + Num2str(i))
		NVAR Interval = $("root:Packages:tClamp18:StimulatorInterval" + Num2str(i))
		NVAR Train = $("root:Packages:tClamp18:StimulatorTrain" + Num2str(i))
		NVAR Duration = $("root:Packages:tClamp18:StimulatorDuration" + Num2str(i))

		Variable j = 0
		For(j = 0; j < Train; j += 1)
			Variable initialp = trunc((Delay + Interval*j)/deltax(DigitalOut1))
			Variable endp = initialp + trunc(Duration/deltax(DigitalOut1))
			DigitalOut1[initialp, endp] += 2^i
		endFor
	endFor

	FIFOOut = DigitalOut1
end

Proc tClamp18StimulatorStimAndSample()
	silent 1	// retrieving data...
	
	//Global Variables
	String Period = "root:Packages:tClamp18:StimulatorITC18Period"
	String Freq = "root:Packages:tClamp18:StimulatorFreq"
	//Global Waves	
	String FIFOout = "root:Packages:tClamp18:FIFOout"
	String FIFOin = "root:Packages:tClamp18:FIFOin"

	ITC18SetAll 0,0,0,0,0,0		// bug!! don't pre-set Digital output channels. If they are set, all digial output channels will unintendedly fire.
	ITC18seq "D", "N"

	PauseUpdate

	ITC18StimandSample $FIFOout, $FIFOin, $Period, 14, 0
    
      ResumeUpdate
endMacro

Function tClamp18UseStimulator()
	Wave DigitalOut1 = $"root:Packages:tClamp18:DigitalOut1"	//Output Wave for DigitalOut1
	DigitalOut1 = 0

	Variable i = 0
	For(i = 0; i < 4; i += 1)
		NVAR Delay = $("root:Packages:tClamp18:StimulatorDelay" + Num2str(i))
		NVAR Interval = $("root:Packages:tClamp18:StimulatorInterval" + Num2str(i))
		NVAR Train = $("root:Packages:tClamp18:StimulatorTrain" + Num2str(i))
		NVAR Duration = $("root:Packages:tClamp18:StimulatorDuration" + Num2str(i))

		Variable j = 0
		For(j = 0; j < Train; j += 1)
			Variable initialp = trunc((Delay + Interval*j)/deltax(DigitalOut1))
			Variable endp = initialp + trunc(Duration/deltax(DigitalOut1))
			DigitalOut1[initialp, endp] += 2^i
		endFor
	endFor
end

Function tClamp18StimulatorReset(ctrlName) : ButtonControl
	String ctrlName

	NVAR Counter = root:Packages:tClamp18:StimulatorCounter
	NVAR CounterLimit = root:Packages:tClamp18:StimulatorCounterLimit
	
	Counter = 0
	CounterLimit = 0
End

// Stimulator End

///////////////////////////////////////////////////////////////////
// Timer Panel

Function tClamp18_NewTimerPanel()
	NewPanel/N=tClamp18_TimerPanel/W=(12,57,291,154)
	ValDisplay ValdisptClampETime,pos={5,5},size={100,13},title="ET (s)",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:ElapsedTime"
	ValDisplay ValdisptClampTimeFromTick,pos={5,29},size={100,13},title="TTime (s)",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:TimeFromTick"
	ValDisplay ValdisptClampOscilloCounter,pos={5,55},size={100,13},title="Oscillo ",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:OscilloCounter"
	ValDisplay ValdisptClampSealCounter,pos={5,78},size={100,13},title="Seal",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:SealTestCounter"
	ValDisplay ValdisptClampStimCounter,pos={124,55},size={120,13},title="Stimulator",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp18:StimulatorCounter"
	SetVariable SetvartClampTimerISI,pos={124,3},size={120,16},limits={1,inf,1},title="TimerISI (tick)",value= root:Packages:tClamp18:TimerISI
	Button BttClampTimeStart,pos={124,25},size={50,20},proc=tClamp18TimerStart,title="Run"
	Button BttClampBackGStop,pos={174, 25},size={50,20},proc=tClamp18BackGStop,title="Stop"
	Button BttClampTimerReset,pos={224, 25},size={50,20},proc=tClamp18TimerReset,title="Reset"
end

Function tClamp18_DisplayTimer()
	If(WinType("tClamp18_TimerPanel") == 7)
		DoWindow/HIDE = ? $("tClamp18_TimerPanel")
		If(V_flag == 1)
			DoWindow/HIDE = 1 $("tClamp18_TimerPanel")
		else
			DoWindow/HIDE = 0/F $("tClamp18_TimerPanel")
		endif
	else	
		tClamp18_NewTimerPanel()
	endif
End

Function tClamp18_HideTimer()
	If(WinType("tClamp18_TimerPanel"))
		DoWindow/HIDE = 1 tClamp18_TimerPanel
	endif
End

Function tClamp18TimerUpdate()
	NVAR timefromtick = root:Packages:tClamp18:TimeFromTick
	NVAR elapsedtime = root:Packages:tClamp18:ElapsedTime
	Variable now
	Variable delta
	now = ticks/60
	delta = now - timefromtick
	elapsedtime += delta
	timefromtick = now
	return 0
end

Function tClamp18TimerStart(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR ElapsedTime = root:Packages:tClamp18:ElapsedTime
	NVAR TimeFromTick = root:Packages:tClamp18:TimeFromTick
	NVAR ISI = root:Packages:tClamp18:TimerISI
	TimeFromTick = ticks/60
	SetBackground tClamp18TimerUpdate()
	CtrlBackground period = ISI, dialogsOK = 1, noBurst = 1,start
End

Function tClamp18BackGStop(ctrlName) : ButtonControl
	String ctrlName
	
	CtrlBackground stop
	
	If(StringMatch(ctrlName, "BttClampBackGStop_tab1"))
		NVAR NumTrial = root:Packages:tClamp18:NumTrial
		NumTrial += 1
	endIf
End

Function tClamp18TimerReset(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR ElapsedTime = root:Packages:tClamp18:ElapsedTime
	NVAR TimeFromTick = root:Packages:tClamp18:TimeFromTick
	NVAR OscilloCounter = root:Packages:tClamp18:OscilloCounter
	NVAR SealTestCounter = root:Packages:tClamp18:SealTestCounter
	NVAR StimulatorCounter = root:Packages:tClamp18:StimulatorCounter
	NVAR TimerISITicks = root:Packages:tClamp18:TimerISITicks
	
	ElapsedTime = 0
	TimeFromTick = ticks/60
	TimerISITicks = ticks
	OscilloCounter = 0
	SealTestCounter = 0
	StimulatorCounter = 0
End

//end Timer Panel

///////////////////////////////////////////////////////////////////
// Utilites

Function tClamp18BitCoder(bit0, bit1, bit2, bit3, bit4, bit5, bit6, bit7)
	Variable bit0, bit1, bit2, bit3, bit4, bit5, bit6, bit7
	
	Variable vOut = 0

	bit0 = trunc(bit0)
	If(bit0)
		vOut += 2^0
	endif
	
	bit1 = trunc(bit1)
	If(bit1)
		vOut += 2^1
	endif
	
	bit2 = trunc(bit2)
	If(bit2)
		vOut += 2^2
	endif
	
	bit3 = trunc(bit3)
	If(bit3)
		vOut += 2^3
	endif

	bit4 = trunc(bit4)
	If(bit4)
		vOut += 2^4
	endif

	bit5 = trunc(bit5)
	If(bit5)
		vOut += 2^5
	endif

	bit6 = trunc(bit6)
	If(bit6)
		vOut += 2^6
	endif

	bit7 = trunc(bit7)
	If(bit7)
		vOut += 2^7
	endif

	return vOut
end

Function tClamp18BitUpdate(srcStr, destStr, ForTimes)
	String srcStr, destStr
	Variable ForTimes

	NVAR vOut = $destStr
	vOut = 0
	
	Variable i = 0
	For(i = 0; i < ForTimes; i +=1)
		NVAR bit = $(srcStr + Num2str(i))
		bit = trunc(bit)
		If(bit)
			vOut += 2^i
		endif
	endfor
end