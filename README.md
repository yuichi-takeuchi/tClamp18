# tClamp18
tClamp18 offers a series of Igor Pro GUIs for data acquision via an InstruTECH ITC-18 AD/DA board. tClamp18 is optimized for whole-cell patch-clamp recordings in voltage- and current-clamp modes but it may be used for general data acquision purposes as well. tClamp18 is quite flexible in channel settings harnessing 8 ADCs and 4 DACs with any kinds of amplifiers from different manufactures (Axon, HEKA, Werner, DAGAN, Nihon Kohden etc.). tClamp18 is also very flexible in stimulus protocol: up to 4 analog waveforms made in Igor Pro and 4 digital outputs can be combined at 5 micro second resolution with an intuitive virtual 4 channel stimulator. Thus, tClamp18 is an ideal solution for simultaneous multi-cellular whole-cell recordings with several patch-clamp amplifiers with untypical complex stimulus protocol. tClamp18 is similar to the pClamp software (Axon) and the PatchMaster software (HEKA), but superior to them in the sense of flexibility and its cost. tClamp18 does not implement telegraph functions, so experimenters need to be careful not to forget switching gain settings when you change amplifier gain during experiments.

## Getting Started

### Prerequisites
* IGOR Pro 6 (https://www.wavemetrics.com/)
* InstruTECH ITC-18 and a host interface (http://www.heka.com/products/products_main.html#acq_itc18)
* Driver software of ITC-18 (http://www.heka.com/downloads/downloads_main.html#down_acq)
* ITC-18 XOP for Igor Pro 6.x (ITC18_X86_V76.XOP) (http://www.heka.com/downloads/downloads_main.html#down_xops)

This code has been tested in Igor Pro version 6.3.7.2. for Windows and supposed to work in Igor Pro 6.1 or later.
This code is supposed to work for Windows Vista, 7, 8, 10 and Mac X also, but tested only in Windows XP and 7.
This code is supposed to work any host interfaces (PCI-18, PCI-18V3, or USB-18), but has been tested only with USB-18.

### Installing
#### Hardware
* under construction

#### Software
* under construction

#### Test with demo files
* under construction

## How to setup your recording system with tClamp18
### DAC ADC Settings: input and output gain settings for each channel
* under construction
* template
* examples

### Oscilloscope (OSC) Protocols: stimulus and recording settings
* under construction
* template
* examples

### Stimulator Protocols: 
* under construction
* template
* examples

## Work flow
### Initialize your experiment
* Launch your Igor Pro.
* Initialize tClamp18 by clicking "tClampInitialize" in Initialize submenu of tClamp18 menu.
* Select a DAC ADC setting in tClamp18 menu.
* Select a Oscillo Protocol in tClamp18 menu.
* Select a Stimulator Protocol in tClamp menu, if you want to use it.

#### Example of Initialization Macro
It is very convenient if the above initialization processes are automated.
* StimTTLPrep.ipf
Select "StimTTLPrep" in Macros menu.
* StimTTLPrep.ipf depends on tClamp18_SettingEPC7PLUS_700A.ipf, tClamp18_PairedPulseStimulation.ipf, tClamp18_E7PM7A_TTL_Stim.ipf files, which can be found in expample zips.

### Seal test
* under construction

### Voltage-clamp recordings
* under construction

### Current-clamp recordings
* under construction

### Saving your waves and experiments
* under construction

## Help
* Click "Help" in tClamp18 menu.

## DOI

## Versioning
We use [SemVer](http://semver.org/) for versioning.

## Releases
* Prerelease, 2017/06/06

## Authors
* **Yuichi Takeuchi PhD** - *Initial work* - [GitHub](https://github.com/yuichi-takeuchi)
* Affiliation: Department of Physiology, University of Szeged, Hungary
* E-mail: yuichi-takeuchi@umin.net

## License
This project is licensed under the MIT License.

## Acknowledgments
* Department of Physiology, Tokyo Women's Medical University, Tokyo, Japan
* Department of Information Physiology, National Institute for Physiological Sciences, Okazaki, Japan

## References
tClamp18 has been used for the following works:

* Takeuchi Y, Yamasaki M, Nagumo Y, Imoto K, Watanabe M, Miyata M (2012) Rewiring of afferent fibers in the somatosensory thalamus of mice caused by peripheral sensory nerve transection. J Neurosci 32:6917-6930.
* Takeuchi Y, Asano H, Katayama Y, Muragaki Y, Imoto K, Miyata M (2014) Large-scale somatotopic refinement via functional synapse elimination in the sensory thalamus of developing mice. J Neurosci 34:1258-1270.
* Takeuchi Y, Osaki H, Yagasaki Y, Katayama Y, Miyata M (2017) Afferent Fiber Remodeling in the Somatosensory Thalamus of Mice as a Neural Basis of Somatotopic Reorganization in the Brain and Ectopic Mechanical Hypersensitivity after Peripheral Sensory Nerve Injury. eNeuro 4:e0345-0316.
