#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Menu "tClamp18"
	SubMenu "DAC ADC Settings"
"Setting A", tClampSettingTemplateA()
	End
End

Function tClampSettingTemplateA()
	tClamp18_FolderCheck()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp18

	//DAC0
	Variable/G CommandSensVC_DAC0 = 1
	Variable/G CommandSensCC_DAC0 = 1

	//DAC1
	Variable/G CommandSensVC_DAC1 = 1
	Variable/G CommandSensCC_DAC1 = 1

	//DAC2
	Variable/G CommandSensVC_DAC2 = 1
	Variable/G CommandSensCC_DAC2 = 1	

	//DAC3
	Variable/G CommandSensVC_DAC3 = 1
	Variable/G CommandSensCC_DAC3 = 1

	//ADC0
	Variable/G ADCMode0 = 0
	Variable/G SealTestPulse0 = 0.25

	//ADC0 VC
	Variable/G ADCRangeVC0 = 10
	Variable/G AmpGainADCVC0 = 1
	Variable/G ScalingFactorADCVC0 = 1e+09
	String/G LabelADCVC0 = "ADCVC0"
	String/G UnitADCVC0 = "A"
	String/G AmpGainListADCVC0 = "1;2;5;10;20;50;100;200;500;1000:2000"
	String/G CouplingDAC_ADCVC0 = "none"
	String/G CouplingADC_ADCVC0 = "none"

	//ADC0 CC
	Variable/G ADCRangeCC0 = 10
	Variable/G AmpGainADCCC0 = 1
	Variable/G ScalingFactorADCCC0 = 1
	String/G LabelADCCC0 = "ADC0 CC"
	String/G UnitADCCC0 = "V"
	String/G AmpGainListADCCC0 = "1;2;5;10;20;50;100;200;500;1000;2000"
	String/G CouplingDAC_ADCCC0 = "none"
	String/G CouplingADC_ADCCC0 = "none"

	//ADC1
	Variable/G ADCMode1 = 0
	Variable/G SealTestPulse1 = 0.25

	//ADC1 VC
	Variable/G ADCRangeVC1 = 10
	Variable/G AmpGainADCVC1 = 1
	Variable/G ScalingFactorADCVC1 = 1e+09
	String/G LabelADCVC1 = "ADC1 VC"
	String/G UnitADCVC1 = "A"
	String/G AmpGainListADCVC1 = "1;2;5;10;20;50;100;200;500;1000:2000"
	String/G CouplingDAC_ADCVC1 = "none"
	String/G CouplingADC_ADCVC1 = "none"

	//ADC1 CC
	Variable/G ADCRangeCC1 = 10
	Variable/G AmpGainADCCC1 = 1
	Variable/G ScalingFactorADCCC1 = 1
	String/G LabelADCCC1 = "ADC1 CC"
	String/G UnitADCCC1 = "V"
	String/G AmpGainListADCCC1 = "1;2;5;10;20;50;100;200;500;1000;2000"
	String/G CouplingDAC_ADCCC1 = "none"
	String/G CouplingADC_ADCCC1 = "none"

	//ADC2
	Variable/G ADCMode2 = 0
	Variable/G SealTestPulse2 = 0.25

	//ADC2 VC
	Variable/G ADCRangeVC2 = 10
	Variable/G AmpGainADCVC2 = 1
	Variable/G ScalingFactorADCVC2 = 1e+09
	String/G LabelADCVC2 = "ADC2 VC"
	String/G UnitADCVC02= "A"
	String/G AmpGainListADCVC2 = "1;2;5;10;20;50;100;200;500;1000:2000"
	String/G CouplingDAC_ADCVC2 = "none"
	String/G CouplingADC_ADCVC2 = "none"

	//ADC2 CC
	Variable/G ADCRangeCC2 = 10
	Variable/G AmpGainADCCC2 = 1
	Variable/G ScalingFactorADCCC2 = 1
	String/G LabelADCCC2 = "ADC2 CC"
	String/G UnitADCCC2 = "V"
	String/G AmpGainListADCCC2 = "1;2;5;10;20;50;100;200;500;1000;2000"
	String/G CouplingDAC_ADCCC2 = "none"
	String/G CouplingADC_ADCCC2 = "none"

	//ADC3
	Variable/G ADCMode3 = 0
	Variable/G SealTestPulse3 = 0.25

	//ADC3 VC
	Variable/G ADCRangeVC3 = 10
	Variable/G AmpGainADCVC3 = 1
	Variable/G ScalingFactorADCVC3 = 1e+09
	String/G LabelADCVC3 = "ADC3 VC"
	String/G UnitADCVC3 = "A"
	String/G AmpGainListADCVC3 = "1;2;5;10;20;50;100;200;500;1000:2000"
	String/G CouplingDAC_ADCVC3 = "none"
	String/G CouplingADC_ADCVC3 = "none"

	//ADC3 CC
	Variable/G ADCRangeCC3 = 10
	Variable/G AmpGainADCCC = 1
	Variable/G ScalingFactorADCCC3 = 1
	String/G LabelADCCC3 = "ADC3 CC"
	String/G UnitADCCC3 = "V"
	String/G AmpGainListADCCC3 = "1;2;5;10;20;50;100;200;500;1000;2000"
	String/G CouplingDAC_ADCCC3 = "none"
	String/G CouplingADC_ADCCC3 = "none"

	//ADC4
	Variable/G ADCMode4 = 0
	Variable/G SealTestPulse4 = 0.25

	//ADC4 VC
	Variable/G ADCRangeVC4 = 10
	Variable/G AmpGainADCVC4 = 1
	Variable/G ScalingFactorADCVC4 = 1e+09
	String/G LabelADCVC4 = "ADC4 VC"
	String/G UnitADCVC4 = "A"
	String/G AmpGainListADCVC4 = "1;2;5;10;20;50;100;200;500;1000:2000"
	String/G CouplingDAC_ADCVC4 = "none"
	String/G CouplingADC_ADCVC4 = "none"

	//ADC4 CC
	Variable/G ADCRangeCC4 = 10
	Variable/G AmpGainADCCC4 = 1
	Variable/G ScalingFactorADCCC4 = 1
	String/G LabelADCCC4 = "ADC4 CC"
	String/G UnitADCCC4 = "V"
	String/G AmpGainListADCCC4 = "1;2;5;10;20;50;100;200;500;1000;2000"
	String/G CouplingDAC_ADCCC4 = "none"
	String/G CouplingADC_ADCCC4 = "none"

	//ADC5
	Variable/G ADCMode5 = 0
	Variable/G SealTestPulse5 = 0.25

	//ADC5 VC
	Variable/G ADCRangeVC5 = 10
	Variable/G AmpGainADCVC5 = 1
	Variable/G ScalingFactorADCVC5 = 1e+09
	String/G LabelADCVC5 = "ADC5 VC"
	String/G UnitADCVC5 = "A"
	String/G AmpGainListADCVC5 = "1;2;5;10;20;50;100;200;500;1000:2000"
	String/G CouplingDAC_ADCVC5 = "none"
	String/G CouplingADC_ADCVC5 = "none"

	//ADC5 CC
	Variable/G ADCRangeCC5 = 10
	Variable/G AmpGainADCCC5 = 1
	Variable/G ScalingFactorADCCC5 = 1
	String/G LabelADCCC5 = "ADC5 CC"
	String/G UnitADCCC5 = "V"
	String/G AmpGainListADCCC5 = "1;2;5;10;20;50;100;200;500;1000;2000"
	String/G CouplingDAC_ADCCC5 = "none"
	String/G CouplingADC_ADCCC5 = "none"

	//ADC6
	Variable/G ADCMode6 = 0
	Variable/G SealTestPulse6 = 0.25

	//ADC6 VC
	Variable/G ADCRangeVC6 = 10
	Variable/G AmpGainADCVC6 = 1
	Variable/G ScalingFactorADCVC6 = 1e+09
	String/G LabelADCVC6 = "ADC6 VC"
	String/G UnitADCVC6 = "A"
	String/G AmpGainListADCVC6 = "1;2;5;10;20;50;100;200;500;1000:2000"
	String/G CouplingDAC_ADCVC6 = "none"
	String/G CouplingADC_ADCVC6 = "none"

	//ADC6 CC
	Variable/G ADCRangeCC6 = 10
	Variable/G AmpGainADCCC6 = 1
	Variable/G ScalingFactorADCCC6 = 1
	String/G LabelADCCC6 = "ADC6 CC"
	String/G UnitADCCC6 = "V"
	String/G AmpGainListADCCC6 = "1;2;5;10;20;50;100;200;500;1000;2000"
	String/G CouplingDAC_ADCCC6 = "none"
	String/G CouplingADC_ADCCC6 = "none"

	//ADC7
	Variable/G ADCMode7 = 0
	Variable/G SealTestPulse7 = 0.25

	//ADC7 VC
	Variable/G ADCRangeVC7 = 10
	Variable/G AmpGainADCVC7 = 1
	Variable/G ScalingFactorADCVC7 = 1e+09
	String/G LabelADCVC7 = "ADCVC7"
	String/G UnitADCVC7 = "A"
	String/G AmpGainListADCVC7 = "1;2;5;10;20;50;100;200;500;1000:2000"
	String/G CouplingDAC_ADCVC7 = "none"
	String/G CouplingADC_ADCVC7 = "none"

	//ADC7 CC
	Variable/G ADCRangeCC7 = 10
	Variable/G AmpGainADCCC7 = 1
	Variable/G ScalingFactorADCCC7 = 1
	String/G LabelADCCC7 = "ADC7 CC"
	String/G UnitADCCC7 = "V"
	String/G AmpGainListADCCC7 = "1;2;5;10;20;50;100;200;500;1000;2000"
	String/G CouplingDAC_ADCCC7 = "none"
	String/G CouplingADC_ADCCC7 = "none"

	tClamp18SetChannelMode()

	tClamp18PrepWindows(1, 1) // tClamp18PrepWindows(bitDAC, bitADC)
	tClamp18MoveWinXXXX()
	SetDataFolder fldrSav0
	tClamp18SetChannelMode()
End

Function tClamp18MoveWinXXXX()
	MoveWindow/W=tClamp18_TimerPanel 800,7,1020,85
	MoveWindow/W=tClamp18DAC0 193.5, 743, 438.75, 815
	MoveWindow/W=tClamp18ADC0 58.5, 564.5, 283.5, 714.5
	MoveWindow/W=tClamp18OscilloADC0 28.5,151.25,305.25,389.75
	MoveWindow/W=tClamp18SealTestADC0 28.5,297.5,305.25,536
End


